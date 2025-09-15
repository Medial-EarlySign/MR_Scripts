#!/usr/bin/env perl  
use strict(vars) ;

# Read Genders
open (GD,"W:\\CRC\\AllDataSets\\Demographics") or die "Cannot open Demographics" ;

my %gender ;
while (<GD>) {
	chomp ;
	my ($id,$byear,$gender) = split ;
	$gender{$id} = $gender ;
}
close GD ;

# Read Codes.
open (IN,"W:\\CRC\\THIN\\IndividualData\\symptom_codes") or die "Cannot read symptoms" ;

my %codes ;
while (<IN>) {
	chomp ;
	my ($code,$level,$type) = split ;
	$codes{$type}->{$code} = $level ;
}
close IN ;

# Read Ids
open (IN,"W:\\CRC\\THIN_MAR2013\\ID2NR") or die "Cannot read ID2NR" ;

my @paths ;
while (<IN>) {
	chomp ;
	my ($id,$nr) = split ;
	my $dir = substr($id,0,5) ;
	push @paths,[$nr,"W:\\CRC\\THIN\\IndividualData\\$dir\\$nr.parsed"] ;
}

# Loop
my %counter ;
foreach my $rec (@paths) {
	my ($nr,$file) = @$rec ;
	if (!exists $gender{$nr}) {
		print STDERR "Ignoring $nr . Not in Dem\n" ;
		next ;
	}
	
	print STDERR "Working on $file\n" ;
	open (IN,$file) or die "Cannot open ..." ;
	
	while (<IN>) {
		chomp ;
		if (/(\S+)\tMED\t.*CAT=\s+(.*?)\((\S+)\)/ and exists $codes{MED}->{$3}) {
			print "$nr\t$1\t$codes{MED}->{$3}\t$2\n" ;
			$counter{$3} ++ ;
		} elsif (/(\S+)\tAHD\t.*RC=\s+(.*?)\((\S+)\)/ and exists $codes{AHD}->{$3}) {
			print "$nr\t$1\t$codes{AHD}->{$3}\t$2\n" ;
			$counter{$3} ++ ;
		} elsif (/(\S+)\tAHD\t.*RC=\s+.*?423\.\.[00|11]/) {
			my $date = $1 ;
			if (/NUM_RESULT: (\S+) \/\/ MEASURE_UNIT: g\/dL/) {
				print "$nr\t$date\t1\tLow Hb: $1\n" if ($1>0 and $gender{$nr} eq "M" and $1 < 13 or $gender{$nr} eq "F" and $1 < 12) ;
			} elsif (/NUM_RESULT: (\S+)/ and $1>30) {
				my $hem = $1/10 ;
				print "$nr\t$date\t1\tLow Hb: $hem\n" if ($hem>0 and $gender{$nr} eq "M" and $hem < 13 or $gender{$nr} eq "F" and $hem < 12) ;
			} elsif (/NUM_RESULT: (\S+)/ and $1 < 30) {
				print "$nr\t$date\t1\tLow Hb: $1\n" if ($10 and $gender{$nr} eq "M" and $1 < 13 or $gender{$nr} eq "F" and $1 < 12) ;
			} else {
				print "Error : $_ ?\n" ;
			}
		}
	}
	close IN ;
}

print "Summary :\n" ;
map {print "$_ $counter{$_}\n"} sort keys %counter;