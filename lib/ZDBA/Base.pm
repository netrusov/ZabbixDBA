package ZDBA::Base;

use Moo::Role;

with 'MooX::Log::Any';

has VERSION      => ( is => 'ro', default => '3.000' );
has PROJECT_NAME => ( is => 'ro', default => 'ZabbixDBA' );
has RETRY_COUNT  => ( is => 'ro', default => 2 );
has SLEEP_DAEMON => ( is => 'ro', default => 120 );
has SLEEP_THREAD => ( is => 'ro', default => 60 );

1;
