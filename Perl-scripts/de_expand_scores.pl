#!/usr/bin/env perl 

# A script for uniting Ids of the format ID_I to ID. Consistency is also checked


die "Usage : $0 inScores outScores" if (@ARGV != 2) ;
my ($inScores,$outScores) = @ARGV ;

open (IN,$inScores) or die "Cannot open $inScores for reading" ;
open (OUT,">$outScores") or die "Cannot open $outScores for writing" ;

my %info ;
while (<IN>) {
	chomp ;
	my ($id,$date,$score,$time,@info) = split /\t/,$_ ;
	my $info = join "\t",($score,@info) ;
	$id =~ /(\S+)_\d+/ or die "Cannot parse id $id" ;
	$id = $1 ;
	if (exists $info{"$id.$date"}) {
		die "Inconsistency at $id.$date" if ($info ne $info{"$id.$date"}) ;
	} else {
		my $out = join "\t",($id,$date,$score,$time,@info) ;
		print OUT "$out\n" ;
	}
	$info{"$id.$date"} = $info ;
}
