#!/usr/bin/env perl 

# A script for expansion of data (CBC) and demography files.
# An ID with N entries (N different dates in the CBCs file) is expanded into N Ids (ID_I, I=1..N) ID_I has all the CBCs up to the
# I'th date. Demographics is expanded accordingly.
# The input file is assumed to be 'blocked' (all lines of a given id must be given together)
# All files should be tab delimeted
# Input data format is - Id Code Date Value 

die "Usage : $0 inPrefix outPrefix" if (@ARGV != 2) ;

my ($inPrefix,$outPrefix) = @ARGV ;

# Open Files
open (INDATA,"$inPrefix.Data.txt") or die "Cannot open $inPrefix.Data.txt for reading" ;
open (INDEM,"$inPrefix.Demographics.txt") or die "Cannot open $inPrefix.Demographics.txt for reading" ;
open (OUTDATA,">$outPrefix.Data.txt") or die "Cannot open $outPrefix.Data.txt for writing" ;
open (OUTDEM,">$outPrefix.Demographics.txt") or die "Cannot open $outPrefix.Demographics.txt for writing" ;

my %counts ;
my %nids ;
my $prev_id ;
my @lines ;

while (<INDATA>) {
	chomp ;
	my @data = split /\t/,$_ ;
	
	die "Line: \'$\' cannot be parsed. Are you sure your file is tab delimeted ?" if (scalar(@data) != 4) ;
	my $id = shift @data ;
	if ((defined $prev_id) and ($id ne $prev_id)) { 
		die "Input file is not given in blocks [All lines of each id must be given together]" if (exists $nids{$id}) ;
		$nids{$prev_id} = handle_id($prev_id,\@lines) ;
		@lines = () ;
	}
	push @lines,\@data ;
	$prev_id = $id ;
}

$nids{$prev_id} = handle_id($prev_id,\@lines) ;

while (<INDEM>) {
	chomp ; 
	my @data = split /\t/,$_ ;
	die "Cannot parse line \'$_\' in demography file. Are you sure it is tab delimeted ?" if (@data != 3) ;
	my $id = shift @data ;
	if (! exists $nids{$id}) {
		my $line = join "\t",($id,@data) ;
		print OUTDEM "$line\n" ;
	} else {
		for my $i (1..$nids{$id}) {
			my $line = join "\t",("$id\_$i",@data) ;
			print OUTDEM "$line\n" ;
		}
	}
}

print STDERR "== Elvis has left the building ==\n" ;

# date is the third column (second after removing id)
sub handle_id {
	my ($id,$lines) = @_ ;
	
	my %dates = map {($_->[1] => 1)} @$lines ;
	my @dates = sort {$b<=>$a} keys %dates ;
	
	my %counts = map {($dates[$_] => $_ + 1)} (0..$#dates) ;
	foreach my $line (@$lines) {
		for my $i (1..$counts{$line->[1]}) {
			my $line = join "\t",("$id\_$i",@$line) ;
			print OUTDATA "$line\n" ;
		}
	}
	
	return (scalar(@dates)) ;
}
