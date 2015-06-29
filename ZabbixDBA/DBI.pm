package ZabbixDBA::DBI;

BEGIN {
    push @ISA, 'DBI::db';
}

use 5.010;
use strict;
use warnings;
use Carp qw(confess carp);
use base 'DBI::db';

our $VERSION = 1.001;

use parent 'DBI';
use DBD::Oracle qw(:ora_session_modes);

sub new {
    my ( $class, $dsn, $user, $pass, $opts ) = @_;
    if ( $opts && !ref $opts ) {
        confess q{Method '_connect' needs hash ref as fourth arg};
    }

    $opts->{PrintError} ||= 0;
    $opts->{RaiseError} ||= 0;
    $opts->{AutoCommit} ||= 0;

    if ( lc($user) eq 'sys' ) {
        $opts->{ora_session_mode} = ORA_SYSDBA;
    }

    my $dbh = DBI->connect( $dsn, $user, $pass, $opts )
        or confess DBI->errstr;

    return bless $dbh, $class;
}

sub fetchone {
    my ( $self, $query, $opts, @bind_values ) = @_;

    if ( ref $query ) {
        confess 'Only Strings allowed';
    }

    my $result = $self->selectrow_array( $query, $opts, @bind_values );

    if ( $self->errstr ) {
        carp 'An error occurred: ' . $self->errstr;
        return;
    }

    return $result;
}

sub fetchmany {
    my ( $self, $query, $opts, @bind_values ) = @_;

    my @queries = _is_legal($query);
    my @rows;

    for (@queries) {
        my $result = $self->selectall_arrayref( $_, $opts, @bind_values );

        if ( $self->errstr ) {
            carp 'An error occurred: ' . $self->errstr;
            next;
        }

        for ( @{$result} ) {
            push @rows, $_;
        }

    }
    return wantarray ? @rows : \@rows;
}

sub fetchplsql {
    my ( $self, $query, $opts, @bind_values ) = @_;

    my @queries = _is_legal($query);
    my @rows;

    for (@queries) {
        $self->func( 1_000_000, 'dbms_output_enable' );
        $self->do( $_, $opts, @bind_values );

        if ( $self->errstr ) {
            carp 'An error occurred: ' . $self->errstr;
            next;
        }

        my @result = $self->func('dbms_output_get');
        push @rows, @result;
    }

    return wantarray ? @rows : \@rows;
}

sub _is_legal {
    my ($query) = @_;

    my @queries;

    if ( ref $query eq 'ARRAY' ) {
        push @queries, @{$query};
    }
    elsif ( ref $query eq 'HASH' ) {
        confess 'Hashes are illegal. Only Strings and Arrays allowed.';
    }
    else {
        push @queries, $query;
    }

    return wantarray ? @queries : \@queries;
}

1;