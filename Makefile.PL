use ExtUtils::MakeMaker;
# See lib/ExtUtils/MakeMaker.pm for details of how to influence
# the contents of the Makefile that is written.

# extract version from Utils file
# this is basically the Maj.Min.subversion number ... for all files

open(IN, 'Games/Roguelike/Utils.pm');
my ($ver, $rev);
while (<IN>) {
	$rev = $1 if /Revision: (\d+)/s;
	$ver = $1 if /VERSION[\s='"]*([\d.]+)/s;
	last if $ver && $rev;
}
close IN;

WriteMakefile(
    NAME         => 'Roguelike-Utils',
    VERSION      => "$ver$rev",
    AUTHOR       => 'Erik Aronesty (erik@q32.com)',
    ABSTRACT     => 'Roguelike Libary for Perl',
    PREREQ_PM    => {
                     'Test::Simple' => 0.44,
                    },
);
