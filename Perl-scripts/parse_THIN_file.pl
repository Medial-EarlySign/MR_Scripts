#!/usr/bin/env perl  

use strict(vars) ;
my @days2month = (0,31,59,90,120,151,181,212,243,273,304,334) ;

die "Usage: $0 nr/nr-file" unless (@ARGV == 1) ;
my ($nr) = @ARGV ;

# ID-2-NR Mapping
my $id2nr = "W:\\CRC\\THIN_MAR2013\\ID2NR" ;
open (ID,$id2nr) or die "Cannot open $id2nr for reading" ;
my %nr2dir ;

while (<ID>) {
	chomp ;
	my ($id,$nr) = split ;
	$nr2dir{$nr} = substr($id,0,5) ;
}
close ID ;

# Get NRs
my @nrs ;
if (exists $nr2dir{$nr}) {
	print STDERR "Regarding $nr as a numerator !\n" ;
	push @nrs,$nr ;
} else {
	print STDERR "Cannot find dir for $nr. Regarding as a file\n" ;
	open (NR,$nr) or die "Cannot open $nr for reading" ;
	while (<NR>) {
		chomp ;
		push @nrs,$_ ;
	}
	close NR ;
}

# Read read-codes
my $readcodes = "T:\\THIN\\EPIC 65\\Ancil 1205\\Readcodes1205.txt";
open (RC,$readcodes) or die "Cannot open $readcodes for reading" ;

my %readcodes ;
while (<RC>) {
	chomp ;
	my $code = substr($_,0,7) ; $code =~ s/^s\s+//g ; $code =~ s/\s+$//g ;
	my $desc = substr($_,7,60) ; $desc =~ s/^s\s+//g ; $desc =~ s/\s+$//g ;
	$readcodes{$code} = $desc ;
}
close RC ;

# Read drug-codes
my $readcodes = "T:\\THIN\\EPIC 65\\Ancil 1205\\Drugcodes1205.txt";
open (RC,$readcodes) or die "Cannot open $readcodes for reading" ;

my %drugcodes ;
while (<RC>) {
	chomp ;
	my $code = substr($_,0,8) ; $code =~ s/^s\s+//g ; $code =~ s/\s+$//g ;
	my $desc = substr($_,41,120) ; $desc =~ s/^s\s+//g ; $desc =~ s/\s+$//g ;
	$drugcodes{$code} = $desc ;
}
close RC ;

# Read AHD-codes
my $ahdcodes = "W:\\CRC\\THIN\\IndividualData\\AHDCodes.txt" ;
open (AC,$ahdcodes) or die "Cannot open $ahdcodes for reading" ;

my %ahdcodes ;
while (<AC>) {
	chomp ;
	my ($file,$code,$desc,@fields) = split /\t/,$_ ;
	$ahdcodes{$code} = {desc => $desc, fields => \@fields} ;
}
close AC ;

# Read AHD-lookups
my $ahdlookup = "W:\\CRC\\THIN\\IndividualData\\AHDlookups.txt" ;
open (AL,$ahdlookup) or die "Cannot open $ahdlookup for reading" ;

my %ahdlookup ;
while (<AL>) {
	chomp ;
	my ($name,$desc,$key,$val) = split /\t/,$_ ;
	$ahdlookup{$desc}->{$key} = $val ;
}
close AL;

# Read Lookups
my $lookup = "T:\\THIN\\EPIC 65\\Ancil 1205\\THINLookups.txt" ;
open (LP,$lookup) or die "Cannot open $lookup for reading" ;

my %lookup ;
while (<LP>) {
	chomp ;
	my $table = substr($_,0,10) ; $table =~ s/^\s+//g ; $table =~ s/\s+$//g ;
	my $key = substr($_,10,3) ; $key =~ s/^\s+//g ; $key =~ s/\s+$//g ;
	my $val = substr($_,13,256) ; $val =~ s/^\s+//g ; $val =~ s/\s+$//g ;

	$lookup{$table}->{$key} = $val ;
}
close LP ;

# Handle
map {handle_nr($_)} @nrs ;

################################################################

sub handle_nr {
	my $inr = shift ;
	my $dir = $nr2dir{$inr} ;
	print STDERR "Working on $inr in $dir\n" ;
	
	open (OUT,">W:\\CRC\\THIN\\IndividualData\\$dir\\$inr.parsed") or die "Cannot open output file for $inr" ;
	
	# Read File
	my $file = "W:\\CRC\\THIN\\IndividualData\\$dir\\$inr" ;
	open (IN,$file) or die "Cannot open $file for reading" ;

	my ($nr,$id,$info,@data) ; ;
	while (<IN>) {
		chomp;
		if (/^NR/) {
			/NR (\d+)\s+ID (\S+)\s+(\S+)/ or die "Cannot parse $_" ;
			($nr,$id,$info) = ($1,$2,$3) ;
			die "Inconsistent NR ($nr != $inr) !?" if ($nr != $inr) ;
		} else {
			my ($date,$type,$data) = split /\t/,$_ ;
			push @data,[$date,$type,$data] ;
		}
	}
	close IN ;

	my @sorted = sort {$a->[0] <=> $b->[0]} @data ;
	my @info = split ",",$info ;
	my ($yob,$sex,$regdate,$regstat,$deathdate,$deathinfo) = map {$info[$_]} (1,3,4,5,8,9) ;

	$sex = $lookup{sex}->{$sex} ;
	$regstat = $lookup{regstat}->{$regstat} ; 
	$deathinfo = $lookup{deathinfo}->{$deathinfo} if (defined $deathinfo and $deathinfo ne "") ;
	print OUT "NR= $inr\tID= $id\tYOB= $yob\tSEX= $sex\tREG= $regstat $regdate\tDEATH=  $deathinfo $deathdate\n" ;

	foreach my $rec (@sorted) {
		my ($date,$type,$data) = @$rec ;
		if ($type eq "MED") {
			my @info = split ",",$data ;
			my ($enddate,$datatype,$medcode,$category) = map {$info[$_]} (0,1,2,3,11) ;
			my $length = ($enddate eq "00000000") ? 0 : get_days($enddate) - get_days($date) ;
			$datatype = $lookup{datatype}->{$datatype} ;
			$category = $lookup{category}->{$category} ;
			warn "Unknown ReadCode $medcode in $data" if (!exists $readcodes{$medcode}) ;
			my $desc = $readcodes{$medcode} ;
			print OUT "$date\tMED\tLEN= $length\tTYPE= $datatype\tCAT= $category\t$desc ($medcode)\n" ;
		} elsif ($type eq "THE") {
			my @info = split ",",$data ;
			my ($drug,$days,$type) = map {$info[$_]} (0,4,7) ;
			$type = $lookup{prsctype}->{$type} ;
			warn "Unknown DrugCode $drug in $data" if (!exists $drugcodes{$drug}) ;
			my $desc = $drugcodes{$drug} ;
			print OUT "$date\tTHE\tLEN= $days\tTYPE= $type\t$desc ($drug)\n" ;
		} elsif ($type eq "AHD") {
			my @info = split ",",$data ;
			my ($ahdcode,@data) = map {$info[$_]} (0,2,3,4,5,6,7,8) ;
			my $medcode = pop @data ;
			warn "Unknown ReadCode $medcode in $data" if (!exists $readcodes{$medcode}) ;
			my $meddesc = $readcodes{$medcode} ;
			warn "Unknown AhdCode $ahdcode in $data" if (!exists $ahdcodes{$ahdcode}) ;
			my $ahddesc = $ahdcodes{$ahdcode}->{desc} ;
			my @ahd_info ;
			for my $i (0..5) {
				if ($ahdcodes{$ahdcode}->{fields}->[$i] ne "" and $data[$i] ne "") {
					my $name = $ahdcodes{$ahdcode}->{fields}->[$i] ;
					my $desc = (exists $ahdlookup{$name}->{$data[$i]}) ? $ahdlookup{$name}->{$data[$i]} : $data[$i];
					push @ahd_info,"$name: $desc" ;
				}
			}
			my $ahdinfo = join " // ",@ahd_info ;
			print OUT "$date\tAHD\tRC= $meddesc ($medcode)\tAHD= $ahddesc ($ahdcode) ($ahdinfo)\n" ;
		}
	}
	
	close OUT ;
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