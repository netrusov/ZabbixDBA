use strict; use warnings; use bytes; use DBI; use JSON; use IO::Socket::INET;
my $c = do( shift @ARGV );
for my $d ( @{ $c->{db}{list} } ) { fork and next;
  my $dc = { %{ $c->{db}{default} }, %{ $c->{db}{$d} } };
  my $dh = DBI->connect( $dc->{dsn}, $dc->{user}, $dc->{pass} );
  while (1) {
    my $qc = do( $dc->{query_list} ); my @d;
    for my $q ( @{ $qc->{list} } ) {
      my $r = $dh->selectrow_arrayref( $qc->{$q}{query} );
      push @d, { host => $d, key => $q, value => $r->[0] };
    }
    my $r = JSON->new->utf8->encode( { 'request' => 'sender data', 'data' => [@d] } );
    my $s = IO::Socket::INET->new( PeerHost => $c->{zabbix}{host}, PeerPort => $c->{zabbix}{port} );
    $s->send( pack( 'a4 b V V a*', 'ZBXD', 0x01, length $r, 0x00, $r ) );
    $s->close;
    sleep 60;
  }
}
