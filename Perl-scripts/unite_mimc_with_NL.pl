#!/usr/bin/env perl 

use FileHandle ;
use strict(vars) ;

my %out_fh ;
my %exchange_cols_for = (ADMISSIONS => 1,
						 POE_ORDER => 1,
						 ICUSTAY_DETAIL => 1,
						 ICUSTAYEVENTS => 1,
						 CENSUSEVENTS => 1,
						 ICUSTAY_DAYS => 1) ;
my %add_subject_id_for = (POE_MED => 1) ;
						 
# Usage
die "Usage : $0 FileOfDirs FileOfFileTypes OutDir" if (@ARGV != 3) ;
my ($inFile,$fileTypes,$outDir) = @ARGV ;

# Read file types
open (FT,$fileTypes) or die "Cannot open $fileTypes for reading" ;
while (<FT>) {
	chomp ;
	$out_fh{$_} = FileHandle->new("$outDir/$_","w") or die "Cannot open output file $outDir/$_" ;
}
close FT ;

my %header ;
	
# Read Directories
open (IN,$inFile) or die "Cannot open $inFile for reading" ;

my @inDirs ;
while (<IN>) {
	chomp ;
	push @inDirs,$_ ;
}
close IN ;

my $nDirs = scalar @inDirs ;
print STDERR "Working on $nDirs input directories\n" ;

# Collect Files
my %data ;
for my $dir (@inDirs) {
	my @dir = split /\//,$dir ;
	my $id = $dir[-1] ;
	print STDERR "Working on $id\n" ;
	
	foreach my $type (keys %out_fh) {
		my $file = "$dir/$type-$id.txt" ;
		if (-e $file) {
			open (DT,$file) or die "Cannot open $file for reading\n" ;
			my $head = 1 ;
			my @lines ;
			my $q_idx = 0 ;
			while (<DT>) {
				my $line = $_ ;
				if ($head) {
					if (exists $header{$type}) {
						die "Header mismatch at $id for $type" if ($line ne $header{$type}) ;
					} else {
						die "Header \'$line\' does not start with SUBJECT_ID at $file" if ($line !~ /^SUBJECT_ID/) ;
						$header{$type} = $line ;
						$out_fh{$type}->print("$line") ;
					}
					$head = 0 ;
				} else {
					fix_line(\$line,$type,$id) ;
					$q_idx += (0 + $line=~s/\"/\"/g) ;
					if ($q_idx%2 == 0) {
						$out_fh{$type}->print("$line\n") ;
						$q_idx = 0 ;
					} else {
						$out_fh{$type}->print("$line++NewLine++") ;
					}
				}
			}
		} else {
			print "$file NOT AVAILABLE\n" ;
		}
	}
}

sub fix_line {
	my ($line,$type,$id) = @_ ;
	
	chomp $$line;
	if (exists $exchange_cols_for{$type}) {
		# Exchange columns 1 and 2 - make SUBJECT_ID first column
		my @data = split ",",$$line ;
		my $temp = $data[0] ;
		$data[0] = $data[1] ;
		$data[1] = $temp ;
		$$line = join ",",@data ;
	} elsif (exists $add_subject_id_for{$type}) {
		$$line = "$id,".$$line ;
	}
}
