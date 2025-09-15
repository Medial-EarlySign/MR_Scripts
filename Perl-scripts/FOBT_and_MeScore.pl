#!/usr/bin/env perl 
use strict(vars) ;

my @days2month = (0,31,59,90,120,151,181,212,243,273,304,334) ;
my ($min_age,$max_age) = (50,75) ;
my ($min_year,$max_year) = (2008,2009) ;

# Cancer Registry
my $registry_file = "W:\\CRC\\AllDataSets\\Registry" ;
open (REG,$registry_file) or die "Cannot open $registry_file for reading" ;

my (%cancer,%crc) ;
print STDERR "Reading $registry_file ..." ;
while (<REG>) {
	chomp ;
	my @data = split ",",$_ ;
	my $id = $data[0] ;
	$cancer{$id} =1 ;
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

# Read Demography + Status
my @files = ("T:\\macabi4\\men_demography\\men_demography_unfiltered_26-6-11.csv","T:\\macabi4\\women_demography\\women_demography_unfiltered_26-6-11.csv") ;

my %good ;
my %gender ;
my $ntotal = 0 ;
foreach my $file (@files) {
	open (CSR,$file) or die "Cannot open $file for reading" ;

	print STDERR "Reading $file ..." ;
	while (<CSR>) {
		chomp ;
		my ($id,$byear,$gender,$dummy,$stat,$reason,$date) = split ",",$_ ;
		$ntotal ++ ;
		$good{$id} = 1 if ($byear < $min_year-$min_age and $byear > $min_year-$max_age and 
							($crc{$id} or ($stat==1 and $date < $min_year*10000) or ($stat==2 and $date > ($max_year+1)*10000))) ;
		$gender{$id} = ($gender eq "ז") ? "Male" : "Female" ;
	}
	print STDERR " Done\n" ;	
	close CSR ;
}

# All FOBT files
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
		if ($good{$id} and $date > $min_year*10000 and $date < ($max_year+1)*10000) {
			my $day = get_days($date) ;
			if (!exists $crc{$id} or $day < $crc{$id}) {
				$fobt{$id}->{$day}->{n} ++ ;
				my $res = (exists $types{$result}) ? $types{$result} : 0 ;
				$fobt{$id}->{$day}->{npos} += $res ;
			}
		}
	}
	print STDERR " Done\n" ;
	close FOBT ;
}

# MScores
		
my %med ;		
	
print STDERR "Reading MeScores ..." ;
while (<>) {
	chomp ;
	next if (/Combine/) ;
	my ($id,$date,$score) = split ;
	if ($good{$id} and $date > $min_year*10000 and $date < ($max_year+1)*10000) {
		my $day = get_days($date) ;
		$med{$id}->{$day} = $score if (!exists $crc{$id} or $day < $crc{$id}) ;
	}		 
}
print STDERR " Done\n" ;

#map {print "$_\n" if (!exists $med{$_})} keys %good ;
#exit 0 ;

# Count
my %summary ;
print STDERR "Uncensored population, aged $min_age - $max_age at $min_year (up to $max_year) : \n" ;
my $min_date = get_days($min_year*10000); 
foreach my $gender (qw/Male Female ale/) {
	my $ngood = 0.8 * (scalar (grep {$gender{$_} =~ $gender} keys %good)) ;
	my $nfobt = scalar (grep {$gender{$_}  =~ $gender} keys %fobt) ;
	my $npos_fobt = scalar (grep {$gender{$_}  =~ $gender} keys %med) ;
	my $nmed = scalar (grep {$gender{$_}  =~ $gender} keys %med) ;
#	printf "$gender : $ngood available, $nfobt performed FOBT in $min_year-$max_year (%.2f) ; $nmed have MeScore in $min_year-$max_year (%.2f)\n",
#					100*$nfobt/$ngood,100*$nmed/$ngood ;
	$summary{TOTAL}->{$gender} = int ($ngood + 0.5) ;
	$summary{FOBT}->{$gender} = $nfobt ;
	$summary{CBC}->{$gender} = $nmed ;
		
	my ($npos,$ntpos,$nfobt) = (0,0) ;
	my (%fobt_ids,%med_ids,%fobt_pos_ids,%med_pos_ids1,%med_pos_ids2) ;
	my (%fobt_pscore,%med_pscore1,%med_pscore2) ;
	my @mscores ;
	
	# All Cancers
	my $nall_crc = 0 ;
	foreach my $id (keys %good) {
		if ($gender{$id}  =~ $gender) {
			my $day = -1 ;
			if (exists $fobt{$id}) {
				my @days = sort {$b <=> $a} keys %{$fobt{$id}} ;
				$day = $days[0] ;	
			}
		
			if (exists $med{$id}) {
				my @days = sort {$b <=> $a} keys %{$med{$id}} ;
				$day = $days[0] if ($days[0] > $day) ;
			}
		
			$nall_crc ++ if (exists $crc{$id} and $crc{$id} > $min_date and ($day==-1 or $crc{$id} <= $day+730)) ;
		}
	}
#	print STDERR "$gender - ALL CRC : $nall_crc\n" ;
	$summary{CRC}->{$gender} = $nall_crc ;
		
	foreach my $id (grep {$gender{$_}  =~ $gender} keys %fobt) {
		my @days = sort {$b <=> $a} keys %{$fobt{$id}} ;
		my $day = $days[0] ;
		$nfobt++ ;
		if ($fobt{$id}->{$day}->{npos} > 0) {
			$npos ++ ;
			$fobt_pscore{$id} = 1 ;
			if (exists $crc{$id} and $crc{$id}-$day <= 730) {
				$ntpos ++ ;
				$fobt_pos_ids{$id} = 1 ;
			}
		}
		
		$fobt_ids{$id} = 1 ;
	}
		
#	printf "$gender - FOBT : TP = $ntpos ; P = $npos => tpr = %.2f\n",100*$ntpos/$npos ;
	$summary{"FOBT-P"}->{$gender} = $npos ;
	$summary{"FOBT-TP"}->{$gender} = $ntpos ;
	
	foreach my $id (grep {$gender{$_} =~ $gender} keys %med) {
		my @days = sort {$b <=> $a} keys %{$med{$id}} ;
		my $day = $days[0] ;
		
		push @mscores,{day => $day, id => $id, score => $med{$id}->{$day}} ;
		$med_ids{$id} = 1 ;
	}
	
	my $nfobt_ids = scalar keys %fobt_ids ;
	my $nmed_ids = scalar keys %med_ids ;
	my $ncommon_ids = scalar grep {exists $med_ids{$_}} keys %fobt_ids ;
	my $nbefore ;
	foreach my $id (keys %fobt_ids) {
		if (exists $med_ids{$id}) {
			my @days = sort {$b <=> $a} keys %{$fobt{$id}} ;
			my $day = $days[0] ; 
			foreach my $med_day (keys %{$med{$id}}) {
				if ($med_day < $day) {
					$nbefore ++ ;
				last ;
				}
			}
		}
	}
		
#	print "$gender : FOBT = $nfobt_ids ; MED = $nmed_ids ; Common = $ncommon_ids ; MED before FOBT = $nbefore\n" ;
	$summary{"CBC-and-FOBT"}->{$gender} = $ncommon_ids ;
	$summary{"CBC-before-FOBT"}->{$gender} = $nbefore ;
	
	my @scores = sort {$b->{score} <=> $a->{score}} @mscores ;
	$ntpos = 0 ;
	for my $i (0..$npos) {
		my $id = $scores[$i]->{id} ;
		my $day = $scores[$i]->{day} ;
		$med_pscore1{$id} = 1 ;
		if (exists $crc{$id} and $crc{$id}-$day <= 730) {
			$ntpos ++ ;
			$med_pos_ids1{$id} = 1 ;
		}
	}
	
#	printf "$gender - MeScore : TP = $ntpos ; P = $npos => tpr = %.2f\n",100*$ntpos/$npos ;
	$summary{"MeScore1-P"}->{$gender} = $npos ;
	$summary{"MeScore1-TP"}->{$gender} = $ntpos ;
	
	$nfobt_ids = scalar keys %fobt_pos_ids ;
	$nmed_ids = scalar keys %med_pos_ids1 ;
	$ncommon_ids = scalar grep {exists $med_pos_ids1{$_}} keys %fobt_pos_ids ;
#	print "$gender CRC - : FOBT = $nfobt_ids ; MED = $nmed_ids ; Common = $ncommon_ids\n" ;
	$summary{"MeScore1-and-FOBT-TP"}->{$gender}  = $ncommon_ids ;
	$summary{"MeScore1-and-FOBT-combined_detection"}->{$gender} = $nfobt_ids + $nmed_ids - $ncommon_ids ;
	$ncommon_ids = scalar grep {exists $med_pos_ids1{$_}} keys %fobt_ids ;
	$summary{"MeScore1-TP-and-FOBT"}->{$gender} = $ncommon_ids ;
	
	$nfobt_ids = scalar keys %fobt_pscore ;
	$nmed_ids = scalar keys %med_pscore1 ;
	$ncommon_ids = scalar grep {exists $med_pscore1{$_}} keys %fobt_pscore ;
#	print "$gender COLONOSCOPY - : FOBT = $nfobt_ids ; MED = $nmed_ids ; Common = $ncommon_ids\n" ;
	$summary{"MeScore1-and-FOBT-P"}->{$gender}  = $ncommon_ids ;
	$summary{"MeScore1-and-FOBT-combined_colonscopies"}->{$gender} = $nfobt_ids + $nmed_ids - $ncommon_ids ;
	
	$npos = int (0.5 + $npos * (scalar @scores) / $nfobt) ;
	$ntpos = 0 ;
	for my $i (0..$npos) {
		my $id = $scores[$i]->{id} ;
		my $day = $scores[$i]->{day} ;
		$med_pscore2{$id} = 1 ;
		if (exists $crc{$id} and $crc{$id}-$day <= 730) {
			$ntpos ++ ;
			$med_pos_ids2{$id} = 1 ;
		}
	}
#	printf "$gender - MeScore : TP = $ntpos ; P = $npos => tpr = %.2f\n",100*$ntpos/$npos ;
	$summary{"MeScore2-P"}->{$gender} = $npos ;
	$summary{"MeScore2-TP"}->{$gender} = $ntpos ;

	$nfobt_ids = scalar keys %fobt_pos_ids ;
	$nmed_ids = scalar keys %med_pos_ids2 ;
	$ncommon_ids = scalar grep {exists $med_pos_ids2{$_}} keys %fobt_pos_ids ;
#	print "$gender CRC - : FOBT = $nfobt_ids ; MED = $nmed_ids ; Common = $ncommon_ids\n" ;
	$summary{"MeScore2-and-FOBT-TP"}->{$gender}  = $ncommon_ids ;
	$summary{"MeScore2-and-FOBT-combined_detection"}->{$gender} = $nfobt_ids + $nmed_ids - $ncommon_ids ;
	$ncommon_ids = scalar grep {exists $med_pos_ids2{$_}} keys %fobt_ids ;
	$summary{"MeScore2-TP-and-FOBT"}->{$gender} = $ncommon_ids ;
	
	$nfobt_ids = scalar keys %fobt_pscore ;
	$nmed_ids = scalar keys %med_pscore2 ;
	$ncommon_ids = scalar grep {exists $med_pscore2{$_}} keys %fobt_pscore ;
#	print "$gender COLONOSCOPY - : FOBT = $nfobt_ids ; MED = $nmed_ids ; Common = $ncommon_ids\n" ;
	$summary{"MeScore2-and-FOBT-P"}->{$gender}  = $ncommon_ids ;
	$summary{"MeScore2-and-FOBT-combined_colonscopies"}->{$gender} = $nfobt_ids + $nmed_ids - $ncommon_ids ;
}

my @gs = qw/Female Male ale/ ;
print "\tFemale\tMale\tAll\n" ;
print "TOTAL" ; map {print "\t".$summary{TOTAL}->{$_}} @gs ; print "\n" ;
print "FOBT" ; map {printf"\t%d (%.0f%%)",$summary{FOBT}->{$_},100*$summary{FOBT}->{$_}/$summary{TOTAL}->{$_}} @gs ; print "\n" ;
print "CBC" ; map {printf"\t%d (%.0f%%)",$summary{CBC}->{$_},100*$summary{CBC}->{$_}/$summary{TOTAL}->{$_}} @gs ; print "\n" ;
print "CBC and FOBT" ; map {printf"\t%d (%.0f%% of FOBT)",$summary{"CBC-and-FOBT"}->{$_},100*$summary{"CBC-and-FOBT"}->{$_}/$summary{FOBT}->{$_}} @gs ; print "\n" ;
print "CBC before FOBT" ; map {printf"\t%d (%.0f%% of FOBT)",$summary{"CBC-before-FOBT"}->{$_},100*$summary{"CBC-before-FOBT"}->{$_}/$summary{FOBT}->{$_}} @gs ; print "\n" ;
print "FOBT P" ; map {printf"\t%d (Rate = %.1f%%)",$summary{"FOBT-P"}->{$_},100*$summary{"FOBT-P"}->{$_}/$summary{FOBT}->{$_}} @gs ; print "\n" ;
print "FOBT TP" ; map {printf"\t%d (TPR = %.1f%%)",$summary{"FOBT-TP"}->{$_},100*$summary{"FOBT-TP"}->{$_}/$summary{"FOBT-P"}->{$_}} @gs ; print "\n" ;
print "MeScore(1) P" ; map {printf"\t%d (Rate = %.1f%%)",$summary{"MeScore1-P"}->{$_},100*$summary{"MeScore1-P"}->{$_}/$summary{CBC}->{$_}} @gs ; print "\n" ;
print "MeScore(1) TP" ; map {printf"\t%d (TPR = %.1f%%)",$summary{"MeScore1-TP"}->{$_},100*$summary{"MeScore1-TP"}->{$_}/$summary{"MeScore1-P"}->{$_}} @gs ; print "\n" ;
print "FOBT P and MeScore(1) P" ; map {printf"\t%d",$summary{"MeScore1-and-FOBT-P"}->{$_}} @gs ; print "\n" ;
print "Combined FOBT and MeScore(1) Colonoscopies" ; map {printf"\t%d",$summary{"MeScore1-and-FOBT-combined_colonscopies"}->{$_}} @gs ; print "\n" ;
print "FOBT and MeScore(1) TP" ; map {printf"\t%d",$summary{"MeScore1-TP-and-FOBT"}->{$_}} @gs ; print "\n" ;
print "FOBT P and MeScore(1) TP" ; map {printf"\t%d",$summary{"MeScore1-and-FOBT-TP"}->{$_}} @gs ; print "\n" ;
print "Combined FOBT and MeScore(1) Detection" ; map {printf"\t%d (x %.1f)",$summary{"MeScore1-and-FOBT-combined_detection"}->{$_}
					,$summary{"MeScore1-and-FOBT-combined_detection"}->{$_}/$summary{"FOBT-TP"}->{$_}} @gs ; print "\n" ;
print "MeScore(2) P" ; map {printf"\t%d (Rate = %.1f%%)",$summary{"MeScore2-P"}->{$_},100*$summary{"MeScore2-P"}->{$_}/$summary{CBC}->{$_}} @gs ; print "\n" ;
print "MeScore(2) TP" ; map {printf"\t%d (TPR = %.1f%%)",$summary{"MeScore2-TP"}->{$_},100*$summary{"MeScore2-TP"}->{$_}/$summary{"MeScore2-P"}->{$_}} @gs ; print "\n" ;
print "FOBT P and MeScore(2) P" ; map {printf"\t%d",$summary{"MeScore2-and-FOBT-P"}->{$_}} @gs ; print "\n" ;
print "Combined FOBT and MeScore(2) Colonoscopies" ; map {printf"\t%d",$summary{"MeScore2-and-FOBT-combined_colonscopies"}->{$_}} @gs ; print "\n" ;
print "FOBT and MeScore(2) TP" ; map {printf"\t%d",$summary{"MeScore2-TP-and-FOBT"}->{$_}} @gs ; print "\n" ;
print "FOBT P and MeScore(2) TP" ; map {printf"\t%d",$summary{"MeScore2-and-FOBT-TP"}->{$_}} @gs ; print "\n" ;
print "Combined FOBT and MeScore(2) Detection" ; map {printf"\t%d (x %.1f)",$summary{"MeScore2-and-FOBT-combined_detection"}->{$_}
					,$summary{"MeScore2-and-FOBT-combined_detection"}->{$_}/$summary{"FOBT-TP"}->{$_}} @gs ; print "\n" ;
print "CRC" ; map {printf "\t%d",$summary{CRC}->{$_}} @gs ; print "\n" ;
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
