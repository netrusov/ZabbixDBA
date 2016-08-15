package ZDBA::Sender;

use Carp ();
use English '-no_match_vars';
use Encode 'encode';
use IO::Socket::INET;
use JSON;

use Moo;

with 'ZDBA::Base';

# *** Public attributes

has [qw|host port|] => (
  is       => 'ro',
  required => 1
);

has timeout => (
  is      => 'ro',
  default => 10
);

has protocol => (
  is      => 'ro',
  default => 'tcp'
);

# *** Private attributes

has socket => ( is => 'rw' );

has json => (
  is => 'ro',
  default => sub { JSON->new->utf8 }
);

has request_format => (
  is      => 'ro',
  default => 'a4 b V V a*'
);

# *** Public methods

sub connect {
  my ($self) = @_;

  my $socket = IO::Socket::INET->new(
    PeerHost => $self->host,
    PeerPort => $self->port,
    Timeout  => $self->timeout,
    Proto    => $self->protocol
  );

  unless ($socket) {
    Carp::confess $self->log->fatal( q{unable to connect to '%s:%d': %s}, $self->host, $self->port, $EXTENDED_OS_ERROR );
  }

  return $self->socket($socket);
}

sub disconnect {
  my ($self) = @_;

  return 1 unless $self->socket;

  $self->socket->close;
  $self->socket(undef);

  return 1;
}

sub send {
  my ( $self, @data ) = @_;

  unless (@data) {
    $self->log->debug( sub { q{nothing to send} } );
    return 1;
  }

  # prepare request body
  my $request = $self->json->encode( {
      'request' => 'sender data',
      'data'    => [@data]
  } );

  $self->log->debug( sub { qq{ready to send data to Zabbix:\n%s}, $request } );

  $self->connect unless $self->socket;
  $self->socket->send( $self->_pack_request($request) );

  if ($EVAL_ERROR) {
    $self->log->error( q{failed to send data to Zabbix: %s}, $EVAL_ERROR );
  } else {
    $self->log->debug( sub { q{data has been sent to Zabbix} } );
  }

  $self->disconnect;

  return 1;
}

# *** Private methods

sub _pack_request {
  my ( $self, $request ) = @_;
  return pack( $self->request_format, 'ZBXD', 0x01, length( encode( 'UTF-8', $request ) ), 0x00, $request );
}

1;

__END__
