#!perl -T

use Test::More tests => 25;

package foo;
use strict;
no warnings;

use Object::Event;

our @ISA = qw/Object::Event/;

package main;
use strict;
no warnings;

my $f = foo->new;

my ($before, $event, $after, $ext_before, $ext_after);
sub clear { $before = $event = $after = $ext_before = $ext_after = 0 }

$f->reg_cb (
   before_test     => sub { $before     = 1; $_[0]->stop_event if $_[1] eq 'before'     },
   ext_before_test => sub { $ext_before = 1; $_[0]->stop_event if $_[1] eq 'ext_before' },
   test            => sub { $event      = 1; $_[0]->stop_event if $_[1] eq 'event'      },
   ext_after_test  => sub { $ext_after  = 1; $_[0]->stop_event if $_[1] eq 'ext_after'  },
   after_test      => sub { $after      = 1; $_[0]->stop_event if $_[1] eq 'after'      },
);

clear();
$f->event ('test', 'event');

is ($before,     1, 'before has been executed');
is ($ext_before, 1, 'ext_before has been executed');
is ($event,      1, 'event has been executed');
is ($ext_after,  0, 'ext_after has not been executed');
is ($after,      0, 'after has not been executed');

clear();
$f->event ('test', 'before');

is ($before,     1, 'before has been executed');
is ($ext_before, 0, 'ext_before has been executed');
is ($event,      0, 'event has been executed');
is ($ext_after,  0, 'ext_after has not been executed');
is ($after,      0, 'after has not been executed');

clear();
$f->event ('test', 'after');

is ($before,     1, 'before has been executed');
is ($ext_before, 1, 'ext_before has been executed');
is ($event,      1, 'event has been executed');
is ($ext_after,  1, 'ext_after has not been executed');
is ($after,      1, 'after has not been executed');

clear();
$f->event ('test', 'ext_before');

is ($before,     1, 'before has been executed');
is ($ext_before, 1, 'ext_before has been executed');
is ($event,      0, 'event has been executed');
is ($ext_after,  0, 'ext_after has not been executed');
is ($after,      0, 'after has not been executed');

clear();
$f->event ('test', 'ext_after');

is ($before,     1, 'before has been executed');
is ($ext_before, 1, 'ext_before has been executed');
is ($event,      1, 'event has been executed');
is ($ext_after,  1, 'ext_after has not been executed');
is ($after,      0, 'after has not been executed');

