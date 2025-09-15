#!/usr/bin/env perl 
use strict(vars) ;

# Read Analysis (base + raw) files and prepare for input to Study-Performance-System.

my $user;

BEGIN {
die "Unsupported operating system name: $^O" unless ($^O eq "MSWin32" or $^O eq "linux");
$user = `whoami`; chomp $user;
print STDERR "User $user is invoking script $0 on a $^O machine\n";
}

use strict;
use lib "//nas1/UsersData/$user/MR/Projects/Scripts/Perl-modules" ;
use PrepareDataForSPS qw(prepare_data_for_SPS) ;

die "Usage $0 inPrefix outPrefix resolution [Key/Value pairs]" unless (@ARGV>=3 and scalar(@ARGV)%2==1) ;

PrepareDataForSPS::prepare_data_for_SPS(@ARGV) ;