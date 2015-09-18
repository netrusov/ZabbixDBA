package Dispatcher;

use 5.010;
use strict;
use warnings FATAL => 'all';

use DBI;
use Try::Tiny;

sub new {
    my $class = shift;
    return bless {@_}, $class;
}

sub connect {
    my $self = shift;
    my ( $db, $conf, $log, $sender ) = @$self{qw|db conf log sender|};

    my $opts = {
        PrintError => 0,
        RaiseError => 0,
        AutoCommit => 0,
    };

    if ( !$conf->{$db}->{dsn} ) {
        $log->warnf( q{[dbi] DSN not specified for %s}, $db );
        return;
    }

    my $user = $conf->{$db}->{user}     // $conf->{default}->{user};
    my $pass = $conf->{$db}->{password} // $conf->{default}->{password};

    my $alive = 1;

    my $dbh = DBI->connect_cached( $conf->{$db}->{dsn}, $user, $pass, $opts );

    if ( DBI->errstr() ) {
        $log->errorf( q{[dbi] connection failed for '%s@%s' : %s},
            $user, $db, DBI->errstr() );
        $alive = 0;
    }
    try {
        $sender->send( [ $db, 'alive', $alive ] );
    }
    catch {
        $log->warnf( q{[sender] %s}, $_ );
    };

    if ($alive) {
        $log->infof( q{[dbi] connected to '%s@%s' (%s)},
            $user, $db, $conf->{$db}->{dsn} );
    }
    $self->{dbh} = $dbh;

    return $alive;
}

sub ping {
    my $self = shift;
    my ( $db, $dbh, $log, $sender ) = @$self{qw|db dbh log sender|};

    my $alive = 1;

    if ( !$dbh->ping() ) {
        $log->errorf( q{[dbi] connection lost contact for '%s'}, $db );
        $alive = 0;
    }

    try {
        $sender->send( [ $db, 'alive', $alive ] );
    }
    catch {
        $log->warnf( q{[sender] %s}, $_ );
    };

    return $alive;
}

sub fetchall {
    my ( $self, $query_name, $query, $opts, @bind_values ) = @_;
    my ( $db, $dbh, $log ) = @$self{qw|db dbh log|};

    my $result = $dbh->selectall_arrayref( $query, $opts, @bind_values );

    if ( $dbh->errstr() ) {
        $log->errorf( q{[dbi] %s => %s : %s},
            $db, $query_name, $dbh->errstr() );
    }

    # Issuing rollback due to some internal DBI methods
    # that require commit/rollback after using Slice in fetch
    $dbh->rollback();

    return $result;
}

sub disconnect {
    my $self = shift;
    $self->{dbh}->disconnect();
    return 1;
}

sub set {
    my $self = shift;
    my $args = {@_};
    $self->{$_} = $args->{$_} for ( keys %{$args} );
    return 1;
}

sub data {
    my ( $self, @data ) = @_;
    push @{ $self->{data} }, @data;
    return 1;
}

sub send {
    my ( $self, @data )   = @_;
    my ( $log,  $sender ) = @$self{qw|log sender|};
    
    try {
        $sender->send( @{ $self->{data} } );
    }
    catch {
        $log->warnf( q{[sender] %s}, $_ );
    };

    undef $self->{data};

    return 1;
}

1;
