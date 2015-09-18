#!/usr/bin/env perl
package main;

use 5.010;
use strict;
use warnings FATAL => 'all';

use FindBin ();

if ( eval 'use threads; 1' ) {
    exec 'env', $^X, $FindBin::Bin . '/ThreadedZabbixDBA.pl', @ARGV;
}
else {
    exec 'env', $^X, $FindBin::Bin . '/ForkedZabbixDBA.pl', @ARGV;
}

1;
