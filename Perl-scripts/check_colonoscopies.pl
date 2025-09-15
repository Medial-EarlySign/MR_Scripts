#!/usr/bin/env perl 
use strict(vars);

my @days2month = (0,31,59,90,120,151,181,212,243,273,304,334) ;

# Read Registry
my $registry_file = "W:\\CRC\\AllDataSets\\Registry" ;
open (REG,$registry_file) or die "Cannot open $registry_file for reading" ;

my %crc ;
print STDERR "Reading $registry_file ..." ;
while (<REG>) {
	chomp ;
	my @data = split ",",$_ ;
	my $id = $data[0] ;
	my ($month,$day,$year) = split "/",$data[5] ;
	$month = "0$month" if (length($month)==1) ;
	$day = "0$day" if (length($day)==1) ;
	my $cancer = "$data[14] $data[15] $data[16]" ;
	push @{$crc{$id}},get_days("$year$month$day") if ($cancer eq "Digestive Organs Digestive Organs Rectum" or $cancer eq "Digestive Organs Digestive Organs Colon") ;
}
print STDERR " Done\n" ;
close REG ;

# Read Byears
my $byears_file = "W:\\CRC\\AllDataSets\\Byears" ;
open (BYR,$byears_file) or die "Cannot open $byears_file for reading" ;

my %byear ;
my %byear_ids ;
print STDERR "Reading $byears_file ..." ;
while (<BYR>) {
	chomp ;
	my ($id,$byear) = split ;
	next if ($id > 4000000 or $byear < 1900) ;
	
	$byear{$id} = $byear ;
	push @{$byear_ids{$byear}},$id ;
}
print STDERR " Done\n" ;
close BYR ;

# Read colonscopies
my $col_file = "T:\\macabi4\\Colonoscopies\\colonoscopies_22-12-11.csv" ;
open (COL,$col_file) or die "Cannot open $col_file for reading" ;

my %cols ;
print STDERR "Reading $col_file ..." ;
while (<COL>) {
	chomp ;
	my @data = split ",",$_ ;
	my $id = $data[0] ;
	next if (!exists $byear{$id}) ;
	my $date = 19000000 + $data[4] ;
	push @{$cols{$id}},get_days($date) ;
}
print STDERR " Done\n" ;
close COL ;

# Single Colonscopy; No cancer up to 2 years after; check one-year CRC rate up to end of 2010
my $last_allowed = get_days(20101230) - 3*365 ;

my %col_samples ;
my %all_ids ;
foreach my $id (keys %cols) {
	next if (scalar @{$cols{$id}} > 1) ;
	my $col_day = $cols{$id}->[0] ;
	next if ($col_day > $last_allowed) ;
		
		
	my $crc_exclude = 0 ;
	if (exists $crc{$id}) {
		foreach my $crc_day (@{$crc{$id}}) {
			if ($crc_day < $col_day + 2*365) {
				$crc_exclude = 1;
				last ;
			}
		}
	}
	next if ($crc_exclude) ;

	my $crc_status = 0 ;
	if (exists $crc{$id}) {
		foreach my $crc_day  (@{$crc{$id}}) {
			if ($crc_day < $col_day + 3*365) {
				$crc_status = 1;
				last ;
			}
		}
	}
	push @{$col_samples{$crc_status}},$id ;
	$all_ids{$id} = 1 ;
	print "$id\n" ;
}

my ($npos,$nneg) = (scalar(@{$col_samples{1}}),scalar(@{$col_samples{0}})) ;
print STDERR "COL : $npos Pos and $nneg Neg\n" ;

# Take matched controls
my $ratio = 1 ;
my %selected ;
my %control_samples ;
my $nall = $npos+$nneg ;

my $nn = 0 ;
foreach my $id (keys %all_ids) {
	print STDERR "Matching for $nn/$nall..." if ($nn%5000 == 1) ;
	my $byear = $byear{$id} ;
	my $col_day = $cols{$id}->[0] ;
	
	my $n = 0 ;
	foreach my $new_id (@{$byear_ids{$byear}}) {
		next if (exists $all_ids{$new_id} or exists $selected{$new_id}) ;
		
		my $crc_exclude = 0 ;
		if (exists $crc{$new_id}) {
			foreach my $crc_day (@{$crc{$new_id}}) {
				if ($crc_day < $col_day + 2*365) {
					$crc_exclude = 1;
					last ;
				}
			}
		}
		next if ($crc_exclude) ;
		
		my $crc_status = 0 ;
		if (exists $crc{$new_id}) {
			foreach my $crc_day  (@{$crc{$new_id}}) {
				if ($crc_day < $col_day + 3*365) {
					$crc_status = 1;
					last ;
				}
			}
		}
		
		push @{$control_samples{$crc_status}},$id ;
		$selected{$new_id} = 1 ;
		$n++ ;

		last if ($n==$ratio) ;
	}

	die "Cannot match to $id (N=$n)" if ($n!=$ratio) ;
	$nn++ ;
}
	
my ($npos,$nneg) = (scalar(@{$control_samples{1}}),scalar(@{$control_samples{0}})) ;
print STDERR "Control : $npos Pos and $nneg Neg\n" ;	
	
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