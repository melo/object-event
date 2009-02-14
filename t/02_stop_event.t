#!perl -T

use Test::More tests => 9;

package foo;
use strict;
no warnings;

use Object::Event;

our @ISA = qw/Object::Event/;

package main;
use strict;
no warnings;

my $f = foo->new;

my ($before, $event, $after);
sub clear { $before = $event = $after = 0 }

$f->reg_cb (
   before_test => sub { $before = 1; $_[0]->stop_event if $_[1] eq 'before' },
   test        => sub { $event  = 1; $_[0]->stop_event if $_[1] eq 'event' },
   after_test  => sub { $after  = 1; $_[0]->stop_event if $_[1] eq 'after' },
);

clear();
$f->event ('test', 'event');

is ($before, 1, 'before has been executed');
is ($event,  1, 'event has been executed');
is ($after,  0, 'after has not been executed');

clear();
$f->event ('test', 'before');

is ($before, 1, 'before has been executed');
is ($event,  0, 'event has not been executed');
is ($after,  0, 'after has not been executed');

clear();
$f->event ('test', 'after');

is ($before, 1, 'before has been executed');
is ($event,  1, 'event has been executed');
is ($after,  1, 'after has been executed');
