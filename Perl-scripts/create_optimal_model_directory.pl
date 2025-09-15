#!/usr/bin/env perl 
use strict(vars) ;
use Getopt::Long;

my %na = ("-1.#IO" => 1,
		  "1.#IO" => 1,
		  "NA" => 1,
		  ) ;

my $params = {
	no_run => 0,
	no_copy => 0,
	no_odds => 0,
	no_r => 0,
	no_earlystage => 0,
	no_history => 0,
	no_combdetect => 0,
	};

GetOptions($params,
	"in_dir=s",      # input dir
	"age_dir=s",     # age-only results dir
	"no_run",        # flag if not to run comamnds
	"no_copy",       # flag if not to copy full analysis files 
	"no_odds",       # flag if not to create odds graphs
	"no_r",          # flag if not to execute R script
	"no_earlystage", # flag if to skip early stage graphs
	"no_history",    # flag if to skip history analysis graphs 
	"no_combdetect", # flag if not to run combined detection analysis
	);
	
print STDERR "Parameters: " . join(", ", map {"$_ => $params->{$_}"} sort keys %$params) . "\n";
	
# # die "Usage $0 --in_dir InDir --age_dir AgeDir <flags>" if (! exists $params->{in_dir} or ! exists $params->{age_dir}); 
my ($InDir,$AgeDir) = ($params->{in_dir}, $params->{age_dir});

# Create ReadMe
open (OUT,">ReadMe.txt") or die "Cannot opern ReadMe file for wrinting" ;
print OUT "Input Directory = $InDir\n" ;
print OUT "Age Directory = $AgeDir\n" ;
close OUT ;

# Collect Data and Fix
unless ($params->{no_copy}) {
	foreach my $gender (qw/men women combined/) {
		foreach my $type (qw/THIN FullCV Validation LearnPredict/) {
			run_cmd ("cp $InDir\\FullAnalysis.$gender.$type.Raw .") ;
			foreach my $suffix ("",".Short") {
				fix("$InDir\\FullAnalysis.$gender.$type$suffix","FullAnalysis.$gender.$type$suffix")  ;
			}
		}
		
#		run_cmd("cp $InDir\\Analysis.NoHistory.$gender.Raw .") ;
#		foreach my $suffix ("",".Short") {
#			fix("$InDir\\Analysis.NoHistory.$gender$suffix","Analysis.NoHistory.$gender$suffix") ;	
#		}
	}
	
	run_cmd("cp $AgeDir\\FullAnalysis.combined.LearnPredict.Raw AgeAnalysis.combined.LearnPredict.Raw") ;
	foreach my $suffix ("",".Short") {
		fix("$AgeDir\\FullAnalysis.combined.LearnPredict$suffix","AgeAnalysis.combined.LearnPredict$suffix") ;	
	}
}

# Odds Binning.
unless ($params->{no_odds}) {
	run_cmd("C:\\Medial\\Perl-scripts\\FOBT_odds.pl $InDir\\LearnPredict_predictions.combined FOBT_odds") ;
	run_cmd("C:\\Medial\\Perl-scripts\\CRC_odds.pl $InDir\\LearnPredict_predictions.combined CRC_odds") ;
}

# Graphs
run_cmd("\\\\server\\Work\\Applications\\R\\R-latest\\bin\\R CMD BATCH --silent --slave --no-timing C:\\Medial\\R-Scripts\\generate_all_graphs.r all_graphs.Rout") unless ($params->{no_r});

# Early Stages
unless ($params->{no_earlystage}) {
	my $reg_file = "\\\\server\\Work\\CRC\\AllDataSets\\Registry" ;
	my $rem_file = "LateStageIds" ;
	
	open (REG,$reg_file) or die "Cannot open $reg_file for reading" ;
	open (REM,">$rem_file") or die "Cannot open $rem_file for writing" ;
	
	while (<REG>) {
		chomp ;
		my @data = split ",",$_ ;
		print REM "$data[0]\n" unless ($data[4] eq "1" or $data[4] eq "0") ;
	}
	
	close REG ;
	close REM ;
	
	my $cmd = "C:\\Medial\\Projects\\ColonCancer\\AnalyzeScores\\Release\\bootstrap_analysis.exe in=$InDir\\full_cv_predictions.combined1".
		      " params=\\\\server\\UsersData\\Yaron\\ModelSelection\\parameters_file.short dir=\\\\server\\work\\CRC\\AllDataSets\\Directions".
			  " rem=$rem_file out=Analysis.combined.FullCV.EarlyStage" ;
	run_cmd($cmd) ;
}

# History 
unless ($params->{no_history}) {

    open (IN,"$InDir\\LearnPredict_NoHistory_predictions.combined.Ptrn4") or die "Cannot open $InDir\\LearnPredict_NoHistory_predictions.combined.Ptrn4 for reading\n" ;
	open (OUT,">Predictions.HistoryPattern4") or die "Cannot open Predictions.HistoryPattern4 for writing\n" ;
	print STDERR "Reading HistoryPattern 4 ..." ;
	
	my %subset ;
	my $header = 1 ;
	while (<IN>) {
		print OUT $_ ;
		if ($header) {
			$header = 0 ;
			next ;
		}
		
		chomp ;
		my ($id,$date) = split ;
		$subset{"$id.$date"} = 1 ;		
	}
	
	close IN ;
	close OUT ;
	
	my $n = scalar keys %subset ;
	print STDERR " Done : Read $n samples\n" ;
	
	foreach my $ptrn (0,1,2,3) {
		my $in_file = ($ptrn == 0) ? "LearnPredict_predictions.combined" : "LearnPredict_NoHistory_predictions.combined.Ptrn$ptrn" ;
		open (IN,"$InDir\\$in_file") or die "Cannot open $InDir\\$in_file for reading\n" ;
		open (OUT,">Predictions.HistoryPattern$ptrn") or die "Cannot open Predictions.HistoryPattern$ptrn for writing\n" ;
		print STDERR "Reading Histroy Pattern $ptrn ..." ;
		
		my $header = 1 ;
		while (<IN>) {
			if ($header) {
				$header = 0 ;
				print OUT $_ ;
				next ;
			}
			
			chomp ;
			my ($id,$date) = split ;
			print OUT "$_\n" if (exists $subset{"$id.$date"}) ;		
		}
		
		close IN ;
		close OUT ;
		print STDERR " Done\n" ;
	}`
	
	foreach my $ptrn (0..4) {
		my $cmd = "C:\\Medial\\Projects\\ColonCancer\\AnalyzeScores\\Release\\bootstrap_analysis.exe --in=Predictions.HistoryPattern$ptrn".
		  " --params=\\\\server\\UsersData\\Yaron\\ModelSelection\\parameters_file.short --dir=\\\\server\\work\\CRC\\AllDataSets\\Directions".
		  " --out=Analysis.HistoryPattern$ptrn" ;
		run_cmd($cmd) ;
	}
}

# Combined Detection
unless ($params->{no_combdetect}) {
	my $cmd = "C:\\Medial\\Perl-scripts\\FOBT_and_MeScore.pl $InDir\\full_cv_predictions.combined1 > FOBT_and_MeScore.stdout";
	run_cmd($cmd);
}

####################################################################################
sub run_cmd {
	my ($command) = @_ ;
	
	print STDERR "Running \'$command\'\n" ;
	(system($command) == 0 or die "\'$command\' Failed") unless ($params->{no_run}) ;
	
	return ;
}

sub fix {
	my ($inFile,$outFile) = @_ ;

	open (IN,$inFile) or die "Cannot open $inFile for reading" ;
	open (OUT,">$outFile") or die "Cannot open $outFile for writing" ;
	
	while (<IN>) {
		chomp ; 
		my @data = split /\t/,$_ ;
		map {$
		data[$_] = "NA" if (exists $na{$data[$_]})} (0..$#data) ;
		my $out = join "\t",@data ;
		print OUT "$out\n" ;
	}
	
	close IN ;
	close OUT ;
}


