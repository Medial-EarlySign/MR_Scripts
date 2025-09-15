#!/usr/bin/env perl 

# A script for unit-testing of the MSCRC engine

use strict(vars);
use Getopt::Long;
use FileHandle;
use DirHandle;
use Cwd;

# LINUX/WINDOWS ?
my $user = `whoami` ; chomp $user ;
my $arch = ($^O eq "linux") ? "Linux" : "Win32" ;
my $suffix = ($^O eq "linux") ? "" : ".exe" ; 
my $scorer = "//nas1/UsersData/$user/Medial/Projects/ColonCancer/TestProduct/$arch/Release/TestProduct$suffix" ;

# Default arguments
my $p = {
	error_codes => "//nas1/UsersData/$user/Medial/Resources/MSCRC_Version_freezing_files//MeScorer_error_codes.txt",
	input_dir => "//nas1/Work/CRC/Product/UnitTesting/MeScorer/DMQRF_FEB_2016",
	scorer => $scorer,
	prefix => "Test.20120330",
	};
	
GetOptions($p,
	"engine_dir=s",		# Engine directory
	"error_codes=s", 	# Error codes file
	"work_dir=s",		# Directory for temporary engine
	"input_dir=s",		# Parent Directory for unit-testing data 
	"scorer=s",			# Executable of scorer
	"prefix=s",			# Prefix of unit-testing input files
	);
	
print STDERR "Command line: $0 " . join(" ", @ARGV) . "\n";	
print STDERR "Parameters: " . join(", ", map {"$_ => $p->{$_}"} sort keys %$p) . "\n";

map {die "Missing required argument $_" unless (defined $p->{$_})} qw/engine_dir error_codes work_dir input_dir scorer prefix/ ;
my $dir  = "$p->{input_dir}" ;

my $engine_dir = $p->{engine_dir} ;

# Read Error Codes
my %error_codes ;
read_error_codes($p->{error_codes},\%error_codes) ;

# Create Workdir
run_cmd("mkdir -p $p->{work_dir}") ;
run_cmd("cp $engine_dir/* $p->{work_dir}") ;

# Good Run
test(1,$p->{scorer},"$engine_dir $dir/Test1 $p->{prefix} 0",0,\%error_codes) ;

# Problems reading RF models
corrupt_binary_file("$p->{work_dir}/combined_qrf1") ;
test(2,$p->{scorer},"$p->{work_dir} $dir/Test1 $p->{prefix} 0",103,\%error_codes) ;
run_cmd("cp -f $engine_dir/combined_qrf1 $p->{work_dir}") ;

run_cmd("rm -f $p->{work_dir}/combined_qrf1") ;
test(3,$p->{scorer},"$p->{work_dir} $dir/Test1 $p->{prefix} 0",103,\%error_codes) ;
run_cmd("cp -f $engine_dir/combined_qrf1 $p->{work_dir}") ;

corrupt_binary_file("$p->{work_dir}/combined_qrf2") ;
test(4,$p->{scorer},"$p->{work_dir} $dir/Test1 $p->{prefix} 0",104,\%error_codes) ;
run_cmd("cp $engine_dir/combined_qrf2 $p->{work_dir}") ;

run_cmd("rm -f $p->{work_dir}/combined_qrf2") ;
test(5,$p->{scorer},"$p->{work_dir} $dir/Test1 $p->{prefix} 0",104,\%error_codes) ;
run_cmd("cp -f $engine_dir/combined_qrf2 $p->{work_dir}") ;

# Problems reading score-probs
corrupt_binary_file("$p->{work_dir}/combined_score_probs.bin") ;
test(6,$p->{scorer},"$p->{work_dir} $dir/Test1 $p->{prefix} 0",105,\%error_codes) ;
run_cmd("cp $engine_dir/combined_score_probs.bin $p->{work_dir}") ;

run_cmd("rm -f $p->{work_dir}/combined_score_probs.bin") ;
test(7,$p->{scorer},"$p->{work_dir} $dir/Test1 $p->{prefix} 0",105,\%error_codes) ;
run_cmd("cp -f $engine_dir/combined_score_probs.bin $p->{work_dir}") ;

# Problems reading pred-to-spec
corrupt_binary_file("$p->{work_dir}/combined_pred_to_spec.bin") ;
test(8,$p->{scorer},"$p->{work_dir} $dir/Test1 $p->{prefix} 0",106,\%error_codes) ;
run_cmd("cp $engine_dir/combined_pred_to_spec.bin $p->{work_dir}") ;

run_cmd("rm -f $p->{work_dir}/combined_pred_to_spec.bin") ;
test(9,$p->{scorer},"$p->{work_dir} $dir/Test1 $p->{prefix} 0",106,\%error_codes) ;
run_cmd("cp -f $engine_dir/combined_pred_to_spec.bin $p->{work_dir}") ;

# Problems reading incidence
corrupt_binary_file("$p->{work_dir}/men_incidence.bin") ;
test(10,$p->{scorer},"$p->{work_dir} $dir/Test1 $p->{prefix} 0",107,\%error_codes) ;
run_cmd("cp $engine_dir/men_incidence.bin $p->{work_dir}") ;

run_cmd("rm -f $p->{work_dir}/men_incidence.bin") ;
test(11,$p->{scorer},"$p->{work_dir} $dir/Test1 $p->{prefix} 0",107,\%error_codes) ;
run_cmd("cp -f $engine_dir/men_incidence.bin $p->{work_dir}") ;

corrupt_binary_file("$p->{work_dir}/women_incidence.bin") ;
test(12,$p->{scorer},"$p->{work_dir} $dir/Test1 $p->{prefix} 0",108,\%error_codes) ;
run_cmd("cp $engine_dir/women_incidence.bin $p->{work_dir}") ;

run_cmd("rm -f $p->{work_dir}/women_incidence.bin") ;
test(13,$p->{scorer},"$p->{work_dir} $dir/Test1 $p->{prefix} 0",108,\%error_codes) ;
run_cmd("cp -f $engine_dir/women_incidence.bin $p->{work_dir}") ;

# Problems reading shift-file
corrupt_shift_file($p->{work_dir}) ;
test(14,$p->{scorer},"$p->{work_dir} $dir/Test1 $p->{prefix} 0",109,\%error_codes) ;
run_cmd("cp $engine_dir/shift_params.txt $p->{work_dir}") ;

run_cmd("rm -f $p->{work_dir}/shift_params.txt") ;
test(15,$p->{scorer},"$p->{work_dir} $dir/Test1 $p->{prefix} 0",109,\%error_codes) ;
run_cmd("cp -f $engine_dir/shift_params.txt $p->{work_dir}") ;

# Problems reading features params
run_cmd("rm -f $p->{work_dir}/codes.txt") ;
test(16,$p->{scorer},"$p->{work_dir} $dir/Test1 $p->{prefix} 0",121,\%error_codes) ;
run_cmd("cp $engine_dir/codes.txt $p->{work_dir}") ;

corrupt_features_file_wrong_name($p->{work_dir}) ;
test(17,$p->{scorer},"$p->{work_dir} $dir/Test1 $p->{prefix} 0",124,\%error_codes) ;
run_cmd("cp $engine_dir/codes.txt $p->{work_dir}") ;

corrupt_features_file_missing_field($p->{work_dir}) ;
test(18,$p->{scorer},"$p->{work_dir} $dir/Test1 $p->{prefix} 0",122,\%error_codes) ;
run_cmd("cp $engine_dir/codes.txt $p->{work_dir}") ;

corrupt_features_file_missing_line($p->{work_dir}) ;
test(19,$p->{scorer},"$p->{work_dir} $dir/Test1 $p->{prefix} 0",123,\%error_codes) ;
run_cmd("cp $engine_dir/codes.txt $p->{work_dir}") ;

# Problems reading extra params
run_cmd("rm -f $p->{work_dir}/extra_params.txt") ;
test(20,$p->{scorer},"$p->{work_dir} $dir/Test1 $p->{prefix} 0",125,\%error_codes) ;
run_cmd("cp $engine_dir/extra_params.txt $p->{work_dir}") ;

corrupt_extra_params_file($p->{work_dir}) ;
test(21,$p->{scorer},"$p->{work_dir} $dir/Test1 $p->{prefix} 0",126,\%error_codes) ;
run_cmd("cp $engine_dir/extra_params.txt $p->{work_dir}") ;

# Problems reading linear model params
run_cmd("rm -f $p->{work_dir}/combined_lm_params.bin") ;
test(22,$p->{scorer},"$p->{work_dir} $dir/Test1 $p->{prefix} 0",102,\%error_codes) ;
run_cmd("cp $engine_dir/combined_lm_params.bin $p->{work_dir}") ;

corrupt_binary_file("$p->{work_dir}/combined_lm_params.bin") ;
test(23,$p->{scorer},"$p->{work_dir} $dir/Test1 $p->{prefix} 0",102,\%error_codes) ;
run_cmd("cp $engine_dir/combined_lm_params.bin $p->{work_dir}") ;

# Problems reading version file
run_cmd("rm -f $p->{work_dir}/Version.txt") ;
test(24,$p->{scorer},"$p->{work_dir} $dir/Test1 $p->{prefix} 0",131,\%error_codes) ;
run_cmd("cp $engine_dir/Version.txt $p->{work_dir}") ;

# Good Run ;
test_good_run(101,$p->{scorer},$p->{work_dir},"$dir/Test2",$p->{prefix},0,\%error_codes,201) ; #	MESSAGE_NO_BLOOD_DATA 1
test_good_run(102,$p->{scorer},$p->{work_dir},"$dir/Test3",$p->{prefix},0,\%error_codes,202) ; #	MESSAGE_ILLEGAL_GENDER 2
test_good_run(103,$p->{scorer},$p->{work_dir},"$dir/Test4",$p->{prefix},0,\%error_codes,203) ; #	MESSAGE_ILLEGAL_DATE 3
test_good_run(104,$p->{scorer},$p->{work_dir},"$dir/Test5",$p->{prefix},0,\%error_codes,204) ; #	MESSAGE_AGE_OUT_OF_RANGE 4
test_good_run(105,$p->{scorer},$p->{work_dir},"$dir/Test6",$p->{prefix},0,\%error_codes,205) ; #	MESSAGE_NO_CBC_TO_SCORE 5
test_good_run(106,$p->{scorer},$p->{work_dir},"$dir/Test7",$p->{prefix},0,\%error_codes,211) ; #	MESSAGE_NOT_LAST_CBC 11
test_good_run(107,$p->{scorer},$p->{work_dir},"$dir/Test8",$p->{prefix},0,\%error_codes,221) ; #	MESSAGE_ILLEGAL_AGE 21
test_good_run(108,$p->{scorer},$p->{work_dir},"$dir/Test9",$p->{prefix},0,\%error_codes,222) ; #	MESSAGE_NEGATIVE_AGE 22
test_good_run(109,$p->{scorer},$p->{work_dir},"$dir/Test10",$p->{prefix},0,\%error_codes,223) ; #	MESSAGE_TOO_MANY_CLIPPINGS 23
test_good_run(110,$p->{scorer},$p->{work_dir},"$dir/Test11",$p->{prefix},0,\%error_codes,224) ; #	MESSAGE_MINIMAL_REQ_UNMET 24
test_good_run(111,$p->{scorer},$p->{work_dir},"$dir/Test12",$p->{prefix},0,\%error_codes,225) ; #	MESSAGE_MULTIPLE_TEST_VALS 25
test_good_run(112,$p->{scorer},$p->{work_dir},"$dir/Test13",$p->{prefix},0,\%error_codes,231) ; #	MESSAGE_CLIPPING_INPUT 31
test_good_run(113,$p->{scorer},$p->{work_dir},"$dir/Test14",$p->{prefix},0,\%error_codes,232) ; #	MESSAGE_REMOVING_INPUT 32

print STDERR "Unit-Testing successful\n" ;

#################################################################################
# 								Functions										#
#################################################################################
sub read_error_codes {
	my ($file,$error_codes) = @_ ;
	
	open (IN,$file) or die "Cannot open $file for reading" ;
	while (<IN>) {
		chomp ;
		my ($type,$code,$desc) = split /\t/,$_ ;
		
		if ($type eq "setUp") {
			$code += 100 ;
		} elsif ($type eq "getScore") {
			$code += 200 ;
		} else {
			die "Unknown error-code type \'$type\'" ;
		}
		
		$error_codes->{$code} = $desc ;
	}
	close IN ;
}


sub find {
	my ($file,$code) = @_ ;
	
	open (IN,$file) or die "Cannot open $file for reading" ;
	while (<IN>) {
		chomp ;
		my ($id,$date,$score,$messages) = split /\t/,$_ ;
		my @messages = split /\s+/,$messages ;
		foreach my $message(@messages) {
			my ($icode) = split ",",$message ;
			if ($icode == $code) { 
				close IN ;
				return 1 ;
			}
		}
	}

	close IN ;
	return 0 ;
}

sub test {
	my ($test_id,$scorer,$params,$code,$codes, $msg) = @_ ;
	
	my $command = "$scorer $params UnitTesting >stdout 2>stderr" ;
	print STDERR "Test $test_id : $command " ;
	my $rc = system($command)/256 ;
	if ($rc ==$code) {
		print STDERR " RC = $rc ($codes->{$rc}) . OK\n" ;
	} else {
		die " RC = $rc ($codes->{$rc}). Expected $code ($codes->{$code}). Failed" . ((defined $msg) ? ". $msg" : "") ;
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
	my ($test_id,$scorer,$engine_dir,$dir,$prefix,$flag,$codes,$message) = @_ ;

	my $command = "$scorer $engine_dir $dir $prefix $flag UnitTesting >stdout 2>stderr" ;
	print STDERR "Test $test_id : $command " ;
	my $rc = system($command) ;
	die " RC = $rc ($codes->{$rc}). Failed" if ($rc != 0) ;
	
	if (find("$dir/$prefix.Scores.txt",$message) == 1) {
		print STDERR " Found $message. OK\n" ;
	} else {
		die " Cannot find $message. Failed" ;
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