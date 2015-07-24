package ZabbixDBA::Configurator;

use 5.010;
use strict;
use warnings;
use English qw(-no_match_vars);
use Carp qw(confess);

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

sub merge {

    # Hope this will work fine
    my ( $self, $source ) = @_;

    if ( !$source ) { return; }

    for ( keys %{$source} ) {
        if ( $self->{$_} ) {
            if ( ref $source->{$_} eq 'HASH' ) {
                merge( $source->{$_}, $self->{$_} );
            }
            if ( ref $source->{$_} eq 'ARRAY' ) {
                push @{ $self->{$_} }, @{ $source->{$_} };
            }
        }
        else {
            $self->{$_} = $source->{$_};
        }
    }
    return 1;
}

1;
