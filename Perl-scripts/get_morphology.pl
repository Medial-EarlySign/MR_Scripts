#!/usr/bin/env perl  

use strict(vars) ;
my @days2month = (0,31,59,90,120,151,181,212,243,273,304,334) ;

# ID-2-NR Mapping
my $id2nr = "W:\\CRC\\THIN_MAR2013\\ID2NR" ;
open (ID,$id2nr) or die "Cannot open $id2nr for reading" ;
my %id2nr ;
my %nr2id ;

while (<ID>) {
	chomp ;
	my ($id,$nr) = split ;
	$id2nr{$id} = $nr ;
	$nr2id{$nr} = $id ;
}
close ID ;

# Cancer Registry
my $registry_file = "W:\\CRC\\AllDataSets\\Registry" ;
open (REG,$registry_file) or die "Cannot open $registry_file for reading" ;

my %luca ;
print STDERR "Reading $registry_file ..." ;
while (<REG>) {
	chomp ;
	my @data = split ",",$_ ;
	my $nr= $data[0] ;
	my ($month,$day,$year) = split "/",$data[5] ;
	$month = "0$month" if (length($month)==1) ;
	$day = "0$day" if (length($day)==1) ;
	my $cancer = "$data[14] $data[15] $data[16]" ;
	my $date = get_days("$year$month$day") ;
	push @{$luca{$nr2id{$nr}}},{date => $date, days => get_days($date)} if (exists $nr2id{$nr} and $cancer eq "Respiratory system Lung and Bronchus Unspecified") ;
#	push @{$luca{$nr2id{$nr}}},{date => $date, days => get_days($date)} if (exists $nr2id{$nr} and $cancer eq "Digestive Organs Digestive Organs Colon") ;
}
print STDERR " Done\n" ;
close REG ;

my @nrs = keys %luca ;

# Med Codes for morphology
my %morph_codes ;
my $morph_file = "W:\\\\CRC\\FullOldTHIN\\thin_cancer_medcodes_info_03jul2013_w_morph.txt" ;
open (MRP,$morph_file) or die "Cannot open $morph_file for reading" ;

my $header = 1 ;
my %cols ;
while (<MRP>) {
	chomp ;
	my @data = split /\t/,$_ ;
	if ($header == 1) {
		map {$cols{$data[$_]} = $_} (0..$#data) ;
		$header = 0 ;
		die "Missing Fields in Header" if (!exists $cols{"Read code"} or !exists $cols{"description"} or !exists $cols{"status"}) ;
	} else {
		$morph_codes{$data[$cols{"Read code"}]} = $data[$cols{"description"}] ; # if ($data[$cols{"status"}] eq "morph") ;
	}
}

close MRP ;
my $nrp = scalar keys %morph_codes ;
print STDERR "Read $nrp morph codes\n" ;

# Read MED file and extract morph codes per lung cancer
my $med_file = "T:\\\\THIN\\EPIC\ 88\\MedialResearch_med.csv" ;

my %morph ;
open (MED,$med_file) or die "Cannot open $med_file for reading" ;


my %work ;
while (<MED>) {
	next if (/pracid/)  ;
	chomp ;
	
	my $id = substr($_,0,5) . substr($_,6,4) ;
	if (exists $luca{$id}) {
		
		my $medcode = substr($_, 32, 7);
		if (exists $morph_codes{$medcode}) {
			my $date = substr($_, 11, 8) ;
			if ($date%10000 != 0) {
				my $days = get_days($date) ;
				my @ids ;
				foreach my $i (0..scalar(@{$luca{$id}})-1) {
					push @ids,$i if (abs($days - $luca{$id}->[$i]->{days}) < 120) ;
				}
				
				if (@ids > 1) {
					print STDERR "Cannot choose cancer for Morphology for $id ($id2nr{$id}) at $date\n" ;
				} else {
					push @{$luca{$id}->[$ids[0]]->{morph}},$morph_codes{$medcode} ;
				}
			}
		}
	}
}

foreach my $id (keys %luca) {
	my $nr = $id2nr{$id} ;
	foreach my $rec (@{$luca{$id}}) {
		my $morph = join "\t",@{$rec->{morph}} ;
		print "$nr\t$rec->{date}\t$morph\n" ;
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
