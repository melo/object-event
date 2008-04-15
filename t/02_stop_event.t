#!perl -T

use Test::More tests => 2;

package foo;
use strict;
no warnings;

use Object::Event;

our @ISA = qw/Object::Event/;

package main;
use strict;
no warnings;

my $f = foo->new;

my $a = 0;
my $b = 0;
$f->reg_cb (
   before_test => sub { $a = 1 },
   test        => sub { $_[0]->stop_event; },
   after_test  => sub { $b = 1; },
);

$f->event ('test');

is ($a, 1, 'before has been executed');
is ($b, 0, 'after has not been executed');
