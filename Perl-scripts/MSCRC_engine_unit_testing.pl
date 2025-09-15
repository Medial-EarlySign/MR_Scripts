#!/usr/bin/env perl 

# A script for unit-testing of the MSCRC engine

use strict(vars);
use Getopt::Long;
use FileHandle;
use DirHandle;
use Cwd;

my $p = {
	error_codes => "H:/Medial/Resources/MSCRC_Version_freezing_files//error_codes.txt",
	input_dir => "W:/CRC/Product/UnitTesting",
	versions_file => "C:/MSCRC/Files/Versions.txt",
	scorer => "H:/Medial/Projects/ColonCancer/MS_CRC_scorer/x64/Release/MS_CRC_scorer.exe",
	prefix => "Test.20120330",
	};
	
GetOptions($p,
	"engine_ver=s",		# Engine version identifier
	"versions_file=s",	# Engine locations file
	"error_codes=s", 	# Error codes file
	"work_dir=s",		# Directory for temporary engine
	"input_dir=s",		# Parent Directory for unit-testing data 
	"scorer=s",			# Executable of scorer
	"prefix=s",			# Prefix of unit-testing input files
	);
	
print STDERR "Command line: $0 " . join(" ", @ARGV) . "\n";	
print STDERR "Parameters: " . join(", ", map {"$_ => $p->{$_}"} sort keys %$p) . "\n";

map {die "Missing required argument $_" unless (defined $p->{$_})} qw/engine_ver versions_file error_codes work_dir input_dir scorer prefix/ ;
my $dir  = "$p->{input_dir}/$p->{engine_ver}" ;

# Read Error Codes
my %error_codes ;
read_error_codes($p->{error_codes},\%error_codes) ;

# Update Version File
my $test_engine = "$p->{engine_ver}.UnitTesting" ;
my $engine_dir = update_versions_file($p->{versions_file},$test_engine,$p->{work_dir},$p->{engine_ver}) ;

# Create Workdir
run_cmd("mkdir -p $p->{work_dir}") ;

# Perform tests - 
# Wrong number of parameters
test(1,$p->{scorer},"a b c",1,\%error_codes) ;
test(2,$p->{scorer},"a b c d e",1,\%error_codes) ;

# Problems with Error Bound
test(3,$p->{scorer},"$p->{engine_ver} $dir/Test1 $p->{prefix} XX",2,\%error_codes) ;
test(4,$p->{scorer},"$p->{engine_ver} $dir/Test1 $p->{prefix} -13",2,\%error_codes) ;
test(5,$p->{scorer},"$p->{engine_ver} $dir/Test1 $p->{prefix} 103",2,\%error_codes) ;

# Good Run
test(6,$p->{scorer},"$p->{engine_ver} $dir/Test1 $p->{prefix} 95.5",0,\%error_codes) ;

# Missing Engines File
missing_engines_file_test(7,$p->{scorer},"$p->{engine_ver} $dir/Test1 $p->{prefix} 95.5",11,\%error_codes,$p->{versions_file}) ;

# Missing Engine
test(8,$p->{scorer},"DummyTest $dir/Test1 $p->{prefix} 80",13,\%error_codes) ;

run_cmd("cp $engine_dir/* $p->{work_dir}") ;

# Problems reading RF model2
corrupt_binary_file("$p->{work_dir}/combined_rf1") ;
test(9,$p->{scorer},"$test_engine $dir/Test1 $p->{prefix} 80",22,\%error_codes) ;
run_cmd("cp -f $engine_dir/combined_rf1 $p->{work_dir}") ;

corrupt_binary_file("$p->{work_dir}/combined_rf2") ;
test(10,$p->{scorer},"$test_engine $dir/Test1 $p->{prefix} 80",23,\%error_codes) ;
run_cmd("cp $engine_dir/combined_rf2 $p->{work_dir}") ;

# Problems reading score-probs
corrupt_binary_file("$p->{work_dir}/combined_score_probs.bin") ;
test(11,$p->{scorer},"$test_engine $dir/Test1 $p->{prefix} 80",24,\%error_codes) ;
run_cmd("cp $engine_dir/combined_score_probs.bin $p->{work_dir}") ;

# Problems reading pred-to-spec
corrupt_binary_file("$p->{work_dir}/combined_pred_to_spec.bin") ;
test(12,$p->{scorer},"$test_engine $dir/Test1 $p->{prefix} 80",25,\%error_codes) ;
run_cmd("cp $engine_dir/combined_pred_to_spec.bin $p->{work_dir}") ;

# Problems reading incidence
corrupt_binary_file("$p->{work_dir}/men_incidence.bin") ;
test(13,$p->{scorer},"$test_engine $dir/Test1 $p->{prefix} 80",26,\%error_codes) ;
run_cmd("cp $engine_dir/men_incidence.bin $p->{work_dir}") ;

corrupt_binary_file("$p->{work_dir}/women_incidence.bin") ;
test(14,$p->{scorer},"$test_engine $dir/Test1 $p->{prefix} 80",27,\%error_codes) ;
run_cmd("cp $engine_dir/women_incidence.bin $p->{work_dir}") ;

# Problems reading shift-file
corrupt_shift_file($p->{work_dir}) ;
test(15,$p->{scorer},"$test_engine $dir/Test1 $p->{prefix} 80",28,\%error_codes) ;
run_cmd("cp $engine_dir/shift_params.txt $p->{work_dir}") ;

# Problems reading features params
run_cmd("rm -f $p->{work_dir}/codes.txt") ;
test(16,$p->{scorer},"$test_engine $dir/Test1 $p->{prefix} 80",31,\%error_codes) ;
run_cmd("cp $engine_dir/codes.txt $p->{work_dir}") ;

corrupt_features_file_wrong_name($p->{work_dir}) ;
test(17,$p->{scorer},"$test_engine $dir/Test1 $p->{prefix} 80",34,\%error_codes) ;
run_cmd("cp $engine_dir/codes.txt $p->{work_dir}") ;

corrupt_features_file_missing_field($p->{work_dir}) ;
test(18,$p->{scorer},"$test_engine $dir/Test1 $p->{prefix} 80",32,\%error_codes) ;
run_cmd("cp $engine_dir/codes.txt $p->{work_dir}") ;

corrupt_features_file_missing_line($p->{work_dir}) ;
test(19,$p->{scorer},"$test_engine $dir/Test1 $p->{prefix} 80",33,\%error_codes) ;
run_cmd("cp $engine_dir/codes.txt $p->{work_dir}") ;

# Problems reading extra params
run_cmd("rm -f $p->{work_dir}/extra_params.txt") ;
test(20,$p->{scorer},"$test_engine $dir/Test1 $p->{prefix} 80",35,\%error_codes) ;
run_cmd("cp $engine_dir/extra_params.txt $p->{work_dir}") ;

corrupt_extra_params_file($p->{work_dir}) ;
test(21,$p->{scorer},"$test_engine $dir/Test1 $p->{prefix} 80",36,\%error_codes) ;
run_cmd("cp $engine_dir/extra_params.txt $p->{work_dir}") ;

# Problems reading demographics file
test(22,$p->{scorer},"$p->{engine_ver} $dir/Test2 $p->{prefix} 80",52,\%error_codes) ;
test(23,$p->{scorer},"$p->{engine_ver} $dir/Test3 $p->{prefix} 80",53,\%error_codes) ;
test(24,$p->{scorer},"$p->{engine_ver} $dir/Test4 $p->{prefix} 80",54,\%error_codes) ;

# Problem Reading Data File
test(25,$p->{scorer},"$p->{engine_ver} $dir/Test5 $p->{prefix} 80",62,\%error_codes) ;
test(26,$p->{scorer},"$p->{engine_ver} $dir/Test6 $p->{prefix} 80",64,\%error_codes) ;
test(27,$p->{scorer},"$p->{engine_ver} $dir/Test7 $p->{prefix} 80",64,\%error_codes) ;
test(28,$p->{scorer},"$p->{engine_ver} $dir/Test8 $p->{prefix} 80",65,\%error_codes) ;

# Tracker problem 
my $scorer32 = $p->{scorer} ; $scorer32 =~ s/x64\/// ;
test(29,$scorer32,"$p->{engine_ver} $dir/Test1 $p->{prefix} 80",3,\%error_codes) ;

# Problem with output file 
test(30,$p->{scorer},"$p->{engine_ver} $dir/Test10 $p->{prefix} 80",81,\%error_codes, 
	"Verify that there is no write permission to folder $dir/Test10") ;

# ErrThreshold reached
test(31,$p->{scorer},"$p->{engine_ver} $dir/Test11 $p->{prefix} 40",4,\%error_codes) ;

# Problems reading linear model params
run_cmd("rm -f $p->{work_dir}/combined_lm_params.bin") ;
test(32,$p->{scorer},"$test_engine $dir/Test1 $p->{prefix} 80",37,\%error_codes) ;
run_cmd("cp $engine_dir/combined_lm_params.bin $p->{work_dir}") ;

corrupt_binary_file("$p->{work_dir}/combined_lm_params.bin") ;
test(33,$p->{scorer},"$test_engine $dir/Test1 $p->{prefix} 80",39,\%error_codes) ;
run_cmd("cp $engine_dir/combined_lm_params.bin $p->{work_dir}") ;

# Good Run ; Warnings
test_good_run(34,$p->{scorer},$p->{engine_ver},"$dir/Test13",$p->{prefix},80,\%error_codes,1,11) ;
test_good_run(35,$p->{scorer},$p->{engine_ver},"$dir/Test16",$p->{prefix},80,\%error_codes,1,13) ;
test_good_run(36,$p->{scorer},$p->{engine_ver},"$dir/Test18",$p->{prefix},80,\%error_codes,1,14) ;
test_good_run(37,$p->{scorer},$p->{engine_ver},"$dir/Test11",$p->{prefix},80,\%error_codes,2,21) ;
test_good_run(38,$p->{scorer},$p->{engine_ver},"$dir/Test12",$p->{prefix},80,\%error_codes,2,22) ;
test_good_run(39,$p->{scorer},$p->{engine_ver},"$dir/Test14",$p->{prefix},80,\%error_codes,2,23) ;
test_good_run(40,$p->{scorer},$p->{engine_ver},"$dir/Test15",$p->{prefix},80,\%error_codes,1,15) ;
test_good_run(41,$p->{scorer},$p->{engine_ver},"$dir/Test19",$p->{prefix},80,\%error_codes,1,12) ;
test_good_run(42,$p->{scorer},$p->{engine_ver},"$dir/Test20",$p->{prefix},80,\%error_codes,1,16) ;

print STDERR "Unit-Testing successful\n" ;

#################################################################################
# 								Functions										#
#################################################################################
sub read_error_codes {
	my ($file,$error_codes) = @_ ;
	
	open (IN,$file) or die "Cannot open $file for reading" ;
	while (<IN>) {
		chomp ;
		my ($id,@desc) = split ;
		$error_codes->{$id} = join " ",@desc ;
	}
	close IN ;
}

sub update_versions_file {
	my ($versions_file,$new_engine,$new_engine_dir,$engine) = @_ ;

	open(IN,$versions_file) or die "Cannot open $versions_file for reading" ;
	
	my ($found,$file) ;
	while (<IN>) {
		chomp ;
		my ($name,$path) = split ;
		if ($name eq $new_engine) {
			$found = $path ;
		} elsif ($name eq $engine) {
			$file = $path ;
		}
	}
	close IN ;
	
	die "Cannot find $engine in Versions-File $versions_file" if (! defined $file) ;

	if (! defined $found) { 
		open (OUT,">>$versions_file") or die "Cannot open $versions_file for writing" ;
		print OUT "$new_engine\t$new_engine_dir\n" ;
	} else {
		die "$new_engine already exists in Versions file pointing to the wrong path ($found)" if ($found ne $new_engine_dir) ;
	}
	close OUT ;
	
	return $file ;
}

sub find {
	my ($file,$code1,$code2) = @_ ;
	
	open (IN,$file) or die "Cannot open $file for reading" ;
	while (<IN>) {
		chomp ;
		my @data = split ;
		if ($data[-2]==$code1 and $data[-1]==$code2) {
			close IN ;
			return 1 ;
		}
	}

	close IN ;
	return 0 ;
}

sub test {
	my ($test_id,$scorer,$params,$code,$codes, $msg) = @_ ;
	
	my $command = "$scorer $params" ;
	print STDERR "Test $test_id : $command " ;
	my $rc = system($command)/256 ;
	if ($rc ==$code) {
		print STDERR " RC = $rc ($codes->{$rc}) . OK\n" ;
	} else {
		die " RC = $rc ($codes->{$rc}). Expected $code ($codes->{$code}). Failed" . ((defined $msg) ? ". $msg" : "") ;
	}
}

sub missing_engines_file_test {
	my ($test_id,$scorer,$params,$code,$codes,$versions_file) = @_ ;
	
	my $temp_file = "$versions_file.Temp" ;		
	run_cmd("mv $versions_file $temp_file") ;
	
	my $command = "$scorer $params" ;
	print STDERR "Test $test_id : $command " ;
	my $rc = system($command)/256 ;
	run_cmd("mv $temp_file $versions_file") ;
	
	if ($rc == $code) {
		print STDERR " RC = $rc ($codes->{$rc}) . OK\n" ;
	} else {
		die " RC = $rc ($codes->{$rc}). Expected $code ($codes->{$code}). Failed" ;
	}
}

sub run_cmd {
	my $command = shift @_ ;
	if ((my $rc = system($command)) != 0) {
		die "Command $command Failed (RC = $rc)\n" ;
	}
	
	return ;
}

sub test_good_run {
	my ($test_id,$scorer,$engine_ver,$dir,$prefix,$bound,$codes,$group,$code) = @_ ;
	
	my $command = "$scorer $engine_ver $dir $prefix $bound" ;
	print STDERR "Test $test_id : $command " ;
	my $rc = system($command) ;
	die " RC = $rc ($codes->{$rc}). Failed" if ($rc != 0) ;
	
	if (find("$dir/$prefix.Scores.txt",$group,$code) == 1) {
		print STDERR " Found $group/$code. OK\n" ;
	} else {
		die " Cannot find $group/$code. Failed" ;
	}
}

sub corrupt_binary_file {
	my $file = shift @_ ;
	
	open(OUT,">$file") or die "Cannot open $file for writing" ;
	binmode(OUT) ;
	
	my $buffer = (-1.0) x 256 ;
	print OUT $buffer ;
	close OUT ;
}
	
sub corrupt_shift_file {
	
	my $dir = shift @_ ;
	my $file = "$dir/shift_params.txt" ;
	
	open (OUT,">$file") or die "Cannot open $file for reading" ;
	print OUT "Corrupted\n" ;
	close OUT ;
}
	
sub corrupt_features_file_wrong_name {

	my $dir = shift @_ ;
	my $file = "$dir/codes.txt" ;
	
	open (IN,$file) or die "Cannot open $file for reading" ;
	my @data = <IN> ;
	close IN ;
	
	my @line = split /\t/,$data[0] ;
	$line[1] = "Dummy" ;
	$data[0] = join "\t",@line;
	
	open (OUT,">$file") or die "Cannot open $file for writing" ;
	map {print OUT $_} @data ;
	close OUT ;
}

sub corrupt_features_file_missing_field {

	my $dir = shift @_ ;
	my $file = "$dir/codes.txt" ;
	
	open (IN,$file) or die "Cannot open $file for reading" ;
	my @data = <IN> ;
	close IN ;
	
	my @line = split /\t/,$data[0] ;
	pop @line ;
	$data[0] = join "\t",@line;
	
	open (OUT,">$file") or die "Cannot open $file for writing" ;
	map {print OUT $_} @data ;
	close OUT ;
}

sub corrupt_features_file_missing_line {

	my $dir = shift @_ ;
	my $file = "$dir/codes.txt" ;
	
	open (IN,$file) or die "Cannot open $file for reading" ;
	my @data = <IN> ;
	close IN ;
	
	pop @data ;
	
	open (OUT,">$file") or die "Cannot open $file for writing" ;
	map {print OUT $_} @data ;
	close OUT ;
}

sub corrupt_extra_params_file {

	my $dir = shift @_ ;
	my $file = "$dir/extra_params.txt" ;
	
	open (IN,$file) or die "Cannot open $file for reading" ;
	my @data = <IN> ;
	close IN ;
	
	pop @data ;
	
	open (OUT,">$file") or die "Cannot open $file for writing" ;
	map {print OUT $_} @data ;
	print OUT "Dummy\t111\n" ;
	close OUT ;
}
