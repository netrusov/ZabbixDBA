package Zabbix::Sender;

use 5.010;
use strict;
use warnings;
use English qw(-no_match_vars);

use Carp ();
use JSON ();
use IO::Socket::INET;

sub new {
    my $class = shift;
    return bless {@_}, $class;
}

sub send {
    my ( $self, @data ) = @_;
    for my $server ( values %{$self} ) {

        for (@data) {
            if ( !ref ) {
                next;
            }
            my $socket = IO::Socket::INET->new(
                PeerHost => $server->{address},
                PeerPort => $server->{port},
                Proto    => 'tcp',
            );

            if ( !$socket ) {
                Carp::confess sprintf
                    'Unable to connect to server %s:%d',
                    $server->{address},
                    $server->{port};
            }

            my $data_ref = {};
            @$data_ref{qw|host key value|} = @{$_};

            my $data = {
                'request' => 'sender data',
                'data'    => [$data_ref],
            };

            my $json = JSON::->new()->utf8()->encode($data);

            use bytes;
            my $length = length($json);
            no bytes;

            my $out = pack( 'a4 b C4 C4 a*',
                'ZBXD',
                0x01,
                ( $length & 0xFF ),
                ( $length & 0x00FF ) >> 8,
                ( $length & 0x0000FF ) >> 16,
                ( $length & 0x000000FF ) >> 24,
                0x00,
                0x00,
                0x00,
                0x00,
                $json );
            $socket->send($out);
            $socket->close();
        }

    }
    return 1;
}

1;
