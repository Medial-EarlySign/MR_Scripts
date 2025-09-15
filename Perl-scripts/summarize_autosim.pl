#!/usr/bin/env perl 
use strict(vars);

my @filesList ;
while (<>) {
	chomp ;
	push @filesList,$_ ;
}
my $nFiles = @filesList ;
print STDERR "Will work on $nFiles files\n" ;
	
my @cols ;
my %sums ;
my %nums ;
foreach my $file (@filesList) {
	print STDERR "Working on $file\n" ;
	$file =~ /Analysis\.(\S+)\.(\S+).AutoSim/ or die "Cannot parse $file\n";
	my ($data,$gender) = ($1,$2) ;
	open (IN,$file) or die "Cannot open $file for reading\n" ;
	my $header = 1 ;
	while (<IN>) {
		chomp ;
		my @data = split "\t",$_ ;	
		if ($header) {
			$header = 0 ;
			if (! @cols) {
				for my $i (0..$#data) {
					push @cols,[$i,$1,$2] if ($data[$i] =~ /EarlySens(\d)\@FP(\S+)-Mean/ and $2 >= 1 and $2 <= 5) ;
				}
			} else {
				foreach my $rec (@cols) {
					my ($col,$id,$fp) = @$rec ;
					die "Mismatch at $file header : ".$data[$col]. " vs EarlySens$id\@FP$fp-Mean" if ($data[$col] ne "EarlySens$id\@FP$fp-Mean") ;
				}
			}
		} else {
			my $ar = $data[0] ;
			next if ($ar ne "50-75") ;
			foreach my $rec (@cols) {
				foreach my $type ("ALL","EarlySens".$rec->[1],"FP".$rec->[2],$data,$gender,$ar) {
					$nums{$type} ++ ;
					$sums{$type} += $data[$rec->[0]] ;
				}
			}
		}
	}
}

foreach my $type (sort keys %nums) {
	my $mean = $sums{$type}/$nums{$type} ;
	print STDERR "$type\t$mean\t$nums{$type}\n" ;
}

my $mean = $sums{ALL}/$nums{ALL} ;
print "Summary\t$mean\t$nums{ALL}\n" ;
		
			