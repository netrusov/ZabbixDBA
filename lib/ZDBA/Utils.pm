package ZDBA::Utils;

use strict;
use warnings;
use feature 'switch';

use Carp ();
use English '-no_match_vars';
use Exporter 'import';

our @EXPORT_OK = qw(hash_merge slurp spurt);

sub hash_merge {
  my ( $target, $source ) = @_;

  return unless $source;
  return unless ref $target eq 'HASH' && ref $target eq ref $source;

  no warnings 'experimental';
  for my $key ( keys %{$source} ) {
    if ( exists $target->{$key} ) {
      next unless ref $target->{$key} eq ref $source->{$key};

      for ( ref $source->{$key} ) {
        when (/ARRAY/) { push @{ $target->{$key} }, @{ $source->{$key} } }
        when (/HASH/) { hash_merge( $target->{$key}, $source->{$key} ) }
        default { undef }    # skip scalar references
      }
    } else {
      $target->{$key} = $source->{$key}
    }
  }
  use warnings 'experimental';

  return $target;
}

sub slurp {
  my ( $file, $mode ) = @_;

  $mode ||= '<';

  open my $fh, $mode, $file or Carp::confess sprintf q{failed to open file '%s': %s}, $file, $EXTENDED_OS_ERROR;

  my ( $ret, $content );

  while ( $ret = $fh->sysread( my $buffer, 131072, 0 ) ) { $content .= $buffer }

  unless ( defined $ret ) {
    Carp::confess sprintf q{failed to read from file '%s': %s}, $file, $EXTENDED_OS_ERROR;
  }

  close $fh
    or Carp::confess sprintf q{failed to close filehandle for file '%s': %s}, $file, $EXTENDED_OS_ERROR;

  return $content;
}

sub spurt {
  my ( $content, $file, $mode ) = @_;

  $mode ||= '>';

  open my $fh, $mode, $file
    or Carp::confess sprintf q{failed to open file '%s': %s}, $file, $EXTENDED_OS_ERROR;

  defined $fh->syswrite($content)
    or Carp::confess sprintf q{failed to write to file '%s': %s}, $file, $EXTENDED_OS_ERROR;

  close $fh
    or Carp::confess sprintf q{failed to close filehandle for file '%s': %s}, $file, $EXTENDED_OS_ERROR;

  return $content;
}

1;

__END__
