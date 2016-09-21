package main;

use strict;
use warnings;

use forks 'exit' => 'threads_only';
use sigtrap 'handler', \&stop, 'normal-signals';
use FindBin '$Bin';
use File::Spec;
use Log::Log4perl ':easy';
use Log::Any::Adapter;

use lib File::Spec->catpath( $Bin, 'lib' );
use ZDBA;

$ENV{ZDBA_SPLIT_LOGS} = 0;

Log::Any::Adapter->set('Log4perl');
Log::Log4perl::init( File::Spec->catpath( $Bin, 'conf', 'log4perl.conf' ) );

my $running = 1;
my $counter = {};
my $pool    = {};

my $zdba = ZDBA->new( config => { file => shift @ARGV } );

$zdba->log->info( q{starting %s (version %s)}, $zdba->PROJECT_NAME, $zdba->VERSION );

while ($running) {
  $zdba->config->load;

  $ENV{ZDBA_SPLIT_LOGS} = $zdba->{config}{daemon}{split_logs};

  for my $db ( keys %{$pool} ) {
    unless ( grep { m/$db/ms } @{ $zdba->{config}{db}{list} } ) {
      $zdba->log->info( q{database '%s' has gone from configuration}, $db );

      $pool->{$db}->kill('INT')->join;
      delete $pool->{$db};
      delete $counter->{$db};
    }
  }

  for my $db ( @{ $zdba->{config}{db}{list} } ) {
    if ( $pool->{$db} ) {
      if ( $pool->{$db}->is_running ) {
        next;
      } else {
        count($db) or next;
      }
    }

    $zdba->log->info( q{starting thread for database '%s'}, $db );

    $pool->{$db} = threads->create( sub {
        $ENV{ZDBA_DBNAME} = $db;
        Log::Log4perl::init( File::Spec->catpath( $Bin, 'conf', 'log4perl.conf' ) );
        $zdba->monitor($db);
    } );
  }

  for ( threads->list(threads::all) ) {
    $_->kill('INT')->join unless $_->is_running;
  }

  sleep( $zdba->{config}{daemon}{sleep} // $zdba->SLEEP_DAEMON );
}

sub stop {
  $zdba->log->info( q{stopping %s}, $zdba->PROJECT_NAME );

  $running = 0;

  while ( threads->list(threads::all) ) {
    $_->kill('INT')->join for threads->list(threads::all);
  }

  return 1;
}

sub count {
  my ($db) = @_;

  my $rc = 1;

  if ( defined $counter->{$db} ) {
    --$counter->{$db} > 0 ? --$rc : delete $counter->{$db};
  } else {
    $counter->{$db} = $zdba->{config}{db}{$db}{retry_step}
      // $zdba->{config}{db}{default}{retry_step}
      // $zdba->RETRY_STEP;
    --$rc;
  }

  return $rc;
}

sub logfile_name {
  my $prefix = shift // 'zdba';
  my $name = $ENV{ZDBA_SPLIT_LOGS} ? ( $ENV{ZDBA_DBNAME} ? "${prefix}_$ENV{ZDBA_DBNAME}" : $prefix ) : $prefix;
  return File::Spec->catpath( $Bin, 'log', "${name}.log" );
}

1;

__END__
