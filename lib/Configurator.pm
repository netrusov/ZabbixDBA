package Configurator;

use 5.010;
use strict;
use warnings;
use English qw(-no_match_vars);
use Carp         ();
use Data::Dumper ();

my $config_file;

sub new {
    my ( $class, $file ) = @_;

    Carp::confess 'No file specified' if ( !defined $file );
    Carp::confess "Not a valid file: $file" if ( !-f $file );

    my $self = {};

    if ( !eval { $self = do($file) } ) {
        Carp::confess "Failure compiling '$file': " . $EVAL_ERROR;
    }

    $config_file = $file;

    return bless $self, $class;
}

sub merge {

    # Hope this will work fine
    my ( $self, $source ) = @_;

    if ( !$source ) { return; }

    for ( keys %{$source} ) {
        if ( $self->{$_} ) {
            if ( ref $source->{$_} eq 'HASH' ) {
                merge( $self->{$_}, $source->{$_} );
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

sub save {
    my ( $self, $to ) = @_;

    my $file = $to // $config_file;

    open my $fh, '>', $file
        or Carp::confess "Failed to open '$file': " . $OS_ERROR;
    print {$fh} Data::Dumper->Dump( [$self] )
        or Carp::confess "Failed to write to '$file': " . $OS_ERROR;
    close $fh or Carp::confess 'Failed to close filehandle: ' . $OS_ERROR;

    return 1;
}

sub dump {
    print Data::Dumper->Dump( [shift] );
    return 1;
}

1;
