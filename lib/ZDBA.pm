package ZDBA;
use strict;
use warnings FATAL => 'all';

use File::Basename ();
use File::Spec ();
use Try::Tiny;
use List::MoreUtils ();

use Configurator;
use Zabbix::Sender;

use ZDBA::Controller;

use Moo;

with 'ZDBA::Base';

has confile => (
    is       => 'ro',
    required => 1
);

no Moo;

#our $VERSION = __PACKAGE__->VERSION();

sub monitor {
    my ( $self, $db ) = @_;

    my $running = 1;

    local $SIG{INT} = sub { $running = 0 };

    my $c = Configurator->new( file => $self->confile() );

    my $sender = Zabbix::Sender->new( $c->conf()->{zabbix} );

    my $controller = ZDBA::Controller->new(
        db      => $db,
        dbconf  => $c->conf()->{db}{$db},
        default => $c->conf()->{db}{default}
    );

    if ( $controller->connect() ) {
        $sender->send( [ $db, 'alive', 1 ] );
    }
    else {
        $sender->send( [ $db, 'alive', 0 ] );
        exit 1;
    }

    while ($running) {
        $c->load();

        if ( $controller->ping() ) {
            $sender->send( [ $db, 'alive', 1 ] );
        }
        else {
            $sender->send( [ $db, 'alive', 0 ] );
            exit 1;
        }

        my $ql = Configurator->new(
            file => File::Spec->rel2abs(
                $c->conf()->{db}{$db}{query_list}
                  // $c->conf()->{db}{default}{query_list},
                File::Basename::dirname( $c->file() )
            )
        );

        if ( $c->conf()->{db}{$db}{extra_query_list} ) {
            try {
                $ql->merge(
                    Configurator->new(
                        file => File::Spec->rel2abs(
                            $c->conf()->{db}{$db}{extra_query_list},
                            File::Basename::dirname( $c->conf()->file() )
                        )
                    )->conf()
                );
            }
            catch {
                $self->log()->warnf( q{[configurator] %s}, $_ );
            };
        }

        my @data;

        for my $query ( @{ $ql->conf()->{query_list} } ) {
            next unless $ql->conf()->{$query};

            my $arrayref = $controller->fetchall(
                $query, $ql->conf()->{$query}->{query},
                undef,  @{ $ql->conf()->{$query}->{bind_values} }
            ) or next;

            my $result;

            for my $row ( @{$arrayref} ) {
                $result .= join q{ }, map { $_ // () } @{$row};
            }

            if ( !defined $result || !length $result ) {
                $result = $ql->conf()->{$query}->{no_data_found} // next;
            }

            if ( $ql->conf()->{$query}->{send_to} ) {
                push @data, [ $_, $query, $result ]
                  for @{ $ql->conf()->{$query}->{send_to} };
            }
            else {
                push @data, [ $db, $query, $result ];
            }
        }

        $sender->send(@data);

        sleep( $c->conf()->{$db}->{sleep} // __PACKAGE__->SLEEP() );
    }

    $controller->disconnect();

    return 1;
}

1;

__END__
