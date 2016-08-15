package ZDBA::Logger;

use Log::Any;

local $| = 1;
our $AUTOLOAD;

use Moo;

has logger => (
  is      => 'ro',
  lazy    => 1,
  default => sub { Log::Any->get_logger( category => ref shift ) }
);

# This creepy chunk of code creates wrappers for Log::Any's methods
# that check for current log level, get caller's package name and line number where this method was called.
# Profit of passing subroutine is that all code inside it will only be called on corresponding log level.
sub AUTOLOAD {

  # get missing method name
  ( my $method = $AUTOLOAD ) =~ s/^.*::(\w+?)f?$/$1/;
  return if $method =~ /^[A-Z]+$/;

  # get level checker name (eg. 'is_debug')
  ( my $is_level = $method ) =~ s/^/is_/;

  # create wrapper
  my $sub = sub {
    my ( $self, @args ) = @_;
    return unless $self->logger->$is_level;
    my $caller = sprintf '[%s]', join q{:}, ( caller(1) )[3], ( caller(0) )[2];
    my ( $string, @binds ) = ref $args[0] ? $args[0]->() : @args;
    my $message = sprintf $string, @binds;
    $self->logger->$method( join q{ }, $caller, $message );
    return $message;
  };

  # create reference to newly created method in symbol table
  no strict 'refs';
  *{$AUTOLOAD} = $sub;
  use strict 'refs';

  goto &{$sub};
}

1;

__END__
