#!/usr/bin/env perl 

use strict(vars) ;

my $header = 1 ;
my %cols ;
while (<>) {
	chomp ;
	my @x = split  ;
	if ($header) {
		$header = 0 ;
		for my $i (0..$#x) {
			$cols{$1} = $i if ($x[$i] =~ /(\S+)-Mean/) ;
		}
	} else {
		if (exists $cols{"SENS\@90"}) {
			printf "$x[0]/$x[1]: AUC = %.2f [%.2f, %.2f], odds-ratio at 10%% sensitivity = %.0f [%.0f, %.0f], sensitivity at 90%% specificity = %.1f%% [%.1f, %.1f] (%d Pos)\n",
			$x[$cols{AUC}],$x[$cols{AUC}+2],$x[$cols{AUC}+3],$x[$cols{"OR\@10"}],$x[$cols{"OR\@10"}+2],$x[$cols{"OR\@10"}+3],$x[$cols{"SENS\@90"}],$x[$cols{"SENS\@90"}+2],$x[$cols{"SENS\@90"}+3],
			$x[$cols{NPOS}];
		} elsif (exists $cols{"SENS\@FP10"}) {
			printf "$x[0]/$x[1]: AUC = %.2f [%.2f, %.2f], odds-ratio at 10%% sensitivity = %.0f [%.0f, %.0f], sensitivity at 90%% specificity = %.1f%% [%.1f, %.1f], sensitivity at 99%% specificity = %.1f%% [%.1f, %.1f] (%d Pos)\n",
			$x[$cols{AUC}],$x[$cols{AUC}+2],$x[$cols{AUC}+3],
			$x[$cols{"OR\@10"}],$x[$cols{"OR\@10"}+2],$x[$cols{"OR\@10"}+3],
			$x[$cols{"SENS\@FP10"}],$x[$cols{"SENS\@FP10"}+2],$x[$cols{"SENS\@FP10"}+3],
			$x[$cols{"SENS\@FP1"}],$x[$cols{"SENS\@FP1"}+2],$x[$cols{"SENS\@FP1"}+3],
			$x[$cols{NPOS}];
		} elsif (exists $cols{"SENS\@FP10.0"}) {
			printf "$x[0]/$x[1]: AUC = %.2f [%.2f, %.2f], odds-ratio at 10%% sensitivity = %.0f [%.0f, %.0f], sensitivity at 90%% specificity = %.1f%% [%.1f, %.1f], sensitivity at 99%% specificity = %.1f%% [%.1f, %.1f] (%d Pos)\n",
			$x[$cols{AUC}],$x[$cols{AUC}+2],$x[$cols{AUC}+3],
			$x[$cols{"OR\@10.0"}],$x[$cols{"OR\@10.0"}+2],$x[$cols{"OR\@10.0"}+3],
			$x[$cols{"SENS\@FP10.0"}],$x[$cols{"SENS\@FP10.0"}+2],$x[$cols{"SENS\@FP10.0"}+3],
			$x[$cols{"SENS\@FP1.0"}],$x[$cols{"SENS\@FP1.0"}+2],$x[$cols{"SENS\@FP1.0"}+3],
			$x[$cols{NPOS}];
		} else {
			die "Cannot handle input data" ;
		}
	}
}
