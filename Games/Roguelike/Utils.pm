# For license, docs, see the POD documentation at the end of this file

package Games::Roguelike::Utils;

use strict;

require Exporter;

# direction helpers

our $REV = '$Revision: 132 $';
$REV =~ m/: (\d+)/;
our $VERSION = '0.4.' . $1;

our $DIRN = 8;                                                                   # number of ways to move (don't count ".")
our @DIRS = ('n','s','e','w','ne','se','nw','sw', '.');                          # names of dirs (zero indexed array)
our @DD = ([0,-1],[0,1],[1,0],[-1,0],[1,-1],[1,1],[-1,-1],[-1,1],[0,0]);         # map offsets caused by moving in these dirs
our %DD = ('n'=>[0,-1],'s'=>[0,1],'e'=>[1,0],'w'=>[-1,0],'ne'=>[1,-1],'se'=>[1,1],'nw'=>[-1,-1],'sw'=>[-1,1], '.'=>[0,0]);       # name/to/offset map
our %DI = ('n'=>0,'s'=>1,'e'=>2,'w'=>3,'ne'=>4,'se'=>5,'nw'=>6,'sw'=>7,'.'=>8);          # name/to/index map

BEGIN {
	require Exporter;
	our @ISA=qw(Exporter);
	our @EXPORT_OK = qw(min max ardel rarr distance randsort intify randi $DIRN @DD %DD %DI @DIRS round);
	our %EXPORT_TAGS = (all=>\@EXPORT_OK);
}

use Games::Roguelike::Area;

eval 'use Games::Roguelike::Pov_C';

if (!defined(&distance)) {
	eval('
        sub distance {
                return sqrt(($_[0]-$_[2])*($_[0]-$_[2])+($_[1]-$_[3])*($_[1]-$_[3]));
        }
	');
}

sub intify {
        for (@_) {
                $_=int($_);
        }
}

sub randsort {
        my @a = @_;
        my @d;
        while (@a) {
                push @d, splice(@a, rand()*$#a, 1);
        }
        return @d;
}

sub round {
	return int($_[0]+0.5);
}

sub randi {
	my ($a, $b) = @_;
	if ($b) {
		# rand num between a and b, inclusive
		return $a+int(rand()*($b-$a+1));
	} else {
		# rand num between 0 and a-1
		return int(rand()*$a);
	}
}

sub ardel {
	my ($ar, $t) = @_;
	for (my $i=0;$i<=$#{$ar};++$i) {
		splice(@{$ar},$i,1) if $ar->[$i] eq $t;
	}
}

sub max {
	my ($a, $b) = @_;
	return $a >= $b ? $a : $b;
}

sub min {
	my ($a, $b) = @_;
	return $a <= $b ? $a : $b;
}

sub rarr {
	my ($arr) = @_;
die Dumper($arr);
	return $arr->[$#{$arr}*rand()];
}

=head1 NAME

Games::Roguelike - Rogelike Library for Perl

=head1 SYNOPSIS

 package myworld;
 use base 'Games::Roguelike::World';

 $r = myworld->new(w=>80,h=>50,dispw=>40,disph=>18);     # creates a world with specified width/height & map display width/height
 $r->area(new Games::Roguelike::Area(name=>'1'));                    # create a new area in this world called "1"
 $r->area->genmaze2();                                   # make a cavelike maze
 $char = Games::Roguelike::Mob->new($r->area, sym=>'@', pov=>8);      # add a mobile object with symbol '@'
 $r->setvp($char);                                       # set viewpoint to be from $char's perspective
 $r->drawmap();                                          # draw the active area map from the current perspective
 while (!((my $c = $r->getch()) eq 'q')) {
        $char->kbdmove($c);
        $r->drawmap();
 }

=head1 DESCRIPTION

library for pulling together field of view, character handling and map drawing code.   

	* Games::Roguelike::World is the primary object used
	* uses the Games::Roguelike::Console library to draw on the screen
	* assumes the user will be using overridden Games::Roguelike::Mob's as characters in the game
	* Games::Roguelike.pm itself is a just a utility module used by other classes

=head1 SEE ALSO

L<Games::Roguelike::Area>, L<Games::Roguelike::Mob>, L<Games::Roguelike::Console>

=head1 AUTHOR

Erik Aronesty C<erik@q32.com>

=head1 LICENSE

This program is free software; you can redistribute it and/or 
modify it under the same terms as Perl itself.

See L<http://www.perl.com/perl/misc/Artistic.html> or the included LICENSE file.

=cut

1;
