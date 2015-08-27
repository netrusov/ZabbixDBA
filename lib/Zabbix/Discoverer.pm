package Zabbix::Discoverer;

use 5.010;
use strict;
use warnings;
use English qw(-no_match_vars);

use JSON ();

sub new {
    return bless {}, shift;
}

sub rule {
    my ( $self, $db, $rule, $result, $keys ) = @_;

    # JSON is required by Zabbix when discovering items
    my $json = { data => [] };
    for my $row ( @{$result} ) {
        push @{ $json->{data} },
            { map { sprintf( '{#%s}', $_ ) => $row->{$_} } @{$keys} };
    }
    return [ $db, $rule, JSON::encode_json($json) ];
}

sub item {
    my ( $self, $db, $item, $result, $keys ) = @_;
    my @data;
    for my $row ( @{$result} ) {
        for ( keys %{$keys} ) {
            push @data,
                [
                $db,
                sprintf( '%s[%s]', $item, $row->{$_} ),
                $row->{ $keys->{$_} }
                ];
        }
    }
    return @data;
}

1;
