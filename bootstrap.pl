#!/usr/bin/env perl

use 5.010;
use strict;
use warnings;
use Carp qw(confess);

our $VERSION = 1.001;

use JSON qw(encode_json);

use ZabbixDBA::Configurator;
use ZabbixDBA::DBI;
use ZabbixDBA::Sender;

if ( scalar @ARGV < 2 ) {
    confess 'Usage: perl bootstrap.pl start /path/to/config.pl';
}

my ( $command, $confile ) = @ARGV;

if ( $command ne 'start' ) {
    confess 'Usage: perl bootstrap.pl start /path/to/config.pl';
}

my ( $conf, $sender );
my $dbpool = {};

my $running = 1;
local $SIG{USR1} = sub { $running = 0; };

while ($running) {
    $conf = ZabbixDBA::Configurator->new($confile);
    $sender = ZabbixDBA::Sender->new( map { $_ => $conf->{$_} }
            @{ $conf->{zabbix_server_list} } );

    for my $db ( @{ $conf->{database_list} } ) {
        if ( !$conf->{$db} ) {
            next;
        }

        if ( !$dbpool->{$db} ) {
            my $user = $conf->{$db}->{user} // $conf->{default}->{user};
            my $pass = $conf->{$db}->{password}
                // $conf->{default}->{password};
            $dbpool->{$db}
                = ZabbixDBA::DBI->new( $conf->{$db}->{dsn}, $user, $pass );
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

        while ( my ( $rule, $v ) = each %{ $ql->{discovery}->{rule} } ) {
            my $json = { data => [] };
            my $result
                = $dbpool->{$db}->fetchmany( $v->{query}, { Slice => {} } );
            for my $row ( @{$result} ) {
                push @{ $json->{data} },
                    { map { sprintf( '{#%s}', $_ ) => $row->{$_} }
                        @{ $v->{columns} } };
            }
            $sender->send( $db, $rule, encode_json($json) );
        }

        while ( my ( $item, $v ) = each %{ $ql->{discovery}->{item} } ) {
            my $result
                = $dbpool->{$db}->fetchmany( $v->{query}, { Slice => {} } );
            for my $row ( @{$result} ) {
                for ( keys %{ $v->{key} } ) {
                    $sender->send(
                        $db,
                        sprintf( '%s[%s]', $item, $row->{$_} ),
                        $row->{ $v->{key}->{$_} }
                    );
                }
            }
        }

        for my $query ( @{ $ql->{query_list} } ) {
            if ( !$ql->{$query} ) {
                next;
            }

            my $result
                = $dbpool->{$db}->fetchone( $ql->{$query}->{query} );
            if ( !$result ) {
                $result = $ql->{$query}->{no_data_found} // next;
            }
            $sender->send( $db, $query, $result );
        }
    }

    sleep $conf->{daemon}->{sleep};
}


for (keys %{$dbpool}) {
    $dbpool->{$_}->disconnect;
}