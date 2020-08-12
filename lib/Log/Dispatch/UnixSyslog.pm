use strict;
use warnings;
package Log::Dispatch::UnixSyslog;

use parent qw(Log::Dispatch::Output);
# ABSTRACT: log events to syslog with Unix::Syslog

use Log::Dispatch 2.0 ();
use Unix::Syslog;

=head1 SYNOPSIS

  use Log::Dispatch;
  use Log::Dispatch::UnixSyslog;

  my $log = Log::Dispatch->new;

  $log->add(
    Log::Dispatch::UnixSyslog->new(
      ident => 'super-cool-daemon',
      min_level => 'debug',
      flush_if  => sub { (shift)->event_count >= 60 },
    )
  );

  while (@events) {
    $log->warn($_);
  }

=head1 DESCRIPTION

This provides a Log::Dispatch log output plugin that sends things to syslog.
"But there's already Log::Dispatch:Syslog!" you cry.  Well, that uses
Sys::Syslog, which is core, but it's overcomplicated and inefficient, too.
This plugin uses Unix::Syslog, which does a lot less, and should be more
efficient at doing it.

=method new

 my $output = Log::Dispatch::UnixSyslog->new(\%arg);

This method constructs a new Log::Dispatch::UnixSyslog output object.  In
addition to the standard parameters documented in L<Log::Dispatch::Output>,
this takes the following arguments:

  ident     - a string to prepend to all messages in the system log; required
  facility  - which syslog facility to log to (as a string); required

=cut

my %IS_FACILITY = map {; $_ => 1 } qw(
  auth    authpriv    cron    daemon
  ftp     kern        lpr     mail
  news    security    syslog  user
  uucp
  local0  local1      local2  local3
  local4  local5      local6  local7
);

sub new {
  my ($class, %arg) = @_;

  Carp::croak('required parameter "ident" empty or undefined')
    unless length $arg{ident};

  Carp::croak('required parameter "facility" not defined')
    unless defined $arg{facility};

  Carp::croak('provided facility value is not a valid syslog facility')
    unless $IS_FACILITY{ $arg{facility} };

  my $const_name = "LOG_\U$arg{facility}";

  Carp::croak('provided facility value is valid but unknown?!')
    unless my $const = Unix::Syslog->can($const_name);

  my $self = {
    ident     => $arg{ident},
    facility  => scalar $const->(),
  };

  bless $self => $class;

  # this is our duty as a well-behaved Log::Dispatch plugin
  $self->_basic_init(%arg);

  # hand wringing: What if someone is re-openlog-ing after this?  Well, they
  # ought not to do that!  We could re-open every time, but let's just see how
  # this goes, for now. -- rjbs, 2020-08-11
  Unix::Syslog::openlog($self->{ident}, 0, $self->{facility});

  return $self;
}

=method log_message

This is the method which performs the actual logging, as detailed by
Log::Dispatch::Output.

=cut

sub log_message {
  my ($self, %p) = @_;

  # In syslog, emergency is 0 and debug is 7.  In Log::Dispatch, it is the
  # reverse.  Bah. -- rjbs, 2020-08-11
  my $sys_level = 7 - $self->_level_as_number($p{level});
  my $priority  = $sys_level | $self->{facility};

  Unix::Syslog::syslog($priority, '%s', $p{message});

  return;
}

1;
