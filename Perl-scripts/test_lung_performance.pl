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

# Check
for my $year (2007..2010) {
	my $sorted_medial = get_medial_ids($year,74) ;
	my $n_all = scalar @$sorted_medial ;
	print STDERR "N(ALL) at $year = $n_all\n" ;
	
	my $nlst1_ids = get_ids($year,55,74,30,15) ;
	my $n_nlst1 = scalar keys %$nlst1_ids ;
	print STDERR "N(NLST1) at $year = $n_nlst1\n" ;
	
	my $nlst2_ids = get_ids($year,50,74,20,100) ;
	my $n_nlst2 = scalar keys %$nlst2_ids ;
	print STDERR "N(NLST2) at $year = $n_nlst2\n" ;

	my @sorted_nlst2_medial = grep {exists $nlst2_ids->{$_->{id}}} @$sorted_medial ;
	
	my %medial1_ids = map {($sorted_medial->[$_]->{id} => 1)} (0..($n_nlst1-1)) ;
	my %medial2_ids = map {($sorted_medial->[$_]->{id} => 1)} (0..($n_nlst2-1)) ;
	my %medial_nlst2_to_1_ids = map {($sorted_nlst2_medial[$_]->{id} => 1)} (0..($n_nlst1-1)) ;
	
	foreach my $fmonths (3,6,9,12,18,24) {
		my ($sens,$ppv) = get_moments($year,$fmonths,$nlst1_ids) ;
		printf "$fmonths-months NLST1 sensitivity at $year = %f ; PPV = %f\n",$sens,$ppv ;
		
		my ($sens,$ppv) = get_moments($year,$fmonths,$nlst2_ids) ;
		printf "$fmonths-months NLST2 sensitivity at $year = %f ; PPV = %f\n",$sens,$ppv ;
		
		my ($sens,$ppv) = get_moments($year,$fmonths,\%medial1_ids) ;
		printf "$fmonths-months Medial1 sensitivity at $year = %f ; PPV = %f\n",$sens,$ppv ;
		
		my ($sens,$ppv) = get_moments($year,$fmonths,\%medial2_ids) ;
		printf "$fmonths-months Medial2 sensitivity at $year = %f ; PPV = %f\n",$sens,$ppv ;
		
		my ($sens,$ppv) = get_moments($year,$fmonths,\%medial_nlst2_to_1_ids) ;
		printf "$fmonths-months Medial1_on_2 sensitivity at $year = %f ; PPV = %f\n",$sens,$ppv ;
	}
}

################################################################
sub get_moments {
	
	my ($year,$fmonths,$ids) = @_ ;
	
	my $nids = scalar (grep {exists $mescores{$year}->{$_}} keys %$ids) ;
	
	my $first_month = $year*100 + 01 ;
	my $last_month = sprintf("%04d%02d",$year + int($fmonths/12) ,(1+$fmonths%12)) ;
	
	my ($n,$tp) = (0,0,0) ;
	foreach my $id (keys %registry) {
		next if (!exists $mescores{$year}->{$id}) ;
		
		for my $rec (@{$registry{$id}}) {
			my $type = $rec->{type} ;
			my $cmonth = int ($rec->{date} / 100) ;
			if ($type eq "Respiratory system,Lung and Bronchus,Unspecified" and $cmonth >= $first_month and $cmonth <= $last_month) {
				$n++ ;
				$tp ++ if (exists $ids->{$id}) ;
				last ;
			}
		}
	}
	
#	print STDERR "$nids // $n // $tp\n" ;
	my $sens = 100*$tp/$n ;
	my $ppv = 100*$tp/(scalar keys %$ids) ;
	
	return ($sens,$ppv) ;
}

sub get_medial_ids {

	my ($year,$max_age) = @_ ;
	
	my @candidates ;
	foreach my $id (keys %{$mescores{$year}}) {
	
		my $age = $year - $demographics{$id}->{byear} ;
		next if ($age > $max_age); 
		
		push @candidates,{id => $id, score => $mescores{$year}->{$id}->{score}} ;
	}
	
	my @sorted = sort {$b->{score} <=> $a->{score}} @candidates ;
	return \@sorted ;
	
	
}

sub get_ids {

	my ($year,$min_age,$max_age,$min_pack_years,$max_time_since_quitting) = @_ ;
	
	my %ids ;
	foreach my $id (keys %smx_info) {
		next if (! exists $mescores{$year}->{$id}) ;
		
		next if ($smx_info{$id}->{start} == -1) ;
		next if ($year - $smx_info{$id}->{end} > $max_time_since_quitting) ;
		
		my $age = $year - $demographics{$id}->{byear} ;
		next if ($age < $min_age or $age > $max_age); 
		
		my $pack_years = ($smx_info{$id}->{end} + 1 - $smx_info{$id}->{start})*$smx_info{$id}->{cigs}/20 ;
		next if ($pack_years < $min_pack_years) ;
		
		$ids{$id} = 1 ;
	}
	
	return \%ids ;
}
		
	
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
		my $year = int ($date/10000) ;
		$mescores{$year}->{$id} = {date => $date, score => $score} if (!exists $mescores{$year}->{$id} or $date > $mescores{$year}->{$id}->{date}) ;
	}
	close IN ;
	
	foreach my $year (sort {$a<=>$b} keys %mescores) {
		my $n = scalar keys %{$mescores{$year}} ;
		print STDERR "# of Ids with scores at $year = $n\n" ;
	}
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