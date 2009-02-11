#!perl

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
   test => sub {
      my ($f) = @_;

      $a++;

      $f->unreg_my_set;
      $f->event ('test2');
   },
   test2 => sub {
      my ($f) = @_;
      $b++;
   }
);

$f->event ('test');
$f->event ('test');
$f->event ('test2');
$f->event ('test2');

is ($a, 1, 'first callback was called once');
is ($b, 0, 'second callback was called never');
