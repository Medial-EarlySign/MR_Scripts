#!/usr/bin/env perl 

use strict;

# (1) Quit unless we have the correct number of command-line args
my $num_args = $#ARGV + 1;
if ($num_args != 3) {
	print "\nUsage: get_predictions_intersection.pl <input_predictions_file1> <input_predictions_file2> output_file\n";
	exit;
}
my $preds_file1 = $ARGV[0];
my $preds_file2 = $ARGV[1];
my $output = $ARGV[2];

# (2) Open files
open (P1,"<$preds_file1") or die "Cannot open $preds_file1 file" ;
open (P2,"<$preds_file2") or die "Cannot open $preds_file2 file" ;
open (OUT, ">$output") or die "Cannot open $output file" ;

# (3) Read files
my @preds1;
my $header = 1;
while (<P1>) {
	if ($header == 1) {$header = 0; next;}
	chomp;
	my ($id,$date,@rest) = split;
	my $key = "$id\t$date";
	push @preds1, $key;
}

my @preds2;
$header = 1;
while (<P2>) {
	if ($header == 1) {$header = 0; next;}
	chomp;
	my ($id,$date,@rest) = split;
	my $key = "$id\t$date";
	push @preds2, $key;
}

# (4) Create intersection file
my %preds1_hash = map { $_ => 1 } @preds1;
my @intersect = grep { $preds1_hash{$_} } @preds2;
print OUT join("\n", @intersect);

close (P1);
close (P2);
close (OUT);

