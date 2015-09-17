#!/usr/bin/env perl

package main;

use 5.010;
use strict;
use warnings FATAL => 'all';
use sigtrap 'handler', \&stop, 'normal-signals';

use threads;
use threads::shared;

use English qw(-no_match_vars);
use Carp    ();
use FindBin ();
use lib "$FindBin::Bin/lib";
use Time::HiRes ();
use Try::Tiny;

use Log::Log4perl qw/:easy/;
use Log::Any qw($log);
use Log::Any::Adapter;

use Constants;
use Connector;
use Configurator;
use Zabbix::Discoverer;
use Zabbix::Sender;

Log::Log4perl::init("$FindBin::Bin/conf/log4perl.conf");
Log::Any::Adapter->set('Log4perl');

if ( !@ARGV ) {
    Carp::confess 'Usage: perl ZabbixDBA.pl /path/to/config.pl &';
}

my ($confile) = @ARGV;
my $running : shared = 1;
my $conf : shared   = shared_clone( {} );
my $sender : shared = shared_clone( {} );
my $threads         = {};
my $counter         = {};

sub stop {
    $log->infof( q{[main] stopping %s monitoring plugin}, $PROJECT_NAME );
    $running = 0;

    while ( threads->list(threads::all) ) {
        for ( threads->list(threads::all) ) {
            $_->join() if $_->is_joinable();
        }
    }

    return 1;
}

$log->infof( q{[main] starting %s monitoring plugin}, $PROJECT_NAME );

while ($running) {

    # Reloading configuration file to see if
    # values were changed (no need to restart daemon)
    try {
        $conf = shared_clone( Configurator->new($confile) );
    }
    catch {
        $log->errorf( q{[configurator] %s}, $_ );
        Carp::confess $_;
    };

    try {
        $sender = shared_clone(
            Zabbix::Sender->new(
                map { $_ => $conf->{$_} } @{ $conf->{zabbix_server_list} }
            )
        );
    }
    catch {
        $log->errorf( q{[sender] %s}, $_ );
        Carp::confess $_;
    };

    for my $db ( @{ $conf->{database_list} } ) {
        if ( !$conf->{$db} ) {
            count($db) or next;
            $log->errorf(
                q{[configurator] configuration of '%s' is not described in '%s'},
                $db, $confile
            );
            next;
        }

        if ( $threads->{$db} ) {
            if ( $threads->{$db}->is_running() ) {
                next;
            }

            count($db) or next;
        }

        $threads->{$db} = threads->create( { 'exit' => 'thread_only' },
            'start_thread', $db );

    }

    sleep( $conf->{daemon}->{sleep} // $SLEEP );
}

sub count {
    my ($db) = @_;

    my $rc = 1;

    if ( defined $counter->{$db} ) {
        --$rc if --$counter->{$db} > 0;
    }
    else {
        $counter->{$db} = $conf->{$db}->{retry_count} // $RETRY_COUNT;
        --$rc;
    }

    return $rc;
}

sub start_thread {
    my ($db) = @_;

    my $conn = Connector->new(
        db     => $db,
        conf   => $conf,
        log    => $log,
        sender => $sender
    );

    $conn->connect() or exit 1;

    while ($running) {

        $conn->set( conf => $conf, sender => $sender );

        $conn->ping() or exit 1;

        my $ql;

        try {
            $ql
                = Configurator->new( $conf->{$db}->{query_list_file}
                    // $conf->{default}->{query_list_file} );
        }
        catch {
            $log->errorf( q{[configurator] %s}, $_ );
            exit 1;
        };

        if ( $conf->{$db}->{extra_query_list_file} ) {
            try {
                $ql->merge(
                    Configurator->new(
                        $conf->{$db}->{extra_query_list_file}
                    )
                );
            }
            catch {
                $log->errorf( q{[configurator] %s}, $_ );
            };
        }

        my $start = [Time::HiRes::gettimeofday];
        my @data;
        while ( my ( $rule, $v ) = each %{ $ql->{discovery}->{rule} } ) {
            my $result
                = $conn->selectall_arrayref( $rule, $v->{query},
                { Slice => {} } )
                or next;

            if ( defined $result ) {
                push @data,
                    Zabbix::Discoverer::rule( $db, $rule, $result,
                    $v->{keys} );
            }
        }

        while ( my ( $item, $v ) = each %{ $ql->{discovery}->{item} } ) {
            my $result
                = $conn->selectall_arrayref( $item, $v->{query},
                { Slice => {} } )
                or next;

            if ( defined $result ) {
                push @data,
                    Zabbix::Discoverer::item( $db, $item, $result,
                    $v->{keys} );
            }
        }

        for my $query ( @{ $ql->{query_list} } ) {
            if ( !$ql->{$query} ) {
                next;
            }
            my $arrayref = $conn->selectall_arrayref(
                $query, $ql->{$query}->{query},
                undef,  @{ $ql->{$query}->{bind_values} }
            ) or next;

            my $result;

            for my $row ( @{$arrayref} ) {
                $result .= join q{ }, map { $_ // () } @{$row};
            }

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

        try {
            $sender->send(@data);
        }
        catch {
            $log->warnf( q{[sender] %s}, $_ );
        };

        undef @data;
        $log->infof( q{[thread] completed fetching data on '%s', elapsed: %s},
            $db,
            Time::HiRes::tv_interval( $start, [Time::HiRes::gettimeofday] ) );

        sleep( $conf->{$db}->{sleep} // $SLEEP );
    }

    $log->infof( q{[dbi] disconnecting from '%s'}, $db );
    $conn->disconnect();

    return 1;
}

1;
