#!/usr/bin/env perl 

use strict(vars) ;
use File::stat ;
use Getopt::Long;

my $p = {
		max => 100000,
		header => 0,
		} ;
		
GetOptions($p,
		  "inFile=s",		# Input File
		  "index=s",		# Output Index File
		  "max=i",			# Max ID
		  "col=i",			# ColNum for indexing
		  "sep=s",			# Separator
		  "header",			# First line is header
		  ) ;

print STDERR "Command line: $0 " . join(" ", @ARGV) . "\n";
print STDERR "Parameters: " . join(", ", map {"$_ => $p->{$_}"} sort keys %$p) . "\n";
map {die "Missing required parameter $_" if (! exists $p->{$_})} qw/inFile index max col sep/ ;
		 
my $inFile = $p->{inFile} ;
print STDERR "Working on $inFile ...\n" ;

open (IN,$inFile) or die "Cannot open $inFile for reading" ;
my @pos ;
my $idCol = $p->{col} ;
my ($pos,$prevId) ;
my %done ;
my $maxId = $p->{max} ;
my @pos = (-1)x($maxId+1) ;
my $sep = $p->{sep} ;

my $nids ;
my $first = 1 ;
while (<IN>) {
	if ($first and $p->{header}) {
		$first = 0 ;
		next ;
	}

	chomp ;
	my @info = split $sep,$_ ;

	my $id = $info[$idCol] ;
	die "ID $id is too large (max = $maxId)\n" if ($id > $maxId) ;
	
	if ($id != $prevId) {
		die "Messed up file for $id. Quitting\n" if ($done{$id}) ;
#			print STDERR "Unordered file [$id after $prevId]\n" unless ($id > $prevId) ;
		$pos[$id] = $pos ;
		$done{$id} = 1 ;
		$nids ++ ;
	}
	$prevId = $id ;

	$pos = tell(IN) ;
}
close IN ;

my $nVals = ($maxId+1) ;
print STDERR "DONE Reading $nids ids in [0,$maxId]\n" ;
my $outFile = $p->{index} ;
open (OUT,">:raw","$outFile") or die "Cannot open indexing file $outFile" ;
print OUT pack("q$nVals",@pos) ;
close OUT ;
