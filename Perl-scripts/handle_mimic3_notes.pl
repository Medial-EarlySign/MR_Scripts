#!/usr/bin/env perl 

# Usage
die "Usage : $0 inFile ourFile" if (@ARGV != 2) ;
my ($inFile,$outFile) = @ARGV ;

# Read
open (IN,$inFile) or die "Cannot open $inFile for reading\n" ;
open (OUT,">$outFile") or die "Cannot open $outFile for writing\n" ;

my $head = 1;
my @lines ;
my $q_idx = 0 ;
while (my $line = <IN>) {
	chomp $line;
	if ($head) {
		die "Header \'$line\' does not start with ROW_ID at $file" if ($line !~ /^\"ROW_ID/) ;
		print OUT "$line\n" ;
		$head = 0 ;
	} else {
		$q_idx += (0 + $line=~s/\"/\"/g) ;
		if ($q_idx%2 == 0) {
			print OUT "$line\n" ;
			$q_idx = 0 ;
		} else {
			print OUT "$line++NewLine++" ;
		}
	}
}

