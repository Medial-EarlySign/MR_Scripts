#!/usr/bin/env perl 
my @days2month = (0,31,59,90,120,151,181,212,243,273,304,334) ;
my ($year,$month,$day,$hour,$minute,$second) ;
while (my $inTime = <>) {

	$inTime =~ s/://g ;
	$inTime =~ s/-//g ;
	$inTime =~ s/ //g ;
	
	if ($inTime =~ /(\d\d\d\d)(\d\d)(\d\d)(\d\d)(\d\d)(\d\d)/ or $inTime =~ /(\d\d\d\d)\-(\d\d)\-(\d\d) (\d\d):(\d\d):(\d\d)/) {
		($year,$month,$day,$hour,$minute,$second) = ($1,$2,$3,$4,$5,$6) ;
	} elsif ($inTime =~ /(\d\d\d\d)(\d\d)(\d\d)/) {
		print STDERR "$inTime $1 $2 $3 2\n" ;	
		($year,$month,$day,$hour,$minute,$second) = ($1,$2,$3,0,0,0) ;
	} else {
		die "$inTime ??" ;
	}
	
	my $days = 365 * ($year-2500) ;
	$days += int(($year-2497)/4) ;
	$days -= int(($year-2401)/100);

	$days += $days2month[$month-1] ;
	$days ++ if ($month>2 && ($year%4)==0 && (($year%100)!=0 || ($year%400)==0)) ;

	$days += ($day-1) ;

	$minute ++ if ($second > 30) ;

	my $minutes =  ($days*24*60) + ($hour*60) + $minute ;
	print "$minutes\n" ;
}