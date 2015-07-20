#!/usr/bin/env perl

use 5.010;
use strict;
use warnings;
use English qw(-no_match_vars);
use Carp qw(confess carp);

use DBI;
use Parallel::ForkManager;

use JSON qw(encode_json);
use Try::Tiny;
use Time::HiRes qw(gettimeofday tv_interval);

use FindBin qw($Bin);
use lib $Bin;

use Log::Any qw($log);
use Log::Any::Adapter ( 'File', $PROGRAM_NAME . '.log' );

use ZabbixDBA::Configurator;
use ZabbixDBA::Sender;

our $VERSION = '1.011';

if ( scalar @ARGV < 2 ) {
    confess 'Usage: perl bootstrap.pl start /path/to/config.pl';
}

my ( $command, $confile ) = @ARGV;

if ( $command ne 'start' ) {
    confess 'Usage: perl bootstrap.pl start /path/to/config.pl';
}
my $running = 1;

local $SIG{INT}  = \&stop;
local $SIG{HUP}  = \&stop;
local $SIG{ALRM} = \&stop;
local $SIG{USR1} = \&stop;

my $pm = Parallel::ForkManager->new(20);
my ( $conf, $sender, $dbpool );

$log->info('Starting');

while ($running) {

    # Reloading configuration file to see if
    # values were changed (no need to restart daemon)
    try {
        $conf = ZabbixDBA::Configurator->new($confile);
    }
    catch {
        $log->errorf( q{[configuration] %s}, $_ );
        confess $_;
    };

    $pm->set_max_procs( $conf->{daemon}->{maxproc} // 20 );

    try {
        $sender = ZabbixDBA::Sender->new( map { $_ => $conf->{$_} }
                @{ $conf->{zabbix_server_list} } );
    }
    catch {
        $log->errorf( q{[configuration] %s}, $_ );
        confess $_;
    };

    for my $db ( @{ $conf->{database_list} } ) {
        if ( !$conf->{$db} || !$conf->{$db}->{dsn} ) {
            $log->warnf(
                q{[database] configuration of '%s' is not described in '%s'},
                $db, $confile
            );
            next;
        }

        if ( !$dbpool->{$db} ) {
            $dbpool->{$db} = get_connection($db) or next;
        }

        $dbpool->{$db}->do(q{SELECT NULL FROM DUAL});

        if ( $dbpool->{$db}->errstr() ) {
            $log->errorf( q{[database] connection lost contact for '%s' : %s},
                $db, $dbpool->{$db}->errstr() );
            $dbpool->{$db} = get_connection($db) or next;
        }

        my $ql;

        try {
            $ql
                = ZabbixDBA::Configurator->new(
                $conf->{$db}->{query_list_file}
                    // $conf->{default}->{query_list_file} );
        }
        catch {
            $log->errorf( q{[configuration] %s}, $_ );
            return;
        } or next;

        if ( $conf->{$db}->{extra_query_list_file} ) {
            my $eql;

            try {
                $eql = ZabbixDBA::Configurator->new(
                    $conf->{$db}->{extra_query_list_file} );
            }
            catch {
                $log->error($_);
            };
            if ($eql) {
                if ( $eql->{query_list} ) {
                    push @{ $ql->{query_list} }, @{ $eql->{query_list} };
                    for ( @{ $eql->{query_list} } ) {
                        $ql->{$_} = $eql->{$_};
                    }
                }
                for ( keys %{ $eql->{discovery}->{rule} } ) {
                    $ql->{discovery}->{rule}->{$_}
                        = $eql->{discovery}->{rule}->{$_};
                }
                for ( keys %{ $eql->{discovery}->{item} } ) {
                    $ql->{discovery}->{item}->{$_}
                        = $eql->{discovery}->{item}->{$_};
                }
            }
        }

        $pm->start() and next;

        # Starting fork() of main code
        # -----------------------------------------------------------
        my $dbh   = $dbpool->{$db}->clone();
        my $start = [gettimeofday];
        my @data;
        while ( my ( $rule, $v ) = each %{ $ql->{discovery}->{rule} } ) {

            # JSON is required by Zabbix when discovering items
            my $json = { data => [] };

            my $result
                = $dbh->selectall_arrayref( $v->{query}, { Slice => {} } );

            if ( $dbh->errstr() ) {
                $log->errorf( q{[item_discovery] %s => %s : %s},
                    $db, $rule, $dbh->errstr() );
                next;
            }

            for my $row ( @{$result} ) {
                push @{ $json->{data} },
                    { map { sprintf( '{#%s}', $_ ) => $row->{$_} }
                        @{ $v->{keys} } };
            }
            push @data, [ $db, $rule, encode_json($json) ];
        }

        while ( my ( $item, $v ) = each %{ $ql->{discovery}->{item} } ) {
            my $result
                = $dbh->selectall_arrayref( $v->{query}, { Slice => {} } );
            if ( $dbh->errstr() ) {
                $log->errorf( q{[item_discovery] %s => %s : %s},
                    $db, $item, $dbh->errstr() );
                next;
            }

            for my $row ( @{$result} ) {
                for ( keys %{ $v->{keys} } ) {
                    push @data,
                        [
                        $db,
                        sprintf( '%s[%s]', $item, $row->{$_} ),
                        $row->{ $v->{keys}->{$_} }
                        ];
                }
            }
        }

        for my $query ( @{ $ql->{query_list} } ) {
            if ( !$ql->{$query} ) {
                next;
            }
            my $result
                = $dbh->selectrow_arrayref( $ql->{$query}->{query} );

            if ( $dbh->errstr() ) {
                $log->error( sprintf q{[query] %s => %s : %s},
                    $db, $query, $dbh->errstr() );
                next;
            }

            if ( !$result ) {
                $result = $ql->{$query}->{no_data_found} // next;
            }
            else {
                $result = join q{ }, @{$result};
            }

            push @data, [ $db, $query, $result ];
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
            $PROCESS_ID, $db, tv_interval( $start, [gettimeofday] ) );

        $pm->finish();

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
        = DBI->connect( $conf->{$db}->{dsn}, $user, $pass, $opts );

    if ( DBI->errstr() ) {
        $log->errorf( q{[database] connection failed for '%s@%s' : %s},
            $user, $db, DBI->errstr() );
        return;
    }

    $log->infof( q{[database] connected to '%s'}, $db );

    return $dbh;
}

sub stop {
    $running = 0;
    $log->info('Stopping');
    for ( keys %{$dbpool} ) {
        $log->infof( q{[database] disconnecting from '%s'}, $_ );
        $dbpool->{$_}->disconnect;
    }
    return 1;
}
