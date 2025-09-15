#!/usr/bin/env perl 

use Getopt::Long;
use strict(vars) ;

### main ###

my @days2month = (0,31,59,90,120,151,181,212,243,273,304,334) ;

my $p = {
	snoMed => "//server/Work/Data/SnoMed/SnoMed",
	ICD9 => "//server/Work/Data/ICD9.2012/CMS30_DESC_SHORT_DX.txt",
	ICDO => "//server/Work/Data/ICD-O/ICD-O",
	ReadCodes => "//server/Work/Data/THIN/Readcodes",
	cancerCodes => "//server/Work/Data/MHS/CancerCodes",
	gap => 60,
	};
	
GetOptions($p,
	"inReg=s",			# input registry file
	"outReg=s",			# output registry file
	"snoMed=s",			# SnoMed file
	"ICD9=s",			# ICD-9 file
	"ICDO=s",			# ICD-O file
	"ReadCodes=s",		# Read Codes file
	"cancerCodes=s",	# MHS Cancer Codes
	"sep=s",			# Separatot
	"gap=i",			# Maximal gap in days for redundant cancer information
	) ;

print STDERR "Command line: $0 " . join(" ", @ARGV) . "\n";	
print STDERR "Parameters: " . join("\n", map {"$_ => $p->{$_}"} sort keys %$p) . "\n\n";
map {die "Missing Required parameter $_" if (! defined $p->{$_})} qw/inReg outReg sep/ ;

# Metastases
my $metastases = init_metastases() ;

# Read Registry File
open (REG,$p->{inReg}) or die "Cannot open $p->{inReg} for reading" ;

my %reg ;
my $n = 0 ;
while (<REG>) {
	next if (/NUMERATOR/) ;
	
	chomp ;
	my @data = split $p->{sep},$_ ;
	my ($id,$stage_cd,$stage_mecc,$date,$icd9,$icdo,$morph) = map {$data[$_]} (0,3,4,5,6,7,8) ;
	my $type ;
	if ($id < 4000000) { # MHS
		$type = join ",",map {$data[$_]} (11,12,13) ;
	} else {
		$type = join ",", map {$data[$_]} (14,15,16) ;
	}
	
	my ($month,$day,$year) = split "/",$date ;
	my $date = 10000*$year + 100*$month + $day ;
	my $additional = 0;
	if ($id >= 4000000 and $id < 6000000) { #THIN
 		$additional = $icd9 ;
		$icd9 = 0 ;
	}	
	
	$icd9 =~ s/\.//g  ;
	$icdo =~ s/\.//g ;
	
	$stage_mecc = " " if ($year < 2000) ;
	
	$stage_mecc = 9 if ($stage_mecc eq "NULL") ;
	$stage_cd = 9 if ($stage_cd eq "NULL") ;
	
	push @{$reg{$id}->{$date}},{cd => $stage_cd, mec => $stage_mecc, morph => $morph, icd9 => $icd9, icdo => $icdo, additional => $additional, type => $type} ;
	$n++ ;
}
close REG ;

my $nid = scalar keys %reg ;
print STDERR "Read $n entries for $nid Ids from $p->{regFile}\n" ;

# Read SnoMed MorphCodes
open (SNO,$p->{snoMed}) or die "Cannot open $p->{snoMed} for reading" ;

my %snomed ;
while (<SNO>) {
	chomp ;
	my ($id,$desc) = split /\t/,$_ ;
	$desc =~ s/\"//g ;
	$snomed{$id} = $desc ;
}
close SNO ;

my $nsnomed = scalar keys %snomed ;
print STDERR "Read $nsnomed SnoMed Ids from $p->{snoMed}\n" ;
	
# Read ICD9 Codes
open (ICD9,$p->{ICD9}) or die "Cannot open $p->{ICD9} for reading" ;

my %icd9 ;
while (<ICD9>) {
	chomp ;
	my ($id,@desc) = split ;
	my $desc = join " " , @desc ;
	$icd9{$id} = $desc ;
}
close ICD9 ;
my $nicd9 = scalar keys %icd9 ;
print STDERR "Read $nicd9 ICD9 Ids from $p->{ICD9}\n" ;

# Read ICD-O Codes
open (ICDO,$p->{ICDO}) or die "Cannot open $p->{ICDO} for reading" ;

my %icdo ;
while (<ICDO>) {
	chomp ;
	my ($id,@desc) = split ;
	$icdo{$id} = join " " , @desc ;
}
close ICDO ;

my $nicdo = scalar keys %icdo ;
print STDERR "Read $nicdo ICDO Ids from $p->{ICDO}\n" ;

# Read ReadCodes
open (RD,$p->{ReadCodes}) or die "Cannot open $p->{ReadCodes} for reading" ;

my %additional ;
while (<RD>) {
	chomp ;
	my ($id,@desc) = split ;
	$additional{$id} = join " " , @desc ;
}
close RD ;

my $nrd = scalar keys %additional ;
print STDERR "Read $nrd readCodes Ids from $p->{ReadCodes}\n" ;
	
# Read MHS Cancer Codes
open (CC,"$p->{cancerCodes}") or die "Cannot open $p->{cancerCodes} for reading" ;

my %cancerCodes ;
while (<CC>) {
	chomp ;
	my ($codes,$info) = split /\t/,$_ ;
	die "Multiple entry for $codes. Quitting" if (exists $cancerCodes{$codes}) ;
	$cancerCodes{$codes} = $info ;
}
close CC ;

# Complete
open (OUT,">$p->{outReg}") or die "Cannot open $p->{outReg} for wrinting" ;

print OUT "NR\tDate\tType\tStage(MEC)\tMorphology[SnoMed]\tSite[ICD9]\tSite[ICD-O]\tAdditional Info\n" ;

my %out ;
foreach my $id (sort {$a<=>$b} keys %reg) {
	foreach my $date (keys %{$reg{$id}}) { 
		foreach my $rec (@{$reg{$id}->{$date}}) {
		
			my $type = $rec->{type} ;
			if ($id <= 4000000) { # MHS
				if (!exists $cancerCodes{$type}) {
					print "Cannot find type for $type for $id/$date\n" ;
					next ;
				}
				$type = $cancerCodes{$type} ;
			}
			
			my $stage = ($id < 4000000 and $rec->{mec} =~ /\S/) ? $rec->{mec} : "" ;
			my $snomed = $rec->{morph} ;
			my $icd9 = $rec->{icd9} ;
			my $icdo = $rec->{icdo} ;
			my $additional = $rec->{additional} ;

			my $morph = ""  ;
			if ($snomed ne "0") {
				$morph = "SnoMed[$snomed]:" ;
				$morph .= $snomed{$snomed} if (exists $snomed{$snomed}) ;
			} else {
				$morph = "SnoMed[0]:" ;
			}
			
			my $site1 = "" ;
			if ($icd9 ne "0") {
				$site1 = "ICD9[$icd9]:" ;
				$site1 .= $icd9{$icd9} if (exists $icd9{$icd9}) ;
			} else {
				$morph = "ICD9[0]:" ;
			}
			
			my $site2 = "" ;
			if ($icdo ne "0") {
				$site2 = "ICDO[$icdo]:" ;
				$site2 .= $icdo{$icdo} if (exists $icdo{$icdo}) ;
				$site1 .= $icd9{$icd9} if (exists $icd9{$icd9}) ;
			} else {
				$morph = "ICDO[0]:" ;
			}

			my $info = "" ;
			if ($additional ne "0") {
				die "MISSING Additional Code $additional" if (! exists $additional{$additional}) ;
				$info = $additional{$additional} ;
				$type = $metastases->{$info} if (exists $metastases->{$info}) ;
			}
			
			my $rec = {date => $date, stage => $stage, snomed => $morph, icd9 => $site1, icdo => $site2, info => $info} ;
			$rec->{n} = getInfo($rec) ;
			$rec->{line} = getLine($id,$type,$date,$rec) ;
			$rec->{day} = get_days($date) ;
			push @{$out{$id}->{$type}},$rec  ;
		}
	}
}

# Filter and print
foreach my $id (sort {$a<=>$b} keys %out) {
	foreach my $type (sort keys %{$out{$id}}) {

		my @recs = sort {$a->{date} <=> $b->{date} or $b->{n} <=> $a->{n}} @{$out{$id}->{$type}} ;
		
		for my $i (0..$#recs) {
			my $redundant = 0 ;
			for my $j (0..$i-1) {
				if (includedInfo($recs[$i],$recs[$j])) {
					if ($recs[$i]->{day} > $recs[$j]->{day} + $p->{gap}) {
						print "Warning: $id $recs[$j]->{date} => $recs[$i]->{date} ($type)\n" ;
					} else {
						print "Info: $id $type $recs[$j]->{line} => $recs[$i]->{line}\n" ;
						$redundant = 1 ;
						last ;
					}
					print "Warning: $id $type $recs[$j]->{line} => $recs[$i]->{line}\n" if ($recs[$j]->{n} > $recs[$i]->{n}) ;
				}
			}
			print OUT "$recs[$i]->{line}\n" if ($redundant == 0) ;	
		}
	}
}


#### FUNCTIONS ####

sub includedInfo {
	my ($test,$ref) = @_ ;
	
	return 0 unless ($test->{stage} == 9 or $test->{stage} == $ref->{stage}) ;
	return 0 unless ($test->{snomed} =~ /SnoMed\[0\]/ or $test->{snomed} eq $ref->{snomed}) ;
	return 0 unless ($test->{icd9} =~ /ICD9\[0\]/ or $test->{icd9} =~ /ICD9\[NULL\]/ or $test->{icd9} eq $ref->{icd9}) ;
	return 0 unless ($test->{icdo} =~ /ICDO\[0\]/ or $test->{icdo} =~ /ICDO\[Cxxx\]/ or $test->{icdo} eq $ref->{icdo}) ;
	
	return 1 ;
}

sub getLine {
	my ($id,$type,$date,$rec) = @_ ;
	my $info = join "\t",map {$rec->{$_}} qw/stage snomed icd9 icdo info/ ;
	return "$id\t$date\t$type\t$info" ;
}

sub getInfo {
	my $rec = shift @_ ;
	
	my $nInfo = 0 ;
	$nInfo ++ unless ($rec->{stage} == 9) ;
	$nInfo ++ unless ($rec->{snomed} =~ /SnoMed\[0\]/) ;
	$nInfo ++ unless ($rec->{icd9} =~ /ICD9\[0\]/ or $rec->{icd9} =~ /ICD9\[NULL\]/) ;
	$nInfo ++ unless ($rec->{icdo} =~ /ICDO\[0\]/ or $rec->{icdo} =~ /ICDO\[Cxxx\]/) ;

	return $nInfo ;
}
	

sub init_metastases {

	my %metastases = (
		"Liver metastases" => "Metastases To,Digestive System,Liver",
		"Secondary malig neop of large intestine or rectum NOS" => "Metastases To,Digestive System,Small Intestine and Rectum",
		"Secondary malignant neoplasm of large intestine and rectum" => "Metastases To,Digestive System,Large Intestine and Rectum",
		"Secondary malignant neoplasm of liver" => "Metastases To,Digestive System,Liver",
		"Secondary malignant neoplasm of lung" => "Metastases To,Respiratory System,Lung and Bronchus",
		"Secondary malignant neoplasm of rectum" => "Metastases To,Digestive System,Colon and Rectum",
		) ;

	return \%metastases ;
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