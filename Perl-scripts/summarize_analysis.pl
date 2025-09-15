#!/usr/bin/env perl 
use strict(vars) ;

die "Usage: $0 File" if (@ARGV != 1) ;
my $file = @ARGV[0] ;

open (LST,$file) or die "Cannot open $file for reading" ;
my %files ;
my @names ;
while (<LST>) {
	chomp ;
	my ($name,$path) = split ;
	push @names,$name ;
	$files{$name} = $path ;
}
close LST ;

my %data ;
my $header  ;
my @cols ;
foreach my $name (@names) {
	my $file = $files{$name} ;
	open (IN,$file) or die "Cannot open $file for reading" ;
	
	my $read_head = 0 ;
	while (<IN>) {
		chomp ;
		if ($read_head == 0) {
			$header = $_ if (! defined $header) ;
			die "Header Mismatch at $file" if ($_ ne $header) ;
			$read_head = 1 ;
		} else {		
			my ($tw,$ar,$cs,$nbs,@data) = split ;
			$data{"$name.$tw.$ar"} = \@data ;
			push @cols,"$name.$tw.$ar" ;
		}
	}
	close IN ;
}

my ($tw,$ar,$cs,$nbs,@data) = split /\t/,$header ;
my $head = join "\t",("Value",@cols) ;
print "$head\n" ;

for (my $i=0; $i<$#data; $i+=4) {
	my $field = $data[$i] ;
	die "$field ?" unless ($field =~ /-Mean/) ;
	$field =~ s/-Mean// ;
	
	my @line = ($field) ;
	for my $in (@cols) {
		my ($mean,$lb,$ub) = map {$data{$in}->[$_]} ($i,$i+2,$i+3) ;
		push @line,"$mean [$lb,$ub]" ;
	}
	my $line = join "\t",@line ;
	print "$line\n" ;
}