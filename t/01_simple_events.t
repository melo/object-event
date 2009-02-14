#!perl -T

use Test::More tests => 12;

package foo;
use strict;
no warnings;

use Object::Event;

our @ISA = qw/Object::Event/;

package main;
use strict;
no warnings;

my $f = foo->new;

my $cnt           = 0;
my @cnt           = ();
my $called        = 0;
my $called_after  = 0;
my $called_before = 0;
my $ids = $f->reg_cb (
   before_test => sub { $called_before += $_[1] },
   test        => sub { $cnt[$cnt++] = 'first'; $called += $_[1] },
   test        => sub { $cnt[$cnt++] = 'second'; $called -= ($_[1] / 2) },
   after_test  => sub { $called_after  += $_[1] },
);

$f->event (test => 10);

$f->unreg_cb ($ids);

$f->event (test => 20);

is ($called, 5, "the two main event callbacks were called");
is ($cnt[0], 'first', "the first event callback was called first");
is ($cnt[1], 'second', "the second event callback was called first");
is ($called_after, 10, "main after event callback was called");
is ($called_before, 10, "main before event callback was called");

my $cb = sub { $called++ };
$f->reg_cb( hit_me => $cb );
$f->event('hit_me');
is($called, 6, 'Hit me was called');

$f->unreg_cb($cb);
$f->event('hit_me');
is($called, 6, 'Hit me was unregistered correctly');

my $died;
$f->set_exception_cb(sub {
  $died++;
});
$f->reg_cb( zombie => sub { die "And we are done, " } );

$f->event('zombie');
is ($died, 1, 'Exception callback was called');

$f->set_exception_cb(undef);

$SIG{__WARN__} = sub { $died = $_[0] };
$f->event('zombie');
like ($died, qr/unhandled callback exception/, 'Exception generated a warning');

$f->remove_all_callbacks;
$called = 0;
$f->event('hit_me');
is ($called, 0, 'No more registered events');

my $t = $f->events_as_string_dump;
is ($t, '');

$f->reg_cb('hit_me' => $cb);

$t = $f->events_as_string_dump;
is ($t, "hit_me: 1\n");

