#!/usr/bin/env perl

use Statistics::Distributions ;

use strict(vars) ;

my $min_score = 0 ;
die "Usage : $0 RawFile1 IncidenceFile1 RawFile2 IncidenceFile2 Type N Suffix" if (@ARGV != 7) ;
my ($raw_file1,$inc_file1,$raw_file2,$inc_file2,$type,$n,$suffix) = @ARGV ;

my $raw1 = read_raw ($raw_file1,$type) ;
my $raw2 = read_raw ($raw_file2,$type) ;
my $inc1 = read_inc ($inc_file1,$type) ;
my $inc2 = read_inc ($inc_file2,$type) ;

my $exps = get_exps($raw1,$inc1,$n) ;
check_exps($raw2,$inc2,$n,$exps,$suffix) ;

## Functions
sub read_inc {

	my ($file,$type) = @_ ;
	
	open (IN,$file) or die "Cannot open $file for reading" ;

	my %inc ;
	while (<IN>) {
		chomp ;
		my ($curr_type,$inc) = split ;
		return $inc if ($type eq $curr_type) ;
	}
	
	die "No incidence for $type in $file" ;
}
	
sub read_raw {

	my ($file,$type) = @_ ;
	
	open (IN,$file) or die "Cannot open $file for reading" ;
	
	my @info ;
	while (<IN>) {
		chomp ;
		my ($curr_type,$score,$label) = split ;
		next if ($score < $min_score || $curr_type ne $type) ;
		push @info,[$score,$label] ;
	}
	close IN ;

	@info = sort {$a->[0] <=> $b->[0]} @info ;
	return \@info ;
}

sub get_exps {
	my ($raw,$inc,$nbins) = @_ ;
	
	my @exps ;
	my $ratio ;
		
	# Total incidence
	my $n = scalar @$raw ;
	my $npos = scalar (grep {$_->[1] > 0} @$raw) ;
	my $obs_inc = $npos/$n ;
#	print STDERR "Learning : $type - $inc vs $obs_inc\n" ;
	$ratio = $obs_inc/$inc ;
		
	# Equal sized
	my $bin_size = int($n/$nbins) + 1 ;
	
	my ($cnt, $bin) = (0,0) ;
	foreach my $rec (@$raw) {
		$exps[$bin]->{cnts}->[$rec->[1]] ++ ;
		$cnt = ($cnt + 1)%$bin_size ;
		if ($cnt == 0) {
			$exps[$bin]->{max} = $rec->[0] ;
			$bin ++ ;
		}
	}	
	
	foreach my $rec (@exps) {
		$rec->{max} = 100 if (! exists $rec->{max}) ;
				
		map {$rec->{cnts}->[$_] += 0} (0,1) ;
		$rec->{adjusted_n} = $rec->{cnts}->[1] + $rec->{cnts}->[0]* $ratio ;
		$rec->{p} = $rec->{cnts}->[1]/$rec->{adjusted_n} ;
	}
	
	return \@exps
}

sub check_exps {
	my ($raw,$inc,$nbins,$exps,$suffix) = @_ ;
	
	my $file = "Recalibration.$suffix" ;
	open (OUT,">$file") or die "Cannot open $file for writing " ;
	
	my @cnts ;
	my $ratio ;
		
	# Total incidence
	my $n = scalar @$raw ;
	my $npos = scalar (grep {$_->[1] > 0} @$raw) ;
	my $obs_inc = $npos/$n ;
#	print STDERR "Testing : $type - $inc vs $obs_inc\n" ;
	$ratio = $obs_inc/$inc ;
		
	foreach my $rec (@$raw) {
		my $bin = get_bin($rec->[0],$exps,$nbins) ;
		$cnts[$bin]->[$rec->[1]] ++ ;
	}
	
	my $hl ;
	foreach my $bin (0..scalar(@$exps)-1) {
		my $rec = $exps->[$bin] ;
				
		my @ecnts = @{$rec->{cnts}} ;
		my $adjusted_n = $rec->{adjusted_n} ;				
		my $p = $rec->{p} ;
		my $max = $rec->{max} ;
				
		my @cnts2 = @{$cnts[$bin]} ;
		map {$cnts2[$_] += 0} (0,1) ; 
		my $adjusted_n2 = $cnts2[1] + $cnts2[0] * $ratio ;
		my $p2 = $cnts2[1]/$adjusted_n2 ;
				
		my $obs_n = $cnts2[0] + $cnts2[1] ;
		my $tot_n =  $obs_n / ($p + (1-$p)/$ratio) ;
		my $exp = int($tot_n * $p) ;
		my $obs = $cnts2[1] ;
		my $p1 = $tot_n*$p/$obs_n ;
		my $current_hl = ($obs - $exp) * ($obs - $exp)/ ($obs_n * $p1 * (1-$p1)) ;
		$hl += $current_hl ;
  
		printf OUT "$bin\t$max\t@ecnts[0]\t$ecnts[1]\t$adjusted_n\t%.5f\t$cnts2[0]\t$cnts2[1]\t$adjusted_n2\t%.5f\t$obs_n\t$exp\t$obs\t%.2f\n" ,$p,$p2,$current_hl;
	}
	close OUT ;	
	
	my $p = Statistics::Distributions::chisqrprob($nbins-1,$hl) ;
	
	do_cox($suffix) ;
	open (ROUT,">>cox_$suffix") or die "Canont append to Rout" ;
	print ROUT "HOSMER LEMESHOW Score = $hl ; P-Value = $p\n" ;
	close ROUT ;
	
	
}

sub do_cox {
	my ($suffix) = @_ ;
	
	# R script
	my $file = "cox.r" ;
	open (ROUT,">$file") or die "Cannot open $file for writing" ;
	
	print ROUT "library(aod) ;\n" ;
	print ROUT "data <- read.delim(\"Recalibration.$suffix\", header=F) ;\n" ;
	print ROUT "p1 <- data\$V6 ;\n" ;  
	print ROUT "p2 <- data\$V10 -p1; \n" ; 
	print ROUT "mdl <- lm (p2~p1); \n" ; 
	print ROUT "wld <- wald.test(b = coef(mdl),Sigma=vcov(mdl),Terms=c(1:2)); \n" ; 
	print ROUT "sink(\"cox_$suffix\") ;\n" ;
	print ROUT "print(wld); \n" ; 
	print ROUT "sink() ;\n" ;
	close RUOT ;
  
	system("R CMD BATCH --silent --no_timing $file") == 0 or die "R script failed\n" ;
}


  
sub get_bin {
	my ($score,$exps,$nbins) = @_ ;
	
	for my $i (0..(scalar(@{$exps})-1)) {
		return $i if ($score <= $exps->[$i]->{max}) ;
	}
	
	die "Cannot find bin for $score\n" ;
}
	
