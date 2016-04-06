package ZDBA;

use strict;
use warnings FATAL => 'all';

use File::Basename  ();
use File::Spec      ();
use List::MoreUtils ();
use Time::HiRes     ();
use Try::Tiny;

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

    my $c;

    try {
        $c = Configurator->new( file => $self->confile() );
    }
    catch {
        $self->log()->errorf( q{[%s:%d] %s}, __PACKAGE__, __LINE__, $_ );
        exit 1;
    };

    my $sender = Zabbix::Sender->new( $c->conf()->{zabbix} );

    my $controller = ZDBA::Controller->new(
        db      => $db,
        dbconf  => $c->conf()->{db}{$db},
        default => $c->conf()->{db}{default}
    );

    if ( !$controller->connect() ) {
        $sender->send( [ $db, 'alive', 0 ] );
        exit 1;
    }

    while ($running) {
        try {
            $c->load();
        }
        catch {
            $self->log()->errorf( q{[%s:%d] %s}, __PACKAGE__, __LINE__, $_ );
            exit 1;
        };

        if ( !$controller->ping() ) {
            $sender->send( [ $db, 'alive', 0 ] );
            exit 1;
        }

        $sender->send( [ $db, 'alive', 1 ] );

        my $ql;

        try {
            $ql = Configurator->new(
                file => File::Spec->rel2abs(
                    $c->conf()->{db}{$db}{query_list}
                      // $c->conf()->{db}{default}{query_list},
                    File::Basename::dirname( $c->file() )
                )
            );
        }
        catch {
            $self->log()->errorf( q{[%s:%d] %s}, __PACKAGE__, __LINE__, $_ );
            exit 1;
        };

        if ( $c->conf()->{db}{$db}{extra_query_list} ) {
            try {
                $ql->merge(
                    Configurator->new(
                        file => File::Spec->rel2abs(
                            $c->conf()->{db}{$db}{extra_query_list},
                            File::Basename::dirname( $c->file() )
                        )
                    )->conf()
                );
            }
            catch {
                $self->log()->warnf( q{[%s:%d] %s}, __PACKAGE__, __LINE__, $_ );
            };
        }

        my @data;

        $self->log()->debugf( q{[%s:%d] started fetching data on '%s'},
            __PACKAGE__, __LINE__, $db );

        my $start = [Time::HiRes::gettimeofday];

        for my $query ( @{ $ql->conf()->{query_list} } ) {
            next unless $ql->conf()->{$query} && $ql->conf()->{$query}{query};

            my $qref = $ql->conf()->{$query};

            my $result = $controller->fetchall( $query, $qref->{query},
                undef, @{ $qref->{bind_values} } );

            next unless $result;

            my $data;

            for my $row ( @{$result} ) {
                $data .= join q{ }, map { $_ // () } @{$row};
            }

            if ( !defined $data || !length $data ) {
                $data = $qref->{no_data_found} // next;
            }

            if ( $qref->{send_to} ) {
                push @data, [ $_, $query, $data ] for @{ $qref->{send_to} };
            }
            else {
                push @data, [ $db, $query, $data ];
            }
        }

        while ( my ( $query, $qref ) =
            each %{ $ql->conf()->{discovery}{rule} } )
        {
            my $result = $controller->fetchall(
                $query, $qref->{query},
                { Slice => {} },
                @{ $qref->{bind_values} }
            );

            next unless $result;

            while ( my @result_piece = splice @{$result}, 0, 5 ) {
                my $data = { data => [] };

                for my $row (@result_piece) {
                    push @{ $data->{data} },
                      { map { sprintf( '{#%s}', $_ ) => $row->{$_} }
                          @{ $qref->{keys} } };
                }

                # Why not sender's JSON?
                push @data, [ $db, $query, $sender->_json()->encode($data) ];
            }
        }

        while ( my ( $query, $qref ) =
            each %{ $ql->conf()->{discovery}{item} } )
        {
            my $result = $controller->fetchall(
                $query, $qref->{query},
                { Slice => {} },
                @{ $qref->{bind_values} }
            );

            next unless $result;

            for my $row ( @{$result} ) {
                push @data, map {
                    [
                        $db,
                        sprintf( '%s[%s]', $query, $row->{$_} ),
                        $row->{ $qref->{keys}{$_} }
                    ]
                } keys %{ $qref->{keys} };
            }
        }

        $self->log()->infof(
            q{[%s:%d] completed fetching data on '%s', elapsed: %s},
            __PACKAGE__,
            __LINE__,
            $db,
            Time::HiRes::tv_interval( $start, [Time::HiRes::gettimeofday] )
        );

        $sender->send(@data);

        sleep( $c->conf()->{db}{$db}{sleep} // $c->conf()->{db}{default}{sleep}
              // $self->SLEEP_THREAD() );
    }

    $controller->disconnect();

    return 1;
}

1;

__END__
