#!/usr/bin/env perl 
use strict(vars) ;

die "Usage : $0 ScoresFile OutFile" if (@ARGV != 2) ;

my ($mescores,$out) = @ARGV ;
open (OUT,">$out") or die "Cannot open $out for writing" ;

my @days2month = (0,31,59,90,120,151,181,212,243,273,304,334) ;

# Cancer Registry
my $registry_file = "W:\\CRC\\AllDataSets\\Registry" ;
open (REG,$registry_file) or die "Cannot open $registry_file for reading" ;

my (%cancer,%crc) ;
print STDERR "Reading $registry_file ..." ;
while (<REG>) {
	chomp ;
	my @data = split ",",$_ ;
	my $id = $data[0] ;
	$cancer{$id} = 1 ;
	my ($month,$day,$year) = split "/",$data[5] ;
	$month = "0$month" if (length($month)==1) ;
	$day = "0$day" if (length($day)==1) ;
	my $cancer = "$data[14] $data[15] $data[16]" ;
	my $date = get_days("$year$month$day") ;
	$crc{$id} = $date if (($cancer eq "Digestive Organs Digestive Organs Rectum" or $cancer eq "Digestive Organs Digestive Organs Colon") and 
						  (!exists $crc{$id} or $date < $crc{$id})) ;
}
print STDERR " Done\n" ;
close REG ;

# MScores	
my %med ;		
open (MED,$mescores) or die "Cannot open $mescores for reading" ;
	
print STDERR "Reading $mescores ..." ;
my $header = 1 ;
while (<MED>) {
	chomp ;
	if ($header) {
		$header = 0 ;
	} else {
		my ($id,$date,$score,$bin1,$bin2) = split ;
		my $day = get_days($date) ;
		$med{$id}->{$day} = {Bin1 => $bin1, Bin2 => $bin2}; 
	}
}
print STDERR " Done\n" ;
close MED ;

# Odds.
foreach my $type (qw/Bin1 Bin2/) {
	my (%npos,%nneg) ;
	foreach my $id (keys %med) {
		if (! exists $cancer{$id}) {
			my @days = keys %{$med{$id}} ;
			my $idx = int(scalar(@days)*rand()) ;
			$nneg{$med{$id}->{$days[$idx]}->{$type}}++ ;
		} elsif (exists $crc{$id}) {
			my @days = sort {$a<=>$b} keys %{$med{$id}} ;
			my $day = -1 ;
			foreach my $iday (@days) {
				last if ($iday > $crc{$id}) ;
				$day = $iday if ($iday > $crc{$id}-90) ;
			}
			$npos{$med{$id}->{$day}->{$type}}++ if ($day != -1) ;
		}
	}
	
	map {$npos{$_} += 0} keys %nneg ;
	map {$nneg{$_} += 0} keys %npos ;
	
	foreach my $bin (sort {$a<=>$b} keys %nneg) {		
		if ($nneg{$bin} == 0) {
			print OUT "$type :: $bin - INF\nn" ;
		} else {
			printf OUT "$type :: $bin - %.3f\n"  , $npos{$bin}/$nneg{$bin} ;
		}
	}
}

################################################################

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

