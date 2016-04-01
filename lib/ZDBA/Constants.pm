#!/usr/bin/env perl

package Constants;

use strict;
use warnings FATAL => 'all';

use Readonly;
use Exporter;

our @ISA    = qw(Exporter);
our @EXPORT = qw(
    *VERSION
    *PROJECT_NAME
    *RETRY_COUNT
    *SLEEP
);

Readonly our $VERSION      => '2.010';
Readonly our $PROJECT_NAME => 'ZabbixDBA';
Readonly our $RETRY_COUNT  => 2;
Readonly our $SLEEP        => 120;

1;
