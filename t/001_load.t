# -*- perl -*-

# t/001_load.t - check module loading and create testing directory

use Test::More tests => 2;

BEGIN { use_ok( 'Games::Roguelike::Area' ); }

my $object = Games::Roguelike::Area->new(noconsole=>1);

isa_ok ($object, 'Games::Roguelike::Area');
