#!/usr/bin/env perl
package main;

use strict;
use warnings FATAL => 'all';

use forks 'exit' => 'threads_only';
use sigtrap 'handler', \&stop, 'normal-signals';

use Carp    ();
use FindBin ();
use lib "$FindBin::Bin/lib";

use Log::Log4perl qw(:easy);
use Log::Any::Adapter;

BEGIN {
    chdir $FindBin::Bin;

    Log::Log4perl::init("$FindBin::Bin/conf/log4perl.conf");
    Log::Any::Adapter->set('Log4perl');
}

use ZDBA;
use ZDBA::Configurator;

if ( !@ARGV ) {
    Carp::confess 'Usage: perl ZabbixDBA.pl /path/to/config.pl &';
}

my ($confile) = @ARGV;
my $running   = 1;
my $pool      = {};
my $counter   = {};

my $zdba = ZDBA->new( confile => $confile );

$zdba->log()->infof( q{[%s:%d] starting %s},
    __PACKAGE__, __LINE__, $zdba->PROJECT_NAME() );

my $c = ZDBA::Configurator->new( file => $confile ) or exit 1;

while ($running) {
    exit 1 unless $c->load();

    for my $db ( keys %{$pool} ) {
        if ( !List::MoreUtils::any { m/$db/ms } @{ $c->conf()->{db}{list} } ) {
            $zdba->log()->infof( q{[%s:%d] %s has gone from configuration},
                __PACKAGE__, __LINE__, $db );

            $pool->{$db}->kill('INT')->join();
            delete $pool->{$db};
            delete $counter->{$db};
        }
    }

    for my $db ( @{ $c->conf()->{db}{list} } ) {
        if ( $pool->{$db} ) {
            if ( $pool->{$db}->is_running() ) {
                next;
            }
            else {
                count($db) or next;
            }
        }

        $zdba->log()->infof( q{[%s:%d] starting thread for %s},
            __PACKAGE__, __LINE__, $db );

        $pool->{$db} = threads->create( sub { $zdba->monitor($db) } );
    }

    for ( threads->list(threads::all) ) {
        $_->kill('INT')->join() if !$_->is_running();
    }

    sleep( $c->conf()->{daemon}{sleep} // $zdba->SLEEP_DAEMON() );
}

sub stop {
    $zdba->log()->infof( q{[%s:%d] stopping %s},
        __PACKAGE__, __LINE__, $zdba->PROJECT_NAME() );

    $running = 0;

    while ( threads->list(threads::all) ) {
        $_->kill('INT')->join() for threads->list(threads::all);
    }

    return 1;
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
        $counter->{$db} = $c->conf()->{db}{$db}{retry_count}
          // $zdba->RETRY_COUNT();
        --$rc;
    }

    return $rc;
}

1;

__END__
