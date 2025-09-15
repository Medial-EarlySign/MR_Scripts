#!/usr/bin/env perl  
use strict(vars) ;

my @days2month = (0,31,59,90,120,151,181,212,243,273,304,334) ;

# Read Cancer Registry
my $registry_file = "W:\\CRC\\AllDataSets\\Registry" ;
open (REG,$registry_file) or die "Cannot open $registry_file for reading" ;

my %crc ;
print STDERR "Reading $registry_file ..." ;
while (<REG>) {
	chomp ;
	my @data = split ",",$_ ;
	my $id = $data[0] ;
	my ($month,$day,$year) = split "/",$data[5] ;
	my $days = get_days(sprintf("%04d%02d%02d",$year,$month,$day)) ;
	my $cancer = "$data[14] $data[15] $data[16]" ;
	$crc{$id} = $days if (($cancer eq "Digestive Organs Digestive Organs Rectum" or $cancer eq "Digestive Organs Digestive Organs Colon") and 
						  (!exists $crc{$id} or $days < $crc{$id}) and $id<4000000) ;
}
print STDERR " Done\n" ;
close REG ;

# Read FOBT files
my @old_fobt_files = ("C:\\Data\\macabi4\\training.men.occult_bld.csv","C:\\Data\\macabi4\\training.women.occult_bld.csv") ;
my %types = ("חיובי" => 1,
			 "חיובי חלש" => 1,
			 "POSITIVE" => 1,
			 "דם סמוי חיובי" => 1,
			 "שלילי" => 0,
			 "דם סמוי שלילי" => 0,
			 "NEGATIVE" => 0,
			 ) ;
my %fobt ;

foreach my $file (@old_fobt_files) {
	open (FOBT,$file) or die "Cannot open $file for reading" ;
	
	print STDERR "Reading $file ..." ;
	while (<FOBT>) {
		chomp ;
		my ($id,$dummy1,$date,$code,$dummy2,$result) = split ",",$_ ;
		my $day = get_days($date) ;
		$fobt{$id}->{$day}->{n} ++ ;
		my $res = (exists $types{$result}) ? $types{$result} : 0 ;
		$fobt{$id}->{$day}->{npos} += $res ;
	}
	print STDERR " Done\n" ;
	close FOBT ;
}

my $time_win = 90 ;
my $counter = 0 ;
foreach my $id (keys %crc) {
	my $screening = 0 ;
	if (exists $fobt{$id}) {
		foreach my $day (keys %{$fobt{$id}}) {
			if ($day <= $crc{$id} and $day >= $crc{$id}-$time_win and $fobt{$id}->{$day}->{npos} > 0) {
#			if ($day <= $crc{$id} and $day >= $crc{$id}-$time_win) {
				$counter++ ;
				$screening = 1 ;
				last ;
			}
		}
	}
	print "$id\n" if (! $screening) 
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