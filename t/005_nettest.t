# -*- perl -*-

# t/005_nettest.t - test network game 

use strict;

use Test::More tests => 3;

use IO::Socket::INET;

BEGIN { use_ok( 'Games::Roguelike::World::Daemon' ); }

my $testaddr = '127.0.0.9';
my $stdout = new IO::File;

open($stdout, ($^O =~ /win32/) ? ">NUL" : ">/dev/null");

my $world = myWorld->new(addr=>$testaddr, port=>0, stdout=>$stdout, noinit=>1);

isa_ok ($world, 'Games::Roguelike::World::Daemon');

$world->area(new Games::Roguelike::Area(name=>'1'));

$world->area->load(map=>'
#######
#.....#
#######
');

my $sock = IO::Socket::INET->new(PeerAddr => $testaddr, PeerPort => $world->{main_sock}->sockport, Proto => 'tcp');
$sock->autoflush(1);
$sock->write(chr(255));

my $now = time();
$world->proc();
isa_ok($world->{vp}, 'Games::Roguelike::Mob');
$sock->write(chr(255));
$world->proc();

# good to clean up so harness doesn't panic
close ($sock);
undef $world;

package myWorld;
use base 'Games::Roguelike::World::Daemon';
sub newconn {                                           
        my $self = shift;
        my $char = Games::Roguelike::Mob->new($self->area(1),
                sym=>'@',
                color=>'',
                pov=>7
        );
        $self->{vp} = $char;                             
        $self->{state} = 'MOVE';                         
}

sub readinput {
        my $self = shift;
	$self->{state} = 'QUIT';
}

sub setfocuscolor {
	# leave color alone, just to make the output easier
}
