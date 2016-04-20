package ZDBA::Configurator;

use Try::Tiny;

use Moo;

extends 'Configurator';
with 'ZDBA::Base';

around new => sub {
    my ( $orig, $self, @args ) = @_;

    my $obj = {};

    try {
        $obj = $self->$orig(@args);
    }
    catch {
        $self->log()->errorf( q{[%s:%d] %s}, __PACKAGE__, __LINE__, $_ );
    };

    return $obj;
};

around load => sub {
    my ( $orig, $self ) = @_;

    try {
        $self->$orig();
    }
    catch {
        $self->log()->errorf( q{[%s:%d] %s}, __PACKAGE__, __LINE__, $_ );
        return;
    };

    return 1;
};

no Moo;

1;
