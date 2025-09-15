#!/usr/bin/env perl 

use strict(vars) ;

# ID-2-NR Mapping
my $id2nr = "W:\\CRC\\THIN_MAR2013\\ID2NR" ;
open (ID,$id2nr) or die "Cannot open $id2nr for reading" ;
my %id2nr ;

while (<ID>) {
	chomp ;
	my ($id,$nr) = split ;
	$id2nr{$id} = $nr ;
}
close ID ;

my $nid = scalar keys %id2nr;
print STDERR "Read $nid entries from $id2nr\n" ;

# Patient ID
my @files = ("W:\\CRC\\NewCtrlTHIN\\new_pat.csv","T:\\THIN\\EPIC 65\\MedialResearch_pat.csv") ;
my %data ;

foreach my $file (@files) {
	open (PAT,$file) or die "Cannot open $file for reading" ;

	while (<PAT>) {
		next if (/pracid/) ;
		
		chomp ;
		my ($id1,$id2,@data) = split ",",$_ ;
		my $id = $id1.$id2 ;
		my $data = join ",",@data ;
		
		die "Cannot find NR for ID=$id" unless (exists $id2nr{$id}) ;
		die "Multiple, Inconsistent PAT entries for ID=$id" if (exists $data{$id} and $data{$id}->{pat} ne $data) ;
		$data{$id1}->{$id2} = "NR $id2nr{$id}\tID $id\t $data" ;
	}
	close PAT ;
}
my $npat = scalar keys %data ;
print STDERR "Read $npat PAT entries\n" ;
exit ;

foreach my $id1 (sort keys %data) {
	print STDERR "Working on $id1\n" ;
	foreach my $id2 (keys %{$data{$id1}}) {
		my $nr = $id2nr{$id1.$id2} ;
		my $file = "W:\\CRC\\THIN_MAR2013\\IndividualData\\$id1\\$nr" ;
		open (OUT,">$file") or die "Cannot open $file: $id1-$id2 for writing" ;
		print OUT "$data{$id1}->{$id2}\n" ;
	}
	close OUT ;
}

# MED data
my %files = (MED => ["W:\\CRC\\NewCtrlTHIN\\new_med.csv","T:\\THIN\\EPIC 88\\MedialResearch_med.csv"],
			 AHD => ["W:\\CRC\\NewCtrlTHIN\\new_ahd.csv","T:\\THIN\\EPIC 65\\MedialResearch_ahd.csv"],
			 THE => ["W:\\THIN_controls_Feb2013\\MedialResearch_the\\MedialResearch_the.csv","T:\\THIN\\EPIC 88\\MedialResearch_the.csv"],
			 ) ;
			 
my $current = "NA";
foreach my $type (keys %files) {
	foreach my $file (@{$files{$type}}) {
		open (IN,$file) or die "Cannot open $file for reading" ;
		
		my $cnt  ;
		while (<IN>) {
			next if (/pracid/) ;	

			chomp ;
			my ($id1,$id2,$date,@data) = split ",",$_ ;
			my $id = $id1.$id2 ;
			my $data = join ",",@data ;		
			
			die "Cannot find NR for ID=$id" unless (exists $id2nr{$id}) ;
			my $nr = $id2nr{$id} ;
			
			if ($id ne $current) {
				close OUT if ($current ne "NA") ;
				my $ofile = "W:\\CRC\\THIN_MAR2013\\IndividualData\\$id1\\$nr" ;
				print STDERR "Working on $file -> $ofile : $id2\n" ;
				die "Cannot find File $id/$nr" unless (-e $file) ;
				$current = $id ;
				open (OUT,">>$ofile") ;
			}
			
			print OUT "$date\t$type\t$data\n"  ;	
		}
		close OUT ;
		close IN ;
		print STDERR "\n" ;
	}
}	
