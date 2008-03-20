package BS::Event;
use strict;
use Scalar::Util qw/weaken/;

=head1 NAME

BS::Event - A class that provides an event callback interface

=head1 SYNOPSIS

   package foo;
   use BS::Event;

   our @ISA = qw/BS::Event/;

   package main;
   my $o = foo->new;

   my $regid = $o->reg_cb (foo => sub {
      print "I got an event, with these args: $_[1], $_[2], $_[3]\n";
   });

   $o->event (foo => 1, 2, 3);

   $o->unreg_cb ($regid);

=head1 DESCRIPTION

This module was mainly written for L<Net::XMPP2>, L<Net::IRC3> and L<BS>
to provide a consistent API for registering and emitting events.
Even though I originally wrote it for those modules I relased it seperately
in case anyone may find this module useful.

For more comprehensive event handling see also L<Glib> and L<POE>.

This class provides a simple way to extend a class, by inheriting from
this class, with an event callback interface.

You will be able to register callbacks for event names and call them later.

This class is only really useful if you derive from it.

=head1 METHODS

=cut

sub new {
   my $this  = shift;
   my $class = ref($this) || $this;
   my $self  = { @_ };
   bless $self, $class;

   return $self
}

=over 4

=item B<set_exception_cb ($cb)>

If some event callback threw an exception then C<$cb> is called with
the exception as first argument.

=cut

sub set_exception_cb {
   my ($self, $cb) = @_;
   $self->{exception_cb} = $cb;
}

=item B<reg_cb ($eventname1, $cb1, [$eventname2, $cb2, ...])>

This method registers a callback C<$cb1> for the event with the
name C<$eventname1>. You can also pass multiple of these eventname => callback
pairs.

The return value will be an ID that represents the set of callbacks you have installed.
Call C<unreg_cb> with that ID to remove those callbacks again.

The callbacks will be called in an array context. If a callback doesn't want to
return any value it should return an empty list. All results from the callbacks
will be appended and returned by the C<event> method.

For every event there are two other events emitted:

Before the callbacks for C<$eventname> is being exectued the event
C<"before_$eventname"> is being emitted.
And after the callbacks for C<$eventname> have been run, the event
C<"after_$eventname"> is being emitted.

The C<"before_$eventname"> callbacks allow you to stop the execution
of all callbacks for the event C<$eventname> and C<"after_$eventname">.
This can be used to intercept events and stop them.

If you give reg_cb a special argument called C<_while_referenced>
you can prevent callbacks from being executed once the reference in the
second argument becomes undef. This works by converting the internal
reference of the argument to C<_while_referenced> to a weak reference
and looking whether that reference becomes undef.

It works like this:

   Scalar::Util::weaken $window;
   $event_source->reg_cb (
      _while_referenced => $window,
      disconnect => sub { $window->destroy }
   );

Whenever the C<disconnect> event is emitted now and C<$window> doesn't
exist anymore the callback will be removed;

=cut

sub reg_cb {
   my ($self, %regs) = @_;

   $self->{_ev_id}++;

   my $while_ref = delete $regs{_while_referenced};

   for my $cmd (keys %regs) {
      my $arg = [$self->{_ev_id}, $regs{$cmd}];

      if (defined $while_ref) {
         push @$arg, (1, $while_ref);
      }

      push @{$self->{events}->{$cmd}}, $arg;

      if ($arg->[2]) {
         weaken $arg->[3];
      }
   }

   $self->{_ev_id}
}

=item B<unreg_cb ($id)>

Removes the set C<$id> of registered callbacks. C<$id> is the
return value of a C<reg_cb> call.

=cut

sub unreg_cb {
   my ($self, $id) = @_;

   for my $key (keys %{$self->{events}}) {
      @{$self->{events}->{$key}} =
         grep {
            $_->[0] ne $id
         } @{$self->{events}->{$key}};
   }
}


=item B<event ($eventname, @args)>

Emits the event C<$eventname> and passes the arguments C<@args>.
The return value is a list of defined return values from the event callbacks.

See also the specification of the before and after events in C<reg_cb> above.

=cut

sub event {
   my ($self, $ev, @arg) = @_;

   my $old_stop = $self->{stop_event};
   $self->{stop_event} = 0;

   my @res;
   push @res, $self->_event ("before_$ev", @arg);

   if ($self->{stop_event}) {
      $self->{stop_event} = $old_stop;
      return @res;
   }

   push @res, $self->_event ("ext_before_$ev", @arg);

   if ($self->{stop_event}) {
      $self->{stop_event} = $old_stop;
      return @res;
   }

   push @res, $self->_event ($ev, @arg);

   push @res, $self->_event ("ext_after_$ev", @arg);

   push @res, $self->_event ("after_$ev", @arg);

   $self->{stop_event} = $old_stop;

   @res
}

=item B<_event ($eventname, @args)>

This directly executes the event C<$eventname> without executing
callbacks of the before and after events (as specified in C<reg_cb> above).

=cut

sub _event {
   my ($self, $ev, @arg) = @_;

   my $old_cb_state = $self->{cb_state};
   my @res;
   my $nxt = [];

   my @evs = @{$self->{events}->{$ev} || []};
   for my $rev (@evs) {
      my $state = $self->{cb_state} = {};

      if ($rev->[2] && not defined $rev->[3]) {
         $state->{remove} = 1;

      } else {
         eval {
            push @res, $rev->[1]->($self, @arg);
         };
         if ($@) {
            if ($self->{exception_cb}) {
               $self->{exception_cb}->($@);
            } else {
               warn "unhandled callback exception (object: $self, event: $ev): $@";
            }
         }
      }

      push @$nxt, $rev unless $state->{remove};
   }
   if (!@$nxt) {
      delete $self->{events}->{$ev}
   } else {
      $self->{events}->{$ev} = $nxt;
   }

   for my $ev_frwd (keys %{$self->{event_forwards}}) {
      my $rev = $self->{event_forwards}->{$ev_frwd};
      my $state = $self->{cb_state} = {};

      my $stop_before = $rev->[0]->{stop_event};
      $rev->[0]->{stop_event} = 0;
      eval {
         push @res, $rev->[1]->($self, $rev->[0], $ev, @arg);
      };
      if ($@) {
         if ($self->{exception_cb}) {
            $self->{exception_cb}->($@);
         } else {
            warn "unhandled callback exception: $@";
         }
      }
      if ($rev->[0]->{stop_event}) {
         $self->stop_event;
      }
      $rev->[0]->{stop_event} = $stop_before;

      if ($state->{remove}) {
         delete $self->{event_forwards}->{$ev_frwd};
      }
   }
   $self->{cb_state} = $old_cb_state;


   @res
}

=item B<unreg_me>

If this method is called from a callback on the first argument to the
callback (thats C<$self>) the callback will be deleted after it is finished.

=cut

sub unreg_me {
   my ($self) = @_;
   $self->{cb_state}->{remove} = 1;
}

=item B<stop_event>

When called in a 'before_' event callback then the execution of the
event is stopped after all 'before_' callbacks have been run.

=cut

sub stop_event {
   my ($self) = @_;
   $self->{stop_event} = 1;
}

=item B<add_forward ($obj, $forward_cb)>

This method allows to forward or copy all events to an object.
C<$forward_cb> will be called everytime an event is generated in C<$self>.
The first argument to the callback C<$forward_cb> will be C<$self>, the second
will be C<$obj>, the third will be the event name and the rest will be
the event arguments. (For third and rest of argument also see description
of C<event>).

(Please note that it might be most useful to call C<_event> in the callback
to allow objects that receive the forwarded events to react better.)

=cut

sub add_forward {
   my ($self, $obj, $forward_cb) = @_;
   $self->{event_forwards}->{$obj} = [$obj, $forward_cb];
}

=item B<remove_forward ($obj)>

This method removes a forward. C<$obj> must be the same
object that was given C<add_forward> as the C<$obj> argument.

=cut

sub remove_forward {
   my ($self, $obj) = @_;
   delete $self->{event_forwards}->{$obj};
}

=item B<remove_all_callbacks>

This method removes all registered event callbacks and forwards
from this object.

=cut

sub remove_all_callbacks {
   my ($self) = @_;
   $self->{events} = {};
   $self->{event_forwards} = {};
   delete $self->{exception_cb};
   delete $self->{cb_state};
   delete $self->{stop_event};
}

sub events_as_string_dump {
   my ($self) = @_;
   my $str = '';
   for my $ev (keys %{$self->{events}}) {
      my $evr = $self->{events}->{$ev};
      $str .= "$ev: " . scalar @{$evr} . "\n";
   }
   $str
}

=back

=head1 AUTHOR

Robin Redeker, C<< <elmex at ta-sa.org> >>, JID: C<< <elmex at jabber.org> >>

=head1 COPYRIGHT & LICENSE

Copyright 2007 Robin Redeker, all rights reserved.

This program is free software; you can redistribute it and/or modify it
under the same terms as Perl itself.

=cut

1;
