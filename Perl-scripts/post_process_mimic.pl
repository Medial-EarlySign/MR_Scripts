#!/usr/bin/env perl 

use strict(vars) ;

my @days2month = (0,31,59,90,120,151,181,212,243,273,304,334) ;
my %hist ;

my %signalUnits = (Monocytes => "10^9/l", MonocytesPerc => "%", 
				   Lymphocytes => "K/micl", LymphocytesPercent => "%", 
				   Neutrophils => "10^9/l", NeutrophilsPercent => "%",
				   Reticulocytes => "K/micl", ReticulocytesPerc => "%",
				 ) ;

die "Usage : $0 inFile outFile" if (@ARGV != 2) ;
my ($inFile,$outFile) = @ARGV ;

open (IN,$inFile) or die "Cannot open $inFile for reading" ;
open (OUT,">$outFile") or die "Cannot open $outFile for writing" ;

my $prevId ;
my @data ;
my $header = 1;

while (<IN>) {
	if ($header) {
		print OUT $_ ;
		$header = 0 ;
	} else {
		chomp ;
		my @line = split /\t/,$_ ;
		my $id = $line[0] ;
		if (defined $prevId and $id != $prevId) {
			parseAndPrint($prevId,\@data);
			@data = () ;
		} 
		
		$prevId = $id ;
		push @data,\@line ;
	}
}

parseAndPrint($prevId,\@data);
printHist() ;

#### Functions ####
sub printHist {
	foreach my $signalName (keys %hist) {
		my $sum ;
		map {$sum += $hist{$signalName}->{$_}} keys %{$hist{$signalName}} ;
		map {printf "$signalName $_ $hist{$signalName}->{$_} %.2f\n",100*$hist{$signalName}->{$_}/$sum} sort {$a<=>$b} keys %{$hist{$signalName}} ;
		print "\n" ;
	}
}

sub getMinutes {
	my ($inTime) = @_ ;
	
	$inTime =~ /(\d\d)\/(\d\d)\/(\d\d\d\d) (\d\d):(\d\d):(\d\d)/ or die "Cannot parse time $inTime" ;
	my ($day,$month,$year,$hour,$minute,$second) = ($1,$2,$3,$4,$5,$6) ;
	
	my $days = 365 * ($year-2500) ;
	$days += int(($year-2497)/4) ;
	$days -= int(($year-2401)/100);

	$days += $days2month[$month-1] ;
	$days ++ if ($month>2 && ($year%4)==0 && (($year%100)!=0 || ($year%400)==0)) ;

	$days += ($day-1) ;
	return ($days*24*60) + ($hour*60) + $minute + ($second/60) ;
}	
	
sub fixStays {
	my ($id,$data) = @_ ;
	
	my %stayIds ;
	foreach my $rec (@$data) {
		my ($id,$stayId,$signalName,$value,$unit,$time) = @$rec ;
		$stayIds{getMinutes($time)}->{$stayId} ++ if ($stayId ne "");
	}

	my @times = sort {$a<=>$b} keys %stayIds ;
	my %realStayIds ;
	for my $i (0..$#times) {
	
		my $start = ($i>10) ? ($i-10) : 0 ;
		my %pastCounts ;
		for my $j ($start..$i-1) {
			map {$pastCounts{$_} += $stayIds{$times[$j]}->{$_}} keys %{$stayIds{$times[$j]}} ;
		}
		
		my @pastStayIds = sort {$pastCounts{$b} <=> $pastCounts{$a}} keys %pastCounts ;
		my $pastStayId = $pastStayIds[0] if (@pastStayIds == 1 or $pastCounts{$pastStayIds[0]} > 2*$pastCounts{$pastStayIds[1]}) ;
		
		my $end = ($i < $#times-10) ? $i+10 : $#times ;
		my %futureCounts ;
		for my $j ($i+1..$end) {
			map {$futureCounts{$_} += $stayIds{$times[$j]}->{$_}} keys %{$stayIds{$times[$j]}} ;
		}
		
		my @futureStayIds = sort {$futureCounts{$b} <=> $futureCounts{$a}} keys %futureCounts ;
		my $futureStayId = $futureStayIds[0] if (@futureStayIds == 1 or $futureCounts{$futureStayIds[0]} > 2*$futureCounts{$futureStayIds[1]}) ;
		
		$realStayIds{$times[$i]} = $futureStayId if ($futureStayId == $pastStayId) ;
	}
	
	for my $i (0..(scalar(@$data)-1)) {
		my $stayId = $data->[$i]->[1] ;	
		my $time = getMinutes($data->[$i]->[-1]) ;
		if (exists $realStayIds{$time} and $stayId != $realStayIds{$time}) {
			my $realStayId = $realStayIds{$time} ;
			print "Fixing stayId for $id at $time from $stayId to $realStayId\n" ;
			$data->[$i]->[1] = $realStayId ;
		}
	}	
}

sub getStays {
	my ($data,$stays) = @_ ;
	
	foreach my $rec (@$data) {
		my ($id,$stayId,$signalName,$value,$unit,$time) = @$rec ;

		if ($stayId ne "") {
			my $minutes = getMinutes($time) ;
			$stays->{$stayId}->{start} = $minutes if (!exists $stays->{$stayId}->{start} or $minutes < $stays->{$stayId}->{start}) ;
			$stays->{$stayId}->{end} = $minutes if (!exists $stays->{$stayId}->{end} or $minutes > $stays->{$stayId}->{end}) ;
		}
	}
}

sub checkStays {
	my ($id,$stays) = @_ ;

	my @stayIds = sort {$stays->{$a}->{start} <=> $stays->{$b}->{start}} keys %$stays ;
	for my $i (1..$#stayIds) {
		if ($stays->{$stayIds[$i-1]}->{end} > $stays->{$stayIds[$i]}->{start}) {
			print "Overlapping stayIds for $id\n" ;
			return 1 ;
		}
	}
	
	return 0 ;
}

sub parseAndPrint {
	my ($id,$data) = @_ ;
	
	print STDERR "Working on $id\n" ;
	
	my %data ;
	my %stays ;
	
	# Identify stay-ids domains and fix errors
	getStays($data,\%stays) ;
	if (checkStays($id,\%stays)) {
		fixStays($id,$data) ;
		%stays =() ;
		getStays($data,\%stays) ;
	}
	die "Cannot fix stays for $id" if (checkStays($id,\%stays)) ;
	
	# Expand stay-id domains
	my @stayIds = sort {$stays{$a}->{start} <=> $stays{$b}->{start}} keys %stays ;
	for my $i (0..$#stayIds) {
		$stays{$stayIds[$i]}->{start} -= 24*60 if ($i==0 || $stays{$stayIds[$i]}->{start}-24*60 > $stays{$stayIds[$i-1]}->{end}+24*60) ;
		$stays{$stayIds[$i]}->{end} += 24*60 if ($i==$#stayIds || $stays{$stayIds[$i]}->{end}+24*60 > $stays{$stayIds[$i+1]}->{start}-24*60) ;
	}
	
	foreach my $rec (@$data) {
		my ($id,$stayId,$signalName,$value,$unit,$time) = @$rec ;
		push @{$data{$signalName}->{$time}},{value => $value, stayID => $stayId, unit => $unit} ;
	}
	
	# Average
	my %finalData ;
	foreach my $signalName (keys %data) {
		foreach my $time (keys %{$data{$signalName}}) {
			my ($stayId,$unit) = map {$data{$signalName}->{$time}->[0]->{$_}} qw/stayID unit/ ;	
			
			my $n = scalar (@{$data{$signalName}->{$time}}) ;
			$hist{$signalName}->{$n}++ ;
			
			if ($signalName =~ /SOFA/) {
				$finalData{$signalName}->{$time} = $data{$signalName}->{$time}->[-1] ;
			} else {
				my $sum ;
				map {$sum += $_->{value}}  @{$data{$signalName}->{$time}} ;	
			
				$finalData{$signalName}->{$time} = {value => $sum/$n, unit => $unit, stayId => $stayId}  ;
			}
		}
	}
	
	# Handle White Line Information
	foreach my $wbcTime (keys %{$finalData{WhiteCellCount}}) {
		my $wbc = $finalData{WhiteCellCount}->{$wbcTime}->{value} ;
		my $stayId = $finalData{WhiteCellCount}->{$wbcTime}->{stayID} ;
		next if ($wbc == 0) ;
		
		
		if (exists $finalData{Monocytes}->{$wbcTime} and (!exists $finalData{MonocytesPerc}->{$wbcTime})) {
			my $value = 100 *$finalData{Monocytes}->{$wbcTime}->{value} / $wbc ;
			$finalData{MonocytesPerc}->{$wbcTime} = {value => $value, unit => $signalUnits{MonocytesPerc}, stayID => $stayId} ;
		} elsif (!exists $finalData{Monocytes}->{$wbcTime} and (exists $finalData{MonocytesPerc}->{$wbcTime})) {
			my $value = $finalData{MonocytesPerc}->{$wbcTime}->{value} * $wbc / 100 ;
			$finalData{Monocytes}->{$wbcTime} = {value => $value, unit => $signalUnits{Monocytes}, stayID => $stayId} ;
		}
		
		if (exists $finalData{Neutrophils}->{$wbcTime} and (!exists $finalData{NeutrophilsPercent}->{$wbcTime})) {
			my $value = 100 *$finalData{Neutrophils}->{$wbcTime}->{value} / $wbc ;
			$finalData{NeutrophilsPercent}->{$wbcTime} = {value => $value, unit => $signalUnits{NeutrophilsPercent}, stayID => $stayId} ;
		} elsif (!exists $finalData{Neutrophils}->{$wbcTime} and (exists $finalData{NeutrophilsPercent}->{$wbcTime})) {
			my $value = $finalData{NeutrophilsPercent}->{$wbcTime}->{value} * $wbc / 100 ;
			$finalData{Neutrophils}->{$wbcTime} = {value => $value, unit => $signalUnits{Neutrophils}, stayID => $stayId} ;
		}	

		if (exists $finalData{Lymphocytes}->{$wbcTime} and (!exists $finalData{LymphocytesPercent}->{$wbcTime})) {
			my $value = 100 *$finalData{Lymphocytes}->{$wbcTime}->{value} / $wbc ;
			$finalData{LymphocytesPercent}->{$wbcTime} = {value => $value, unit => $signalUnits{LymphocytesPercent}, stayID => $stayId} ;
		} elsif (!exists $finalData{Lymphocytes}->{$wbcTime} and (exists $finalData{LymphocytesPercent}->{$wbcTime})) {
			my $value = $finalData{LymphocytesPercent}->{$wbcTime}->{value} * $wbc / 100 ;
			$finalData{Lymphocytes}->{$wbcTime} = {value => $value, unit => $signalUnits{Lymphocytes}, stayID => $stayId} ;
		}	

#		if (exists $finalData{Reticulocytes}->{$wbcTime} and (!exists $finalData{ReticulocytesPerc}->{$wbcTime})) {
#			my $value = 100 *$finalData{Reticulocytes}->{$wbcTime}->{value} / $wbc ;
#			$finalData{ReticulocytesPerc}->{$wbcTime} = {value => $value, unit => $signalUnits{ReticulocytesPerc}, stayID => $stayId} ;
#		} elsif (!exists $finalData{Reticulocytes}->{$wbcTime} and (exists $finalData{ReticulocytesPerc}->{$wbcTime})) {
#			my $value = $finalData{ReticulocytesPerc}->{$wbcTime}->{value} * $wbc / 100 ;
#			$finalData{Reticulocytes}->{$wbcTime} = {value => $value, unit => $signalUnits{Reticulocytes}, stayID => $stayId} ;
#		}		
	}
	
	foreach my $signalName (keys %finalData) {
		foreach my $time (keys %{$finalData{$signalName}}) {

			my ($stayId,$unit,$value) = map {$finalData{$signalName}->{$time}->{$_}} qw/stayID unit value/ ;			
			# Complete missing stay-ids
			if ($stayId eq "") {
				my $minutes = getMinutes($time) ;
				for my $tempStayId (@stayIds) {
					if ($minutes >= $stays{$tempStayId}->{start} and $minutes <= $stays{$tempStayId}->{end}) {
						$stayId = $tempStayId ;
						last ;
					}
				}
			}
			
			printf OUT "$id\t$stayId\t$signalName\t$value\t$unit\t$time\n" if ($stayId ne "") ;
		}
	}

}