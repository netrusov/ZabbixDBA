#!/usr/bin/env perl

use 5.010;
use strict;
use warnings;
use English qw(-no_match_vars);
use Carp qw(confess carp);
use FindBin qw($Bin);
use lib $Bin;

use DBI;
use Parallel::ForkManager;

use Log::Any qw($log);
use Log::Any::Adapter ( 'File', $PROGRAM_NAME . '.log' );
use Time::HiRes qw(gettimeofday tv_interval);
use Try::Tiny;

use ZabbixDBA::Configurator;
use ZabbixDBA::Discoverer;
use ZabbixDBA::Sender;

our $VERSION = '1.100';

if ( scalar @ARGV < 2 ) {
    confess 'Usage: perl bootstrap.pl start /path/to/config.pl &';
}

my ( $command, $confile ) = @ARGV;

if ( $command !~ m/start/msi ) {
    confess 'Usage: perl bootstrap.pl start /path/to/config.pl &';
}
my $running = 1;

local $SIG{INT}  = \&stop;
local $SIG{HUP}  = \&stop;
local $SIG{ALRM} = \&stop;
local $SIG{USR1} = \&stop;

my ( $conf, $sender, $dbpool );
my $discovery = ZabbixDBA::Discoverer->new();

my $pm = Parallel::ForkManager->new(20);

$pm->run_on_finish(
    sub {
        if ( $_[5] ) {
            delete $dbpool->{ $_[5]->{db} };
        }
    }
);

$log->infof( q{[INFO][main:%d] starting ZabbixDBA monitoring plugin},
    $PROCESS_ID );

while ($running) {

    # Reloading configuration file to see if
    # values were changed (no need to restart daemon)
    try {
        $conf = ZabbixDBA::Configurator->new($confile);
    }
    catch {
        $log->errorf( q{[ERROR][configurator] %s}, $_ );
        confess $_;
    };

    $pm->set_max_procs( $conf->{daemon}->{maxproc} // 20 );

    try {
        $sender = ZabbixDBA::Sender->new( map { $_ => $conf->{$_} }
                @{ $conf->{zabbix_server_list} } );
    }
    catch {
        $log->errorf( q{[ERROR][configurator] %s}, $_ );
        confess $_;
    };

    for my $db ( @{ $conf->{database_list} } ) {
        if ( !$conf->{$db} || !$conf->{$db}->{dsn} ) {
            $log->warnf(
                q{[WARN][configurator] configuration of '%s' is not described in '%s'},
                $db, $confile
            );
            next;
        }

        if ( !$dbpool->{$db} ) {
            $dbpool->{$db} = get_connection($db) or next;
        }

        $dbpool->{$db}->ping();

        if ( $dbpool->{$db}->errstr() ) {
            $log->errorf(
                q{[ERROR][dbi] connection lost contact for '%s' : %s},
                $db, $dbpool->{$db}->errstr() );
            $dbpool->{$db} = get_connection($db) or next;
        }

        try {
            $sender->send( [ $db, 'alive', 1 ] );
        }
        catch {
            $log->warnf( q{[WARN][sender] %s}, $_ );
        };

        my $ql;

        try {
            $ql
                = ZabbixDBA::Configurator->new(
                $conf->{$db}->{query_list_file}
                    // $conf->{default}->{query_list_file} );
        }
        catch {
            $log->errorf( q{[ERROR][configurator] %s}, $_ );
            return;

            # Try::Tiny is acting like a subroutine,
            # so we need to check return value outside of it
            # otherwise Perl will raise warning on next used inside of sub
        } or next;

        if ( $conf->{$db}->{extra_query_list_file} ) {
            my $eql;

            try {
                $eql = ZabbixDBA::Configurator->new(
                    $conf->{$db}->{extra_query_list_file} );
            }
            catch {
                $log->errorf( q{[ERROR][configurator] %s}, $_ );
            };

            $ql->merge($eql);
        }

        $pm->start() and next;

        # Starting fork() of main code
        # -----------------------------------------------------------
        my $dbh = $dbpool->{$db}->clone();
        if ( !$dbh ) {
            $log->errorf( q{[ERROR][dbi] method 'clone' failed for '%s'},
                $db );
            $pm->finish( 0, { db => $db } );
        }
        my $start = [gettimeofday];
        my @data;
        while ( my ( $rule, $v ) = each %{ $ql->{discovery}->{rule} } ) {
            my $result
                = $dbh->selectall_arrayref( $v->{query}, { Slice => {} } );

            if ( $dbh->errstr() ) {
                $log->errorf( q{[ERROR][dbi] %s => %s : %s},
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
                $log->errorf( q{[ERROR][dbi] %s => %s : %s},
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
            my $result
                = $dbh->selectrow_arrayref( $ql->{$query}->{query} );

            if ( $dbh->errstr() ) {
                $log->error( sprintf q{[ERROR][dbi] %s => %s : %s},
                    $db, $query, $dbh->errstr() );
                next;
            }

            if ( !defined $result || !@{$result} ) {
                $result = $ql->{$query}->{no_data_found} // next;
            }
            else {
                $result = join q{ }, @{$result};
            }

            push @data, [ $ql->{$query}->{send_to} // $db, $query, $result ];
        }

        # Issuing rollback due to some internal DBI methods
        # that require commit/rollback after using Slice in fetch
        $dbh->rollback();

        try {
            $sender->send(@data);
        }
        catch {
            $log->warnf( q{[WARN][sender] %s}, $_ );
        };

        undef @data;
        $log->infof(
            q{[INFO][fork:%d] completed fetching data on '%s', elapsed: %s},
            $PROCESS_ID, $db, tv_interval( $start, [gettimeofday] ) );

        $pm->finish(1);

        # -----------------------------------------------------------
    }

    $pm->wait_all_children();

    sleep $conf->{daemon}->{sleep};
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
        $log->errorf( q{[ERROR][dbi] connection failed for '%s@%s' : %s},
            $user, $db, DBI->errstr() );
        $alive = 0;
    }

    try {
        $sender->send( [ $db, 'alive', $alive ] );
    }
    catch {
        $log->warnf( q{[WARN][sender] %s}, $_ );
    };

    if ($alive) {
        $log->infof( q{[INFO][dbi] connected to '%s@%s' (%s)},
            $user, $db, $conf->{$db}->{dsn} );
    }

    return $dbh;
}

sub stop {
    $running = 0;
    $log->infof( q{[INFO][main:%d] stopping ZabbixDBA monitoring plugin},
        $PROCESS_ID );
    for ( keys %{$dbpool} ) {
        $log->infof( q{[INFO][dbi] disconnecting from '%s'}, $_ );
        $dbpool->{$_}->disconnect;
    }
    return 1;
}
