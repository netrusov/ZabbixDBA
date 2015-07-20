package ZabbixDBA::Sender;

use 5.010;
use strict;
use warnings;
use English qw(-no_match_vars);
use Carp qw(confess carp);

our $VERSION = '1.010';

use IO::Socket::INET;
use MIME::Base64 qw(encode_base64);

my $html_template = <<'EOF';
<req>
<host>%s</host>
<key>%s</key>
<data>%s</data>
</req>
EOF

# May be someday I'll use JSON to send data to Zabbix
my $json_template
    = q(ZBXDS{"request":"sender data","data":[{"host":"%s","key":"%s","value":"%s"}]});

sub new {
    my ( $class, %server_list ) = @_;
    my $self = \%server_list;
    return bless $self, $class;
}

sub encode {

# MIME::Base64::encode_base64() adds newline at the end of string,
# but Zabbix doesn't like them, and chomp() doesn't work properly with sprintf.
# That's why this subroutine was created
    chomp( my $result = encode_base64(shift) );
    return $result;
}

sub send {
    my ( $self, @data ) = @_;
    for my $sever ( values %{$self} ) {

        for (@data) {
            if ( !ref $_ ) {
                next;
            }
            my $socket = IO::Socket::INET->new(
                PeerHost => $sever->{address},
                PeerPort => $sever->{port},
                Proto    => 'tcp',
            );

            if ( !$socket ) {
                confess sprintf
                    'Unable to connect to server %s:%d',
                    $sever->{address},
                    $sever->{port};
            }
            my ( $host, $key, $data ) = @{$_};
            my $data_base64 = sprintf $html_template,
                encode($host), encode($key), encode($data);
            $socket->send($data_base64);
            $socket->close();
        }
    }
    return 1;
}

1;
