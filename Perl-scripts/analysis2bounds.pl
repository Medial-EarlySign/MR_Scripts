#!/usr/bin/env perl 
# Read An Analysis File and Create a Bounds File for valiate_cutoffs

use strict(vars) ;

die "Usage: $0 inFile outFile" unless (@ARGV == 2) ;
my ($inFile,$outFile) = @ARGV;

my @fps = (0.1,0.5,1,5,10) ;
my @sns = (5,10,20,30,40,50,60,70,80,90) ;

open (IN,$inFile) or die "Cannot open $inFile for reading" ;
open (OUT,">$outFile") or die "Cannot open $outFile for reading" ;
print OUT "MinDays\tMaxDays\tMinAge\tMaxAge\tScore\tTargetSens\tTargetSpec\n" ;

my $header = 1 ;
my %cols ;
while (<IN>) {
	chomp ;
	s/FP1.0/FP1/g ; s/FP5.0/FP5/g ; # Compatability to old version of bootstrap_analysis
	
	my @data = split  ;
	if ($header) {
		map {$cols{$data[$_]} = $_} (0..$#data) ;
		
		foreach my $fp (@fps) {
			die "Cannot find score for FP=$fp" if (!exists $cols{"SCORE\@FP$fp-Mean"}) ;
			die "Cannot find target sensitivity for FP=$fp" if (!exists $cols{"SENS\@FP$fp-Mean"}) ;
		}
		
		foreach my $sn (@sns) {
			die "Cannot find score for Sens=$sn" if (!exists $cols{"SCORE\@$sn-Mean"}) ;
			die "Cannot find target specificity for Sens=$sn" if (!exists $cols{"SPEC\@$sn-Mean"}) ;
		}	
		
		$header = 0 ;
	
	} else {
		my $time_window = $data[0] ;
		$time_window =~ s/-/\t/ ;
		my $age_range = $data[1] ;
		$age_range =~ s/-/\t/ ;
		
		foreach my $fp (@fps) {			
			my $score = $data[$cols{"SCORE\@FP$fp-Mean"}] ;
			my $spec = 100 - $fp ;
			my $sens = $data[$cols{"SENS\@FP$fp-Mean"}] ;
			
			print OUT "$time_window\t$age_range\t$score\t$sens\t$spec\n" ;
		}
		
		foreach my $sn (@sns) {
			my $score = $data[$cols{"SCORE\@$sn-Mean"}] ;
			my $sens = $sn ;
			my $spec = $data[$cols{"SPEC\@$sn-Mean"}] ;
			
			print OUT "$time_window\t$age_range\t$score\t$sens\t$spec\n" ;		
		}	
	}
}

close IN ;
close OUT ;
