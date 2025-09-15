#!/usr/bin/env perl 

use strict ;

die "Usage : $0 OrigDataFile NewDataFile TempFile" if (@ARGV != 3) ;
my ($origFile,$newFile,$tempFile) = @ARGV; 

# Read New Data
open (IN,$newFile) or die "Cannot open $newFile for reading" ;
my %newData ;
while (my $line = <IN>) {
	my ($id) = split /\t/,$line ;
	push @{$newData{$id}},$line ;
}
close IN ;

# Read/Write data
open (IN,$origFile) or die "Cannot open $origFile for reading" ;
open (OUT,">$tempFile") or die "Cannot open $tempFile for writing" ;

my $prevId ;
while (my $line = <IN>) {
	my ($id) = split /\t/,$line ;
	
	if (!defined $prevId or $id != $prevId) {
		map {print OUT "$_"} @{$newData{$id}} if (exists $newData{$id}) ;
	}
	
	$prevId = $id ;	
	print OUT $line ;
}
close IN ;
close OUT ;

# Temp -> Orig 
open (IN,$tempFile) or die "Cannot open $tempFile for reading" ;
open (OUT,">$origFile") or die "Cannot open $origFile for writing" ;
while (<IN>) {
	print OUT $_ ;
}
close IN ;
close OUT ;