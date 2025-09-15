#!/usr/bin/env perl 
use strict(vars) ;

die "Usage: $0 InMatrix IdsFile OutMatrix TempPrefix" if (@ARGV != 4) ;
my ($inFile,$idsFile,$outFile,$tmpFile) = @ARGV ; 

# Read Ids.
open (IDS,$idsFile) or die "Cannot open $idsFile for reading" ;
my %ids ;
while (<IDS>) {
	chomp ;
	$ids{$_} = 1 ;
}
close IDS ;

my $nids = scalar keys %ids ;
print STDERR "Read $nids from \'$idsFile\'\n" ;

# Transform bin to txt
system("C:\\Medial\\Projects\\ColonCancer\\predictor\\x64\\Release\\utils.exe bin2txt $inFile $tmpFile.in")==0 or die "Cannot transform bin file to text" ;
print STDERR "Done Transfering\n" ;

# Correct
open (TMP,"$tmpFile.in") or die "Cannot open $tmpFile.in for reading" ;
open (TXT,">$tmpFile.out") or die "Cannot open $tmpFile.out for writing" ;

my $nfilter = 0 ;
while (<TMP>) {
	chomp ;
	my @data = split ;
	$data[7] = 3.0 if (int($data[7]) == 1 and ! exists $ids{int($data[0])}) ;

	my $out = join "\t",@data ;
	print TXT "$out\n" ;
}

close TXT ;
close OUT ;
print STDERR "Done Correcting\n" ;

# Transform txt to bin
system("C:\\Medial\\Projects\\ColonCancer\\predictor\\x64\\Release\\utils.exe txt2bin $tmpFile.out $outFile")==0 or die "Cannot transform text file to bin" ;
print STDERR "Done Transfering\n" ;
