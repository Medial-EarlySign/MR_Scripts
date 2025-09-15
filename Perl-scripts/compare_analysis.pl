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
die "Usage: $0 CompareInFile CompareOutFile CompareSummaryFile AllowDiffCheckSum AllowDiffList MeasuresFile ErrorFile" if (@ARGV !=7) ;


CompareAnalysis::compare_analysis(@ARGV) ;
