package ZDBA::Base;

use strict;
use warnings;

use Data::Dumper 'Dumper';

use ZDBA::Logger;

use Moo::Role;

# *** Public attributes

has VERSION      => ( is => 'ro', default => '3.001' );
has PROJECT_NAME => ( is => 'ro', default => 'ZabbixDBA' );
has RETRY_STEP   => ( is => 'ro', default => 2 );
has SLEEP_DAEMON => ( is => 'ro', default => 120 );
has SLEEP_THREAD => ( is => 'ro', default => 60 );

has log => (
  is      => 'ro',
  lazy    => 1,
  default => sub { ZDBA::Logger->new }
);

has dump => (
  is      => 'ro',
  lazy    => 1,
  default => sub { \&Dumper }
);

1;

__END__
