package ZDBA::Base;
use strict;
use warnings FATAL => 'all';

use Moo::Role;

with 'MooseX::Log::Log4perl';

has VERSION      => ( is => 'ro', default => '3.000' );
has PROJECT_NAME => ( is => 'ro', default => 'ZabbixDBA' );
has RETRY_COUNT  => ( is => 'ro', default => 2 );
has SLEEP        => ( is => 'ro', default => 120 );

1;
