#!/usr/bin/env perl 

use strict(vars) ;
use FileHandle ;

die "Usage : $0 inNotes StaysFile outNotes" if (@ARGV!=3) ;
my ($inFile,$infoFile,$outFile) = @ARGV ;

# Open
open (IN,$inFile) or die "Cannot open $inFile for reading" ;
open (MAP,$infoFile) or die "Cannot open $infoFile for reading" ;
open (OUT,">$outFile") or die "Cannot open $outFile for writing" ;

# Read Map
my %staysMap ;
while (<MAP>) {
	chomp ;
	my @data = split ;
	push @{$staysMap{$data[3]}},$data[0] if ($data[1] eq "OrigStayID") ;
}
close MAP ;

# Extend
while (<IN>) {
	chomp ;
	my ($patId,$stayId,@data) = split /\t/,$_ ;
	if (exists $staysMap{$stayId}) {
		foreach my $newId (@{$staysMap{$stayId}}) {
			my $out = join "\t",($patId,$newId,@data) ;
			print OUT "$out\n" ;
		}
	}
}
close IN ;
close OUT ;