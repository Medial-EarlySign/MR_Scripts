#!/usr/bin/env perl 

use strict(vars) ;

die "Usage : $0 FileOfDirs OutDir" if (@ARGV != 2) ;
my ($inFile,$outDir) = @ARGV ;

my %instructions ;
init_instructions() ;

open (IN,$inFile) or die "Cannot open $inFile for reading" ;

my @inDirs ;
while (<IN>) {
	chomp ;
	push @inDirs,$_ ;
}
close IN ;

my $nDirs = scalar @inDirs ;
print STDERR "Working on $nDirs input directories\n" ;

# Collect Patients Info
my %data ;
for my $iDir (0..$#inDirs) {
	print STDERR ($iDir+1)."/$nDirs " if ($iDir%100 == 0) ;
	my $dir = $inDirs[$iDir] ;
	my @dir = split /\//,$dir ;
	my $id = $dir[-1] ;
	
	my $patients_file = "$dir/D_PATIENTS-$id.txt" ;
	read_patients_file($patients_file,$id) ;
}
print STDERR "\n" ;

# FUNCTIONS
sub read_patients_file {
	my ($file,$id) = @_ ;
	
	open (IN,$file) or die "Cannot open $file for reading" ;
	
	my $header = 1 ;
	while (<IN>) {
		chomp ;
		if ($header == 1) {
			die "Header problem at $file" if  ($_ ne $instructions{PATIENTS}->{header}) ;
			$header = 0 ;
		} else {
			die "More than one line in $file ?" if ($header < 0) ;
			my (@fields) = split ",",$_ ;
			
			my $nfields = scalar @fields ;
			die "Fields incosistency in $file (Found $nfields instead of $instructions{PATIENTS}->{nfields})" if ($nfields != $instructions{PATIENTS}->{nfields}) ;
			foreach my $i (0..$#fields) {
				my $field = $fields[$i] ;
				$field =~ s/^\"// ;
				$field =~ s/\"$// ;
								
				if ($instructions{PATIENTS}->{fields}->[$i] eq "SUBJECT_ID") {
					die "ID inconsistency in $file " if ($field != $id) ;
				} else {
					$data{$id}->{PATIENTS}->{$instructions{PATIENTS}->{fields}->[$i]} = $field ;
				}
			}	
		}
	}
	close IN ;
}

sub init_instructions {

	# PATIENTS
	$instructions{PATIENTS}->{header} = "SUBJECT_ID,SEX,DOB,DOD,HOSPITAL_EXPIRE_FLG" ;
	

	foreach my $type (keys %instructions) {
		my @fields = split ",",$instructions{$type}->{header} ;
		$instructions{$type}->{fields} = \@fields ;
		$instructions{$type}->{nfields} = scalar(@fields) ;
	}
}