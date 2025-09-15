#!/usr/bin/env perl 
use strict;
use Getopt::Long;
use FileHandle;

use lib "H:/MR/Projects/Scripts/Perl-modules";

use CompareAnalysis;

### functions

sub open_file {
    my ($fn, $mode) = @_;
    
	print STDERR "Opening file $fn in mode $mode\n";
    $fn = "/dev/stdin" if ($fn eq "-");
    my $fh = FileHandle->new($fn, $mode) or die "Cannot open $fn in mode $mode: $!";

	return $fh;
}

sub safe_exec {
	my ($cmd, $warn) = ("", 0);

	($cmd, $warn) = @_ if (@_ == 2);
	($cmd) = @_ if (@_ == 1);
	die "Wrong number of arguments to safe_exec()" if (@_ > 2);
	
	print STDERR "\"$cmd\" starting on " . `date` ;
	my $rc = system($cmd);
	print STDERR "\"$cmd\" finished execution on " . `date`;
	die "Bad exit code $rc" if ($rc != 0 and $warn == 0);
	warn "Bad exit code $rc" if ($rc != 0);
}

# convert bin matrix (after bin2txt) to the engine input format (20 lines per panel)
sub txt2eng {
	my ($in_fn, $out_fn) = @_;
	my $in = open_file($in_fn, "r");
	my $out = open_file($out_fn, "w");
	
	while (<$in>) {
		chomp;
		my @F = split;
		map {$out->print(join("\t", int($F[0]), $_, int($F[1]), $F[8 + $_]) . "\n")} grep {$F[8+$_] != -1} (1..20);
	}
	$in->close;
	$out->close;
}

# convert bin matrix (after bin2txt) and demographics to expanded input to engine, where each id is expanded to several ids - one per each CBC (with it's full history)
sub txt2expanded_eng {
	my ($inData,$outData,$inDmg,$outDmg) = @_ ;

	my %counters ;
	my $in = open_file($inData, "r");
	my $out = open_file($outData, "w");
	
	my @lines = () ;
	while (<$in>) {
		chomp;
		my @F = split;
		@lines = () if ((scalar(@lines) == 0) or ($F[0] != $lines[0]->[0])) ;

		my $ngood = scalar grep {$F[8+$_] != -1} (1..20) ;
		if ($ngood) {
			push @lines,\@F ;

			my $cnt = scalar @lines ;
			$counters{int($lines[0]->[0])} = $cnt ;
			foreach my $line (@lines) {
				map {$out->print(join("\t", int($line->[0])."_$cnt", $_, int($line->[1]), $line->[8 + $_]) . "\n")} grep {$line->[8+$_] != -1} (1..20);
			}
		}
	}
	$in->close;
	$out->close;
	
	$in = open_file($inDmg, "r") ;
	$out = open_file($outDmg, "w") ;
	
	while (<$in>) {
		chomp ;
		my ($id,@line) = split ;
		map {$out->print ("$id\_$_ @line\n")} (1..$counters{$id}) if (exists $counters{$id}) ;
	}
}

# convert demographics file to a tab separated format
sub dmg2tsv {
	my ($in_fn, $out_fn) = @_;
	my $in = open_file($in_fn, "r");
	my $out = open_file($out_fn, "w");

	while (<$in>) {
		# print STDERR $_;
		s/ /\t/g;
		s/^/1\t/;
		# print STDERR $_;
		$out->print($_);
	}
	$in->close;
	$out->close;
}

# convert engine input to the product emulator input format (20 lines per panel)
sub eng2prod {
	my ($in_pref, $out_pref) = @_;
	
	# Data
	my $in = open_file("$in_pref.Data.txt", "r");
	my $out = open_file("$out_pref.Data.txt", "w");

#	my @C = qw(5041 5048 50221 50223 50224 50225 50226 50227 50228 50229 50230 50232 50234 50235 50236 50237 50239 50241 50233 50238); 
	my @C = (1 .. 20);
	my @M = qw(JAN FEB MAR APR MAY JUN JUL AUG SEP OCT NOV DEC);
	
	while (<$in>) {
		chomp;
		my ($id,$test_id,$date,$val) = split;
		$date = join("-", substr($date, 0, 4), $M[substr($date, 4, 2) - 1], substr($date, 6, 2));
		$out->print(join("\t",1,$id,$C[$test_id - 1],$date,$val)."\n") ;
	}
	$in->close;
	$out->close;
	
	dmg2tsv("$in_pref.Demographics.txt","$out_pref.Demographics.txt") ;
}

# Convert output of scorer on expanded input to input for performance measurements
sub de_expand_scores {
	my ($in_fn, $out_fn) = @_;
	my $in = open_file($in_fn, "r");
	my $out = open_file($out_fn, "w");

	my $M = {Jan => 1,  Feb => 2,  Mar => 3,  
			 Apr => 4,  May => 5,  Jun => 6, 
			 Jul => 7,  Aug => 8,  Sep => 9,  
			 Oct => 10, Nov => 11, Dec => 12
			 };

	$out->print("Predictions\n");			 
	while (<$in>) {
		chomp ;
		my @F = split /\t/;
		unless ($F[-2] == 2 or ($F[-2] == 1 and $F[-1] == 11)) { # No Score or Score not given to last CBC
			my @D = split(/-/, $F[1]);
			my $date = sprintf("%04d%02d%02d", $D[0], $M->{$D[1]}, $D[2]);
			my $id = ($F[0] =~/(\S+)_/) ? $1 : $F[0] ;
			$out->print("$id $date $F[2]\n") ;
		}
	}
	
	$in->close ;
	$out->close ;
}

# convert MS_CRC_Scorer date format to the standard 8-digit format				
my $month2num = {Jan => "01", Feb => "02", Mar => "03", Apr => "04", 
				 May => "05", Jun => "06", Jul => "07", Aug => "08", 
				 Sep => "09", Oct => "10", Nov => "11", Dec => "12", 
				};
				
sub std_mscrc_date {
	my ($str) = @_;
	my @D = split(/-/, $str);
	
	my $res = $D[0] . $month2num->{$D[1]} . $D[2];
	return $res;
}

sub mscrc_product_match_w_predict {
	my ($scorer_fn, $pred_fn, $match_output_fn, $demog_fn, $min_age, $max_age) = @_;
		
	# initializations

	my $scorer_fh = open_file($scorer_fn, "r");
	my $pred_fh = open_file($pred_fn, "r");
	my $match_output_fh = open_file($match_output_fn, "w");
	my $demog_fh = open_file($demog_fn, "r");
	
	# read birth years
	my $id2byear = {};
	while (<$demog_fh>) {
		chomp;
		my @F = split;
		die "Line $. in demographics file $demog_fn pf illegal format: $_\n" unless (@F == 3);
		$id2byear->{$F[0]} = $F[1];
	}
	
	# read MS_CRC_Scorer ouput
	my $scores = {};
	while (<$scorer_fh>) {
		chomp;
		my @F = split(/\t/);

		if ($F[2] eq "") {
			$match_output_fh->print("No score for: $_\n");
			next;
		}	
		push @{$scores->{$F[0]}}, [std_mscrc_date($F[1]), $F[2]];
	}

	# read predictions
	my $preds = {};
	while (<$pred_fh>) {
		next if ($. == 1); # skip first line
		chomp;
		
		my @F = split;
		die "Illegal date field in prediction file: $_" unless (length($F[1]) == 8);

		push @{$preds->{$F[0]}}, [$F[1], $F[2]];
	}

	# compare 
	my $has_diff = 0;
	for my $id (sort {$a <=> $b} keys %$scores) {
		if (not exists $preds->{$id}) {
			$match_output_fh->print("DIFF: id $id in MS_CRC_Scorer file but not in predict file\n");
			$has_diff = 1 ;
			next;
		}
		my @S = sort {$a->[0] <=> $b->[0]} @{$scores->{$id}};
		my @P = sort {$a->[0] <=> $b->[0]} @{$preds->{$id}};
	
		if ($S[-1]->[0] != $P[-1]->[0] or $S[-1]->[1] != $P[-1]->[1]) {
			$match_output_fh->print("DIFF: score and last pred for id $id are mismatching in single mode comparison\n");
			$has_diff = 1;
			next;
		}
		
		$match_output_fh->print("Scores and preds for $id are matching\n");
	}

	for my $id (sort {$a <=> $b} keys %$preds) {
		if (not exists $scores->{$id}) {
			if (not exists $id2byear->{$id}) {
				$match_output_fh->print("DIFF: id $id in predict file but lacks birth year in MS_CRC_Scorer demographics file\n");
				$has_diff = 1;
			}
			else {
				my @P = sort {$a->[0] <=> $b->[0]} @{$preds->{$id}};
				my $age_at_test = int(($P[-1]->[0] / 10000) - $id2byear->{$id});				
				if ($age_at_test > $max_age or $age_at_test < $min_age) {
					$match_output_fh->print("No score for id $id from predict file in MS_CRC_Scorer file due to age ($age_at_test) out of range ($min_age, $max_age)\n");
				}
				else {
					$match_output_fh->print("DIFF: $id in predict file but not in MS_CRC_Scorer file\n");
					$has_diff = 1;
				}
			}
		}
	}	
	
	return ($has_diff == 1);
}

### main ###
my $p = {
	exe_root => "H:/Medial/Projects/ColonCancer",
	script_root => "H:/Medial/Perl-scripts",
	MHS_dir => "W:/CRC/Maccabi_JUN2013",
	THIN_dir => "W:/CRC/THIN_MAR2013",
	method => "DoubleMatched",
	internal => "RF",
	emulator_dir => "C:/MSCRC",
	engine_ver => "V4.1",
	prev_ver_dir => "",
	msr_file => "H:/Medial/Resources/check_MSCRC_status_files/MeasuresForComparison",
	warn_only_on_diff => 0,
	override_version => 0,
	skip_install_and_export => 0,
	install_and_export_only => 0,
	only_diff_emulator_output => 0,
	allow_diffs_in_comparison => 0,
	combined => 0,
	skip_create_mhs_extrnlv_eng_input => 0,
	skip_eng_run_on_extrnlv => 0,
	skip_create_mhs_intrnlv_eng_input => 0,
	skip_eng_run_on_intrnlv => 0,
	gold_dir => "P:/MeScore_CRC/FrozenVersions/GoldTestVector",
	min_age => 40,
	max_age => 120,
};
	
GetOptions($p,
	"exe_root=s",         # base location of executables
	"script_root=s",      # location of perl scripts
	"MHS_dir=s",          # directory with Maccabi bin files (under Train - IntrnlV - ExtrnlV subdirs)
	"THIN_dir=s",         # directory with THIN bin files 
	"check_MSCRC_dir=s",  # directory of check_MSCRC_status run, should contain predictions by development version
	"method=s",			  # method of prediction
	"internal=s",		  # internal method for composite methods
	"work_dir=s",         # working directory
	# next line is commented since emulator_dir other than the default (C:/MSCRC) is not supported for now
	# "emulator_dir=s",     # main directory of the MSCRC produc emulator (input files are placed in 'Input' subdir and results are exported to 'Output' subdir
	"engine_ver=s",       # engine version identifier
	"prev_ver_dir=s",     # directory with performance files from previous version, for comparison ("NULL" to skip comparison)
	"msr_file=s",         # file with measurments for comparison
	"warn_only_on_diff",  # only issue a warning when a comparison identifies any difference (default behavior is to exit)
	"override_version",	  # override an existing version in Versions.txt
	"skip_install_and_export",  # assume that MSCRC software emulator installation and export of engine version were already done	
	"install_and_export_only",   # quit after installing the MSCRC software emulator and exporting the engine version
	"only_diff_emulator_output", # perform only the steps after creating emulator output files (in case online creation was interrupted)
	"allow_diffs_in_comparison", # allow differences when comparing against previous version (set to true only if there is a good reason for changes in prediction sets)
	"combined", # engine combines men and women
	"skip_create_mhs_extrnlv_eng_input",
	"skip_eng_run_on_extrnlv",
	"skip_create_mhs_intrnlv_eng_input",
	"skip_eng_run_on_intrnlv",
	"gold_dir=s",        # directory with test vector used to verify the version
	"min_age=i",         # minimal allowed age at time of test in MS_CRC_Scorer
	"max_age=i",         # maximal allowed age at time of test in MS_CRC_Scorer
);
	
print STDERR "Command line: $0 " . join(" ", @ARGV) . "\n";	
print STDERR "Parameters: " . join(", ", map {"$_ => $p->{$_}"} sort keys %$p) . "\n";

die "Unsupported value $p->{emulator_dir} for emulator dir, only default value C:/MSCRC is allowed" if ($p->{emulator_dir} ne "C:/MSCRC");

if (not $p->{only_diff_emulator_output}) {

	### create or update emulator installation (prepare in paralell a ForInstall directory with files needed for hardware installation)
	if (not $p->{skip_install_and_export}) {
		# create the emulator directory (not overriding it if already exists)
		safe_exec("mkdir -p $p->{emulator_dir}");
		# assign proper permissions for the emulator folder tio enable the installation
		safe_exec("icacls $p->{emulator_dir} /inheritance:r /grant:r \"SYSTEM\":(OI)(CI)F \"Users\":(OI)(CI)F");
		
		my $inst_dir = "$p->{work_dir}/ForInstall";
		safe_exec("mkdir -p $inst_dir");
		
		# taking care of permiossions
		safe_exec("icacls \"$p->{emulator_dir}\" /grant SYSTEM:(OI)(CI)F");
		
		# uninstall the MSCRC service (if installed)
		my $sysrc ;
		my $cmd = "sc GetDisplayName MSCRC" ;
		if (($sysrc = system($cmd)) ==0 ) {
			safe_exec("C:/Windows/Microsoft.NET/Framework64/v4.0.30319/InstallUtil.exe /u $p->{emulator_dir}/Programs/Service/MSCRC.JobsService.exe") ;
		} elsif ($sysrc != 36*256) {
			die "Command : $cmd failed. RC = $sysrc" ;
		}

		# creade data subdirs
		safe_exec("mkdir -p $p->{emulator_dir}/Input");
		safe_exec("mkdir -p $p->{emulator_dir}/Output");
		safe_exec("mkdir -p $p->{emulator_dir}/Data");
		
		# copy service files to emulator subdir
		safe_exec("mkdir -p $p->{emulator_dir}/Programs/Service");
		safe_exec("cp -f H:/Medial/Applications/MeScore_CRC/MSCRC/MSCRC.JobsService/bin/x64/Emulator/* $p->{emulator_dir}/Programs/Service"); 
		
		safe_exec("mkdir -p $inst_dir/Programs/Service");
		safe_exec("cp -f H:/Medial/Applications/MeScore_CRC/MSCRC/MSCRC.JobsService/bin/x64/Release/* $inst_dir/Programs/Service"); 

		# copy console executable files to emulator subdir 
		safe_exec("mkdir -p $p->{emulator_dir}/Programs/Console");
		safe_exec("cp -f H:/Medial/Applications/MeScore_CRC/MSCRC/MSCRC.Console/bin/x64/Emulator/* $p->{emulator_dir}/Programs/Console"); 
		
		safe_exec("mkdir -p $inst_dir/Programs/Console");
		safe_exec("cp -f H:/Medial/Applications/MeScore_CRC/MSCRC/MSCRC.Console/bin/x64/Release/* $inst_dir/Programs/Console"); 
	
		# copy Momitor and Shell files (install version only)
		safe_exec("mkdir -p $inst_dir/Programs/Monitor");
		safe_exec("cp -f H:/Medial/Applications/MeScore_CRC/MSCRC/MSCRC.Tools.Monitor/bin/x64/Release/* $inst_dir/Programs/Monitor");
		
		safe_exec("mkdir -p $inst_dir/Programs/Shell");
		safe_exec("cp -f H:/Medial/Applications/MeScore_CRC/MSCRC/MSCRC.Tools.Shell/bin/x64/Release/* $inst_dir/Programs/Shell");
		
		# copy certain text files to emulator subdir from Applications/MeScore_CRC/mscrc build
		safe_exec("mkdir -p $p->{emulator_dir}/Files");
		map {safe_exec("cp -f H:/Medial/Applications/MeScore_CRC/MSCRC/Files/$_ $p->{emulator_dir}/Files")} qw(CodesAndUnits.txt CodeConversions.txt ScoreResults.txt UnitConversions.txt);
		
		safe_exec("mkdir -p $inst_dir/Files");
		map {safe_exec("cp -f H:/Medial/Applications/MeScore_CRC/MSCRC/Files/$_ $inst_dir/Files")} qw(CodesAndUnits.txt CodeConversions.txt ScoreResults.txt UnitConversions.txt);

		# copy MS_CRC_scorer.exe to the emulator subdir, compute its CRC and update a certain XML file (...\Service\MSCRC.JobsService.exe.config); also change ErrorThresholdPercent to 100
		safe_exec("mkdir -p $p->{emulator_dir}/Programs/Scorer");
		safe_exec("cp -f H:/Medial/Projects/ColonCancer/MS_CRC_scorer/x64/Release/MS_CRC_scorer.exe $p->{emulator_dir}/Programs/Scorer/");
		
		safe_exec("mkdir -p $inst_dir/Programs/Scorer");
		safe_exec("cp -f H:/Medial/Projects/ColonCancer/MS_CRC_scorer/x64/Release/MS_CRC_scorer.exe $inst_dir/Programs/Scorer/");
		
		safe_exec("H:/Medial/Applications/MeScore_CRC/MSCRC.Tools/MSCRC.Tools.HashCalculator/bin/x64/Release/MSCRC.Tools.HashCalculator.exe H:/Medial/Projects/ColonCancer/MS_CRC_scorer/x64/Release/MS_CRC_scorer.exe > $p->{work_dir}/mscrc_scorer_hash");
		my $hash_fh = open_file("$p->{work_dir}/mscrc_scorer_hash", "r");
		my $hash_txt = join("", <$hash_fh>);
		$hash_fh->close;
		if (not $hash_txt =~ m/\'([0-9a-f]+)\'/) { 
			die "Illegal format of HashCalculator output: $hash_txt";
		}
		else {
			my $new_hash = $1;
			my $cfg_fh = open_file("$p->{emulator_dir}/Programs/Service/MSCRC.JobsService.exe.config", "r");
			my $cfg_new_fh = open_file("$p->{work_dir}/MSCRC.JobsService.exe.config.new", "w");

			while (<$cfg_fh>) {
				if (m/ExecutableHash/) {			
					print STDERR "Replacing ExecutablHash line in JobsService config file:\n$_   =>   ";   
					s/value=\"[0-9a-f]*\"/value=\"$new_hash\"/;
					print STDERR "$_\n";
					$cfg_new_fh->print($_);
				}
				elsif (m/ErrorThresholdPercent/) {			
					print STDERR "Replacing ErrorThresholdPercent line in JobsService config file:\n$_   =>   ";   
					s/\"\d+\"/\"100\"/;
					print STDERR "$_\n";
					$cfg_new_fh->print($_);				
				}
				else {
					$cfg_new_fh->print($_);
				}
			}
			$cfg_fh->close;
			$cfg_new_fh->close;
			safe_exec("cp -rf $p->{work_dir}/MSCRC.JobsService.exe.config.new $p->{emulator_dir}/Programs/Service/MSCRC.JobsService.exe.config");
			
			my $cfg_inst_fh = open_file("$inst_dir/Programs/Service/MSCRC.JobsService.exe.config", "r");
			my $cfg_inst_new_fh = open_file("$inst_dir/Programs/Service/MSCRC.JobsService.exe.config.new", "w");
			while (<$cfg_inst_fh>) {
				if (m/ExecutableHash/) {			
					print STDERR "Replacing ExecutablHash line in JobsService install config file:\n$_   =>   ";   
					s/value=\"[0-9a-f]*\"/value=\"$new_hash\"/;
					print STDERR "$_\n";
					$cfg_inst_new_fh->print($_);
				}
				else {
					$cfg_inst_new_fh->print($_);
				}
			}
			$cfg_inst_fh->close;
			$cfg_inst_new_fh->close;
			safe_exec("mv $inst_dir/Programs/Service/MSCRC.JobsService.exe.config.new $inst_dir/Programs/Service/MSCRC.JobsService.exe.config");
		}
		

		# install the service and attempt to start it
		safe_exec("C:/Windows/Microsoft.NET/Framework64/v4.0.30319/InstallUtil.exe $p->{emulator_dir}/Programs/Service/MSCRC.JobsService.exe");
		 
		# check if the service is actually running
		safe_exec("net start > $p->{work_dir}/services_status");
		my $serv_fh = open_file("$p->{work_dir}/services_status", "r");
		my $serv_txt = join("", <$serv_fh>);
		if (not $serv_txt =~ m/MeScore CRC Service/) { 
			die "MSCRC service failed to start";
		}
		$serv_fh->close;

	# Export engine from check_MSCRC_status directory to emulartor's versions directory
		my $engine_dir = "$p->{emulator_dir}/Programs/Scorer/Versions/$p->{engine_ver}" ;
		safe_exec("mkdir -p $engine_dir") ;
		
		my $engine_inst_dir = "$inst_dir/Programs/Scorer/Versions/$p->{engine_ver}" ;
		safe_exec("mkdir -p $engine_inst_dir") ;
		
		my @genders = qw/men women/ ;
		my @engine_genders = ($p->{combined}) ? ("combined") : @genders ;
		my $combined_flag = ($p->{combined}) ? " --combined" : "";
		if ($p->{method} eq "rfgbm") {
			my $setup = "$engine_dir/Setup" ;
			my $setup_fh = open_file("$engine_dir/Setup", "w") ; 

			$setup_fh->print("Features\tH:/Medial/Resources/MSCRC_Version_freezing_files/features_list\n") ;
			$setup_fh->print("Extra\tH:/Medial/Resources/MSCRC_Version_freezing_files/engine_extra_params.txt\n") ;
			foreach my $gender (@engine_genders) {
				$setup_fh->print($gender."Outliers\t$p->{check_MSCRC_dir}/learn_$gender\_outliers\n") ;
				$setup_fh->print($gender."Completion\t$p->{check_MSCRC_dir}/learn_$gender\_completion\n") ;
				$setup_fh->print($gender."Model\t$p->{check_MSCRC_dir}/learn_$gender\_predictor\n") ;
			}
			$setup_fh->close ;	
			safe_exec("H:/Medial/Projects/ColonCancer/predictor/x64/Release/export_engine.exe --method $p->{method} --setup $setup --dir $engine_dir $combined_flag") ;
			safe_exec("cp -rf $engine_dir/* $engine_inst_dir");
		} elsif ($p->{method} eq "DoubleMatched") {
			my $setup = "$engine_dir/Setup" ;
			my $setup_fh = open_file("$engine_dir/Setup", "w") ; 

			$setup_fh->print("Features\tH:/Medial/Resources/MSCRC_Version_freezing_files/features_list\n") ;
			$setup_fh->print("Extra\tH:/Medial/Resources/MSCRC_Version_freezing_files/engine_extra_params.txt\n") ;
			$setup_fh->print("Shift\t$p->{check_MSCRC_dir}/ShiftFile\n") ;
			
			foreach my $gender (@engine_genders) {
				$setup_fh->print($gender."Outliers\t$p->{check_MSCRC_dir}/learn_$gender\_outliers\n") ;
				$setup_fh->print($gender."Completion\t$p->{check_MSCRC_dir}/learn_$gender\_completion\n") ;
				$setup_fh->print($gender."Model\t$p->{check_MSCRC_dir}/learn_$gender\_predictor\n") ;
			}
			
			foreach my $gender (@genders) {
				$setup_fh->print($gender."Incidence\tH:/Medial/Resources/check_MSCRC_status_files/SEER_Incidence.$gender\n") ;
			}
			$setup_fh->close ;	
			
			safe_exec("H:/Medial/Projects/ColonCancer/predictor/x64/Release/export_engine.exe --method $p->{method} --setup $setup --dir $engine_dir --internal $p->{internal} $combined_flag") ;
			safe_exec("cp -rf $engine_dir/* $engine_inst_dir");
		
		} else {
			die "Method $p->{method} is not implemented yet" ;
		}

		my $version_fh = open_file("H:/Medial/Resources/MSCRC_Version_freezing_files/Versions.txt", "r") ;
		my @versions ;
		my $replace ;
		while(<$version_fh>) {
			chomp ;
			my ($name,$dir) = split ;
			if ($name eq $p->{engine_ver}) {
				die "Version $p->{engine_ver} already in Versions File" unless ($p->{override_version}) ;
				push @versions,"$name\t$engine_dir\n" ;
				$replace = 1 ;
			} else {
				push @versions,"$name\t$dir\n" ;
			}
		}
		$version_fh->close ;
		push @versions,"$p->{engine_ver}\t$engine_dir\n" if (! $replace) ;

		$version_fh = open_file("H:/Medial/Resources/MSCRC_Version_freezing_files/Versions.txt", "w") ;
		map {$version_fh->print($_)} @versions ;
		$version_fh->close ;
			
		my $clients_fh = open_file("H:/Medial/Resources/MSCRC_Version_freezing_files/Clients.txt","w") ;
		$clients_fh->print("ClientId\tName\tEngineVersionId\tCodeConversionId\tScoreResultId\n1\tTest\t$p->{engine_ver}\t1\t1\n") ;
		$clients_fh->close ;

		# copy Versions.txt and Client.txt from the Resources repository
		safe_exec("cp -f H:/Medial/Resources/MSCRC_Version_freezing_files/Versions.txt $p->{emulator_dir}/Files");
		safe_exec("cp -f H:/Medial/Resources/MSCRC_Version_freezing_files/Clients.txt $p->{emulator_dir}/Files");
		safe_exec("grep -w $p->{engine_ver} H:/Medial/Resources/MSCRC_Version_freezing_files/Versions.txt > $inst_dir/Files/Versions.txt");
		safe_exec("cp -f H:/Medial/Resources/MSCRC_Version_freezing_files/Clients.txt $inst_dir/Files");
	} # end of if on skip_install_and_export

	if ($p->{install_and_export_only}) {
		print STDERR "\nScript completed successfully\n";
		exit(0) ;
	}
	

	# check some input parameters
	die "Name of check_MSCRC_dir must begin with CheckMSCRC, input name \"$p->{check_MSCRC_dir}\" is illegal" unless ($p->{check_MSCRC_dir} =~ m/\/CheckMSCRC/);
	die "Name of work_dir must begin with PostCheckMSCRC, input name \"$p->{work_dir}\" is illegal" unless ($p->{work_dir} =~ m/\/PostCheckMSCRC/);
	safe_exec("mkdir -p $p->{work_dir}");

	# create engine and product emulator input data files from MHS ExtrnlV and THIN Train bin files
	my $utils_exe = "$p->{exe_root}/predictor/x64/Release/utils"; 
	
	if (not $p->{skip_create_mhs_extrnlv_eng_input}) {
		safe_exec("$utils_exe bin2txt $p->{MHS_dir}/ExtrnlV/men_validation.bin $p->{work_dir}/men_validation.txt");
		safe_exec("$utils_exe bin2txt $p->{MHS_dir}/ExtrnlV/women_validation.bin $p->{work_dir}/women_validation.txt");
		safe_exec("$utils_exe bin2txt $p->{THIN_dir}/Train/men_crc_and_stomach.bin $p->{work_dir}/men_thin_train.txt");
		safe_exec("$utils_exe bin2txt $p->{THIN_dir}/Train/women_crc_and_stomach.bin $p->{work_dir}/women_thin_train.txt");

		txt2eng("$p->{work_dir}/men_validation.txt", "$p->{work_dir}/men_validation.20140101.Data.txt");
		txt2eng("$p->{work_dir}/women_validation.txt", "$p->{work_dir}/women_validation.20140101.Data.txt");
		txt2eng("$p->{work_dir}/men_thin_train.txt", "$p->{work_dir}/men_thin_train.20140101.Data.txt");
		txt2eng("$p->{work_dir}/women_thin_train.txt", "$p->{work_dir}/women_thin_train.20140101.Data.txt");

		# dummy creation of demographics input files
		safe_exec("cp W:/CRC/AllDataSets/Demographics $p->{work_dir}/men_validation.20140101.Demographics.txt");
		safe_exec("cp W:/CRC/AllDataSets/Demographics $p->{work_dir}/women_validation.20140101.Demographics.txt");
		safe_exec("cp W:/CRC/AllDataSets/Demographics $p->{work_dir}/men_thin_train.20140101.Demographics.txt");
		safe_exec("cp W:/CRC/AllDataSets/Demographics $p->{work_dir}/women_thin_train.20140101.Demographics.txt");

		# create code files for product emulator
		safe_exec("cp H:/Medial/Resources/MSCRC_Version_freezing_files/MSCRC.Codes.txt $p->{work_dir}/Test.2014-JAN-01.set1.Codes.txt");
		safe_exec("cp H:/Medial/Resources/MSCRC_Version_freezing_files/MSCRC.Codes.txt $p->{work_dir}/Test.2014-JAN-01.set2.Codes.txt");
		safe_exec("cp H:/Medial/Resources/MSCRC_Version_freezing_files/MSCRC.Codes.txt $p->{work_dir}/Test.2014-JAN-01.set3.Codes.txt");
		safe_exec("cp H:/Medial/Resources/MSCRC_Version_freezing_files/MSCRC.Codes.txt $p->{work_dir}/Test.2014-JAN-01.set4.Codes.txt");
	}
	
	# run engine on MHS external validation and THIN Train and comapre engine outputs and predictions
	my $eng_exe = "$p->{exe_root}/MS_CRC_scorer/x64/Release/MS_CRC_scorer";
	if (not $p->{skip_eng_run_on_extrnlv}) {
		safe_exec("$eng_exe $p->{engine_ver} $p->{work_dir} men_validation.20140101 100");
		my $m1 = mscrc_product_match_w_predict("$p->{work_dir}/men_validation.20140101.Scores.txt", 
											   "$p->{check_MSCRC_dir}/MaccabiValidation_predictions.men",
											   "$p->{work_dir}/log.eng_vs_pred.men",
											   "$p->{work_dir}/men_validation.20140101.Demographics.txt",
											   $p->{min_age}, $p->{max_age});
		if ($m1 != 0) {
			print STDERR "WARNING: mismatches between $p->{work_dir}/men_validation.20140101.Scores.txt and $p->{check_MSCRC_dir}/MaccabiValidation_predictions.men\n";
			exit(1) unless ($p->{warn_only_on_diff});
		}
		
		safe_exec("$eng_exe $p->{engine_ver} $p->{work_dir} women_validation.20140101 100");
		my $m2 = mscrc_product_match_w_predict("$p->{work_dir}/women_validation.20140101.Scores.txt", 
											   "$p->{check_MSCRC_dir}/MaccabiValidation_predictions.women",
											   "$p->{work_dir}/log.eng_vs_pred.women",
											   "$p->{work_dir}/women_validation.20140101.Demographics.txt",
											   $p->{min_age}, $p->{max_age});
		if ($m2 != 0) {
			print STDERR "WARNING: mismatches between $p->{work_dir}/women_validation.20140101.Scores.txt and $p->{check_MSCRC_dir}/MaccabiValidation_predictions.women\n";
			exit(1) unless ($p->{warn_only_on_diff});
		}	

		safe_exec("$eng_exe $p->{engine_ver} $p->{work_dir} men_thin_train.20140101 100");
		my $m3 = mscrc_product_match_w_predict("$p->{work_dir}/men_thin_train.20140101.Scores.txt", 
											   "$p->{check_MSCRC_dir}/THIN_Train_predictions.men",
											   "$p->{work_dir}/log.eng_vs_pred.thin_men",
											   "$p->{work_dir}/men_thin_train.20140101.Demographics.txt",
											   $p->{min_age}, $p->{max_age});
		if ($m3 != 0) {
			print STDERR "WARNING: mismatches between $p->{work_dir}/men_thin_train.20140101.Scores.txt and $p->{check_MSCRC_dir}/THIN_Train_predictions.men\n";
			exit(1) unless ($p->{warn_only_on_diff});
		}
		
		safe_exec("$eng_exe $p->{engine_ver} $p->{work_dir} women_thin_train.20140101 100");
		my $m4 = mscrc_product_match_w_predict("$p->{work_dir}/women_thin_train.20140101.Scores.txt", 
											   "$p->{check_MSCRC_dir}/THIN_Train_predictions.women",
											   "$p->{work_dir}/log.eng_vs_pred.thin_women",
											   "$p->{work_dir}/women_thin_train.20140101.Demographics.txt",
											   $p->{min_age}, $p->{max_age});
		if ($m4 != 0) {
			print STDERR "WARNING: mismatches between $p->{work_dir}/women_thin_train.20140101.Scores.txt and $p->{check_MSCRC_dir}/THIN_Train_predictions.women\n";
			exit(1) unless ($p->{warn_only_on_diff});
		}
	}
	
	# Expand Maccabi IntrnlV and THIN IntrnlV + ExtrnlV
	if (not $p->{skip_create_mhs_intrnlv_eng_input}) {
		safe_exec("$utils_exe bin2txt $p->{MHS_dir}/IntrnlV/men_validation.bin $p->{work_dir}/MHS_intrnlv_men.txt");
		safe_exec("$utils_exe bin2txt $p->{MHS_dir}/IntrnlV/women_validation.bin $p->{work_dir}/MHS_intrnlv_women.txt");
		safe_exec("$utils_exe bin2txt $p->{THIN_dir}/IntrnlV/men_validation.bin $p->{work_dir}/THIN_intrnlv_men.txt");
		safe_exec("$utils_exe bin2txt $p->{THIN_dir}/IntrnlV/women_validation.bin $p->{work_dir}/THIN_intrnlv_women.txt");
		safe_exec("$utils_exe bin2txt $p->{THIN_dir}/ExtrnlV/men_validation.bin $p->{work_dir}/THIN_extrnlv_men.txt");
		safe_exec("$utils_exe bin2txt $p->{THIN_dir}/ExtrnlV/women_validation.bin $p->{work_dir}/THIN_extrnlv_women.txt");
		safe_exec("cat $p->{work_dir}/THIN_intrnlv_men.txt $p->{work_dir}/THIN_extrnlv_men.txt > $p->{work_dir}/THIN_validation_men.txt");
		safe_exec("cat $p->{work_dir}/THIN_intrnlv_women.txt $p->{work_dir}/THIN_extrnlv_women.txt > $p->{work_dir}/THIN_validation_women.txt");

		txt2expanded_eng("$p->{work_dir}/MHS_intrnlv_men.txt", "$p->{work_dir}/MHS_intrnlv_men.20140101.Data.txt","W:/CRC/AllDataSets/Demographics", "$p->{work_dir}/MHS_intrnlv_men.20140101.Demographics.txt");
		txt2expanded_eng("$p->{work_dir}/MHS_intrnlv_women.txt", "$p->{work_dir}/MHS_intrnlv_women.20140101.Data.txt","W:/CRC/AllDataSets/Demographics", "$p->{work_dir}/MHS_intrnlv_women.20140101.Demographics.txt");
		txt2expanded_eng("$p->{work_dir}/THIN_validation_men.txt", "$p->{work_dir}/THIN_validation_men.20140101.Data.txt","W:/CRC/AllDataSets/Demographics", "$p->{work_dir}/THIN_validation_men.20140101.Demographics.txt");
		txt2expanded_eng("$p->{work_dir}/THIN_validation_women.txt", "$p->{work_dir}/THIN_validation_women.20140101.Data.txt","W:/CRC/AllDataSets/Demographics", "$p->{work_dir}/THIN_validation_women.20140101.Demographics.txt");

		eng2prod("$p->{work_dir}/MHS_intrnlv_men.20140101", "$p->{work_dir}/Test.2014-JAN-01.set1") ;
		eng2prod("$p->{work_dir}/MHS_intrnlv_women.20140101", "$p->{work_dir}/Test.2014-JAN-01.set2") ;
		eng2prod("$p->{work_dir}/THIN_validation_men.20140101", "$p->{work_dir}/Test.2014-JAN-01.set3") ;
		eng2prod("$p->{work_dir}/THIN_validation_women.20140101", "$p->{work_dir}/Test.2014-JAN-01.set4") ;
	}
	
	if (not $p->{skip_eng_run_on_intrnlv}) {
		# run engine on expanded Maccabi IntrnlV and THIN IntrnlV + ExtrnlV
		safe_exec("$eng_exe $p->{engine_ver} $p->{work_dir} MHS_intrnlv_men.20140101 100");
		safe_exec("$eng_exe $p->{engine_ver} $p->{work_dir} MHS_intrnlv_women.20140101 100");
		safe_exec("$eng_exe $p->{engine_ver} $p->{work_dir} THIN_validation_men.20140101 100");
		safe_exec("$eng_exe $p->{engine_ver} $p->{work_dir} THIN_validation_women.20140101 100");

		# preprare expanded output of engine to performance measurements
		de_expand_scores("$p->{work_dir}/MHS_intrnlv_men.20140101.Scores.txt","$p->{work_dir}/MHS_intrnlv_men.20140101.predictions") ;
		de_expand_scores("$p->{work_dir}/MHS_intrnlv_women.20140101.Scores.txt","$p->{work_dir}/MHS_intrnlv_women.20140101.predictions") ;
		de_expand_scores("$p->{work_dir}/THIN_validation_men.20140101.Scores.txt","$p->{work_dir}/THIN_validation_men.20140101.predictions") ;
		de_expand_scores("$p->{work_dir}/THIN_validation_women.20140101.Scores.txt","$p->{work_dir}/THIN_validation_women.20140101.predictions") ;
	}
	
	my $ba_exe = "$p->{exe_root}/AnalyzeScores/x64/Release/bootstrap_analysis";
	my $ba_args = "--nbin_types=0 --params=H:/Medial/Resources/check_MSCRC_status_files/parameters_files/parameters_file --dir=W:/CRC/AllDataSets/save.28apr2014.before_thin_mar2014/Directions.crc --byear=W:/CRC/AllDataSets/save.28apr2014.before_thin_mar2014/Byears --censor=W:/CRC/AllDataSets/save.28apr2014.before_thin_mar2014/Censor --reg=W:/CRC/AllDataSets/save.28apr2014.before_thin_mar2014/Registry.mrf";

	safe_exec("$ba_exe --in=$p->{work_dir}/MHS_intrnlv_men.20140101.predictions --out=$p->{work_dir}/Analysis.MHS_intrnlv_men.20140101 $ba_args 2> $p->{work_dir}/log.analysis.MHS_intrnlv_men.20140101"); 
	safe_exec("$ba_exe --in=$p->{work_dir}/MHS_intrnlv_women.20140101.predictions --out=$p->{work_dir}/Analysis.MHS_intrnlv_women.20140101 $ba_args 2> $p->{work_dir}/log.analysis.MHS_intrnlv_women.20140101"); 
	safe_exec("$ba_exe --in=$p->{work_dir}/THIN_validation_men.20140101.predictions --out=$p->{work_dir}/Analysis.THIN_validation_men.20140101 $ba_args 2> $p->{work_dir}/log.analysis.THIN_validation_men.20140101"); 
	safe_exec("$ba_exe --in=$p->{work_dir}/THIN_validation_women.20140101.predictions --out=$p->{work_dir}/Analysis.THIN_validation_women.20140101 $ba_args 2> $p->{work_dir}/log.analysis.THIN_validation_women.20140101"); 
	

	
	# compare against performance metrics of a previous version



	if ($p->{prev_ver_dir} ne "NULL") {
	
		safe_exec("$ba_exe --in=$p->{prev_ver_dir}/MHS_intrnlv_men.20140101.predictions --out=$p->{work_dir}/Prev.Analysis.MHS_intrnlv_men.20140101 $ba_args 2> $p->{work_dir}/prev.log.analysis.MHS_intrnlv_men.20140101"); 
		safe_exec("$ba_exe --in=$p->{work_dir}/MHS_intrnlv_women.20140101.predictions --out=$p->{work_dir}/Prev.Analysis.MHS_intrnlv_women.20140101 $ba_args 2> $p->{work_dir}/prev.log.analysis.MHS_intrnlv_women.20140101"); 
		safe_exec("$ba_exe --in=$p->{work_dir}/THIN_validation_men.20140101.predictions --out=$p->{work_dir}/Prev.Analysis.THIN_validation_men.20140101 $ba_args 2> $p->{work_dir}/prev.log.analysis.THIN_validation_men.20140101"); 
		safe_exec("$ba_exe --in=$p->{work_dir}/THIN_validation_women.20140101.predictions --out=$p->{work_dir}/Prev.Analysis.THIN_validation_women.20140101 $ba_args 2> $p->{work_dir}/prev.log.analysis.THIN_validation_women.20140101"); 
		
		my $cfl_fh = open_file("$p->{work_dir}/CurrentFilesList", "w");
		$cfl_fh->print("MHS\tmen\t$p->{work_dir}/Analysis.MHS_intrnlv_men.20140101\n");
		$cfl_fh->print("MHS\twomen\t$p->{work_dir}/Analysis.MHS_intrnlv_women.20140101\n");	
		$cfl_fh->print("THIN\tmen\t$p->{work_dir}/Analysis.THIN_validation_men.20140101\n");
		$cfl_fh->print("THIN\twomen\t$p->{work_dir}/Analysis.THIN_validation_women.20140101\n");	
		$cfl_fh->close;
	
		my $pfl_fh = open_file("$p->{work_dir}/PrevFilesList", "w");
		$pfl_fh->print("MHS\tmen\t$p->{work_dir}/Prev.Analysis.MHS_intrnlv_men.20140101\n");
		$pfl_fh->print("MHS\twomen\t$p->{work_dir}/Prev.Analysis.MHS_intrnlv_women.20140101\n");	
		$pfl_fh->print("THIN\tmen\t$p->{work_dir}/Prev.Analysis.THIN_validation_men.20140101\n");
		$pfl_fh->print("THIN\twomen\t$p->{work_dir}/Prev.Analysis.THIN_validation_women.20140101\n");	
		$pfl_fh->close;
		
		my $compare_lists = {Current => "$p->{work_dir}/CurrentFilesList",
							 GoldStandard => "$p->{work_dir}/PrevFilesList"
							};	

		my  ($err_code, $errors) = CompareAnalysis::strict_compare_analysis($compare_lists, $p->{msr_file}, 
																			$p->{allow_diffs_in_comparison}, $p->{allow_diffs_in_comparison});
		print STDERR "Error code from strict_compare_analysis: $err_code\n";
		if ($err_code == -1) {
			my $error = $errors->[0] ;
			die "Failed : $error" ;
		} else {
			map {print STDERR "Problem : $_\n"} @$errors ;
			die "Candidate version is not as good as previous version in certain measures" if (@$errors > 0);
		}
	}

	# copy product emulator input files to emulator Input subdir and remove corresponding output files
	safe_exec("cp -f $p->{work_dir}/Test.2014-JAN-01.set* $p->{emulator_dir}/Input/");
	safe_exec("cp -f $p->{gold_dir}/Test.2000-JAN-01.Gold.* $p->{emulator_dir}/Input/");
	safe_exec("rm -f $p->{emulator_dir}/Output/*");
	print STDERR "Use MSCRC product emulator GUI to run on 2014-JAN-01 set1 - set4, and on 2000-JAN-01.Gold, export results and then exit the console";
	safe_exec("$p->{emulator_dir}/Programs/Console/MSCRC.Console.exe");

} # of only_diff_emulator_output

# copy results on gold test vector to a designated directory
safe_exec("mkdir -p $p->{work_dir}/GoldTestVector");
safe_exec("cp -f $p->{gold_dir}/Test.2000-JAN-01.Gold.* $p->{work_dir}/GoldTestVector");
safe_exec("cp -f $p->{emulator_dir}/Output/TEST.2000-JAN-01.Gold.Scores.txt $p->{work_dir}/GoldTestVector");

# copy product emulator output files from C:/MSCRC/Output and compare with engine ouputs
safe_exec("tail -n +19  $p->{emulator_dir}/Output/TEST.2014-JAN-01.set1.Scores.txt > $p->{work_dir}/TEST.2014-JAN-01.set1.Scores.txt");
safe_exec("tail -n +19  $p->{emulator_dir}/Output/TEST.2014-JAN-01.set2.Scores.txt > $p->{work_dir}/TEST.2014-JAN-01.set2.Scores.txt");
safe_exec("tail -n +19  $p->{emulator_dir}/Output/TEST.2014-JAN-01.set3.Scores.txt > $p->{work_dir}/TEST.2014-JAN-01.set3.Scores.txt");
safe_exec("tail -n +19  $p->{emulator_dir}/Output/TEST.2014-JAN-01.set4.Scores.txt > $p->{work_dir}/TEST.2014-JAN-01.set4.Scores.txt");

# diff product emulator outputs against engine outputs on Maccabi ExtrnlV files
safe_exec("cut -f 2,3,4 $p->{work_dir}/TEST.2014-JAN-01.set1.Scores.txt > $p->{work_dir}/TEST.2014-JAN-01.set1.Scores.for_diff.txt");
safe_exec("cut -f 2,3,4 $p->{work_dir}/TEST.2014-JAN-01.set2.Scores.txt > $p->{work_dir}/TEST.2014-JAN-01.set2.Scores.for_diff.txt");
safe_exec("cut -f 2,3,4 $p->{work_dir}/TEST.2014-JAN-01.set3.Scores.txt > $p->{work_dir}/TEST.2014-JAN-01.set3.Scores.for_diff.txt");
safe_exec("cut -f 2,3,4 $p->{work_dir}/TEST.2014-JAN-01.set4.Scores.txt > $p->{work_dir}/TEST.2014-JAN-01.set4.Scores.for_diff.txt");

safe_exec("cut -f 1,2,3 $p->{work_dir}/MHS_intrnlv_men.20140101.Scores.txt > $p->{work_dir}/MHS_intrnlv_men.20140101.Scores.for_diff.txt");
safe_exec("cut -f 1,2,3 $p->{work_dir}/MHS_intrnlv_women.20140101.Scores.txt > $p->{work_dir}/MHS_intrnlv_women.20140101.Scores.for_diff.txt");
safe_exec("cut -f 1,2,3 $p->{work_dir}/THIN_validation_men.20140101.Scores.txt > $p->{work_dir}/THIN_validation_men.20140101.Scores.for_diff.txt");
safe_exec("cut -f 1,2,3 $p->{work_dir}/THIN_validation_women.20140101.Scores.txt > $p->{work_dir}/THIN_validation_women.20140101.Scores.for_diff.txt");

safe_exec("diff $p->{work_dir}/TEST.2014-JAN-01.set1.Scores.for_diff.txt $p->{work_dir}/MHS_intrnlv_men.20140101.Scores.for_diff.txt > $p->{work_dir}/MHS_intrnlv_men.20140101.Scores.diff_prod_vs_engine", $p->{warn_only_on_diff});
safe_exec("diff $p->{work_dir}/TEST.2014-JAN-01.set2.Scores.for_diff.txt $p->{work_dir}/MHS_intrnlv_women.20140101.Scores.for_diff.txt > $p->{work_dir}/MHS_intrnlv_women.20140101.Scores.diff_prod_vs_engine", $p->{warn_only_on_diff});
safe_exec("diff $p->{work_dir}/TEST.2014-JAN-01.set3.Scores.for_diff.txt $p->{work_dir}/THIN_validation_men.20140101.Scores.for_diff.txt > $p->{work_dir}/THIN_validation_men.20140101.Scores.diff_prod_vs_engine", $p->{warn_only_on_diff});
safe_exec("diff $p->{work_dir}/TEST.2014-JAN-01.set4.Scores.for_diff.txt $p->{work_dir}/THIN_validation_women.20140101.Scores.for_diff.txt > $p->{work_dir}/THIN_validation_women.20140101.Scores.diff_prod_vs_engine", $p->{warn_only_on_diff});

print STDERR "\nScript completed successfully\n";


