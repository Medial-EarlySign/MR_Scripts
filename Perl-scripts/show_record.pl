#!/usr/bin/env perl 

use strict(vars) ;

die "$0 NR [ID2NR-File Records-Dir]" if (@ARGV != 1 and @ARGV != 3) ;

my $nr = shift @ARGV ;
my ($id2nr,$dir) ;
if (@ARGV) {
	($id2nr,$dir) = @ARGV ;
} else {
	($id2nr,$dir) = ("W:/CRC/THIN_MAR2013/ID2NR","W:/CRC/THIN/IndividualData") ;
}

# Get ID
open (IN,$id2nr) or die "Cannot open ID2NR file $id2nr" ;
my $id ;
while (<IN>) {
	chomp ;
	my ($cid,$cnr) = split ;
	if ($cnr == $nr) {
		$id = $cid ;
		last ;
	}
}
close IN ;

die "Cannot find ID for $nr" unless (defined $id) ;

# Print file
my $file = $dir . "/" . substr($id,0,5) . "/" . $nr . ".parsed" ;
open (FL,$file) or die "Cannot open record file $file for reading" ;
while (<FL>) {
	print $_ ;
}
close FL ;
