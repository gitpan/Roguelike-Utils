use strict;
use ExtUtils::MakeMaker;
# See lib/ExtUtils/MakeMaker.pm for details of how to influence
# the contents of the Makefile that is written.

# extract version from Utils file
# this is basically the Maj.Min.subversion number ... for all files

my $ver = 0;

# if VERSION_FROM took an array ref, and VERSION_REGEX optionally allowed for non-eval parsing....it would be nice.

for (qw(Games/Roguelike/Utils.pm Games/Roguelike/World.pm Games/Roguelike/World/Daemon.pm Games/Roguelike/Area.pm)) {
	my $ver2 = getver($_);
	$ver = $ver2 if ($ver2 gt $ver);  # stringwise compare...works for me ... for now
}

die "Can't get version from files" unless $ver;

my @exe_files = qw(scripts/example scripts/netgame scripts/tictactoe);


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


# since it's my module, i'd prefer not to use Safe & eval 
sub getver {
	my ($f) = @_;
	open(IN, $f);
	my ($ver, $rev);
	while (my $in=<IN>) {
		if (my @v = ($in =~ /VERSION[\s='"]*([\d.]+)\.[\s.'"\[]*qw\$Revision: (\d+)/s)) {
			return join '.', @v;
		}
	}
	close IN;
	return undef;
}
