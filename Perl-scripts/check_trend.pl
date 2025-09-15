#!/usr/bin/env perl 

use strict ;
my @days2month = (0,31,59,90,120,151,181,212,243,273,304,334) ;

my ($min_age,$max_age) = (50,75) ;

# Read Birth-Years
my %byear ;
open (BY,"W:/CancerData/AncillaryFiles/Byears") or die "Cannot open Byears files" ;
while (<BY>) {
	chomp ;
	my ($id,$year) = split ;
	$byear{$id} = $year ;
}
close (BY) ;

# Read Predictions
my @orig_preds ;
print STDERR "Reading ..." ;
my $head = 1;
while (<>) {
	if ($head == 1) {
		$head = 0 ;
		next ;
	}
	chomp ;
	my ($id,$date,$score) = split ;
	my $age = int($date/10000) - $byear{$id} ;
	push @orig_preds,{id => $id, score=>$score,days=>get_days($date)} if ($age >= $min_age and $age <= $max_age) ;
}
close IN ;
print STDERR " Done\n" ;

my @preds = sort {$a->{days} <=> $b->{days}} @orig_preds ;
my $npreds = scalar(@preds) ;

my $end_days = get_days(20140101) ;
my $start_days = get_days(20070101) ;

# Scores of interest
my @scores = (30..90) ;
push @scores, (map {90 + $_/2} (1..15)) ;
push @scores, (map {97.5 + $_/10} (1..25)) ;

foreach my $bound (@scores) {
	print STDERR "Testing $bound" ;
	
	my $pred_idx = 0 ;
	my %done_ids ;
	my $idx = 1 ;
	
	my @ratios ;
	# Loop on months
	for (my $day=$start_days-30; $day<$end_days; $day+=30) {
		$pred_idx ++  while ($pred_idx < $npreds and $preds[$pred_idx]->{days} < $day) ;
		last if ($pred_idx == $npreds) ;
	
		my %counts ;
		# Scores within month in question
		while ($pred_idx < $npreds and $preds[$pred_idx]->{days} < $day + 30) {
			my $rec = $preds[$pred_idx]  ;
			# Id was not sent to colonoscopy already
			if (! exists $done_ids{$rec->{id}}) {
				$counts{tot} ++ ;
				if ($rec->{score} >= $bound) {
					$counts{pos} ++ ;
					$done_ids{$rec->{id}} = 1 ;
				}
			}
			$pred_idx ++ ;
		}

		push @ratios,$counts{pos}/$counts{tot} ;
		$idx ++ ;
	}
	print STDERR "\r" ;
	
	my $smooth = smooth(\@ratios) ;
	map {print "$bound\t$_\t$ratios[$_]\t".($smooth->[$_])."\n"} (0..$#ratios) ;
	
	# Max of 2nd divergance
	my @smooth = @$smooth ;
	my @div1 = map {$smooth[$_] - $smooth[$_-1]} (1..$#smooth) ;
	my @div2 = map {$div1[$_] - $div1[$_-1]} (1..$#div1) ;
	
	my $maxi = 0 ;
	map {$maxi = $_ if ($div2[$_] > $div2[$maxi])} (1..$#div2) ;
	
	my $nnext = 5 ;
	my $pr ;
	map {$pr += $smooth[$_]} ($maxi..$maxi+$nnext-1) ;
	$pr /= $nnext ;
	
	print "$bound $pr\n" ;
}

print STDERR "\n" ;


##########################################################################################
# Smoothing by linear regression
sub smooth {
	my ($in) = @_ ;
	
	my @out ;
	my $n = scalar @$in ;
	
	my $flank = 10 ;
	my $size = 2*$flank+1 ;
	exit (-1) if ($n<$size) ;
	
	for my $i (0..$n-1) {
		my $start = ($i-$flank < 0) ? 0 : $i-$flank ;
		$start = $n-$size if ($start+$size-1 > $n-1) ;
		
		my $meany = 0 ;
		map {$meany += $in->[$_]} ($start..$start+$size-1) ;
		$meany /= $size ;
		
		my ($sxx,$sxy) = (0,0,0) ;
		for my $j (0..$size-1) {
			$sxx += ($j-$flank)*($j-$flank) ;
			$sxy += ($j-$flank)*($in->[$start+$j] - $meany) ;
		}
	
		my $a = $sxy/$sxx ;
		push @out, ($i-($start+$flank))*$a + $meany ;
	}
	
	return \@out ;
}

sub get_days {
	my $date = shift @_ ;

	my $year = int ($date/100/100) ;
	my $month = int (($date % (100*100))/100) ;
	my $day = ($date % 100) ;
	
	my $days = 365 * ($year-1900) ;
	$days += int(($year-1897)/4) ;
	$days -= int(($year-1801)/100);
	$days += int(($year-1601)/400) ;

	$days += $days2month[$month-1] ;
	$days ++ if ($month>2 && ($year%4)==0 && (($year%100)!=0 || ($year%400)==0)) ;

	$days += ($day-1) ;
	return $days ;
}	  