package ZDBA::Config;

use Carp ();
use English '-no_match_vars';
use Cwd 'realpath';

use Moo;

with 'ZDBA::Base';

# *** Public attributes

has file => (
  is       => 'ro',
  required => 1,
  isa      => sub { Carp::confess 'not a valid file' unless $_[0] && -f $_[0] },
  coerce => sub { realpath $_[0] }
);

# *** Public methods

sub load {
  my ($self) = @_;
  my $conf = $self->compile;
  @{$self}{ keys %{$conf} } = values %{$conf};
  return $self;
}

sub compile {
  my ( $self, $file ) = @_;

  $file ||= $self->file;

  my $result = {};

  unless ( $result = do($file) ) {
    Carp::confess $self->log->fatal( q{failed to compile file '%s': %s}, $file, $EVAL_ERROR );
  }

  unless ( ref $result eq 'HASH' ) {
    Carp::confess $self->log->fatal( q{file '%s' did not return a HASH}, $file );
  }

  $self->log->debug( sub { qq{loaded configuration from file '%s':\n%s}, $file, $self->dump->($result) } );

  return $result;
}

# *** Private methods

sub BUILD { shift->load }

1;

__END__
