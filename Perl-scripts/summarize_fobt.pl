#!/usr/bin/env perl 
use strict(vars) ;

# Read FOBT files
my %types = ("חיובי" => 1,
			 "חיובי חלש" => 1,
			 "POSITIVE" => 1,
			 "דם סמוי חיובי" => 1,
			 "שלילי" => 0,
			 "דם סמוי שלילי" => 0,
			 "NEGATIVE" => 0,
			 ) ;
my %fobt ;

while (<>) {
	chomp ;
	my ($id,$dummy1,$date,$code,$dummy2,$result) = split ",",$_ ;
	
	if (exists $types{$result}) {
		$fobt{$id}->{$date}->{n} ++ ;
		$fobt{$id}->{$date}->{npos} += $types{$result} ;
	}

}
		
foreach my $id (keys %fobt) {
	foreach my $date (keys %{$fobt{$id}}) {
		print "$id\t$date\t".$fobt{$id}->{$date}->{n}."\t".$fobt{$id}->{$date}->{npos}."\n" ;
	}
}