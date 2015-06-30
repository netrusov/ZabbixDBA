#!/usr/bin/env perl

use 5.010;
use strict;
use warnings;
use English qw(-no_match_vars);
use Carp qw(confess carp);

our $VERSION = 1.010;

use Parallel::ForkManager;
use DBI;
use FindBin qw($Bin);
use lib $Bin;

use JSON qw(encode_json);

use ZabbixDBA::Configurator;
use ZabbixDBA::Sender;

if ( scalar @ARGV < 2 ) {
    confess 'Usage: perl bootstrap.pl start /path/to/config.pl';
}

my ( $command, $confile ) = @ARGV;

if ( $command ne 'start' ) {
    confess 'Usage: perl bootstrap.pl start /path/to/config.pl';
}

my ( $conf, $sender );

my $pm = Parallel::ForkManager->new(20);

my $dbpool = {};

my $running = 1;

local $SIG{INT}  = sub { $running = 0; };
local $SIG{HUP}  = sub { $running = 0; };
local $SIG{ALRM} = sub { $running = 0; };
local $SIG{USR1} = sub { $running = 0; };

while ($running) {

    # Reloading configuration file to see
    # if values were changed (no need to restart daemon)
    $conf = ZabbixDBA::Configurator->new($confile);
    $pm->set_max_procs( $conf->{daemon}->{maxproc} );
    $sender = ZabbixDBA::Sender->new( map { $_ => $conf->{$_} }
            @{ $conf->{zabbix_server_list} } );

    for my $db ( @{ $conf->{database_list} } ) {
        if ( !$conf->{$db} || !$conf->{$db}->{dsn} ) {
            next;
        }

        if ( !$dbpool->{$db} ) {
            my $opts = {
                PrintError => 0,
                RaiseError => 0,
                AutoCommit => 0,
                AutoInactiveDestroy =>
                    1 # useful when fork() is used, see mode in DBI documentation
            };

            my $user = $conf->{$db}->{user} // $conf->{default}->{user};
            my $pass = $conf->{$db}->{password}
                // $conf->{default}->{password};

            $dbpool->{$db}
                = DBI->connect( $conf->{$db}->{dsn}, $user, $pass, $opts )
                or confess DBI->errstr();
        }

        my $ql = ZabbixDBA::Configurator->new( $conf->{$db}->{query_list_file}
                // $conf->{default}->{query_list_file} );

        if ( $conf->{$db}->{extra_query_list_file} ) {
            my $eql = ZabbixDBA::Configurator->new(
                $conf->{$db}->{extra_query_list_file} );
            push @{ $ql->{query_list} }, @{ $eql->{query_list} };
            for ( @{ $eql->{query_list} } ) {
                $ql->{$_} = $eql->{$_};
            }
        }

        # Starting fork() of main code
        # -----------------------------------------------------------
        my $pid = $pm->start() and next;
        my $dbh = $dbpool->{$db}->clone();
        my @data;
        while ( my ( $rule, $v ) = each %{ $ql->{discovery}->{rule} } ) {

            # JSON is required by Zabbix when discovering items
            my $json = { data => [] };
            my $result
                = $dbh->selectall_arrayref( $v->{query}, { Slice => {} } );

            if ( $dbh->errstr() ) {
                carp 'An error occurred: ' . $dbh->errstr();
                next;
            }

            for my $row ( @{$result} ) {
                push @{ $json->{data} },
                    { map { sprintf( '{#%s}', $_ ) => $row->{$_} }
                        @{ $v->{columns} } };
            }
            push @data, [ $db, $rule, encode_json($json) ];
        }

        while ( my ( $item, $v ) = each %{ $ql->{discovery}->{item} } ) {
            my $result
                = $dbh->selectall_arrayref( $v->{query}, { Slice => {} } );

            for my $row ( @{$result} ) {
                for ( keys %{ $v->{key} } ) {
                    push @data,
                        [
                        $db,
                        sprintf( '%s[%s]', $item, $row->{$_} ),
                        $row->{ $v->{key}->{$_} }
                        ];
                }
            }
        }

        for my $query ( @{ $ql->{query_list} } ) {
            if ( !$ql->{$query} ) {
                next;
            }
            my $result
                = $dbh->selectrow_array( $ql->{$query}->{query} );

            if ( $dbh->errstr() ) {
                carp 'An error occurred: ' . $dbh->errstr();
                next;
            }

            if ( !$result ) {
                $result = $ql->{$query}->{no_data_found} // next;
            }

            push @data, [ $db, $query, $result ];
        }

        # Issuing rollback due to some internal DBI methods
        # that require commit/rollback after using Slice in fetch
        $dbh->rollback();

        $sender->send(@data);

        $pm->finish();

        # -----------------------------------------------------------
    }

    $pm->wait_all_children();

    sleep $conf->{daemon}->{sleep};
}

sub DESTROY {
    for ( keys %{$dbpool} ) {
        $dbpool->{$_}->disconnect;
    }
    return 1;
}
