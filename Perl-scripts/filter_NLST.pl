#!/usr/bin/env perl 

use strict(vars);
use Getopt::Long;
use FileHandle;

my @days2month = (0,31,59,90,120,151,181,212,243,273,304,334) ;
my (%registry,%smx_info,%demographics,%mescores) ;

my $p = {
	smx_file => "W:/LUCA/THIN_MAR2014/Smoking/qtySmx.txt",
	reg_file => "W:/CancerData/AncillaryFiles/Registry",
	dem_file => "W:/CancerData/AncillaryFiles/Demographics",
	};
	
GetOptions($p,
	"smx_file=s",		# Qualitative Smoking File
	"reg_file=s",		# Registry File
	"scr_file=s",		# Scores File
	"dem_file=s",		# Demographics File
	);
	
print STDERR "Command line: $0 " . join(" ", @ARGV) . "\n";	
print STDERR "Parameters: " . join(", ", map {"$_ => $p->{$_}"} sort keys %$p) . "\n";

map {die "Missing required argument $_" unless (defined $p->{$_})} qw/scr_file smx_file reg_file dem_file/ ;

# Read 
read_scores($p->{scr_file}) ; print STDERR "Read Scores\n" ;
read_smx($p->{smx_file}) ; print STDERR "Read Smx Information\n" ;
read_registry($p->{reg_file}) ; print STDERR "Read Registry\n" ;
read_demographics($p->{dem_file}) ; print STDERR "Read Demographics\n" ;


open (OUT1,">$p->{scr_file}.NLST1") or die "Cannot open NLST1 output\n" ;
foreach my $id (keys %mescores) {
	next if ($smx_info{$id}->{start} == -1) ;

	foreach my $date (keys %{$mescores{$id}}) {
		my $year = int ($date/10000) ;
		next if ($year - $smx_info{$id}->{end} > 15) ;

		my $age = $year - $demographics{$id}->{byear} ;
		next if ($age < 55 or $age > 75); 

		my $pack_years = ($smx_info{$id}->{end} + 1 - $smx_info{$id}->{start})*$smx_info{$id}->{cigs}/20 ;
		next if ($pack_years < 30) ;

		print OUT1 "$id $date $mescores{$id}->{$date} 0 0\n" ;
	}
}
close OUT1 ;

open (OUT2,">$p->{scr_file}.NLST2") or die "Cannot open NLST2 output\n" ;
foreach my $id (keys %mescores) {
	next if ($smx_info{$id}->{start} == -1) ;

	foreach my $date (keys %{$mescores{$id}}) {
		my $year = int ($date/10000) ;
		
		my $age = $year - $demographics{$id}->{byear} ;
		next if ($age < 50 or $age > 75); 

		my $pack_years = ($smx_info{$id}->{end} + 1 - $smx_info{$id}->{start})*$smx_info{$id}->{cigs}/20 ;
		next if ($pack_years < 20) ;

		print OUT2 "$id $date $mescores{$id}->{$date} 0 0\n" ;
	}
}
close OUT1 ;

################################################################

	
sub read_registry {
	
	my ($file) = @_ ;
	
	open (IN,$file) or die "Cannot open $file for reading" ;
	while (<IN>) {
		chomp ;
		my ($id,$date,$type) = split /\t/,$_ ;
		
		push @{$registry{$id}},{date => $date, type => $type} ;
	}
	close IN ;
}

sub read_smx {

	my ($file) = @_ ;
	
	open (IN,$file) or die "Cannot open $file for reading" ;
	while (<IN>) {
		chomp ;
		my ($id,$start,$end,$cigs) = split /\t/,$_ ;
		
		$smx_info{$id} = {start => $start, end => $end, cigs => $cigs} ;
	}
	close IN ;
}

sub read_scores {

	my ($file) = @_ ;
	
	open (IN,$file) or die "Cannot open $file for reading" ;
	while (<IN>) {
		chomp ;
		my ($id,$date,$score) = split ;
		$mescores{$id}->{$date} = $score ;
	}
	close IN ;
}

sub read_demographics {

	my ($file) = @_ ;
	
	open (IN,$file) or die "Cannot open $file for reading" ;
	while (<IN>) {
		chomp ;
		my ($id,$byear,$gender) = split ;
		
		$demographics{$id} = {byear => $byear, gender => $gender} ;
	}
	close IN ;
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