package ZabbixDBA::Configurator;

use 5.010;
use strict;
use warnings;
use English qw(-no_match_vars);
use Carp qw(confess);

our $VERSION = '1.001';

sub new {
    my ( $class, $file ) = @_;

    my $self = {};

    if ( !-f $file ) {
        confess "Didn't find '$file'";
    }
    else {
        if ( !eval { $self = do($file) } ) {
            confess "Failure compiling '$file': " . $EVAL_ERROR;
        }
    }

    return bless $self, $class;
}

1;
