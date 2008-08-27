#!perl

use Test::More tests => 1;

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
$f->reg_cb (
   test => sub {
      my ($f) = @_;

      $a++;

      if ($a == 1) {
         $f->event ('test');
      } elsif ($a == 2) {
         $f->unreg_me;
      }
   }
);

$f->event ('test');
$f->event ('test');

is ($a, 2, 'first callback was called twice');
