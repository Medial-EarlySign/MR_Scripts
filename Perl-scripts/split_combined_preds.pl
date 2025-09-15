#!/usr/bin/env perl 
use strict(vars) ;
die "Usage : $0 CombinedPredsFile" if (@ARGV != 1) ;
my $preds_file = $ARGV[0] ;

# Read demographics
my $dem_file = "W:\\CRC\\AllDataSets\\Demographics" ;
open (DEM,$dem_file) or die "Cannot open $dem_file for reading" ;

my %gender ;
while (<DEM>) {
	chomp ;
	my ($id,$byear,$gender) = split ;
	$gender{$id} = $gender ;
}
close DEM ;
print STDERR "Done Reading Demographics\n" ;

# Split
open (IN,$preds_file) or die "Cannot open $preds_file for reading" ;
open (MOUT,">Men.$preds_file") or die "Cannot open Men.$preds_file for writing" ;
open (WOUT,">Women.$preds_file") or die "Cannot open Women.$preds_file for writing" ;

my $header = 1 ;
while (<IN>) {
	chomp ;
	if ($header == 1) {
		print MOUT "$_ MenSubset\n" ;
		print WOUT "$_ WomenSubset\n" ;
		$header = 0 ;
	} else {
		my ($id,@info) = split ;
		die "Unknown id $id" if (! exists $gender{$id}) ;
		if ($gender{$id} eq "M") {
			print MOUT "$_\n" ;
		} else {
			print WOUT "$_\n" ;
		}
	}
}

close IN ; 
close MOUT ;
close WOUT ;