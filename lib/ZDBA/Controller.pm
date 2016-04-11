package ZDBA::Controller;

use strict;
use warnings FATAL => 'all';

use DBI;

use Moo;

with 'ZDBA::Base';

has db => (
    is       => 'ro',
    required => 1
);

has dbconf => (
    is       => 'ro',
    required => 1
);

has default => ( is => 'ro' );

has dbh => ( is => 'rw' );

no Moo;

sub connect {
    my ($self) = @_;

    my $opts = {
        PrintError => 0,
        RaiseError => 0,
        AutoCommit => 0,
    };

    if ( !$self->dbconf()->{dsn} ) {
        $self->log()->warnf( q{[%s:%d] DSN not specified for %s},
            __PACKAGE__, __LINE__, $self->db() );
        return;
    }

    my $user = $self->dbconf()->{user}     // $self->default()->{user};
    my $pass = $self->dbconf()->{password} // $self->default()->{password};

    my $alive = 1;

    my $dbh =
      DBI->connect_cached( $self->dbconf()->{dsn}, $user, $pass, $opts );

    if ( DBI->errstr() ) {
        $self->log()->errorf( q{[%s:%d] connection failed for '%s@%s' : %s},
            __PACKAGE__, __LINE__, $user, $self->db(), DBI->errstr() );
        $alive = 0;
    }

    if ($alive) {
        $self->log()->infof( q{[%s:%d] connected to '%s@%s' (%s)},
            __PACKAGE__, __LINE__, $user, $self->db(), $self->dbconf()->{dsn} );
    }

    $self->dbh($dbh);

    return $alive;
}

sub ping {
    my $self = shift;

    my $alive = 1;

    if ( !$self->dbh()->ping() ) {
        $self->log()->errorf( q{[%s:%d] connection lost contact for '%s'},
            __PACKAGE__, __LINE__, $self->db() );
        $alive = 0;
    }

    return $alive;
}

sub fetchall {
    my ( $self, $query_name, $query, $opts, @bind_values ) = @_;

    $self->log()->debugf( q{[%s:%d] fetching data for '%s' on '%s'},
        __PACKAGE__, __LINE__, $query_name, $self->db() );

    my $result =
      $self->dbh()->selectall_arrayref( $query, $opts, @bind_values );

    if ( $self->dbh()->errstr() ) {
        $self->log()->errorf( q{[%s:%d] %s => %s : %s},
            __PACKAGE__, __LINE__,
            $self->db(), $query_name, $self->dbh()->errstr() );
    }

    # Issuing rollback due to issue in some internal DBI method
    # that requires commit/rollback after using Slice in fetch
    $self->dbh()->rollback();

    return $result // [];
}

sub disconnect {
    my $self = shift;

    $self->log()->infof( q{[%s:%d] disconnecting from '%s'},
        __PACKAGE__, __LINE__, $self->db() );

    return 1 unless $self->dbh();

    $self->dbh()->disconnect();

    return 1;
}

1;

__END__
