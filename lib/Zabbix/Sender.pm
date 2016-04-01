package Zabbix::Sender;

use strict;
use warnings;
use English qw(-no_match_vars);

use Carp ();
use JSON ();
use IO::Socket::INET;

use Moo;

has server => (
    is       => 'ro',
    required => 1
);

has port => (
    is      => 'ro',
    default => 10500
);

has timeout => (
    is      => 'ro',
    default => 30
);

has _socket => ( is => 'rw' );

has _json => (
    is      => 'ro',
    default => sub { JSON->new()->utf8() }
);

has _zabbix_template => (
    is      => 'ro',
    default => 'a4 b C4 C4 a*'
);

no Moo;

sub _connect {
    my ($self) = @_;

    my $socket = IO::Socket::INET->new(
        PeerHost => $self->server(),
        PeerPort => $self->port(),
        Timeout  => $self->timeout(),
        Proto    => 'tcp',
    );

    if ( !$socket ) {
        Carp::confess sprintf
          'Unable to connect to server %s:%d',
          $self->server(),
          $self->port();
    }

    $self->_socket($socket);

    return 1;
}

sub _disconnect {
    my ($self) = @_;

    return unless $self->_socket();

    $self->_socket()->close();

    $self->_socket(undef);

    return 1;
}

sub _pack {
    my ( $self, $data ) = @_;

    use bytes;
    my $length = length($data);
    no bytes;

    my $out = pack(
        $self->_zabbix_template(),         #
        'ZBXD',                            #
        0x01,                              #
        ( $length & 0xFF ),                #
        ( $length & 0x00FF ) >> 8,         #
        ( $length & 0x0000FF ) >> 16,      #
        ( $length & 0x000000FF ) >> 24,    #
        0x00,                              #
        0x00,                              #
        0x00,                              #
        0x00,                              #
        $data
    );

    return $out;
}

sub _encode_request {
    my ( $self, $data ) = @_;

    my $out = $self->_pack( $self->_json()->encode($data) );

    return $out;
}

sub _send {
    my ( $self, $data ) = @_;

    $self->_connect() unless $self->_socket();

    $self->_socket()->send($data);

    $self->_disconnect();

    return 1;
}

sub send {
    my ( $self, @data ) = @_;

    while ( my @data_piece = splice @data, 0, 10 ) {
        my $request = {
            'request' => 'sender data',
            'data'    => [],
        };

        for (@data_piece) {
            next if !ref;

            my $host_data = {};

            @$host_data{qw|host key value|} = @{$_};

            push @{ $request->{data} }, $host_data;
        }

        $self->_send( $self->_encode_request($request) );
    }

    return 1;
}

1;
