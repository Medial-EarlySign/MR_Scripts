#!/usr/bin/env perl 
use strict(vars);

my @filesList ;
while (<>) {
	chomp ;
	push @filesList,$_ ;
}
my $nFiles = @filesList ;
print STDERR "Will work on $nFiles files\n" ;

my %sums ;
my %nums ;
my %rem_periods ;
foreach my $file (@filesList) {
	print STDERR "Working on $file\n" ;
	$file =~ /Analysis\.(\S+)\.(\S+).PeriodicAutoSim/ or die "Cannot parse $file\n";
	my ($data,$gender) = ($1,$2) ;
	open (IN,$file) or die "Cannot open $file for reading\n" ;
	my $header = 1 ;
	my @cols ;
	while (<IN>) {
		chomp ;
		my @data = split "\t",$_ ;	
		if ($header) {
			$header = 0 ;
			for my $i (0..$#data) {
				push @cols,[$i,$1,$2,$3] if ($data[$i] =~ /Period-(\S+)-EarlySens(\d)\@FP(\S+)-Mean/ and $3 >= 1 and $3 <= 5) ;
			}
			
			# Remove first and last period
			my %all_periods ;
			map {$all_periods{$_->[1]} = 1} @cols;
			my @periods = sort keys %all_periods ;
			if (@periods > 2) {
				$rem_periods{$periods[0]} = 1 ;
				$rem_periods{$periods[-1]} = 1 ;
			}
		} else {
			my $ar = $data[0] ;
			next if ($ar ne "50-75") ;
			
			foreach my $rec (@cols) {
				next if (exists $rem_periods{$rec->[1]}) ;
				foreach my $type ("ALL","Period".$rec->[1],"EarlySens".$rec->[2],"FP".$rec->[3],$data,$gender,$ar) {
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
		
			