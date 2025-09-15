#!/usr/bin/env perl 
use strict(vars) ;

# use GetOpt 
# params: CPT file, cpt_desc_col, icd9 file, icd9 desc col
# ...

die "Usage $0 [Ids-File]" if (@ARGV != 0 and @ARGV != 1) ;

# Read HCPC codes
# my $hcpc_file = "W:\\Data\\HCPC\\HCPC2013_A-N.txt" ;
my $hcpc_file = "W:/Data/HCPC/CPT4_CODE.SHORT_DESC.LONG_DESC" ;

open (CPT,$hcpc_file) or die "Cannot read $hcpc_file" ;
my %cpt ;

print STDERR "Reading $hcpc_file ..." ;
while (<CPT>) {
	chomp ;
	my @line = split "\t",$_ ;
	# $cpt{$line[0]} = $line[3] ;
	$cpt{$line[0]} = $line[1] ;
}
print STDERR "Done\n" ;
close CPT ;

# Read ICD9 codes
my $icd9_file = "W:\\Data\\ICD9.2012\\CMS30_DESC_LONG_DX_080612.txt" ;

open (ICD9,$icd9_file) or die "Cannot read $icd9_file" ;
my %icd9;

print STDERR "Reading $icd9_file ... " ;
while (<ICD9>) {
	chomp ;
	/(\S+)\s+(\S.*)/ or die "Cannot parse $_\n" ;
	$icd9{$1} = $2 ;
}
print STDERR "Done\n" ;
close ICD9 ;

# Read Server providers
my $prov_file = "W:\\CRC\\MedMining04Jul2013\\MEDREONC_PROV_SPECIALTY.csv" ;

open (PRV,$prov_file) or die "Cannot read $prov_file" ;
my %providers ;

print STDERR "Reading $prov_file ... " ;
while (<PRV>) {
	my $line = split_one_line($_) ;
	my $id = shift @$line ;
	my $spc = join "_", grep {$_ ne "9X9X"} @$line ;
	$providers{$id} = ($spc eq "") ? "Unknown" : $spc ;
}
print STDERR "Done\n" ;
close PRV ;

# Read Oncology file
my $onc_file = "W:\\CRC\\MedMining04Jul2013\\MEDREONC_ONCOLOGY_FILE.csv" ;

open (ONC,$onc_file) or die "Cannot read $onc_file" ;
my %ids ;
my %all_onc ;

print STDERR "Reading $onc_file ... " ;
while (<ONC>) {
	my $line = split_one_line($_) ;
	my $diag_date = $line->[38] ;
	my $id = $line->[0] ;
		
	my $out = join "// ",map {$line->[$_]} (1,3,5,33,37,38,54) ;
	push @{$all_onc{$id}},[$diag_date,$out] ;
	$ids{$id} = 1 if (($line->[3] =~ "Colon" or $line->[3] =~ "Rectum") and @ARGV==0) ;
}
print STDERR "Done\n" ;
close ONC ; 

# Read ids
if (@ARGV==1) {
	my $file = shift @ARGV ;
	
	open (IDS,$file) or die "Cannot read $file" ;
	
	print STDERR "Reading $file ... " ;
	while (<IDS>) {
		chomp ;
		$ids{$_} = 1 ;
	}
	print STDERR "Done\n" ;
	close IDS ;
	
}

my $ncases = scalar keys %ids ;
print STDERR "Read CRC data for $ncases ids\n" ;

# Read Demographics
my $dem_data = get_lines("W:\\CRC\\MedMining04Jul2013\\MEDREONC_DEMOGRAPHIC_FILE.csv",\%ids) ;
map {die "Cannot find demographics for $_" if (! exists $dem_data->{$_})} keys %ids ;

# And more ...
my %all_data ;
my $enc_data = get_lines("W:\\CRC\\MedMining04Jul2013\\MEDREONC_ENCOUNTER_FILE.csv",\%ids) ;
foreach my $id (keys %$enc_data) {
	foreach my $rec (@{$enc_data->{$id}}) {
		my $type = $rec->[6] ;
		my $prov = $providers{$rec->[18]} ;
		push @{$all_data{$id}},[$rec->[2],"Encounter","$type at $prov"] ;
	}
}

my $diag_data = get_lines("W:\\CRC\\MedMining04Jul2013\\MEDREONC_DIAGNOSIS_FILE.csv",\%ids) ;
foreach my $id (keys %$diag_data) {
	foreach my $rec (@{$diag_data->{$id}}) {
		my $code = $rec->[1] ;
		$code =~ s/\.// ;
		my $desc = exists $icd9{$code} ? $icd9{$code} : "UnKnown" ;
		push @{$all_data{$id}},[$rec->[-1],"Diagnosis",$desc] ;
	}
}

my $prblm_data = get_lines("W:\\CRC\\MedMining04Jul2013\\MEDREONC_PROBLEM_LIST.csv",\%ids) ;
foreach my $id (keys %$prblm_data) {
	foreach my $rec (@{$prblm_data->{$id}}) {
		my $code = $rec->[0] ;
		$code =~ s/\.// ;
		my $desc = exists $icd9{$code} ? $icd9{$code} : "UnKnown" ;
		$desc .= " until $rec->[2]" if ($rec->[2] ne "9X9X") ;
		push @{$all_data{$id}},[$rec->[1],"Problem",$desc] ;
	}
}

my $proc_data = get_lines("W:\\CRC\\MedMining04Jul2013\\MEDREONC_PROCEDURE_FILE.csv",\%ids) ;
foreach my $id (keys %$proc_data) {
	foreach my $rec (@{$proc_data->{$id}}) {
		my $code = $rec->[1] ;
		my $field = $rec->[10] ;
		my $desc = "Unknown ($code)" ;
		if (exists $cpt{$code}) {
			$desc = $cpt{$code} ;
		} else {
			$code =~ s/\.// ;
			$desc = $icd9{$code} if (exists $icd9{$code}) ;
		}
		
		my $info = ($field eq "9X9X") ? "$desc" : "$field: $desc" ;
		
		push @{$all_data{$id}},[$rec->[7],"Procedure","$info"] ;
	}
}

my $fnd_data = get_lines("W:\\CRC\\MedMining04Jul2013\\MEDREONC_FINDINGS_FILE.csv",\%ids) ;
foreach my $id (keys %$fnd_data) {
	my %collected ;
	foreach my $rec (@{$fnd_data->{$id}}) {
		push @{$collected{$rec->[1]}},$rec->[3] ;
	}

	foreach my $date (keys %collected) {
		my $info = join "//",@{$collected{$date}} ;
		push @{$all_data{$id}},[$date,"Finding",$info] ;
	}
}

# Print
foreach my $id (keys %ids) {
	print "ID : $id\n" ;
	my $dem_line = join "\t",@{$dem_data->{$id}->[0]} ;
	print "$id\tDemographics : $dem_line\n" ;
	
	foreach my $onc_entry (@{$all_onc{$id}}) {

		print "$id\tOncology\t$onc_entry->[0]\t$onc_entry->[1]\n" ;
	}
	
	foreach my $entry (sort {$a->[0]<=>$b->[0]} @{$all_data{$id}}) {
		print "$id\t$entry->[1]\t$entry->[0]\t$entry->[2]\n" ;
	}
	
	print "\n" ;
}
	

	
# Functions #
sub get_lines {
	my ($file,$ids) = @_ ;
	
	open (IN,$file) or die "Cannot open $file" ;
	my %data ;
	
	print STDERR "Reading $file ... ";
	my $iline = 0 ;
	while (<IN>) {
		my ($id) = split ",",$_ ;
		if (exists $ids->{$id}) {
			my $line = split_one_line($_) ;
			my $id = shift @$line ;
			push @{$data{$id}},$line  ;
		}
		
		$iline ++ ;
		print STDERR "$iline lines ... " if ($iline % 500000 == 0) ;
#		last if ($iline == 2000000) ;
	}
	print STDERR "Done\n" ;
	close IN ;

	return \%data ;
}
	
sub split_one_line {
        my ($line) = @_;

        chomp $line;
        my @F = split(/,/, $line);
        my @R;
        my $same_val = 0;
        map {push @R, $_ if ($same_val == 0); $R[-1] .= "," . $_ if ($same_val == 1); $same_val = ($R[-1] =~ m/^\"/ and not $R[-1] =~ m/\"$/) ? 1 : 0;} @F;
        map {$_ =~ s/^\"//; $_ =~ s/\"$//;} @R;

        return \@R;
}