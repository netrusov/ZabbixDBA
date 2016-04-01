package Configurator;

use strict;
use warnings;
use English qw(-no_match_vars);

use Carp         ();
use Data::Dumper ();

use Moo;

has file => (
    is       => 'ro',
    required => 1,
    isa      => sub { Carp::confess "Not a valid file: $_[0]" unless -f $_[0] }
);

has conf => ( is => 'rw' );

no Moo;

sub BUILD { shift->load() }

sub load {
    my ($self) = @_;

    my $conf = {};

    if ( !eval { $conf = do( $self->file() ) } ) {
        Carp::confess sprintf "Failure compiling '%s': %s", $self->file(),
          $EVAL_ERROR;
    }

    $self->conf($conf);

    return 1;
}

sub merge {
    my ( $self, $source ) = @_;

    return if !$source;

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

    my $file = $to // $self->file();

    open my $fh, '>', $file
      or Carp::confess "Failed to open '$file': " . $OS_ERROR;
    print {$fh} $self->dump()
      or Carp::confess "Failed to write to '$file': " . $OS_ERROR;
    close $fh or Carp::confess 'Failed to close filehandle: ' . $OS_ERROR;

    return 1;
}

sub dump {
    return Data::Dumper->Dump( [ shift->conf() ] );
}

1;
