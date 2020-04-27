package ZDBA::DBIx;

use Carp ();
use English '-no_match_vars';
use Time::HiRes qw(gettimeofday tv_interval);
use DBI;

use Moo;

with 'ZDBA::Base';

# *** Public attributes

has [qw|dsn user pass|] => (
  is       => 'ro',
  required => 1
);

has options => (
  is      => 'ro',
  default => sub {
    return +{
      PrintError => 0,
      RaiseError => 0,
      AutoCommit => 0
    };
  }
);

# *** Private attributes

has dbh => ( is => 'rw' );

# *** Public methods

sub connect {
  my ($self) = @_;

  $self->log->debug( sub { q{connecting to '%s'}, $self->dsn } );

  my $dbh = DBI->connect_cached( @{$self}{qw|dsn user pass options|} );

  unless ($dbh) {
    Carp::confess $self->log->fatal( q{failed to connect to '%s':\n%s}, $self->dsn, DBI->errstr );
  }

  $self->log->info( q{connected to '%s'}, $self->dsn );

  return $self->dbh($dbh);
}

sub disconnect {
  my ($self) = @_;
  $self->log->debug( sub { q{disconnecting from '%s'}, $self->dsn } );
  return $self->dbh->disconnect;
}

sub fetchone {
  return shift->_fetch( {@_}, 'selectrow_arrayref' );
}

sub fetchall {
  return shift->_fetch( {@_}, 'selectall_arrayref' );
}

# *** Private methods

sub BUILD { shift->connect }

sub _fetch {
  my ( $self, $args, $method ) = @_;

  $method ||= 'selectrow_arrayref';

  $self->connect unless ( $self->dbh && $self->dbh->ping );

  $self->log->debug( sub { qq{fetching data from '%s' using '%s' with options:\n%s}, $self->dsn, $method, $self->dump($args) } );

  my $start = [gettimeofday];
  my $options = { MaxRows => 1000, %{ $args->{options} // {} } };

  my $result = $self->dbh->$method(
    $args->{query},
    $options
  );

  my $end = [gettimeofday];

  my $timing = {
    start   => $start,
    end     => $end,
    elapsed => tv_interval( $start, $end )
  };

  if ( $self->dbh->errstr ) {
    $self->log->error( qq{failed to execute query on '%s':\n%s}, $self->dsn, $self->dbh->errstr );
  } else {
    $self->log->debug( sub { qq{fetched data from '%s' (elapsed %s):\n%s}, $self->dsn, $timing->{elapsed}, $self->dump($result) } );
  }

  $self->dbh->rollback;

  $result = ref $result ? $result : [ grep { defined $_ } $args->{no_data_found} ];

  return wantarray ? ( $result, $timing ) : $result;
}

1;

__END__
