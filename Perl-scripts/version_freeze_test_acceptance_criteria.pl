#!/usr/bin/env perl 
use strict;
use Getopt::Long;
use FileHandle;

### functions ###
sub open_file {
    my ($fn, $mode) = @_;
    
	print STDERR "Opening file $fn in mode $mode\n";
    $fn = "/dev/stdin" if ($fn eq "-");
    my $fh = FileHandle->new($fn, $mode) or die "Cannot open $fn in mode $mode: $!";

	return $fh;
}

sub parse_detailed_comparison_file {
	my ($fn, $required_dataset) = @_;
	my $fh = open_file($fn, "r");
	
	my $res = {};	
	while (<$fh>) {
		chomp;
		s/\t$/\t /;
		my @F = split(/\t/);
		my ($dataset, $gender, $type, $cross_section, $measure, $prev, $curr, $diffstr) = @F;
		die "Wrong number of fields in DetailedComparison line: $_" unless (@F == 8);
		next unless ($dataset eq $required_dataset);
		$res->{$measure}{$gender}{$type}{$cross_section} = {prev => $prev, curr => $curr, diffstr => $diffstr};
	}
	
	return $res;
}

sub test_thresh {
	my ($comp, $measure, $gender, $type, $cross_section, $thresh) = @_;
	my $scr = $comp->{$measure}{$gender}{$type}{$cross_section}{curr};
	die "score for $measure#$gender#$type#$cross_section is missing" if (not defined $scr);	
	
	if ($scr > $thresh) {
		print "PASS: score for $measure#$gender#$type#$cross_section is $scr >= $thresh\n";
	}
	else {
		print "FAIL: scre for $measure#$gender#$type#$cross_section is $scr < $thresh\n";
	}
}

sub comp_score {
	my $diffstr2score = {"---" => -3, "--" => -2, "-" => -1, "" => 0, " " => 0, "+" => 1, "++" => 2, "+++" => 3}; 
	
	my ($comp, $measure, $gender, $type, $cross_section) = @_;
	
	my $ds = $comp->{$measure}{$gender}{$type}{$cross_section}{diffstr};
	die "Undefined or illegal diff string $ds for $measure::$gender::$type::$cross_section" if (not defined $ds or not exists $diffstr2score->{$ds});
	# print "diffstr for $measure#$gender#$type#$cross_section is $ds\n";
		 
	return $diffstr2score->{$ds};	
}	
		
### main ###
my $p = {
};

# Usage example: version_freeze_test_acceptance_criteria.pl --prev_dtld_fn W:/Users/Efrat/CRC_Model_Versions/DMQRF_MAR_2016/Full_Cycle_07032016/CheckMSCRC/VersionsComparisonUluruPersepolisIntersection/DetailedComparison --base_dtld_fn W:/Users/Efrat/CRC_Model_Versions/DMQRF_MAR_2016/Full_Cycle_07032016/CheckMSCRC/VersionsComparisonUluruOuagaIntersection/DetailedComparison	
GetOptions($p,
	"prev_dtld_fn=s",        # path of DetailedComparison between candidate version and previous stable version
	"base_dtld_fn=s",        # path of DetailedComparison between candidate version and base version
	"combined_only",         # work only on combined analysis files
	"unpaired",				 # use unpaired comparison 
	"use_learning_set",      # use LearningSet as an approximation for ExternalValidation
	);
	
print STDERR "Command line: $0 " . join(" ", @ARGV) . "\n";	
print STDERR "Parameters: " . join(", ", map {"$_ => $p->{$_}"} sort keys %$p) . "\n";

my $required_dataset = ($p->{use_learning_set}) ? "LearningSet" : "MaccabiValidation";
my $comp_prev = parse_detailed_comparison_file($p->{prev_dtld_fn}, $required_dataset);
my $comp_base = parse_detailed_comparison_file($p->{base_dtld_fn}, $required_dataset);

my $prefix_paired = ($p->{unpaired}) ? "UnPaired" : "";

# testing first set of criteria: threshold for specifed performance metrics
print "Testing primary acceptance criteria:\n";
test_thresh($comp_prev, "SENS\@FP3.0", "combined", $prefix_paired."Windows", "0-180_40-100"  , 39.926);
if (not $p->{combined_only}) {
	test_thresh($comp_prev, "SENS\@FP3.0", "women"   , $prefix_paired."Windows", "0-180_40-100"  , 41.245);
	test_thresh($comp_prev, "SENS\@FP3.0", "men"     , $prefix_paired."Windows", "0-180_40-100"  , 35.622);
	test_thresh($comp_prev, "SENS\@FP5.0", "women"   , $prefix_paired."Windows", "180-360_50-75", 22.380);
	test_thresh($comp_prev, "SENS\@FP5.0", "men"     , $prefix_paired."Windows", "180-360_50-75", 20.908);
	test_thresh($comp_prev, "EarlySens1\@FP2.5", "women"   , $prefix_paired."AutoSim", "50-75", 6.549);
	test_thresh($comp_prev, "EarlySens1\@FP2.5", "men"     , $prefix_paired."AutoSim", "50-75", 6.724);
}

test_thresh($comp_prev, "SENS\@FP5.0", "combined", $prefix_paired."Windows", "180-360_50-75", 23.510);
test_thresh($comp_prev, "EarlySens1\@FP2.5", "combined", $prefix_paired."AutoSim", "50-75", 7.707);


# testing second set of criteria: compute per-gender comparison scores against the base version
print "Testing secondary acceptance criteria:\n";
for my $gender (qw(combined women men)) {
	my $score = 
		comp_score($comp_base, "SENS\@FP2.5", $gender, $prefix_paired."Windows", "0-180_40-100"  ) +
		comp_score($comp_base, "SENS\@FP2.5", $gender, $prefix_paired."Windows", "0-180_50-75"   ) +
		comp_score($comp_base, "SENS\@FP2.5", $gender, $prefix_paired."Windows", "180-360_40-100") +
		comp_score($comp_base, "SENS\@FP2.5", $gender, $prefix_paired."Windows", "180-360_50-75" ) +
		comp_score($comp_base, "SENS\@FP5.0", $gender, $prefix_paired."Windows", "0-180_40-100"  ) +
		comp_score($comp_base, "SENS\@FP5.0", $gender, $prefix_paired."Windows", "0-180_50-75"   ) +
		comp_score($comp_base, "SENS\@FP5.0", $gender, $prefix_paired."Windows", "180-360_40-100") +
		comp_score($comp_base, "SENS\@FP5.0", $gender, $prefix_paired."Windows", "180-360_50-75" ) +
		comp_score($comp_base, "SENS\@FP1.0", $gender, $prefix_paired."Windows", "360-720_40-100") +
		comp_score($comp_base, "SENS\@FP1.0", $gender, $prefix_paired."Windows", "360-720_50-75" ) +
		comp_score($comp_base, "EarlySens1\@FP2.5", $gender, $prefix_paired."AutoSim", "40-100") +
		comp_score($comp_base, "EarlySens1\@FP2.5", $gender, $prefix_paired."AutoSim", "50-75" ) +
		comp_score($comp_base, "EarlySens2\@FP2.5", $gender, $prefix_paired."AutoSim", "40-100") +
		comp_score($comp_base, "EarlySens2\@FP2.5", $gender, $prefix_paired."AutoSim", "50-75" ) +
		comp_score($comp_base, "EarlySens3\@FP2.5", $gender, $prefix_paired."AutoSim", "40-100") +
		comp_score($comp_base, "EarlySens3\@FP2.5", $gender, $prefix_paired."AutoSim", "50-75" );
	if ($score >= -2) {
		print "PASS: score for comparison against base version on $gender is $score >= -2\n";
	}
	else {
		print "FAIL: score for comparison against base version on $gender is $score < -2\n";
	}
}

# testing third set of criteria: compute per-gender comparison scores against the previous stable version
print "Testing tertiary acceptance criteria:\n";
for my $gender (qw(combined women men)) {
	my $score = 
		comp_score($comp_prev, "SENS\@FP2.5", $gender, $prefix_paired."Windows", "0-180_40-100"  ) +
		comp_score($comp_prev, "SENS\@FP2.5", $gender, $prefix_paired."Windows", "0-180_50-75"   ) +
		comp_score($comp_prev, "SENS\@FP2.5", $gender, $prefix_paired."Windows", "180-360_40-100") +
		comp_score($comp_prev, "SENS\@FP2.5", $gender, $prefix_paired."Windows", "180-360_50-75" ) +
		comp_score($comp_prev, "SENS\@FP5.0", $gender, $prefix_paired."Windows", "0-180_40-100"  ) +
		comp_score($comp_prev, "SENS\@FP5.0", $gender, $prefix_paired."Windows", "0-180_50-75"   ) +
		comp_score($comp_prev, "SENS\@FP5.0", $gender, $prefix_paired."Windows", "180-360_40-100") +
		comp_score($comp_prev, "SENS\@FP5.0", $gender, $prefix_paired."Windows", "180-360_50-75" ) +
		comp_score($comp_prev, "SENS\@FP1.0", $gender, $prefix_paired."Windows", "360-720_40-100") +
		comp_score($comp_prev, "SENS\@FP1.0", $gender, $prefix_paired."Windows", "360-720_50-75" ) +
		comp_score($comp_prev, "EarlySens1\@FP2.5", $gender, $prefix_paired."AutoSim", "40-100") +
		comp_score($comp_prev, "EarlySens1\@FP2.5", $gender, $prefix_paired."AutoSim", "50-75" ) +
		comp_score($comp_prev, "EarlySens2\@FP2.5", $gender, $prefix_paired."AutoSim", "40-100") +
		comp_score($comp_prev, "EarlySens2\@FP2.5", $gender, $prefix_paired."AutoSim", "50-75" ) +
		comp_score($comp_prev, "EarlySens3\@FP2.5", $gender, $prefix_paired."AutoSim", "40-100") +
		comp_score($comp_prev, "EarlySens3\@FP2.5", $gender, $prefix_paired."AutoSim", "50-75" );
	if ($score >= -2) {
		print "PASS: score for comparison against previous version on $gender is $score >= -2\n";
	}
	else {
		print "FAIL: score for comparison against previous version on $gender is $score < -2\n";	
	}
}


