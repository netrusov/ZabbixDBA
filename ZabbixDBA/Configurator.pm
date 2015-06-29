package ZabbixDBA::Configurator;

use strict;
use warnings;
use Carp qw(carp confess);
use English qw(-no_match_vars);

our $VERSION = 1.000;

sub new {
    my ( $class, $file ) = @_;

    my $self = {};

    if ( !-f $file ) {
        confess q{Didn't find configuration file};
    }
    else {
        $self = do($file)
            or confess "Failure compiling '$file': " . $EVAL_ERROR;
    }

    return bless $self, $class;
}

1;
