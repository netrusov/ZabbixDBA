#!/usr/bin/env perl
package main;

use strict;
use warnings FATAL => 'all';

use forks;
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

if ( !@ARGV ) {
    Carp::confess 'Usage: perl ZabbixDBA.pl /path/to/config.pl &';
}

my ($confile) = @ARGV;
my $running   = 1;
my $pool      = {};
my $counter   = {};

my $c = Configurator->new( file => $confile );

while ($running) {
    $c->load();

    for my $db ( keys %{$pool} ) {
        if ( !List::MoreUtils::any { m/$db/ms } @{ $c->conf()->{db}{list} } ) {
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

        $pool->{$db} =
          threads->create(
            sub { ZDBA->new( confile => $confile )->monitor($db) } );
    }

    for ( threads->list(threads::all) ) {
        $_->join() if !$_->is_running();
    }

    sleep( $c->conf()->{daemon}{sleep} // ZDBA->SLEEP_DAEMON() );
}

sub stop {
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
          // ZDBA->RETRY_COUNT();
        --$rc;
    }

    return $rc;
}

1;

__END__
