#!/usr/bin/env perl 
use strict(vars) ;

sub split_one_line {
	my ($line) = @_;
	#print $line;
	
	chomp $line;	
	my @F = split(/,/, $line);
	my @R;
	my $same_val = 0;
	map {push @R, $_ if ($same_val == 0); $R[-1] .= "," . $_ if ($same_val == 1); $same_val = ($R[-1] =~ m/^\"/ and not $R[-1] =~ m/\"$/) ? 1 : 0;} @F;
	map {$_ =~ s/^\"//; $_ =~ s/\"$//;} @R;
	
	#print join("\t", @F) . "\n";
	#print join("\t", @R) . "\n";
		
	return \@R;
}

while (<>) {
	my $F = split_one_line($_);
	
	print join("\t", @$F) . "\n";
}