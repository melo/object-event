#!perl -T

use Test::More tests => 1;

BEGIN {
	use_ok( 'BS::Event' );
}

diag( "Testing BS::Event $BS::Event::VERSION, Perl $], $^X" );
