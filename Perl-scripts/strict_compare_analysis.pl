#!/usr/bin/env perl 

my $user;

BEGIN {
die "Unsupported operating system name: $^O" unless ($^O eq "MSWin32" or $^O eq "linux");
$user = `whoami`; chomp $user;
print STDERR "User $user is invoking script $0 on a $^O machine\n";
}

use strict;
use lib "//nas1/UsersData/$user/MR/Projects/Scripts/Perl-modules" ;

use CompareAnalysis qw(compare_analysis) ;
die "Usage: $0 CurrentFile GoldStandardFile MeasuresFile AllowDiffCheckSum AllowDiffNumbers" if (@ARGV != 5) ;

my ($current,$gold,$measures,$allow_diff_checksums,$allow_diff_numbers) = @ARGV ;
my %files = (Current => $current, GoldStandard => $gold) ;

my ($err_code,$errors) = CompareAnalysis::strict_compare_analysis(\%files,$measures,$allow_diff_checksums,$allow_diff_numbers) ;

if ($err_code == -1) {
	my $error = $errors->[0] ;
	die "Failed : $error" ;
} else {
	map {print "Problem : $_\n"} @$errors ;
}