package Games::Roguelike::Console::ANSI;

=head1 NAME

Games::Roguelike::Console::ANSI - socket-friendly, object oriented curses-like support for an ansi screen buffer

=head1 SYNOPSIS

 use Games::Roguelike::Console::ANSI;

 $con = Games::Roguelike::Console::ANSI->new();
 $con->attron('bold yellow');
 $con->addstr('test');
 $con->attroff();
 $con->refresh();

=head1 DESCRIPTION

Combines ReadKey and Term::ANSIColor into an object oriented curses-like ansi screen buffer.

Inherits from Games::Roguelike::Console.  See Games::Roguelike::Console for list of methods.

=head1 SEE ALSO

L<Games::Roguelike::Console>

=head1 AUTHOR

Erik Aronesty C<erik@q32.com>

=head1 LICENSE

This program is free software; you can redistribute it and/or
modify it under the same terms as Perl itself.

See L<http://www.perl.com/perl/misc/Artistic.html> or the included LICENSE file.

=cut

use strict;
use IO::File;
use Term::ReadKey;
use Term::ANSIColor;
use Carp qw(confess croak);

use base 'Games::Roguelike::Console';

our $KEY_ESCAPE = chr(27);
our $KEY_NOOP = chr(241);
our ($KEY_LEFT, $KEY_UP, $KEY_RIGHT, $KEY_DOWN) = ('[D','[A','[C','[B');

sub new {
        my $pkg = shift;
        croak "usage: Games::Roguelike::Console::ANSI->new()" unless $pkg;

        my $self = bless {}, $pkg;
        $self->init(@_);
        return $self;
}

my $STD;
sub init {
	my $self = shift;

	my %opt = @_;

	$self->{in} = *STDIN{IO} unless $self->{in} = $opt{in};
	$self->{out} = *STDOUT{IO} unless $self->{out} = $opt{out};
 	$self->{cursor} = 1;
	$self->{cx} = 0;
	$self->{cy} = 0;
	$self->{cattr} = '';
	$self->{cbuf} = '';

	if (!$opt{noinit}) {	

	my $out = $self->{out};

	($self->{winx}, $self->{winy}) = GetTerminalSize();
        $self->{invl}=$self->{winx}+1;
        $self->{invr}=-1;
        $self->{invt}=$self->{winy}+1;
        $self->{invb}=-1;

	eval {ReadMode 'cbreak', $self->{in}};

	print $out ("\033[2J"); 	#clear the screen 
	print $out ("\033[0;0H"); 	#jump to 0,0
	print $out ("\033[=0c"); 	#hide cursor

	$self->{cursor} = 0;
	if ($self->{out}->fileno() == 1) {
		$STD = $self;
		$SIG{INT} = \&sig_int_handler;
		$SIG{__DIE__} = \&sig_die_handler;
		$self->{speed} = `stty speed` unless $self->{speed};
	}

	}
	$self->{reset} = color('reset');

}

sub clear {
	my $self = shift;
	my $out = $self->{out};
	@{$self->{buf}} = [];
	@{$self->{cur}} = [];
	print $out ("\033[2J"); 	#clear the screen 
	print $out ("\033[0;0H"); 	#jump to 0,0
}

sub redraw {
	my $self = shift;
	my $out = $self->{out};
        @{$self->{cur}} = [];
	print $out "\033c"; 		# reset
	print $out ("\033[=0c") if !$self->{cursor}; 	# hide cursor
	$self->clear();
	refresh();
}

sub reset_fh {
	my $out = shift;
	#print $out "\033[c"; 		# reset
	print $out "\033[=1c"; 		# show cursor
	print $out "\033[30;0H";     	# jump to col 0
	eval {ReadMode 0, $out};	# normal input
	if ($^O =~ /linux/ && fileno($out) == 1) {
		system("stty sane");
	}
}

sub sig_int_handler {
	reset_fh(*STDOUT{IO});
	exit;
}

sub sig_die_handler {
	die @_ if $^S;
	reset_fh(*STDOUT{IO});
	die @_;
}

sub END {
	# this is only done because DESTROY is never called for some reason
	if ($STD) {
		reset_fh(*STDOUT{IO});
		$STD = undef;
	}
}

sub DESTROY {
	my $self = shift;
	if ($self->{out} && fileno($self->{out})) {
        reset_fh($self->{out});
        if ($self->{out}->fileno() == 1) {
		$STD = undef;
                $SIG{INT} = undef;
                $SIG{__DIE__} = undef;
        }
	}
}

sub tagstr {
	my $self = shift;
	my ($x, $y, $str);
	if (@_ == 1) {
		($x, $y, $str) = ($self->{cx}, $self->{cy}, @_);
	} else {
		($x, $y, $str) = @_;
	}
	my $attr;
	my $r = $x;
        my $c;
	for (my $i = 0; $i < length($str); ++$i) {
		$c = substr($str,$i,1);
		if ($c eq '<') {
			substr($str,$i) =~ s/<([^>]*)>//;
			$attr = $1;
        		$attr =~ s/(bold )?gray/bold black/i;
        		$attr =~ s/,/ /;
        		$attr =~ s/\bon /on_/;
			$c = substr($str,$i,1);
		}
                $self->{buf}->[$y][$r]->[0] = $attr ? color($attr) : '';
                $self->{buf}->[$y][$r]->[1] = $c;
		++$r;
	
        }
        $self->invalidate($x, $y, $x+$r, $y);
        $self->{cy}=$y;
        $self->{cx}=$x+$r;
}

sub attron {
	my $self = shift;
	my ($attr) = @_;
        $attr =~ s/(bold )?gray/bold black/i;
        $attr =~ s/,/ /;
	$self->{cattr} = color($attr);
}

sub attroff {
	my $self = shift;
	my ($attr) = @_;
	$self->{cattr} = '';
}

sub addstr {
	my $self = shift;
	my $str =  pop @_;

	if (@_== 0) {
		for (my $i = 0; $i < length($str); ++$i) {
			$self->{buf}->[$self->{cy}][$self->{cx}+$i]->[0] = $self->{cattr};
			$self->{buf}->[$self->{cy}][$self->{cx}+$i]->[1] = substr($str,$i,1);
		}
		$self->invalidate($self->{cx}, $self->{cy}, $self->{cx} + length($str), $self->{cy});
		$self->{cx} += length($str);
	} elsif (@_==2) {
		my ($y, $x) = @_;
		for (my $i = 0; $i < length($str); ++$i) {
			$self->{buf}->[$y][$x+$i]->[0] = $self->{cattr};
			$self->{buf}->[$y][$x+$i]->[1] = substr($str,$i,1);
		}
		$self->invalidate($x, $y, $x+length($str), $y);
		$self->{cy}=$y;
		$self->{cx}=$x+length($str);
	}
}

sub invalidate {
	my $self = shift;
        my ($l, $t, $r, $b) = @_;
        $r = 0 if ($r < 0);
        $t = 0 if ($t < 0);
        $b = $self->{winy} if ($b > $self->{winy});
        $r = $self->{winx} if ($r > $self->{winx});

        if ($r < $l) {
                my $m = $r;
                $r = $l;
                $l = $m;
        }
        if ($b < $t) {
                my $m = $t;
                $b = $t;
                $t = $m;
        }
        $self->{invl} = $l if $l < $self->{invl};
        $self->{invr} = $r if $r > $self->{invr};
        $self->{invt} = $t if $t < $self->{invt};
        $self->{invb} = $b if $b > $self->{invb};
}

sub refresh {
	my $self = shift;
	my $out = $self->{out};

	# it's expected that the "buf" array will frequently be uninitialized
	no warnings 'uninitialized';
	
	my $cc;
	for (my $y = $self->{invt}; $y <= $self->{invb}; ++$y) {
	for (my $x = $self->{invl}; $x <= $self->{invr}; ++$x) {
	if (!($self->{buf}->[$y][$x]->[0] eq $self->{cur}->[$y][$x]->[0]) || !($self->{buf}->[$y][$x]->[1] eq $self->{cur}->[$y][$x]->[1])) {
		print $out "\033[", ($y+1), ";", ($x+1), "H", @{$self->{buf}->[$y][$x]};
		$cc  += 9;
		$self->{cur}->[$y][$x]->[0]=$self->{buf}->[$y][$x]->[0];
		$self->{cur}->[$y][$x]->[1]=$self->{buf}->[$y][$x]->[1];
		my $pattr = $self->{cur}->[$y][$x]->[0];
		# reduce unnecessary cursor moves & color sets
		while ($x < $self->{invr} && 
			!(   ($self->{buf}->[$y][$x+1]->[0] eq $self->{cur}->[$y][$x+1]->[0]) 
			  && ($self->{buf}->[$y][$x+1]->[1] eq $self->{cur}->[$y][$x+1]->[1])
			 )
		      ) {
			++$x;
			if (!($pattr eq $self->{buf}->[$y][$x]->[0])) {
				print $out $self->{reset};
				print $out $self->{buf}->[$y][$x]->[0];
				$pattr = $self->{buf}->[$y][$x]->[0];
				$cc  += 7;
			}
			print $out $self->{buf}->[$y][$x]->[1];
			$self->{cur}->[$y][$x]->[0]=$self->{buf}->[$y][$x]->[0];
			$self->{cur}->[$y][$x]->[1]=$self->{buf}->[$y][$x]->[1];
			$cc  += 1;
		}
		print $out $self->{reset};
		$cc  += 4;
	}
	}
	}
	$self->{invl}=$self->{winx}+1;	
	$self->{invr}=-1;	
	$self->{invt}=$self->{winy}+1;	
	$self->{invb}=-1;
}

sub move {
	my $self = shift;
	my $out = $self->{out};
	my ($y, $x) = @_;
	$self->{cy}=$y;
	$self->{cx}=$x;
	if ($self->{cursor} && !($self->{cx}==$self->{scx} && $self->{cx}==$self->{scy})) {
		print $out "\033[", ($y+1), ";", ($x+1), "H";
		$self->{scx} = $self->{cx};
		$self->{scy} = $self->{cy};
	}
}

sub cursor {
	my $self = shift;
	my ($set) = @_;
	my $out = $self->{out};
	
	if ($set && !$self->{cursor}) {
		print $out ("\033[=1c");        #show cursor
		$self->{cursor} = 1;
	} elsif (!$set && $self->{cursor}) {
		print $out ("\033[=0c");        #hide cursor
		$self->{cursor} = 0;
	}	
}

sub addch {
	my $self = shift;
	$self->addstr(@_);
}

sub getch {
	my $self = shift;

	my $c;	
	if ($self->{cbuf}) {
		$c = substr($self->{cbuf},0,1);
		$self->{cbuf} = substr($self->{cbuf},1);
	} else {
		$c = ReadKey(0, $self->{in});
	}

	if ($c eq $KEY_ESCAPE) {
		$c = ReadKey(1, $self->{in});
		if ($c eq '[') {
			$c = ReadKey(1, $self->{in});
			$c = '[' . $c;
		} elsif ($c eq $KEY_NOOP) {
			return getch();
		} elsif ($c eq $KEY_ESCAPE) {
			return 'ESC';
		} else {
			# unknown escape sequence
			$self->{cbuf} .= $c;
			return 'ESC';
		}
	}

	if ($c eq $KEY_UP) {
		return 'UP'
	} elsif ($c eq $KEY_DOWN) {
		return 'DOWN'
	} elsif ($c eq $KEY_LEFT) {
		return 'LEFT'
	} elsif ($c eq $KEY_RIGHT) {
		return 'RIGHT'
	}
	
	return $c;
}

sub nbgetch_raw {
        my $self = shift;
        my $c;
        if (length($self->{cbuf}) > 0) {
                $c = substr($self->{cbuf},0,1);
                $self->{cbuf} = substr($self->{cbuf},1);
        } else {
                $c = ReadKey(-1, $self->{in});
        }
	return $c;
}

sub nbgetch {
        my $self = shift;

	my $c = $self->nbgetch_raw();

	if ($c eq $KEY_ESCAPE) {
		my $c2 = $self->nbgetch_raw();
		if (!defined($c2)) {
			$self->{cbuf} = $KEY_ESCAPE;
			$c = undef;
		} elsif ($c2 eq '[') {
			my $c3 = $self->nbgetch_raw();
			if (!defined($c3)) {
				$self->{cbuf} = $KEY_ESCAPE . '[';
			} else {
				$c = '[' . $c3;
				if ($c eq $KEY_UP) {
					$c = 'UP'
				} elsif ($c eq $KEY_DOWN) {
					$c = 'DOWN'
				} elsif ($c eq $KEY_LEFT) {
					$c = 'LEFT'
				} elsif ($c eq $KEY_RIGHT) {
					$c = 'RIGHT'
				}
			}
		} elsif ($c2 eq $KEY_NOOP) {
			$c = undef;
		} elsif ($c2 eq $KEY_ESCAPE) {
			$c = 'ESC';
		} else {
			$c = $c2;
			$c = undef if ord($c) > 240;
		}
	} elsif (ord($c) == 255) {		# telnet esc?
		my $c2 = $self->nbgetch_raw();
                if (!defined($c2)) {
                        $self->{cbuf} = $c;
                        $c = undef;
                } else {
                        $c = $c2;
                        $c = undef if ord($c) > 240;
                }
	}

	return $c;
}

1;
