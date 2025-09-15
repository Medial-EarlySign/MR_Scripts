#!/usr/bin/env perl 

use strict(vars) ;
use File::stat ;

die "Usage : $0 FileOfFilesToIndex" if (@ARGV != 1) ;
my $list = shift @ARGV ;
my @files ;
open (FL,$list) or die "Cannot open \'$list\' for reading" ;
while (<FL>) {
	chomp ;
	push @files,$_ ;
}
my $nFiles = scalar @files ;
print STDERR "Indexing $nFiles files\n" ;

my $nids = 32809 + 1 ;
foreach my $file (@files) {
	print STDERR "Working on $file ... " ;
	open (IN,$file) or die "Cannot open $file for reading" ;
	my @pos = (-1) x $nids ;
	
	my ($pos,$prev_id) ;
	while (<IN>) {
		chomp ;
		my ($id) = split /\,/,$_ ;
		$pos[$id] = $pos if ($id ne "SUBJECT_ID" and $id != $prev_id) ;
		$prev_id = $id ;
		$pos = tell(IN) ;
	}
	close IN ;
	print STDERR "DONE Reading\n" ;
	
	open (OUT,">:raw","$file.idx") or die "Cannot open indexing file for $file" ;
	print OUT pack("q$nids",@pos) ;
	close OUT ;
}
	
