package Games::Roguelike::Console;

use strict;

use Exporter;
our @ISA=qw(Exporter);
use Carp qw(croak);
use warnings::register;

=head1 NAME

Games::Roguelike::Console - platform-neutral console handling

=head1 SYNOPSIS

 use Games::Roguelike::Console;

 $con = Games::Roguelike::Console->new();
 $con->attron('bold yellow');
 $con->addstr('test');
 $con->attroff();
 $con->refresh();

=head1 DESCRIPTION

Attempts to figure out which Games::Roguelike::Console subclass to instantiate in order to provide console support.

=head2 METHODS

=over 4

=item new ([type=>$stype], [noinit=>1])

create a new console, optionally specifying the subtype (currently: win32, ansi or curses), and the noinit flag (which suppresses terminal init)

=item addch ([$y, $x], $str);

=item addstr ([$y, $x], $str);

prints a string at the y, x positions or at the current cursor position (also positions and advances the cursor to y, x+length(str))

=item attron ($attr)

turns on color attributes ie: bold blue, white, white on black, black on bold blue

=item attroff ()

turns off color attributes

=item refresh ()

draws the current screen

=item redraw ()

redraws entire screen (if out of sync)

=item move ($y, $x)

moves the cursor to y, x

=item getch ()

reads a character from input

=item nbgetch ()

reads a character from input, non-blocking

=item parsecolor ()

helper function for subclass, parses an attribute then calls "nativecolor($fg, $bg, $bold)", caching the results

=item tagstr ([$x,$y,] $str)

moves the cursor to x/y and writes the string $str, which can contain <color> tags

=item xymove ($x,$y)

moves the cursor to x/y

=item xych ($x,$y)

moves the cursor to x/y, and writes a character

=item xystr ($x,$y)

moves the cursor to x/y, and writes a string

=back

=head1 SEE ALSO

L<Games::Roguelike::Console::ANSI>, L<Games::Roguelike::Console::Win32>, L<Games::Roguelike::Console::Curses>

=cut


# platform independent
use Games::Roguelike::Console::ANSI;
use Games::Roguelike::Console::Dump;

our ($OK_WIN32, $OK_CURSES, $DUMPFILE, $DUMPKEYS);

if ($^O =~ /Win32/) {
	# console
	eval{require Games::Roguelike::Console::Win32};
	$OK_WIN32 = !$@;
} else {	
	# works ok
	eval{require Games::Roguelike::Console::Curses};
	$OK_CURSES = !$@;
}

# guess best package, and return "new of that package"

sub new {
        my $pkg = shift;
	my %opt = @_;

	if ($DUMPFILE) {
		# override params and just create a dump console
		return new Games::Roguelike::Console::Dump @_, file=>($DUMPFILE?$DUMPFILE:'>/dev/null'), keys=>$DUMPKEYS;
	}
	
	$opt{type} = '' if !defined $opt{type};
	
	if ($opt{type} eq 'ansi') {
		return new Games::Roguelike::Console::ANSI @_;
	}
	if ($opt{type} =~ /dump:(.*):?(.*)/) {
		return new Games::Roguelike::Console::Dump @_, file=>$1, keys=>$2;
	}
	if ($OK_WIN32) {
		return new Games::Roguelike::Console::Win32 @_;
	}
	if ($OK_CURSES) {
		return new Games::Roguelike::Console::Curses @_;
	}
	return new Games::Roguelike::Console::ANSI @_;	
}

sub DESTROY {
	croak "hey, this should never be called, override it!";
}

my %COLORMAP;
sub parsecolor {
	my $self = shift;
	my $pkg = ref($self);
	my ($attr) = @_;
        if (!$COLORMAP{$pkg}{$attr}) {
                my $bg = 'black';
                my $fg = 'white';
                $bg = $1 if $attr=~ s/on[\s_]+(.*)$//;
                $fg = $attr;
                my $bold = 0;
		$bold = 1 if $fg =~ s/\s*bold\s*//;
		$fg = 'white' if !$fg;
                ($fg, $bold) = ('black', 1) if $fg =~ /gray|grey/;
                ($bg, $bold) = ('black', 1) if $bg =~ /gray|grey/;
                $COLORMAP{$pkg}{$attr} = $self->nativecolor($fg, $bg, $bold);
	}
	return $COLORMAP{$pkg}{$attr};
}

sub nativecolor {
	my $self = shift;
	my ($fg, $bg, $bold) = @_;
	croak "nativecolor must be overridden in " . ref($self);
}

# use x/y onstad of y/x

sub xych {
	my $self = shift;
	$self->addch($_[0]) if @_ == 1;
	$self->addch($_[1], $_[0], $_[2]) if @_ > 1;
}

sub xystr {
	my $self = shift;
        $self->addstr($_[0]) if @_ == 1;
        $self->addstr($_[1], $_[0], $_[2]) if @_ > 1;
}

sub xymove {
        my $self = shift;
        $self->move($_[1], $_[0]);
}

sub attrch {
        my $self = shift;
        my ($color, @args) = @_;

        if ($color) {
                $self->attron($color);
                $self->addch(@args);
                $self->attroff($color);
        } else {
                $self->addch(@args);
        }
}

sub attrstr {
        my $self = shift;
        my ($color, @args) = @_;

        if ($color) {
                $self->attron($color);
                $self->addstr(@args);
                $self->attroff($color);
        } else {
                $self->addch(@args);
        }
}

1;
