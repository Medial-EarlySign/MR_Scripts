#!/usr/bin/env perl 

use strict(vars) ;

my %items = (50091 => 1) ;

my @days2month = (0,31,59,90,120,151,181,212,243,273,304,334) ;
my %stats ;

# Get Care Unit Per Time
open (CE,"w:/Users/Yaron/ICU/Mimic/ParseData/CENSUSEVENTS") or die "Cannot open CENSUSEVENTS File" ;

my %careUnits ;
while (<CE>) {
	next if (/SUBJECT_ID/) ;
	
	chomp ;
	my @data = split /\,/,$_ ;
	
	my ($id,$inTime,$outTime,$careUnit) = map {$data[$_]} (0,2,3,4) ;
	push @{$careUnits{$id}},{in=>getMinutes1($inTime), out=>getMinutes1($outTime), unit=>$careUnit} ;
}
close CE ;
print STDERR "Done reading events\n" ;

open (CRP,"w:/Users/Yaron/ICU/Mimic/ParseData/ProcessedCRP") or die "Cannot open ProcessedCRP File" ;

my %moments ;
while (<CRP>) {
	
	chomp ;
	my ($id,$stayId, $item,$value,$unit,$time) = split /\t/,$_ ;

	if (exists $careUnits{$id}) {
		$time = getMinutes2($time) ;
		my %itemCareUnits ;
		foreach my $event (@{$careUnits{$id}}) {
			$itemCareUnits{$event->{unit}} = 1 if ($time >= $event->{in} and $time <= $event->{out}) ;
		}
		
		my @careUnits = keys %itemCareUnits ;
		if (@careUnits == 1) {
			$moments{$careUnits[0]}->{n} ++ ;
			$moments{$careUnits[0]}->{s} += $value ;
			$moments{$careUnits[0]}->{s2} += $value*$value ;
		}
	}
}
close CRP ;
		
foreach my $careUnit (keys %moments) {
	my ($n,$s,$s2) = map {$moments{$careUnit}->{$_}} qw/n s s2/ ;
	my $mean = $s/$n ;
	my $sdv = sqrt(($s2-$mean*$s)/($n-1)) ;
	print "$careUnit\t$n\t$mean\t$sdv\n" ;
}
	
	
# FUNCTIONS
sub getMinutes1 {
	my ($inTime) = @_ ;
	$inTime =~ /(\d\d\d\d)-(\d\d)-(\d\d) (\d\d):(\d\d):(\d\d)/ or die "Cannot parse time $inTime" ;
	my ($year,$month,$day,$hour,$minute,$second) = ($1,$2,$3,$4,$5,$6) ;
	
	my $days = 365 * ($year-2500) ;
	$days += int(($year-2497)/4) ;
	$days -= int(($year-2401)/100);

	$days += $days2month[$month-1] ;
	$days ++ if ($month>2 && ($year%4)==0 && (($year%100)!=0 || ($year%400)==0)) ;

	$days += ($day-1) ;
	return ($days*24*60) + ($hour*60) + $minute + ($second/60) ;
}

sub getMinutes2 {
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