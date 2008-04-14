#!perl -T

use Test::More tests => 2;

package foo;
use strict;
no warnings;

use BS::Event;

our @ISA = qw/BS::Event/;

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
      $f->unreg_me;

      $f->reg_cb (test => sub {
         $b++;
         $f->unreg_me;
      });
   }
);

$f->event ('test');
$f->event ('test');
$f->event ('test');

is ($a, 1, 'first callback was called once');
is ($b, 1, 'second callback was called once');
