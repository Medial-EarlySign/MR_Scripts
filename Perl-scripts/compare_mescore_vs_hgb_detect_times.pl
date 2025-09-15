#!/usr/bin/env perl  -w
use strict ;
use Getopt::Long ;

my $user;

BEGIN {
die "Unsupported operating system name: $^O" unless ($^O eq "MSWin32" or $^O eq "linux");
$user = `whoami`; chomp $user;
print STDERR "User $user is invoking script $0 on a $^O machine\n";
}

use strict;
use lib "//nas1/UsersData/$user/MR/Projects/Scripts/Perl-modules" ;

my $params = {
	score_bnd => 97.2,
	max_years => 3.0,
	};

GetOptions($params,
	"score_bnd=f",  # minimal detection score for MeScore
	"max_years=f",  # size in years of window before registration for using CBC panels
	);
	
print STDERR "Parameters: " . join(", ", map {"$_ => $params->{$_}"} sort keys %$params) . "\n";
	
while (<>) {
	# print STDERR $_;
	chomp;
	my ($id, $crcdate, $strDates, $strScores, $strHgb) = split(/\t/);
	my $c = get_days($crcdate); 
	my @D = map {get_days($_)} split(/,/,$strDates); 
	my @S = split(/,/, $strScores); 
	my @H = split(/,/, $strHgb); 
	# print STDERR join("\t", "All:", join(",", @D), join(",", @S), join(",", @H)) . "\n";
	my $first_in_window = @D;
	for (0 .. $#D) {
		if (($c - $D[$_]) < $params->{max_years} * 365) {
			$first_in_window = $_;
			last;
		}
	}
	# print STDERR "first_in_window: $first_in_window\n";
	
	next if ($first_in_window >= $#D);  # only zero or one CBC in allowed window	
	next if ($H[-1] == 0); # no detection by Hgb guidelines at the last CBC before registration 
	if ($S[-1] < $params->{score_bnd}) { # MeScore failed at this last CBC
		print join("\t", $id, $crcdate, -1, 9999, $strDates, $strScores, $strHgb) . "\n";
	}
	
	# restrict to window
	@D = @D[$first_in_window .. $#D];
	@S = @S[$first_in_window .. $#S];
	@H = @H[$first_in_window .. $#H];
	
	# print STDERR join("\t", "In window:", join(",", @D), join(",", @S), join(",", @H)) . "\n";
	# locate earliest detection dates within window, ignoring last CBC
	my ($s_dist, $h_dist) = (-1, -1);
	for (0 .. ($#D - 1)) {
		$s_dist = max($s_dist, $D[-1] - $D[$_]) if ($S[$_] > $params->{score_bnd}); 
		$h_dist = max($h_dist, $D[-1] - $D[$_]) if ($H[$_] > 0);
	}
	print join("\t", $id, $crcdate, $s_dist, $h_dist, $strDates, $strScores, $strHgb) . "\n";
 }