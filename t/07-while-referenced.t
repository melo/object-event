#!perl

use Test::More tests => 2;

package foo;
use strict;
no warnings;

use Object::Event;

our @ISA = qw/Object::Event/;

package main;
use strict;
use warnings;
use Scalar::Util qw( weaken );

my $f = foo->new;
my $hits;

{
  my $w = foo->new;

  $f->reg_cb(
    _while_referenced => $w,
    hit_me => sub { $hits++ },
  );

  $f->event('hit_me');
  is($hits, 1, 'Event still active');
}
$f->event('hit_me');
is($hits, 1, 'Event no longer active');
