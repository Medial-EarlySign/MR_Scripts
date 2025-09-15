#!/usr/bin/env perl 
use strict(vars);

die "Usage : $0 DetailedComparisonFile" unless (@ARGV == 1) ;
my ($file) = @ARGV ;

open (IN,$file) or die "Cannot open $file for reading" ;

my %params = ("EarlySens1\@FP1" => 1 , "EarlySens1\@FP2.5" => 1 , "EarlySens1\@FP5" => 1 ,
			  "EarlySens2\@FP1" => 1 , "EarlySens2\@FP2.5" => 1 , "EarlySens2\@FP5" => 1 ,
			  "EarlySens3\@FP1" => 1 , "EarlySens3\@FP2.5" => 1 , "EarlySens3\@FP5" => 1 ,			  
			  "SENS\@FP1" => 1, "SENS\@FP5" => 1, "SENS\@FP10" => 1) ;	

my %sums = ("---" => -3, "--" => -2, "-" => -1, "" => 0, "+" => 1, "++" => 2, "+++" => 3) ;
my %sum ;
my %num ;

my $warn ;
while (<IN>) {
	next if (/^Dataset/) ;
	
	chomp ;
	my ($data,$gender,$info,$age,$params,$v1,$v2,$d) = split ;
	if ($info =~ /UnPaired/ and ! $warn) {
		$warn = 1 ;
		print STDERR "Warning : Working with UnPiared files\n" ;
	}
	
	die "Cannot parse diff --$d--" if (!exists $sums{$d}) ;
	if (exists $params{$params}) {
		$params =~ /(\S+)\@FP(\S+)/ or die "Cannot parse $params" ;
		my ($type,$fp) = ($1,$2) ;
		for my $info ($data,$gender,$info,$age,$type,"ALL") {	
			$num{$info} ++ ;
			$sum{$info} += $sums{$d} ;
		}
	}
}

foreach my $info (sort keys %num) {
	my $mean = $sum{$info}/$num{$info} ;
	printf "Average Score for \'$info\' = %.3f on $num{$info} entries\n",$mean ;
}