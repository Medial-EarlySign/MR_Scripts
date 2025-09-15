#!/usr/bin/env perl

use Statistics::Distributions ;

use strict(vars) ;

my $min_score = 0 ;
die "Usage : $0 RawFile1 IncidenceFile1 RawFile2 IncidenceFile2 Type N" if (@ARGV != 6) ;
my ($raw_file1,$inc_file1,$raw_file2,$inc_file2,$type,$n) = @ARGV ;

my $raw1 = read_raw ($raw_file1,$type) ;
my $raw2 = read_raw ($raw_file2,$type) ;
my $inc1 = read_inc ($inc_file1,$type) ;
my $inc2 = read_inc ($inc_file2,$type) ;

my $exps = get_exps($raw1,$inc1,$n) ;
get_score($raw2,$inc2,$n,$exps) ;

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
	$ratio = $obs_inc/$inc ;
	print STDERR "Learning : $type - $inc vs $obs_inc -> $ratio\n" ;
		
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

sub get_score {
	my ($raw,$inc,$nbins,$exps,) = @_ ;
	
	my @cnts ;
	my $ratio ;
		
	# Total incidence
	my $n = scalar @$raw ;
	my $npos = scalar (grep {$_->[1] > 0} @$raw) ;
	my $obs_inc = $npos/$n ;
	$ratio = $obs_inc/$inc ;
	print STDERR "Learning : $type - $inc vs $obs_inc -> $ratio\n" ;
		
	my $min_pos_p = 1.0 ;
	foreach my $rec (@$exps) {
		$min_pos_p = $rec->{p} if ($rec->{p} > 0 and $rec->{p} < $min_pos_p) ;
	}
	print STDERR "Minimal Positive P = $min_pos_p\n" ;		
		
	my $log_score = 0 ;
	my $brier_score = 0 ;
	my $log_score_0 = 0 ;
	
	my $norm = 0 ;
	foreach my $rec (@$raw) {
		my $bin = get_bin($rec->[0],$exps,$nbins) ;
		my $p = ($exps->[$bin]->{p} > 0) ? $exps->[$bin]->{p} : $min_pos_p ;
		
		if ($rec->[1] > 0) {
			$log_score += log($p) ;
#			$log_score_0 += log($incidence) ;
			$brier_score += ($p-$rec->[1])*($p-$rec->[1]) ;
			$norm ++ ;
		} else {
			$log_score += $ratio * log(1-$p) ;
#			$log_score_0 += $ratio * log(1-$incidence) ;
			$brier_score += $ratio * ($p-$rec->[1])*($p-$rec->[1]) ;
			$norm += $ratio
		}
	}
	
	$log_score /= $norm ;
	$brier_score /= $norm ;
	
	printf "Log Score = %.3g\n",$log_score ;
	printf "Brier Score = %.3g\n",$brier_score ;
}
  
sub get_bin {
	my ($score,$exps,$nbins) = @_ ;
	
	for my $i (0..(scalar(@{$exps})-1)) {
		return $i if ($score <= $exps->[$i]->{max}) ;
	}
	
	die "Cannot find bin for $score\n" ;
}
