#!/usr/bin/env perl

package main;

use 5.010;
use strict;
use warnings FATAL => 'all';
use English qw(-no_match_vars);
use sigtrap 'handler', \&stop, 'normal-signals';

use Carp    ();
use FindBin ();
use lib "$FindBin::Bin/lib";
use DBI;
use Parallel::ForkManager;
use Time::HiRes ();
use Try::Tiny;

use Log::Log4perl qw/:easy/;
use Log::Any qw($log);
use Log::Any::Adapter;

Log::Log4perl::init("$FindBin::Bin/conf/log4perl.conf");
Log::Any::Adapter->set('Log4perl');

local $SIG{__WARN__} = sub { $log->info(qq{[main:${PROCESS_ID}] @_}) };

use Configurator;
use Zabbix::Discoverer;
use Zabbix::Sender;

our $VERSION = '1.101';

if ( !@ARGV ) {
    Carp::confess 'Usage: perl ZabbixDBA.pl /path/to/config.pl &';
}

my ($confile) = @ARGV;

my $running = 1;
my ( $conf, $sender, $dbpool );

sub stop {
    $running = 0;
    $log->infof( q{[main:%d] stopping ZabbixDBA monitoring plugin},
        $PROCESS_ID );
    for ( keys %{$dbpool} ) {
        $log->infof( q{[dbi] disconnecting from '%s'}, $_ );
        $dbpool->{$_}->disconnect;
    }
    return 1;
}

my $discovery = Zabbix::Discoverer->new();
my $pm        = Parallel::ForkManager->new(20);

$pm->run_on_finish(
    sub {
        if ( $_[5] ) {
            delete $dbpool->{ $_[5]->{db} };
        }
    }
);

$log->infof( q{[main:%d] starting ZabbixDBA monitoring plugin}, $PROCESS_ID );

while ($running) {

    # Reloading configuration file to see if
    # values were changed (no need to restart daemon)
    try {
        $conf = Configurator->new($confile);
    }
    catch {
        $log->errorf( q{[configurator] %s}, $_ );
        Carp::confess $_;
    };

    $pm->set_max_procs( $conf->{daemon}->{maxproc} // 20 );

    try {
        $sender = Zabbix::Sender->new( map { $conf->{$_} }
                @{ $conf->{zabbix_server_list} } );
    }
    catch {
        $log->errorf( q{[sender] %s}, $_ );
        Carp::confess $_;
    };

    for my $db ( @{ $conf->{database_list} } ) {
        if ( !$conf->{$db} || !$conf->{$db}->{dsn} ) {
            $log->warnf(
                q{[configurator] configuration of '%s' is not described in '%s'},
                $db, $confile
            );
            next;
        }

        if ( !$dbpool->{$db} ) {
            $dbpool->{$db} = get_connection($db) or next;
        }

        $dbpool->{$db}->ping();

        if ( $dbpool->{$db}->errstr() ) {
            $log->errorf( q{[dbi] connection lost contact for '%s' : %s},
                $db, $dbpool->{$db}->errstr() );
            $dbpool->{$db} = get_connection($db) or next;
        }

        try {
            $sender->send( [ $db, 'alive', 1 ] );
        }
        catch {
            $log->warnf( q{[sender] %s}, $_ );
        };

        my $ql;

        try {
            $ql
                = Configurator->new( $conf->{$db}->{query_list_file}
                    // $conf->{default}->{query_list_file} );
        }
        catch {
            $log->errorf( q{[configurator] %s}, $_ );
            return;

            # Try::Tiny is acting like a subroutine,
            # so we need to check return value outside of it
            # otherwise Perl will raise warning on next used inside of sub
        } or next;

        if ( $conf->{$db}->{extra_query_list_file} ) {
            my $eql;

            try {
                $eql = Configurator->new(
                    $conf->{$db}->{extra_query_list_file} );
            }
            catch {
                $log->errorf( q{[configurator] %s}, $_ );
            };

            $ql->merge($eql);
        }

        # Starting fork() of main code
        # -----------------------------------------------------------
        $pm->start() and next;

        my $dbh = $dbpool->{$db}->clone();
        if ( !$dbh ) {
            $log->errorf( q{[dbi] method 'clone' failed for '%s'}, $db );
            $pm->finish( 0, { db => $db } );
        }

        my $start = [Time::HiRes::gettimeofday];
        my @data;
        while ( my ( $rule, $v ) = each %{ $ql->{discovery}->{rule} } ) {
            my $result
                = $dbh->selectall_arrayref( $v->{query}, { Slice => {} } );

            if ( $dbh->errstr() ) {
                $log->errorf( q{[dbi] %s => %s : %s},
                    $db, $rule, $dbh->errstr() );
                next;
            }
            if ( defined $result ) {
                push @data,
                    $discovery->rule( $db, $rule, $result, $v->{keys} );
            }
        }

        while ( my ( $item, $v ) = each %{ $ql->{discovery}->{item} } ) {
            my $result
                = $dbh->selectall_arrayref( $v->{query}, { Slice => {} } );
            if ( $dbh->errstr() ) {
                $log->errorf( q{[dbi] %s => %s : %s},
                    $db, $item, $dbh->errstr() );
                next;
            }
            if ( defined $result ) {
                push @data,
                    $discovery->item( $db, $item, $result, $v->{keys} );
            }
        }

        for my $query ( @{ $ql->{query_list} } ) {
            if ( !$ql->{$query} ) {
                next;
            }
            my $result = $dbh->selectrow_arrayref( $ql->{$query}->{query},
                undef, @{ $ql->{$query}->{bind_values} } );

            if ( $dbh->errstr() ) {
                $log->error( sprintf q{[dbi] %s => %s : %s},
                    $db, $query, $dbh->errstr() );
                next;
            }

            $result = join q{ }, map { $_ // () } @{$result};

            if ( !defined $result || !length $result ) {
                $result = $ql->{$query}->{no_data_found} // next;
            }

            if ( $ql->{$query}->{send_to} ) {
                push @data, [ $_, $query, $result ]
                    for @{ $ql->{$query}->{send_to} };
            }
            else {
                push @data, [ $db, $query, $result ];
            }
        }

        # Issuing rollback due to some internal DBI methods
        # that require commit/rollback after using Slice in fetch
        $dbh->rollback();

        try {
            $sender->send(@data);
        }
        catch {
            $log->warnf( q{[sender] %s}, $_ );
        };

        undef @data;
        $log->infof(
            q{[fork:%d] completed fetching data on '%s', elapsed: %s},
            $PROCESS_ID,
            $db,
            Time::HiRes::tv_interval( $start, [Time::HiRes::gettimeofday] )
        );
        $pm->finish(1);

        # -----------------------------------------------------------
    }

    $pm->wait_all_children();

    sleep( $conf->{daemon}->{sleep} // 120 );
}

sub get_connection {
    my ($db) = @_;
    my $opts = {
        PrintError => 0,
        RaiseError => 0,
        AutoCommit => 0,
        AutoInactiveDestroy =>
            1,    # useful when perfroming fork() for DB connections,
                  # see more in DBI documentation
    };

    my $user = $conf->{$db}->{user}     // $conf->{default}->{user};
    my $pass = $conf->{$db}->{password} // $conf->{default}->{password};

    my $dbh
        = DBI->connect_cached( $conf->{$db}->{dsn}, $user, $pass, $opts );

    my $alive = 1;

    if ( DBI->errstr() ) {
        $log->errorf( q{[dbi] connection failed for '%s@%s' : %s},
            $user, $db, DBI->errstr() );
        $alive = 0;
    }

    try {
        $sender->send( [ $db, 'alive', $alive ] );
    }
    catch {
        $log->warnf( q{[sender] %s}, $_ );
    };

    if ($alive) {
        $log->infof( q{[dbi] connected to '%s@%s' (%s)},
            $user, $db, $conf->{$db}->{dsn} );
    }

    return $dbh;
}

1;
