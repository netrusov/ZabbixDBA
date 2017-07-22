package ZDBA;

use Carp ();
use English '-no_match_vars';
use File::Basename 'dirname';
use File::Spec ();
use JSON;
use Time::HiRes qw(gettimeofday tv_interval);

use ZDBA::Config;
use ZDBA::DBIx;
use ZDBA::Sender;
use ZDBA::Utils qw(hash_merge flatten);

use Moo;

with 'ZDBA::Base';

# *** Public attributes

has config => (
  is       => 'ro',
  required => 1,

  # create new instance of config
  coerce => sub { ZDBA::Config->new(@_) }
);

# *** Private attributes

has [qw|dbi senders|] => (
  is => 'lazy'
);

has dbconf => ( is => 'rw' );

has json => (
  is => 'ro',
  default => sub { JSON->new->utf8 }
);

# *** Public methods

sub monitor {
  my ( $self, $db ) = @_;

  my $running = 1;
  local $SIG{USR1} = sub { $running = 0 };

  $self->log->info( q{starting monitoring of '%s'}, $db );

  # start main endless loop
  while ($running) {

    # reload config from file
    $self->{config}->load;

    # set db configuration
    $self->dbconf( { %{ $self->{config}{db}{default} }, %{ $self->{config}{db}{$db} } } );
    $self->dbconf->{sleep} ||= $self->SLEEP_THREAD;

    $self->log->debug( sub { qq{configuration for '%s' has been loaded:\n%s}, $db, $self->dump( $self->dbconf ) } );

    # load query file
    my $query_file = $self->{dbconf}{query_list};
    my $qconf      = {};
    for my $file ( ref $query_file ? @{$query_file} : $query_file ) {
      my $path = $self->rel2abs($file);
      $qconf = hash_merge( $qconf, $self->config->compile($path) );
    }

    my @data;    # data storage

    push @data, { host => $db, key => 'alive', value => $self->dbi->dbh->ping };

    my $timings = {
      main => {
        start => [gettimeofday]
      },
    };

    # iterate through query list
    for my $query ( @{ $qconf->{list} } ) {

      $self->log->debug( sub { qq{going to execute query '%s' against '%s'}, $query, $db } );

      # execute query on target database and store result
      my ( $result, $timing ) = $self->dbi->fetchone( %{ $qconf->{$query} } );
      $timings->{queries}{$query} = $timing;

      next unless @{$result};    # skip empty results

      # TODO: choose field separator
      $result = join ' ', grep { defined } @{$result}; # when two or more fields selected, join them with space.

      my @recipients = ($db);

      if ( $qconf->{$query}->{send_to} ) {
        my $send_to = $qconf->{$query}->{send_to};
        push @recipients, ref $send_to ? @{$send_to} : $send_to;
      }

      push @data, { host => $_, key => $query, value => $result } for @recipients;
    }

    $self->log->debug( sub { q{processing discovery rules for '%s'}, $db } );

    while ( my ( $query, $qref ) = each %{ $qconf->{discovery}{rule} } ) {
      $qref->{options} ||= { Slice => {} };

      my ( $result, $timing ) = $self->dbi->fetchall( %{$qref} );
      $timings->{queries}{$query} = $timing;

      next unless @{$result};

      my $discovered = { data => [] };

      for my $row ( @{$result} ) {
        push @{ $discovered->{data} }, { map { sprintf( '{#%s}', uc $_ ) => $row->{$_} } @{ $qref->{keys} } };
      }

      push @data, {
        host  => $db,
        key   => $query,
        value => $self->json->encode($discovered)
      };
    }

    while ( my ( $query, $qref ) = each %{ $qconf->{discovery}{item} } ) {
      $qref->{options} ||= { Slice => {} };

      my ( $result, $timing ) = $self->dbi->fetchall( %{$qref} );
      $timings->{queries}{$query} = $timing;

      next unless @{$result};

      for my $row ( @{$result} ) {
        push @data, map {
          {
            host  => $db,
            key   => sprintf( '%s[%s]', $query, $row->{$_} ),
            value => $row->{ $qref->{keys}{$_} }
          }
        } keys %{ $qref->{keys} };
      }
    }

    $timings->{main}{end} = [gettimeofday];
    $timings->{main}{elapsed} = tv_interval( @{ $timings->{main} }{qw|start end|} );

    $self->log->info( q{completed fetching data on '%s' (elapsed %s)}, $db, $timings->{main}{elapsed} );
    $self->log->debug( sub { qq{timings for '%s':\n%s}, $db, $self->dump($timings) } );

    # send fetched data to zabbix
    for my $sender ( values %{ $self->senders } ) {
      $sender->send(@data);
    }

    # cleanup data array
    undef @data;

    $self->log->debug( sub { q{thread for '%s' is going to sleep for %d sec.}, $db, $self->{dbconf}{sleep} } );

    # sleep before next iteration
    sleep $self->{dbconf}{sleep};
  }

  $self->log->info( q{stopping monitoring of '%s'}, $db );

  $self->dbi->disconnect;

  return;
}

# *** Private methods

sub _build_dbi {
  return ZDBA::DBIx->new( shift->{dbconf} );
}

sub _build_senders {
  my $senders = {};

  for my $config ( flatten( shift->{config}{zabbix} ) ) {
    $senders->{$config} = ZDBA::Sender->new($config)
  }

  return $senders;
}

sub rel2abs {
  my ( $self, $path ) = @_;
  return File::Spec->rel2abs( $path, dirname( $self->config->file ) );
}

1;

__END__
