#!/usr/bin/env perl
package main;

use 5.010;
use strict;
use warnings FATAL => 'all';
use sigtrap 'handler', \&stop, 'normal-signals';
use threads 'exit' => 'threads_only';
use threads::shared;

use English qw(-no_match_vars);
use Carp    ();
use FindBin ();
use lib "$FindBin::Bin/lib";
use Time::HiRes ();
use Try::Tiny;
use List::MoreUtils ();
use Log::Log4perl qw/:easy/;
use Log::Any qw($log);
use Log::Any::Adapter;

use Constants;
use Dispatcher;
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
my $dbpool          = {};
my $counter         = {};

sub stop {
    $log->infof( q{[main:%d] stopping %s monitoring plugin, version %s},
        $PROCESS_ID, $PROJECT_NAME, $VERSION );
    $running = 0;

    while ( threads->list(threads::all) ) {
        for ( threads->list(threads::all) ) {
            $_->join() if $_->is_joinable();
        }
    }

    return 1;
}

$log->infof( q{[main:%d] starting %s monitoring plugin, version %s},
    $PROCESS_ID, $PROJECT_NAME, $VERSION );

while ($running) {

    # Reloading configuration file to see if
    # values were changed (no need to restart daemon)
    try {
        $conf = shared_clone( Configurator->new($confile) );
    }
    catch {
        $log->fatalf( q{[configurator] %s}, $_ );
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
        $log->fatalf( q{[sender] %s}, $_ );
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

        if ( $dbpool->{$db} ) {
            if ( $dbpool->{$db}->is_running() ) {
                next;
            }
            count($db) or next;
        }
        $dbpool->{$db} = threads->create( 'start_thread', $db );
    }

    for my $db ( keys %{$dbpool} ) {
        if ( !List::MoreUtils::any {m/$db/ms} @{ $conf->{database_list} } ) {
            $log->infof(
                q{[main:%d] %s is gone from configuration, stopping thread},
                $PROCESS_ID, $db );
            $dbpool->{$db}->kill('INT')->join();
            delete $dbpool->{$db};
            delete $counter->{$db};
        }
    }

    for ( threads->list(threads::all) ) {
        $_->join() if !$_->is_running();
    }

    sleep( $conf->{daemon}->{sleep} // $SLEEP );
}

sub count {
    my ($db) = @_;

    my $rc = 1;

    if ( defined $counter->{$db} ) {
        if ( --$counter->{$db} > 0 ) {
            --$rc;
        }
        else {
            delete $counter->{$db};
        }
    }
    else {
        $counter->{$db} = $conf->{$db}->{retry_count} // $RETRY_COUNT;
        --$rc;
    }
    return $rc;
}

sub start_thread {
    my ($db) = @_;

    my $dispatcher = Dispatcher->new(
        db     => $db,
        conf   => $conf,
        log    => $log,
        sender => $sender
    );

    $dispatcher->connect() or exit 1;

    my $trunning = 1;
    local $SIG{INT} = sub { $trunning = 0 };

    while ( $running && $trunning ) {

        $dispatcher->set( conf => $conf, sender => $sender );

        $dispatcher->ping() or exit 1;

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
                $log->warnf( q{[configurator] %s}, $_ );
            };
        }

        my $start = [Time::HiRes::gettimeofday];
        while ( my ( $rule, $v ) = each %{ $ql->{discovery}->{rule} } ) {
            my $result
                = $dispatcher->fetchall( $rule, $v->{query}, { Slice => {} } )
                or next;

            if ( defined $result ) {
                $dispatcher->data(
                    Zabbix::Discoverer::rule(
                        $db, $rule, $result, $v->{keys}
                    )
                );
            }
        }

        while ( my ( $item, $v ) = each %{ $ql->{discovery}->{item} } ) {
            my $result
                = $dispatcher->fetchall( $item, $v->{query}, { Slice => {} } )
                or next;

            if ( defined $result ) {
                $dispatcher->data(
                    Zabbix::Discoverer::item(
                        $db, $item, $result, $v->{keys}
                    )
                );
            }
        }

        for my $query ( @{ $ql->{query_list} } ) {
            if ( !$ql->{$query} ) {
                next;
            }
            my $arrayref = $dispatcher->fetchall(
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
                $dispatcher->data( [ $_, $query, $result ] )
                    for @{ $ql->{$query}->{send_to} };
            }
            else {
                $dispatcher->data( [ $db, $query, $result ] );
            }
        }

        $dispatcher->send();

        $log->infof(
            q{[thread:%d] completed fetching data on '%s', elapsed: %s},
            threads->tid(),
            $db,
            Time::HiRes::tv_interval( $start, [Time::HiRes::gettimeofday] )
        );

        # sleep( $conf->{$db}->{sleep} // $SLEEP );
        # this sh*t was created because threads module does not
        # actually send kill signals via the OS, but emulates them
        # don't blame me
        for ( 1 ... $conf->{$db}->{sleep} // $SLEEP ) {
            last if !( $running && $trunning );
            sleep 1;
        }
    }

    $log->infof( q{[dbi] disconnecting from '%s'}, $db );
    $dispatcher->disconnect();

    return 1;
}

1;
