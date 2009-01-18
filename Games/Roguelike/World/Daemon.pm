package Games::Roguelike::World::Daemon;

use strict;

use Games::Roguelike::Utils qw(:all);
use Games::Roguelike::Console::ANSI;
use Games::Roguelike::Mob;
use POSIX;

use IO::Socket;
use IO::Select;
use IO::File;

use Time::HiRes qw(time);

use base 'Games::Roguelike::World';

# currently this doesn't work on win32, but there's no reason why it shouldnt
# i think it may have something to do with the use of sysread?

my $WIN32 = ($^O=~/win32/i);
my @SOCKS;

sub new {
    	my $pkg = shift;
	my $r = $pkg->SUPER::new(@_, noconsole=>1);
    	bless $r, $pkg;

	local $! = 0;
	$r->{main_sock} = new IO::Socket::INET(LocalAddr=>'0.0.0.0', LocalPort=>9191, Listen => 1, ReuseAddr => 1);
	die $! unless $r->{main_sock};

	$r->{read_set} = new IO::Select();
	$r->{read_set}->add($r->{main_sock});
	$r->{write_set} = new IO::Select();

	push @SOCKS, $r->{main_sock};
	
	$SIG{__DIE__} = \&sig_die_handler;
	$SIG{INT} = \&sig_int_handler;

	return $r;
}

sub sig_int_handler {
	sig_die_handler();
	exit(0);
}

sub sig_die_handler {
	for (@SOCKS) {
		close($_);
	}
	undef @SOCKS;
	1;
}

sub DESTROY {
    	my $r = shift;
	if ($r->{main_sock}) {
		$r->{main_sock}->close();
	}
	$r->SUPER::DESTROY();
}

sub proc {
    my $self = shift;

#    $self->log("proc " . $self->{read_set}->count());

    my $now = time();
    $self->{ts} = $now unless $self->{ts};
    my $rem = max(0.1, $self->{tick} - ($now - $self->{ts}));

#    $self->log("rem", $rem);

    my ($new_readable, $new_writable, $new_error) = IO::Select->select($self->{read_set}, $self->{write_set}, $self->{read_set}, $rem + .01);

    foreach my $sock (@$new_readable) {
        if ($sock == $self->{main_sock}) {
            my $new_sock = $sock->accept();
	    $self->log("incoming connection from: " , $new_sock->peerhost());
            # new socket may not be readable yet.
	    if ($new_sock) {
		    push @SOCKS, $new_sock;
		    ++$self->{req_count};
		    if ($WIN32) {
		    	ioctl($new_sock, 0x8004667e, pack("I", 1));
		    } else {
		   	fcntl($new_sock, F_SETFL(), O_NONBLOCK());
		    }
		    $new_sock->autoflush(1);
	            $self->{read_set}->add($new_sock);
		    *$new_sock{HASH}->{con} = new Games::Roguelike::Cnsole::ANSI (in=>$new_sock, out=>$new_sock);
		    *$new_sock{HASH}->{time} = time();
		    *$new_sock{HASH}->{errc} = 0;
		    $self->{con} = *$new_sock{HASH}->{con};
		    $self->echo_off();

		    $self->{con} = *$new_sock{HASH}->{con};
		    $self->{state} = '';
		    $self->{vp} = '';
		    $self->newconn($new_sock);	
		    *$new_sock{HASH}->{state} = $self->{state};
		    *$new_sock{HASH}->{char} = $self->{vp};

	    	    $self->log("state is: " , $self->{state});
	    }
        } else {
		if ($sock->eof() || !$sock->connected() || (*$sock{HASH}->{errc} > 5)) {
			$self->{state} = 'QUIT';
		} else {
		    	$self->log("reading from: " , $sock->peerhost());
		    	$self->log("state was: " , $self->{state});
			$self->{con} = *$sock{HASH}->{con};
			$self->{state} = *$sock{HASH}->{state};
			$self->{vp} = *$sock{HASH}->{char};
			$self->readinput($sock);
			*$sock{HASH}->{state} = $self->{state};
			*$sock{HASH}->{char} = $self->{vp};
	    		$self->log("state is: " , $self->{state});
		}

		if ($self->{state} eq 'QUIT') {
			*$sock{HASH}->{char}->{area}->delmob(*$sock{HASH}->{char});
			$self->{read_set}->remove($sock);
			$sock->close();
		} 
	}
    }
    foreach my $sock (@$new_error) {
	*$sock{HASH}->{char}->{area}->delmob(*$sock{HASH}->{char});
	$self->{read_set}->remove($sock);
	close($sock);
    }
    {
    my $now = time();
    my $rem = $now - $self->{ts};

    if ($rem >= $self->{tick}) {
        #$self->log("tick");
    	$self->tick();
    	$self->drawallmaps();
	$self->{ts} = $now;
    }
    }
}

# this should be overridden with queued-move-processors

sub drawallmaps {
    my $self = shift;
    foreach my $sock ($self->{read_set}->handles())  {
        if (*$sock{HASH}->{char}) {
                $self->{vp} = *$sock{HASH}->{char};
                $self->{con} = *$sock{HASH}->{con};
		$self->{area} = $self->{vp}->{area};
                my $color = $self->{vp}->{color};
                my $sym = $self->{vp}->{sym};
		$self->setfocuscolor();
                $self->drawmap();
                $self->{vp}->{color} = $color;
                $self->{vp}->{sym} = $sym;
        }
    }
}

sub echo_off {
        my $self = shift;
	my $sock = $self->{con}->{out};
	# i will echo if needed, you don't echo, i will suppress go ahead, you do suppress goahead
	print $sock "\xff\xfb\x01\xff\xfb\x03\xff\xfd\x0f3";
}

sub echo_on {
        my $self = shift;
	my $sock = $self->{con}->{out};
	# i wont echo, you do echo
	print $sock "\xff\xfc\x01\xff\xfd\x01";
}

sub getstr {
        my $self = shift;
	my $sock = $self->{con}->{in};
	my $first = 1;
	while (1) {
        	my $b;
		my $nb = sysread($sock,$b,1);
        	if (!defined($nb) || $nb <= 0) {
			++(*$sock{HASH}->{errc}) if $first;
                	return undef;
        	} else {
			syswrite($sock,$b,1);	# echo on getstr
			$first = 0 if $first;
                	*$sock{HASH}->{errc} = 0;
			*$sock{HASH}->{sbuf} .= $b;
        	}
		if ($b eq "\n" || $b eq "\r") {
			my $temp = *$sock{HASH}->{sbuf};
			*$sock{HASH}->{sbuf} = '';
			return $temp;
		}
	}
}

sub getch {
	my $self = shift;
	return $self->{con}->nbgetch();

# readkey seems to be working now
#
#	my $sock = $self->{con}->{in};
#        my $b;
#	my $nb = sysread($sock,$b,1);
#	if ($nb <= 0) {
#		++(*$sock{HASH}->{errc});
#		return undef;
#	} else {
#		*$sock{HASH}->{errc} = 0;
#		return $b;
#	}
}

sub charmsg {
	my $self = shift;
	my ($char, $msg, $attr) = @_;
	my $con = $self->{con};
	$self->{con} = $char->{con};
	$self->showmsg($msg,$attr);
	$self->{con} = $con;	
}

sub log {
	my $self = shift;
	print STDOUT scalar(localtime()) . "\t" . join("\t", @_) . "\n";
}

sub dprint {
	my $self = shift;
	print STDOUT scalar(localtime()) . "\t" . join("\t", @_) . "\n";
}

# override this for your game

# for now, the way we report back state changes is to modify
#
#   $self->{state}
#   $self->{vp} 	# for creating/loading/switching to a character's viewpoint
#
# these are then linked to the socket
#
# actual actiona/movement by a charcter should be queued here, then processed according to a random sort and/or a sort based
# on the speed of the character at tick() time
#
# ie: if an ogre and a sprite move during the same tick, the sprite always goes first, even if the 
# ogre's player has a faster internet connection
#
# use getch for a no-echo read of a character
# use getstr for an echoed read of a carraige return delimited string
#
# both will return undef if there's no input yet
# don't "wait" for anything in your functons, game is single threaded! 
#

sub readinput {
	die "need to overide this, see netgame example";
}

# override this for intro screen, please enter yor name, etc.
# use $self->{con} for the the Games::Roguelike::Console object (remember, chars are not actually written until flushed, which you can do here if you want)

sub newconn {
	die "need to overide this, see netgame example";
}

# override to process character and mob actions/movement map is auto-redrawn for all connections after the tick (if changed)
# don't try to draw here... since no character has the focus...it will fail 

sub tick {
}

# change the symbol/color of the character when it's "in focus"
sub setfocuscolor {
        my $self = shift;
	$self->{vp}->{color} = 'bold yellow';
}

1;
