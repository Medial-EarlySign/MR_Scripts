#!/usr/bin/env perl 
use strict;
use Getopt::Long;
use FileHandle;

my $user;

BEGIN {
die "Unsupported operating system name: $^O" unless ($^O eq "MSWin32" or $^O eq "linux");
$user = `whoami`; chomp $user;
print STDERR "User $user is invoking script $0 on a $^O machine\n";
}

use strict;
use lib "//nas1/UsersData/$user/MR/Projects/Scripts/Perl-modules" ;

use MedialUtils;

### functions ###
sub min {
	my ($a, $b) = @_;
	
	return (($a < $b) ? $a : $b);
}

sub max {
	my ($a, $b) = @_;
	
	return (($a > $b) ? $a : $b);
}

sub open_file {
    my ($fn, $mode) = @_;
    
	print STDERR "Opening file $fn in mode $mode\n";
    $fn = "/dev/stdin" if ($fn eq "-");
    my $fh = FileHandle->new($fn, $mode) or die "Cannot open $fn in mode $mode: $!";

	return $fh;
}

my $desc2cigNum = {"Trivial" => 1, "Ex-light" => 9, "Light" => 9, "Medium" => 19, "Moderate" => 19, "Ex-moderate" => 19, 
					"Heavy" => 39, "Ex-heavy" => 39, "Very heavy" => 59, 
				};

sub get_num_cigs {
	my ($cigNums, $smxDescs) = @_;
	
	my $cigNumOut = -1;
	my $numCigFromDesc = "";
	if ($cigNums ne "." and $cigNums > 0 and $cigNums <= 200) {
		$cigNumOut = $cigNums; 
	}
	else {
		$numCigFromDesc = $desc2cigNum->{$1} if ($smxDescs =~ m/^(\S+) smoker/);
		$cigNumOut = $numCigFromDesc if ($numCigFromDesc > 0 and $numCigFromDesc <= 200);
	}
	return ($cigNumOut, $numCigFromDesc);
}
					
### main ###
my $p = {
	avgStartSmxAge => 23, # based on ~950 records with startdate field
	avgQuitSmxAge => 42, # based on 1400 patients with enddate field
	avgCigPerDay => 10,   # based on ~64000 records with non-zero data2 field, dropping records with data2 > 100
	minCigYearsToOutput => 300, # 15 pack-years
	qtySmxFileName => "NULL", 
};
	
GetOptions($p,
	"avgStartSmxAge=f", # average start age for smokers 
	"avgCigPerDay=f",   # average number of cigarettes per day for smolers
	"minCigYearsToOutput=f", # minimal numner of cigarette years in output records
	"qtySmxFileName=s", # file name of quantitative smoking information to be used by prpepare_thin_from_type
);
	
print STDERR "Command line: $0 " . join(" ", @ARGV) . "\n";	
print STDERR "Parameters: " . join(", ", map {"$_ => $p->{$_}"} sort keys %$p) . "\n";

die "Output file name for quanititative smoking information must be given." if ($p->{qtySmxFileName} eq "NULL");
my $qfh = MedialUtils::open_file($p->{qtySmxFileName}, "w");

while (<>) {
	chomp;
	my ($nr, $yob, $gender,
		$evntdates, $smxinds, $cignums, 
		$startdates, $enddates, $smxdescs) = split(/\t/);
	$yob = substr($yob, 0, 4);
	my @evntYears = map {substr($_, 0, 4)} split(/,/, $evntdates);
	my @smxInds = split(/,/, $smxinds);
	my @cigNums = split(/,/, $cignums);
	my @startYears = map {substr($_, 0, 4)} split(/,/, $startdates);
	my @endYears = map {substr($_, 0, 4)} split(/,/, $enddates);
	my @smxDescs = split(/,/, $smxdescs);
	print STDERR "New patient: " . join("\t", $nr, $yob, $gender) . "\n";
	
	my $startSmxYear = 9999;
	my $endSmxYear = 0000;
	my $smxStatus = "no";
	my $exNumCig = 0;
	my $currentNumCig = 0;
	my $cumulNumCig = 0.0;
	my $cigCountPeriod = 0;
	my $numCigFromDesc = 0;
	my $comment = "";
	my $nice_sep = "\t\t\t\t\t";
	print STDERR join("\t", qw(event_year[i] smx[i] cig_num[i] start_year[i] end_year[i] desc[i])) . $nice_sep . 
				join("\t", qw(startSmxYear endSmxYear smxStatus currentNumCig numCigFromDesc cumulNumCig exNumCig cigCountPeriod)) . "\n";

	for my $i (0 .. $#evntYears) {
		if ($evntYears[$i] == $yob){
			$evntYears[$i] = $yob + $p->{avgStartSmxAge} if ($smxInds[$i] eq "Y");
			$evntYears[$i] = $yob + $p->{avgQuitSmxAge} if ($smxInds[$i] eq "D");
			$smxDescs[$i] = $smxDescs[$i] . " moved 'just-born' record" if ($smxInds[$i] eq "D" or $smxInds[$i] eq "Y");
		}	
	}
	my @sort_by_year = sort { $evntYears[$a] <=> $evntYears[$b] } 0 .. $#evntYears;
	my $prev_year = -1;
	for my $i (@sort_by_year) {
		next if ($evntYears[$i] < 1900);
		$numCigFromDesc = 0;
		$comment = "";
		if ($smxStatus eq "yes" and $currentNumCig > 0) { # implies that this is not the first record
			my $delta = ($evntYears[$i] - $prev_year);
			if ($delta < 0){
				$comment = $comment . "ERROR: negative delta, skipping this record ";
			} else {
				$cumulNumCig += $currentNumCig * $delta;
				$cigCountPeriod += $delta;
			}
		}		
		if ($smxInds[$i] eq "Y") {
			$smxStatus = "yes";
			$startSmxYear = min($startSmxYear, $evntYears[$i]);
			$endSmxYear = max($endSmxYear, $evntYears[$i]);
			my ($a, $b) = get_num_cigs($cigNums[$i], $smxDescs[$i]);
			$currentNumCig = $a if ($a != -1); 
			$numCigFromDesc = $b if ($b != "");
		}
		if ($smxInds[$i] eq "D") {
			if ($smxStatus eq "yes") {
				$endSmxYear = max($endSmxYear, $evntYears[$i]);
			}
			if ($smxStatus eq "no"){
				$endSmxYear = max($endSmxYear, min($yob + $p->{avgQuitSmxAge}, $evntYears[$i]));
				$comment = $comment . "switched from never-smoker to ex-smoker, assuming quit in: $endSmxYear ";
			}
			$smxStatus = "ex";
			my ($a, $b) = get_num_cigs($cigNums[$i], $smxDescs[$i]);
			$exNumCig = $a if ($a != -1); 
			$numCigFromDesc = $b if ($b != "");
		}
		if ($smxInds[$i] eq "N") { # unreliable
			if ($smxStatus eq "yes") {
				$endSmxYear = max($endSmxYear, $evntYears[$i]) ;
				$comment = $comment . "ignoring unreliable transition from smoker to never-smoker, assuming still smoking";
			}
		}
		$startSmxYear = min($startSmxYear, $startYears[$i]) if ($startYears[$i] ne ".");
		$endSmxYear = max($endSmxYear, $endYears[$i]) if ($endYears[$i] ne ".");
		
		print STDERR join("\t", $evntYears[$i], $smxInds[$i], $cigNums[$i], 
								$startYears[$i], $endYears[$i], $smxDescs[$i]) . $nice_sep . 
					join("\t", $startSmxYear, $endSmxYear, $smxStatus, $currentNumCig, $numCigFromDesc, $cumulNumCig, $exNumCig, $cigCountPeriod, $comment) . "\n";
		$prev_year = $evntYears[$i];
		
	}
	$startSmxYear = min($startSmxYear, $endSmxYear - 1) if ($endSmxYear >= 1900); 
	$endSmxYear = max($endSmxYear, $startSmxYear + 1) if ($startSmxYear <= 2099);
	if ($smxStatus eq "yes" and $currentNumCig > 0 and $cigCountPeriod == 0) { 
		# if there was only one year of reporting, we don't want to count it as zero...
		$cumulNumCig = $currentNumCig;
		$cigCountPeriod = 1;
	}
	print STDERR $nice_sep . $nice_sep . join("\t", $startSmxYear, $endSmxYear, $smxStatus, $currentNumCig, $numCigFromDesc, $exNumCig, $cumulNumCig, $cigCountPeriod) . "\n";
	my $smxPeriod = $endSmxYear - $startSmxYear;
	
	if ($startSmxYear == 9999) {
		print STDERR "No factual smoking information\n";
		$qfh->print(join("\t", $nr, -1, -1, 0, 0) . "\n");
		print STDERR join("\t", $nr, -1, -1, 0, 0) . "\n";
		next;
	}
	
	if ($cigCountPeriod > $smxPeriod) {
		print STDERR "ERROR: confirmed smoking period longer than extended period\n";
	}
	print STDERR "Smoking period: $startSmxYear - $endSmxYear\n";
	print STDERR "Smoking count: $cumulNumCig in exact reporting period = $cigCountPeriod years\n";
	my $avgCigPerDay = 0.0;
	if ($cigCountPeriod > 0){
		print STDERR "Using cumulNumCig: $cumulNumCig\n";
		$avgCigPerDay = ($cumulNumCig + 0.0)/$cigCountPeriod ;
	} elsif ($exNumCig > 0) {
		print STDERR "Using exNumCig: $exNumCig\n";
		$avgCigPerDay = $exNumCig;
	} else {
		print STDERR "Using global avgCigPerDay: $p->{avgCigPerDay}\n";
		$avgCigPerDay = $p->{avgCigPerDay};
	}
	my $cigCountRep = $cumulNumCig + $avgCigPerDay * ($smxPeriod - $cigCountPeriod);
	my $cigCountRep = $cumulNumCig + $avgCigPerDay * ($smxPeriod - $cigCountPeriod);
	print STDERR "Estimated smoking count in reporting period: $cigCountRep in $smxPeriod years\n";
	my $startExtPeriod = ($yob + $p->{avgStartSmxAge});
	my $extPeriod = max($endSmxYear - $startExtPeriod, 0);
	my $cigCountExt = $cigCountRep + $avgCigPerDay * ($startSmxYear - ($yob + $p->{avgStartSmxAge}));
	print STDERR "Extrapolated smoking count from an average smoking onset age: " .
				"$cigCountExt in $extPeriod years from $startExtPeriod to $endSmxYear\n";
				
	print STDERR join("\t", qw(NR YearOfBirth Gender Year AgeAtYear DistanceFromQuit 
					ReportedPackYears ExtendedPackYears)) . "\n";
	for my $y (min($yob + $p->{avgStartSmxAge}, $startSmxYear).. $endSmxYear) {
		my $ageAtYear = $y - $yob;
		my $distFromQuit = $y - $endSmxYear;	
		my $repCountInYear = max(min($y, $endSmxYear) - $startSmxYear, 0) * $avgCigPerDay;
		my $extCountInYear = max(min($y, $endSmxYear) - ($yob + $p->{avgStartSmxAge}), 0) * $avgCigPerDay;
		my $out_str = join("\t", $nr, $yob, $gender, 
								 $y, $ageAtYear, $distFromQuit, 
								 int($repCountInYear/20), int($extCountInYear/20)) . "\n";
		print STDERR $out_str;
		next if (max($repCountInYear, $extCountInYear) < $p->{minCigYearsToOutput});
	}
	$qfh->print(join("\t", $nr, min($startExtPeriod, $startSmxYear), $endSmxYear, 
							int($avgCigPerDay+0.5), ($smxStatus eq "yes") ? 1 : 0) . "\n");
	print STDERR "Final output: " . join("\t", $nr, min($startExtPeriod, $startSmxYear), $endSmxYear, 
						int($avgCigPerDay+0.5), ($smxStatus eq "yes") ? 1 : 0) . "\n";
}