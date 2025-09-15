#!/usr/bin/env perl 

my $user;

BEGIN {
die "Unsupported operating system name: $^O" unless ($^O eq "MSWin32" or $^O eq "linux");
$user = `whoami`; chomp $user;
print STDERR "User $user is invoking script $0 on a $^O machine\n";
}

use strict;
use lib "//nas1/UsersData/$user/MR/Projects/Scripts/Perl-modules" ;

use PrepareEngineFiles qw(rfgbm_prepare_engine_files) ;

die "Usage : $0 Method SetupFile EngineDir [MaxSdvs = 7]" unless (@ARGV==3 || @ARGV==4) ;

my $method = shift @ARGV ;

if ($method eq "rfgbm") {
	PrepareEngineFiles::rfgbm_prepare_engine_files(@ARGV) ;
} else {
	die "No Engine Preparation Module Available For Method \'$method\'\n" ;
}