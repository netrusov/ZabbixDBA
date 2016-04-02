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
        $self->log()->warnf( q{[dbi] DSN not specified for %s}, $self->db() );
        return;
    }

    my $user = $self->dbconf()->{user}     // $self->default()->{user};
    my $pass = $self->dbconf()->{password} // $self->default()->{password};

    my $alive = 1;

    my $dbh =
      DBI->connect_cached( $self->dbconf()->{dsn}, $user, $pass, $opts );

    if ( DBI->errstr() ) {
        $self->log()->errorf( q{[dbi] connection failed for '%s@%s' : %s},
            $user, $self->db(), DBI->errstr() );
        $alive = 0;
    }

    if ($alive) {
        $self->log()->infof( q{[dbi] connected to '%s@%s' (%s)},
            $user, $self->db(), $self->dbconf()->{dsn} );
    }

    $self->dbh($dbh);

    return $alive;
}

sub ping {
    my $self = shift;

    my $alive = 1;

    if ( !$self->dbh()->ping() ) {
        $self->log()
          ->errorf( q{[dbi] connection lost contact for '%s'}, $self->db() );
        $alive = 0;
    }

    return $alive;
}

sub fetchall {
    my ( $self, $query_name, $query, $opts, @bind_values ) = @_;

    my $result =
      $self->dbh()->selectall_arrayref( $query, $opts, @bind_values );

    if ( $self->dbh()->errstr() ) {
        $self->log()->errorf( q{[dbi] %s => %s : %s},
            $self->db(), $query_name, $self->dbh()->errstr() );
    }

    # Issuing rollback due to issue in some internal DBI method
    # that require commit/rollback after using Slice in fetch
    $self->dbh()->rollback();

    return $result;
}

sub disconnect {
    my $self = shift;

    return 1 unless $self->dbh();

    $self->dbh()->disconnect();

    return 1;
}

1;

__END__
while ( my ( $rule, $v ) = each %{ $ql->conf()->{discovery}->{rule} } ) {
    my $result = $dispatcher->fetchall( $rule, $v->{query}, { Slice => {} } )
      or next;

    if ( defined $result ) {
        $dispatcher->data(
            Zabbix::Discoverer::rule( $self->db(), $rule, $result, $v->{keys} )
        );
    }
}

while ( my ( $item, $v ) = each %{ $ql->conf()->{discovery}->{item} } ) {
    my $result = $dispatcher->fetchall( $item, $v->{query}, { Slice => {} } )
      or next;

    if ( defined $result ) {
        $dispatcher->data(
            Zabbix::Discoverer::item( $self->db(), $item, $result, $v->{keys} )
        );
    }
}
