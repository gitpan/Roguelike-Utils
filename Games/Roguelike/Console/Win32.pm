use strict;
package Games::Roguelike::Console::Win32;

#### refer to Games::Roguelike::Console for docs ###

use Win32::Console;
use Term::ReadKey;
use Carp;

use base 'Games::Roguelike::Console';

sub new {
        my $pkg = shift;
        croak "usage: Games::Roguelike::Console::Win32->new()" unless $pkg;

        my $r = bless {}, $pkg;
        $r->init(@_);
        return $r;
}

my $CON;

#todo: figure out how to free/alloc/resize
sub init {
	my $self = shift;

	$self->{conin} = Win32::Console->new(STD_INPUT_HANDLE);
	$self->{conin}->Mode(ENABLE_PROCESSED_INPUT);
		
	$self->{buf} = Win32::Console->new(GENERIC_READ|GENERIC_WRITE);
	$self->{buf}->Cls();
	$self->{buf}->Cursor(-1,-1,-1,0);
	
	$self->{con} = Win32::Console->new(STD_OUTPUT_HANDLE);
	$self->{cur} = 0;

	($self->{winx},$self->{winy}) = $self->{con}->MaxWindow();
	$self->{con}->Size($self->{winx}, $self->{winy});
	$self->{buf}->Size($self->{winx}, $self->{winy});

	$self->{con}->Cursor(-1,-1,-1,0);
	$self->{con}->Display();
	$self->{con}->Cls();

	$CON = $self->{con} unless $CON;
	
	$SIG{INT} = \&sig_int_handler;
	$SIG{__DIE__} = \&sig_die_handler;
}

sub DESTROY {
	$_[0]->{con}->Cls() if $_[0]->{con};
}

sub sig_int_handler {
	$CON->Cls();
	exit;
}

sub sig_die_handler {
	die @_ if $^S;
        $CON->Cls();
	die @_;
}

sub nativecolor {
        my ($self, $fg, $bg, $fgb, $bgb) = @_;
	$fg = 'light' . $fg if $fgb;

	$fg = 'gray' if $fg eq 'lightblack';
	$bg = 'gray' if $bg eq 'lightblack';
	$fg = 'brown' if $fg eq 'yellow';
	$bg = 'brown' if $bg eq 'yellow';
	$fg = 'yellow' if $fg eq 'lightyellow';
	$bg = 'yellow' if $bg eq 'lightyellow';
	$fg = 'white' if $fg eq 'lightwhite';
	$bg = 'white' if $bg eq 'lightwhite';

	no strict 'refs';
	my $color = ${"FG_" . uc($fg)} | ${"BG_" . uc($bg)} ;

	use strict 'refs';

	return $color;
}

sub attron {
        my $self = shift;
        my ($attr) = @_;
        $self->{cattr} = $self->parsecolor($attr);
}

sub attroff {
	my $self = shift;
	$self->{cattr} = $ATTR_NORMAL;
}

sub addstr {
	my $self = shift;
	my $str =  pop @_;

	if (@_== 0) {
		if ($self->{cx}+length($str) > ($self->{winx}+1)) {
			$str = substr(0, ($self->{cx}+length($str)) - ($self->{winx}));
		}
		return if length($str) == 0;
		$self->{buf}->WriteChar($str, $self->{cx}, $self->{cy});
		$self->{buf}->WriteAttr(chr($self->{cattr}) x length($str), $self->{cx}, $self->{cy});
		$self->invalidate($self->{cx}, $self->{cy}, $self->{cx} + length($str), $self->{cy});
		$self->{cx} += length($str);
	} elsif (@_==2) {
		my ($y, $x) = @_;
		if ($x+length($str) > ($self->{winx}+1)) {
			$str = substr(0, ($x+length($str)) - ($self->{winx}));
		}
		return if length($str) == 0;
		$self->{buf}->WriteChar($str, $x, $y);
		$self->{buf}->WriteAttr(chr($self->{cattr}) x length($str), $x, $y);
		$self->invalidate($x, $y, $x+length($str), $y);
		$self->{cx} = $x + length($str);
		$self->{cy} = $y;
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
                        $attr = chr($self->parsecolor($1));
                        $c = substr($str,$i,1);
                }
                $self->{buf}->WriteChar($c, $r, $y);
                $self->{buf}->WriteAttr($attr, $r, $y);
                ++$r;
        }
        $self->invalidate($x, $y, $x+$r, $y);
        $self->{cy}=$y;
        $self->{cx}=$x+$r;
}

sub refresh {
	my $self = shift;
	#my $rect = $self->{buf}->ReadRect($self->{invl}, $self->{invt}, $self->{invr}, $self->{invb});
	#$self->{con}->WriteRect($rect, $self->{invl}, $self->{invt}, $self->{invr}, $self->{invb});
	my $rect = $self->{buf}->ReadRect(0, 0, $self->{winx}, $self->{winy});
	$self->{con}->WriteRect($rect, 0, 0, $self->{winx}, $self->{winy});
	$self->{invl} = $self->{winx}+1;
	$self->{invt} = $self->{winy}+1;
	$self->{invr} = $self->{invb} = -1;
}

sub move {
	my $self = shift;
	my ($y, $x) = @_;
	$self->{cx}=$x;
	$self->{cy}=$y;
	if ($self->{cursor}) {
		$self->{con}->Cursor($x,$y,-1,1);		
	}
}

sub cursor {
	my $self = shift;
	if ($self->{cursor} != shift) {
		$self->{cursor} = !$self->{cursor};
		$self->{con}->Cursor($self->{cx},$self->{cy},-1,$self->{cursor});
	}
}

sub printw   { 
	my $self = shift;
	$self->addstr(sprintf shift, @_)
} 

sub addch {
	my $self = shift;
	$self->addstr(@_);
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

# todo, support win32 arrow/function/control keys - ReadKey ignores them
sub getch {
        my $self = shift;
        my $c=ReadKey(0);
	return $c;
}

sub nbgetch {
        my $self = shift;
        return ReadKey(-1);
}

1;
