#!/usr/bin/env perl 

use Cwd ;

die "Usage : $0 RepositoriesList" unless (@ARGV == 1) ;
my ($repFile) = @ARGV ;

# Read Repositories
my @reps ;
open (IN,$repFile) or die "Cannot open $repFile for reading" ;
while (<IN>) {
	chomp ;
	push @reps,$_ ;
}
close IN ;

my $nrep = scalar @reps ;
print STDERR "Read $nrep repositoties to check\n" ;

# Check Status
my $dir = getcwd() ;
foreach my $rep (@reps) {
	print STDERR "Checking git status of repository $rep\n";
	die "Directory of this repository does not exist!" unless (-d $rep);
	chdir($rep) ;
	my $out_txt = `git status`; 
	die "Cannot run git status in repository $rep; error code $?" unless ($? == 0) ;
	print STDERR $out_txt;
	my @lines = split(/\n/, $out_txt);
	print STDERR "Last line: $lines[-1]\n";
	
	if ($lines[-1] !~ /nothing to commit, working directory clean/) {
		print STDERR "Repository $rep:\n" ;
		map {print STDERR "$_\n"} @lines;
		die "Fix repository $rep and rerun" ;
	} 
	else {
		print STDERR "Repository $rep OK\n" ;
	}
}
