#!/usr/bin/env perl 

use strict(vars) ;
use File::stat ;

die "Usage : $0 FileToIndex IndexFile" if (@ARGV != 2) ;

my ($inFile,$outFile) = @ARGV ;
print STDERR "Working on $inFile ...\n" ;

open (IN,$inFile) or die "Cannot open $inFile for reading" ;
my @pos ;
my $idCol ;
my ($pos,$prevId) ;
my %done ;
my $maxId = 100000 ;
my @pos = (-1)x($maxId+1) ;

my $nids ;
while (<IN>) {
	chomp ;
	my @info = split /\,/,$_ ;
	if (! defined $idCol) {
		for my $i (0..$#info) {
			if ($info[$i] =~ /SUBJECT_ID/) {
				$idCol = $i ;
				last ;
			}
		}
		$prevId = -1 ;
	} else {
		my $id = $info[$idCol] ;
		die "ID $id is too large (max = $maxId)\n" if ($id > $maxId) ;
		
		if ($id != $prevId) {
			die "Messed up file for $id. Quitting\n" if ($done{$id}) ;
#			print STDERR "Unordered file [$id after $prevId]\n" unless ($id > $prevId) ;
			$pos[$id] = $pos ;
			$done{$id} = 1 ;
			$nids ++ ;
		}
		$prevId = $id ;
	}
	$pos = tell(IN) ;
}
close IN ;

my $nVals = ($maxId+1) ;
print STDERR "DONE Reading $nids ids in [0,$maxId]\n" ;
open (OUT,">:raw","$outFile") or die "Cannot open indexing file $outFile" ;
print OUT pack("q$nVals",@pos) ;
close OUT ;
