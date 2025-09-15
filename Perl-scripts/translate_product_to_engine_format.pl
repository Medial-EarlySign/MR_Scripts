#!/usr/bin/env perl 
use strict(vars) ;

my @months = qw/JAN FEB MAR APR MAY JUN JUL AUG SEP OCT NOV DEC/ ;
my %months = map {($months[$_]=>$_+1)} (0..$#months) ;

my @cbc_test_order = (5041, 5048, 50221, 50223, 50224, 50225, 50226, 50227, 50228, 50229,50230, 50232, 50234, 50235, 50236, 50237, 50239, 50241, 50233, 50238) ;
my %cbc_map = map {($cbc_test_order[$_] => $_+1)} (0..$#cbc_test_order) ;

die "Usage : $0 InPref OutPref" if (@ARGV!=2) ;
my ($in,$out) = @ARGV ;

# Demographics
my $in_file = "$in.Demographics.txt" ;
open (IN,$in_file) or die "Cannot open $in_file for reading" ;

my $out_file = "$out.Demographics.txt";
open (OUT,">$out_file") or die "Cannot open $out_file for writing" ;

while (<IN>) {
	chomp ; 
	my ($grp,$id,$byear,$gender) = split ;
	print OUT "$id\t$byear\t$gender\n" ;
}
close IN ;
close OUT ;

# Data
my $in_file = "$in.Data.txt" ;
open (IN,$in_file) or die "Cannot open $in_file for reading" ;

my $out_file = "$out.Data.txt";
open (OUT,">$out_file") or die "Cannot open $out_file for writing" ;

while (<IN>) {
	chomp ;
	next unless (/\S+/) ;
	my ($grp,$id,$code,$date,$value) = split ;
	$date =~ /(\d\d\d\d)-(\S\S\S)-(\d\d)/ or die "Cannot parse $date" ;
	my ($year,$month,$day) = ($1,$2,$3) ;
	die "Cannot identify $month" if (! exists $months{$month}) ;
	$date = sprintf("$year%02d%02d",$months{$month},$day) ;
	
	$code = $cbc_map{$code} if (exists $cbc_map{$code}) ;	
	print OUT "$id\t$code\t$date\t$value\n" ;
}
close IN ;
close OUT ;