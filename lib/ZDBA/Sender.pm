package ZDBA::Sender;

use Try::Tiny;

use Moo;

extends 'Zabbix::Sender';
with 'ZDBA::Base';

around send => sub {
    my ( $orig, $self, @data ) = @_;

    try {
        $self->$orig(@data)
    }
    catch {
        $self->log()->warnf( q{[%s:%d] %s}, __PACKAGE__, __LINE__, $_ )
    };

    return 1;
};

no Moo;

1;
