#!/usr/bin/env perl 
use strict(vars) ;

my @days2month = (0,31,59,90,120,151,181,212,243,273,304,334) ;
my ($min_age,$max_age) = (50,75) ;

# Cancer Registry
my $registry_file = "W:\\CRC\\AllDataSets\\Registry" ;
open (REG,$registry_file) or die "Cannot open $registry_file for reading" ;

my %cancer_days ;
print STDERR "Reading Registry ... " ;
while (<REG>) {
	chomp ;
	my @data = split ",",$_ ;
	my $id = $data[0] ;
	my ($month,$day,$year) = split "/",$data[5] ;
	$month = "0$month" if (length($month)==1) ;
	$day = "0$day" if (length($day)==1) ;
	my $date = get_days("$year$month$day") ;
	$cancer_days{$id} = $date if (!exists $cancer_days{$id} or $cancer_days{$id} >  $date) ;
}
print STDERR " Done\n" ;
close REG ;

# Read Demography + Status
my @files = ("T:\\macabi4\\men_demography\\men_demography_unfiltered_26-6-11.csv","T:\\macabi4\\women_demography\\women_demography_unfiltered_26-6-11.csv") ;

my %byear ;
foreach my $file (@files) {
	open (CSR,$file) or die "Cannot open $file for reading" ;

	print STDERR "Reading $file ..." ;
	while (<CSR>) {
		chomp ;
		my ($id,$byear) = split ",",$_ ;
		$byear{$id} = $byear ;
	}
	print STDERR " Done\n" ;	
	close CSR ;
}

# Read FOBT files
my @old_fobt_files = ("T:\\macabi4\\training.men.occult_bld.csv","T:\\macabi4\\training.women.occult_bld.csv") ;
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
		my $age = int($date/10000) - $byear{$id} ;
		next if ($age > $max_age or $age < $min_age) ;
		
		my $day = get_days($date) ;
		next if (exists $cancer_days{$id} and $day > $cancer_days{$id}) ;
		
		if (exists $types{$result}) {
			$fobt{$id}->{$day}->{n} ++ ;
			$fobt{$id}->{$day}->{npos} += $types{$result} ;
		}

	}
	print STDERR " Done\n" ;
	close FOBT ;
}

my $nids = scalar keys %fobt ;
print STDERR "N(FOBT Ids) = $nids\n" ;

# Read MeScores	
my %med ;		
	
print STDERR "Reading MeScores ..." ;
while (<>) {
	chomp ;
	next if (/Combine/) ;
	my ($id,$date,$score) = split ;
	my $day = get_days($date) ;
	$med{$id}->{$day} = $score ;
}
print STDERR " Done\n" ;

$nids = scalar keys %med ;
print STDERR "N(MED Ids) = $nids\n" ;

# Check Performance
foreach my $range (30,60,90,120,180) {
	print STDERR "Checking performance up to $range days before FOBT\n" ;

	my @preds ;
	foreach my $id (keys %fobt) {
		next unless (exists $med{$id}) ;

		my @days = sort {$a<=>$b} keys %{$fobt{$id}} ;
		for my $i (0..$#days) {
			next if (($i>0 and $days[$i]-$days[$i-1] < $range) or ($i<$#days and $days[$i+1]-$days[$i] < $range)) ;
			next unless ($fobt{$id}->{$days[$i]}->{n} == 3) ;
			
			my $meday = -1 ;
			foreach my $day (sort {$a<=>$b} keys %{$med{$id}}) {
				next if ($day > $days[$i]) ;
				$meday = $day if ($day >= $days[$i] - $range) ;
			}
			
			next if ($meday==-1) ;	
			push @preds,[$med{$id}->{$meday},$fobt{$id}->{$days[$i]}->{npos}] ;
		}
		
		my $npreds = scalar @preds ;
	}
		
		
	for my $level (1..3) {
		print STDERR "Checking pos-level $level\n" ;
		my (@neg,@pos) ;
		foreach my $pred (@preds) {
			if ($pred->[1] == 0) {
				push @neg,$pred->[0] ;
			} elsif ($pred->[1] >= $level) {
				push @pos,$pred->[0] ;
			}
		}

		my ($nneg,$npos) = (scalar(@neg),scalar(@pos)) ;
		die "NNeg=$nneg ; NPOS=$npos" unless ($nneg and $npos) ;
		my @sneg = sort {$b<=>$a} @neg ;
		
		for my $fpr (1,2.5,3.5,5,10) {
			print STDERR "Checking FPR $fpr\n" ;
			my $fp = int($nneg * $fpr/100) ;
			my $bound = @sneg[$fp] ;
			my $tp = grep {$_>=$bound} @pos ;
			$fp++ while ($fp < $nneg-1 and $sneg[$fp+1]==$bound) ;
			my $lift = ($tp/($tp+$fp))/($npos/($npos+$nneg)) ;
			printf "Range $range Level $level FPR $fpr : Pos = $tp / $npos Neg = $fp / $nneg => Lift = %.2f\n",$lift ;
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
