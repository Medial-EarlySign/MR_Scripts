#!/usr/bin/env perl 

die "Usage : $0 RepositoriesList TagName BranchName -or- $0 RepositoriesList BranchName" unless (@ARGV == 2 or @ARGV == 3) ;
my $tag_flag = (@ARGV == 3 ? 1 : 0);

my ($repFile,$tagName,$branchName) = ("","","");
if ($tag_flag == 1) {
	($repFile,$tagName,$branchName) = @ARGV ;
} else {
	($repFile,$branchName) = @ARGV ;
}

# Read Repositories
my @reps ;
open (IN,$repFile) or die "Cannot open $repFile for reading" ;
while (<IN>) {
	chomp ;
	push @reps,$_ ;
}
close IN ;

my $nrep = scalar @reps ;
print STDERR "Read $nrep repositoties to tag\n" ;

# Tag to Branch
# Assumes no uncommited changes exist in any of the given repos
foreach my $rep (@reps) {
	chdir($rep) ;
	if ($tag_flag == 1) {
		system("git checkout -B $branchName $tagName") == 0 or die "Cannot create branch $branchName from tag $tagName on repository $rep" ;
	} else {
		system("git checkout -B $branchName") == 0 or die "Cannot create branch $branchName on repository $rep" ;
	}
}