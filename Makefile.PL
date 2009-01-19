use strict;
use ExtUtils::MakeMaker;
# See lib/ExtUtils/MakeMaker.pm for details of how to influence
# the contents of the Makefile that is written.

# extract version from Utils file
# this is basically the Maj.Min.subversion number ... for all files

my $ver = getver('Games/Roguelike/Utils.pm');
my $ver2 = getver('Games/Roguelike/World.pm');

if ($ver2 > $ver) {
	$ver = $ver2;
}

my @exe_files = qw(scripts/example scripts/netgame scripts/tictactoe);

push @exe_files, 'scripts/example.cmd' if $^O =~ /win32/i;

WriteMakefile(
    NAME         => 'Roguelike-Utils',
    PMLIBDIRS    => ['Games'],
    VERSION      => "$ver",
    AUTHOR       => 'Erik Aronesty (erik@q32.com)',
    ABSTRACT     => 'Roguelike Utilities for Perl',
    PREREQ_PM    => {
                     'Test::Simple' => 0.44,
		     'Term::ReadKey' => 0,
                    },
    EXE_FILES    => \@exe_files,
);


sub getver {
open(IN, $_[0]);
my ($ver, $rev);
while (<IN>) {
        $rev = $1 if /Revision: (\d+)/s;
        $ver = $1 if /VERSION[\s='"]*([\d.]+)\./s;
        last if $ver && $rev;
}
close IN;
return "$ver.$rev";
}
