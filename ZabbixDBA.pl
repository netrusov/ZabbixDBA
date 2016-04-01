#!/usr/bin/env perl
package main;

use strict;
use warnings FATAL => 'all';
use forks;
use sigtrap 'handler', \&stop, 'normal-signals';

use English qw(-no_match_vars);
use Carp    ();
use FindBin ();
use lib "$FindBin::Bin/lib";

use Try::Tiny;
use List::MoreUtils ();

use Configurator;
use Zabbix::Discoverer;
use Zabbix::Sender;

use ZDBA::Constants;
use ZDBA::Dispatcher;

if ( !@ARGV ) {
    Carp::confess 'Usage: perl ZabbixDBA.pl /path/to/config.pl &';
}

my ($confile) = @ARGV;
my $running = 1;
my $pool          = {};
my $counter         = {};

my $c = Configurator->new($confile);

sub stop {
    $running = 0;
    
    while ( threads->list(threads::all) ) {
            $_->kill('INT')->join() for threads->list(threads::all);
    }

    return 1;
}

while ($running) {
    $c->load();

    for my $db ( @{ $c->conf()->{db}{list} } ) {
        if ( !$c->conf()->{db}{$db} ) {
            count($db) or next;
            next;
        }

        if ( $pool->{$db} ) {
            if ( $pool->{$db}->is_running() ) {
                next;
            }
            count($db) or next;
        }

        $pool->{$db} = threads->create( 'start', $db );
    }

    for my $db ( keys %{$pool} ) {
        if ( !List::MoreUtils::any { m/$db/ms }
            @{ $c->conf()->{db}{list} } )
        {
            $pool->{$db}->kill('INT')->join();
            delete $pool->{$db};
            delete $counter->{$db};
        }
    }

    for ( threads->list(threads::all) ) {
        $_->join() if !$_->is_running();
    }

    sleep( $c->conf()->{daemon}{sleep} // $SLEEP );
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
        $counter->{$db} = $c->conf()->{db}{$db}{retry_count} // $RETRY_COUNT;
        --$rc;
    }

    return $rc;
}

sub start {
    my ($db) = @_;

    my $dispatcher = Dispatcher->new(
        db     => $db,
        conf   => $c,
        sender => $sender
    );

    $dispatcher->connect() or exit 1;

    my $trunning = 1;
    local $SIG{INT} = sub { $trunning = 0 };

    while ( $running && $trunning ) {

        $dispatcher->set( conf => $c, sender => $sender );

        $dispatcher->ping() or exit 1;

        my $ql = Configurator->new( $c->conf()->{db}{$db}{query_list}
                  // $c->conf()->{db}{default}{query_list} );

        if ( $c->conf()->{$db}->{extra_query_list} ) {
            try {
                $ql->merge(
                    Configurator->new( $c->conf()->{$db}->{extra_query_list} )
                );
            }
            catch {
                $log->warnf( q{[configurator] %s}, $_ );
            };
        }

        while ( my ( $rule, $v ) = each %{ $ql->{discovery}->{rule} } ) {
            my $result =
              $dispatcher->fetchall( $rule, $v->{query}, { Slice => {} } )
              or next;

            if ( defined $result ) {
                $dispatcher->data(
                    Zabbix::Discoverer::rule( $db, $rule, $result, $v->{keys} )
                );
            }
        }

        while ( my ( $item, $v ) = each %{ $ql->{discovery}->{item} } ) {
            my $result =
              $dispatcher->fetchall( $item, $v->{query}, { Slice => {} } )
              or next;

            if ( defined $result ) {
                $dispatcher->data(
                    Zabbix::Discoverer::item( $db, $item, $result, $v->{keys} )
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

        sleep( $c->conf()->{$db}->{sleep} // $SLEEP );
    }

    $dispatcher->disconnect();

    return 1;
}

1;
