#!/usr/bin/env perl 
use strict(vars) ;

die "Usage : $0 ScoresFile OutFile" if (@ARGV != 2) ;

my ($mescores,$out) = @ARGV ;
open (OUT,">$out") or die "Cannot open $out for writing" ;

my @days2month = (0,31,59,90,120,151,181,212,243,273,304,334) ;

# All FOBT files
my @old_fobt_files = ("\\\\server\\Data\\macabi4\\training.men.occult_bld.csv","\\\\server\\Data\\macabi4\\training.women.occult_bld.csv") ;
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
		push @{$med{Bin1}->{$bin1}->{$id}},$day;
		push @{$med{Bin2}->{$bin2}->{$id}},$day;	 
	}
}
print STDERR " Done\n" ;
close MED ;

# Odds.
foreach my $type (qw/Bin1 Bin2/) {
	for my $bin (sort {$a<=>$b} keys %{$med{$type}}) {
		my ($npos,$nneg) = (0,0) ;
		foreach my $id (keys %{$med{$type}->{$bin}}) {
			foreach my $day (@{$med{$type}->{$bin}->{$id}}) {
				if (exists $fobt{$id}) {
					my @days = grep {abs($_-$day)<=30} keys %{$fobt{$id}} ;
					if (@days == 1) {
						if ($fobt{$id}->{$days[0]}->{npos} > 0) {
							$npos ++ ;
						} else {
							$nneg ++ ;
						}
					}
				}
			}
		}
		
		if ($nneg == 0) {
			print OUT "$type :: $bin - INF\nn" ;
		} else {
			printf OUT "$type :: $bin - %.3f\n"  , $npos/$nneg ;
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

