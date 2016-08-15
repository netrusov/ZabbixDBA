use strict;
use warnings;
use bytes;

use DBI;
use JSON;
use IO::Socket::INET;

# load configuration file
my $conf = do( shift @ARGV );

# iterate through database list
for my $db ( @{ $conf->{db}{list} } ) {

  # create fork for each database
  fork and next;

  # apply default values
  my $dbconf = { %{ $conf->{db}{default} }, %{ $conf->{db}{$db} } };

  # connect to database
  my $dbh = DBI->connect( $dbconf->{dsn}, $dbconf->{user}, $dbconf->{pass} );

  # start main endless loop
  while (1) {

    # load query file
    my $qconf = do( $dbconf->{query_list} );

    my @data;    # data storage

    # iteratу through query list
    for my $query ( @{ $qconf->{list} } ) {

      # execute query on target database and store result
      my $result = $dbh->selectrow_arrayref( $qconf->{$query}{query} );
      push @data, { host => $db, key => $query, value => $result->[0] };
    }

    # prepare request body
    my $request = JSON->new->utf8->encode( {
        'request' => 'sender data',
        'data'    => [@data]
    } );

    # open connection to zabbix host
    my $socket = IO::Socket::INET->new(
      PeerHost => $conf->{zabbix}{host},
      PeerPort => $conf->{zabbix}{port}
    );

    # pack request and send it to zabbix
    $socket->send( pack( 'a4 b V V a*', 'ZBXD', 0x01, length $request, 0x00, $request ) );

    # close socket
    $socket->close;

    # sleep before next iteration
    sleep 60;
  }
}
