#!/usr/bin/env perl 
# A Script for checking CRC Score status.

my $user;
BEGIN {
die "Unsupported operating system name: $^O" unless ($^O eq "MSWin32" or $^O eq "linux");
$user = `whoami`; chomp $user;
print STDERR "User $user is invoking script $0 on a $^O machine\n";
}

use strict;
use lib "//nas1/UsersData/$user/MR/Projects/Scripts/Perl-modules" ;
use CompareAnalysis qw(compare_analysis) ;
use PrepareDataForSPS qw(prepare_data_for_SPS) ;
use PrepareEngineFiles qw(rfgbm_prepare_engine_files) ;
use MedialUtils qw(correct_path_for_condor) ;

use File::stat ;
use File::Path qw( make_path );
use POSIX qw/strftime/ ;

die "Usage : check_MSCRC_status.pl ConfFile [StartStage EndStage]" if (@ARGV != 1 && @ARGV != 3) ;

# Prepare
my @methods = qw/RF RFGBM RFGBM2 GBM ENSGBM LP LM LUNG_GBM DoubleMatched TwoSteps QRF/ ;
my %methods = map {($_ => 1)} @methods ;

# Read parameters
my %conf ;
read_configuration_file($ARGV[0],\%conf) ;

my @required_keys = qw/WorkDir ProjectRoot Genders ScriptsRoot/ ;
map {die "Required key \'$_\' missing." if (! exists $conf{$_})} @required_keys ;

my $exe_arch = ($^O eq "MSWin32") ? "x64" : "Linux";
my $exe_suffix = ($^O eq "MSWin32") ? ".exe" : "";

my %in_execs = (
				utils => ["$conf{ProjectRoot}/predictor/$exe_arch/Release","utils$exe_suffix",""],
				learn => ["$conf{ProjectRoot}/predictor/$exe_arch/Release","learn$exe_suffix",""],
				full_cv => ["$conf{ProjectRoot}/predictor/$exe_arch/Release","full_cv$exe_suffix",""],
				predict => ["$conf{ProjectRoot}/predictor/$exe_arch/Release","predict$exe_suffix",""],
				shift_preds => ["$conf{ProjectRoot}/predictor/$exe_arch/Release","shift_preds$exe_suffix",""],
				analyze => ["$conf{ProjectRoot}/AnalyzeScores/$exe_arch/Release","bootstrap_analysis$exe_suffix",""],
				validate => ["$conf{ProjectRoot}/AnalyzeScores/$exe_arch/Release","validate_cutoffs$exe_suffix",""],
				) ;

my @stages = qw/Split Learn Predict Shift Analyze Validate ReAnalyzeForCompare Compare Export PostProcess HistoryAnalysis/ ;
my %stages = map {($stages[$_]=> $_)} (0..$#stages);

my ($start_stage,$end_stage) = (0,$#stages) ;
if (@ARGV == 3) {
	die "Unknown StartStage \'$ARGV[1]\'" unless (exists $stages{$ARGV[1]}) ;
	$start_stage = $stages{$ARGV[1]} ;
	
	die "Unknown EndStage \'$ARGV[2]\'" unless (exists $stages{$ARGV[2]}) ;
	$end_stage = $stages{$ARGV[2]} ;
}

my $work_dir = $conf{WorkDir} ;
my $no_run = (exists $conf{NoRun} and $conf{NoRun} ne "N") ;

my @genders = split ",",$conf{Genders} ;
map {die "Unknown gender \'$_\'" if ($_ ne "men" and $_ ne "women")} @genders ;
my $combined_learn = (exists $conf{CombinedLearn} and $conf{CombinedLearn} ne "N") ;

# Init - copy executable to working directory
my %execs ;
foreach my $type (keys %in_execs) {
	my ($from_dir,$exec,$to_file)= @{$in_execs{$type}} ;
	$to_file = $exec if ($to_file eq "");
	my $to_dir = $conf{WorkDir} ;
	if (-f "$from_dir/$exec") {
		run_cmd("cp $from_dir/$exec $to_dir/$to_file") if (! exists $conf{NoCopy} or $conf{NoCopy} eq "N") ;
		$execs{$type} = "$to_dir/$to_file" ;
	}
	else {
		print stderr "Warning: executable $from_dir/$exec is missing\n";
		$execs{$type} = "NULL";
	}
}

# Copy Extra Required Files
if (exists $conf{ExtraFiles}) {
	my @files = split ",",$conf{ExtraFiles} ;
	map {run_cmd("cp -f $_ $conf{WorkDir}")} @files ;
}

# Stage 1 - Splitting
if ($start_stage <= $stages{Split} and $end_stage >= $stages{Split}) {
	my @required_keys = qw/TrainingMatrixSuffix SplitN/ ;
	map {die "Required key \'$_\' missing." if (! exists $conf{$_})} @required_keys ;
	
	my $seed = (exists $conf{SplitSeed}) ? $conf{SplitSeed} : 1 ;

	my $in_dir = (exists $conf{TrainingMatrixDir}) ? $conf{TrainingMatrixDir} : $conf{WorkDir} ;
	my $out_dir = (exists $conf{SplitDir}) ? $conf{SplitDir} : $conf{WorkDir} ;
	my $type = $conf{TrainingMatrixSuffix} ;
	
	for my $gender (@genders) {
		run_cmd("$execs{utils} fold_split $in_dir/$gender\_$type.bin $conf{SplitN} $out_dir/$gender\_$type $seed > $work_dir/fold_split_$gender.stdout 2> $work_dir/fold_split_$gender.stderr")
	}
	
	if ($combined_learn) {
		run_cmd("$execs{utils} fold_split $in_dir/combined_$type.bin $conf{SplitN} $out_dir/combined_$type $seed > $work_dir/fold_split_combined.stdout 2> $work_dir/fold_split_combined.stderr")
	}
	
	print stderr "Successfully completed stage: Splitting\n";
	my $datestring = localtime();
	print stderr "Time: $datestring\n";
	print stderr "-------------------------------------------\n\n";
}

# Stage 2 - Learning & Full CV
if ($start_stage <= $stages{Learn} and $end_stage >= $stages{Learn}) {
	my @required_keys = qw/FeatureParams CondorLearnSubFile LearnExtraParams Method TrainingMatrixSuffix/ ;
	map {die "Required key \'$_\' missing." if (! exists $conf{$_})} @required_keys ;
	die "Unknown method \'$conf{Method}\'" if (! exists $methods{$conf{Method}}) ;	

	die "Combined-learning with Gender-Flag set to 0. Are you sure ? Add \'IgnoreGender := Y\' to configuration file if so." 
		if ($combined_learn and ((!exists $conf{IgnoreGender}) or ($conf{IgnoreGender} ne "Y")) and $conf{FeatureParams} =~ m/^G0/) ;
	
	my $extra_params = $conf{LearnExtraParams} ;
	$extra_params .= " --nfold $conf{LearnNFold}" if (exists $conf{LearnNFold}) ;
	$extra_params .= " --extraFeatures $conf{ExtraFeatures}" if (exists $conf{ExtraFeatures}) ;
	
	if ($conf{Method} eq "DoubleMatched" or $conf{Method} eq "TwoSteps") {
		die "InternalMethod required when doing DoubleMatched/TwoSteps learning" if (! exists($conf{InternalMethod})) ;
		die "Unknown internal method \'$conf{InternalMethod}\'" if (! exists $methods{$conf{InternalMethod}}) ;
		$extra_params .= " --internal_method $conf{InternalMethod}" ;
	}
	
	
	my $out_dir = (exists $conf{LearnOutDir}) ? $conf{LearnOutDir} : $conf{WorkDir} ;
	my $runner_file_name = "$out_dir/$conf{CondorLearnSubFile}" ;
	my $sub_file_info = {queue_list => [], dir => $out_dir, run => $runner_file_name};
	$sub_file_info->{req} = $conf{CondorLearnReq} if (exists $conf{CondorLearnReq}) ;
	$sub_file_info->{mem_req} = $conf{CondorLearnMemReq} if (exists $conf{CondorLearnMemReq}) ;
	$sub_file_info->{rank} = $conf{CondorLearnRank} if (exists $conf{CondorLearnRank}) ;
	
	my $use_completions = 0;
	$use_completions = 1 if (exists $conf{LearnExtraParams} and $conf{LearnExtraParams} =~ m/use_completions/);

	if (! exists $conf{SkipSplitLearning} or $conf{SkipSplitLearning} eq "N" ) {
		my @required_keys = qw/SplitN/ ;
		map {die "Required key \'$_\' missing." if (! exists $conf{$_})} @required_keys ;
				
		my $in_dir = (exists $conf{SplitDir}) ? $conf{SplitDir} : $conf{WorkDir} ;
		my $type = $conf{TrainingMatrixSuffix} ;
		
		my @learning_genders = ($combined_learn) ? qw/combined/ : @genders ;
		for my $i (1..$conf{SplitN}) {
			for my $gender (@learning_genders) {
			
				
				my %queue ;
				$queue{executable} = $execs{learn};
				$queue{initialdir} = $out_dir;
				$queue{in_size} = stat("$in_dir/$gender\_$type.train$i.bin")->size unless($no_run);
				$queue{use_completions} = $use_completions;
				$queue{arguments} = "--binFile $in_dir/$gender\_$type.train$i.bin ".
									"--logFile SplitLearnLog.$gender$i ".
									"--predictorFile learn_split_$gender\_predictor$i ".
									"--completionFile learn_split_$gender\_completion$i ".
									"--outliersFile learn_split_$gender\_outliers$i ". 
									"--featuresSelection $conf{FeatureParams} ".
									"--method $conf{Method} ".
									" $extra_params" ;
				if ($conf{Method} eq "DoubleMatched") {
					die "Incidence file required for DoubleMatched Learning" if (not exists $conf{IncidenceFilesDir} or 
																				 not exists $conf{SplitLearnIncidencePrefix}) ;
					$queue{arguments} .= " --incidence $conf{SplitLearnIncidencePrefix}.$gender" ;
					$queue{transfer_input_files} = "$conf{IncidenceFilesDir}/$conf{SplitLearnIncidencePrefix}.$gender" ;
					
				}				
				if ($use_completions) {
					if (exists $queue{transfer_input_files}) {
						$queue{transfer_input_files} .= ",learn_split_$gender\_completion$i";
					} else {
						$queue{transfer_input_files} = "learn_split_$gender\_completion$i";
					}
				}
				$queue{transfer_output_files} = "SplitLearnLog.$gender$i,learn_split_$gender\_outliers$i,learn_split_$gender\_completion$i,learn_split_$gender\_predictor$i" ;				
				$queue{output} = "learn_split_$gender.stdout$i" ;
				$queue{error} = "learn_split_$gender.stderr$i" ;
				$queue{log} = "$conf{CondorLearnSubFile}.log" ;

				push @{$sub_file_info->{queue_list}}, \%queue;
			}
		}
	}
	
	if (! exists $conf{SkipFullLearning} or $conf{SkipFullLearning} eq "N") {
		my @required_keys = qw/TrainingMatrixSuffix LearnExtraParams/ ;
		map {die "Required key \'$_\' missing." if (! exists $conf{$_})} @required_keys ;
			
		my $in_dir = (exists $conf{TrainingMatrixDir}) ? $conf{TrainingMatrixDir} : $conf{WorkDir} ;
		my $type = $conf{TrainingMatrixSuffix} ;		
		
		my @learning_genders = ($combined_learn) ? qw/combined/ : @genders ;		
		for my $gender (@learning_genders) {
		
			my %queue ;
			$queue{executable} = $execs{learn};
			$queue{initialdir} = $out_dir;
			$queue{in_size} = stat("$in_dir/$gender\_$type.bin")->size unless($no_run);
			$queue{use_completions} = $use_completions;
			$queue{arguments} = "--binFile $in_dir/$gender\_$type.bin ".
								"--logFile LearnLog.$gender ".
								"--predictorFile learn_$gender\_predictor ".
								"--completionFile learn_$gender\_completion ".
								"--outliersFile learn_$gender\_outliers ". 
								"--featuresSelection $conf{FeatureParams} ".
								"--method $conf{Method} ".
								" $extra_params" ;
			if ($conf{Method} eq "DoubleMatched") {
				die "Incidence file required for DoubleMatched Learning" if (not exists $conf{IncidenceFilesDir} or 
																			 not exists $conf{FullIncidencePrefix}) ;
				$queue{arguments} .= " --incidence $conf{FullIncidencePrefix}.$gender" ;
				$queue{transfer_input_files} = "$conf{IncidenceFilesDir}/$conf{FullIncidencePrefix}.$gender" ;
			}

			if ($use_completions) {
				if (exists $queue{transfer_input_files}) {
					$queue{transfer_input_files} .= ",learn_$gender\_completion";
				} else {
					$queue{transfer_input_files} = "learn_$gender\_completion";
				}
			}			
			
			$queue{transfer_output_files} = "LearnLog.$gender,learn_$gender\_outliers,learn_$gender\_completion,learn_$gender\_predictor" ;
			$queue{output} = "learn_$gender.stdout" ;
			$queue{error} = "learn_$gender.stderr" ;
			$queue{log} = "$conf{CondorLearnSubFile}.log" ;

			push @{$sub_file_info->{queue_list}}, \%queue;
		}
	}
	
	if (! exists $conf{SkipFullCV} or $conf{SkipFullCV} eq "N") {
	
		die "DoubleMatched not implemented in FullCV" if ($conf{Method} eq "DoubleMatched") ;
	
		my @required_keys = qw/FullCVNFold TrainingMatrixSuffix FullCVN FullCVExtraParams/ ;
		map {die "Required key \'$_\' missing." if (! exists $conf{$_})} @required_keys ;

		my $in_dir = (exists $conf{TrainingMatrixDir}) ? $conf{TrainingMatrixDir} : $conf{WorkDir} ;
		
		my @seeds = (exists $conf{FullCVSeeds}) ? (split ",",$conf{FullCVSeeds}) : 1..$conf{FullCVN} ;
		die "Illegal FullCV seeds \'%conf{FullCVSeeds}\'" if (scalar(@seeds) != $conf{FullCVN});
		
		my $nbins = (exists $conf{FullCVNBins}) ? $conf{FullCVNBins} : 10 ;
		my $type = $conf{TrainingMatrixSuffix} ;
		
		my $extra_params = "" ;
		$extra_params .= " --extraFeatures $conf{ExtraFeatures}" if (exists $conf{ExtraFeatures}) ;
		
		my @cv_genders = ($combined_learn) ? qw/combined/ : @genders ;
		for my $i (1..$conf{FullCVN}) {
			for my $gender (@genders) {
				my %queue ;
				$queue{executable} = $execs{full_cv};
				$queue{initialdir} = $out_dir;
				$queue{in_size} = ($conf{FullCVNFold} - 1) * stat("$in_dir/$gender\_$type.bin")->size unless ($no_run);
				my $seed = $seeds[$i-1] ;
				my $header = "$gender-$conf{Method}-FullCV$i" ;	
				$queue{arguments} = "--binFile $in_dir/$gender\_$type.bin ".
									"--logFile FullCVLog.$gender$i ".
									"--featuresSelection $conf{FeatureParams} ".
									"--method $conf{Method} ".
									"--nfold $conf{FullCVNFold} ".
									"--nbins $nbins ".
									"--predictOutFile full_cv_predictions.$gender$i ".
									"--header $header ".
									"--seed $seed ".
									"$extra_params ".
									$conf{FullCVExtraParams} ;

				$queue{transfer_output_files} = "FullCVLog.$gender$i,full_cv_predictions.$gender$i" ;	
				$queue{output} = "full_cv_$gender.stdout$i" ;
				$queue{error} = "full_cv_$gender.stderr$i" ;
				$queue{log} = "$conf{CondorLearnSubFile}.log" ;			

				push @{$sub_file_info->{queue_list}}, \%queue;
			}
		}	
	}

	process_submit_info($sub_file_info);
	
	# Split combined Full-CV predictions according to genders
	if ($combined_learn and (! exists $conf{SkipFullCV} or $conf{SkipFullCV} eq "N")) {
		my @required_keys = qw/DemFile/ ;
		
		
		map {die "Required key \'$_\' missing." if (! exists $conf{$_})} @required_keys ;	
		for my $i (1..$conf{FullCVN}) {
			for my $gender (@genders) {
				run_cmd("echo \"Predictions $gender-from-combined\" > full_cv_predictions.$gender$i") ;
				run_cmd("intersect.pl full_cv_predictions.combined$i $conf{DemFile} >> full_cv_predictions.$gender$i") ;
			}
		}
	}

	print stderr "Successfully completed stage: Learn\n";
	my $datestring = localtime();
	print stderr "Time: $datestring\n";
	print stderr "-------------------------------------------\n\n"	;
}

# Stage 3 - Predicting
if ($start_stage <= $stages{Predict} and $end_stage >= $stages{Predict}) {
	my @required_keys = qw/FeatureParams CondorPredictSubFile TrainingMatrixSuffix/ ;
	
	die "Combined-learning with Gender-Flag set to 0. Are you sure ? Add \'IgnoreGender := Y\' to configuration file if so." 
		if ($combined_learn and ((!exists $conf{IgnoreGender}) or ($conf{IgnoreGender} ne "Y")) and $conf{FeatureParams} =~ m/^G0/) ;
	
	my $predict_method ;
	if (exists $conf{PredictMethod}) {
		$predict_method = $conf{PredictMethod} ;
	} elsif (exists $conf{Method}) {
		$predict_method = $conf{Method} ;
	} else {
		die "Either PredictMethod or Method must be given for predicting" ;
	}
	
	my $extra_params = "" ;
	if ($predict_method eq "DoubleMatched" or $predict_method eq "TwoSteps") {
		my $predict_internal_method ;
		if (exists $conf{PredictInternalMethod}) {
			$predict_internal_method = $conf{PredictInternalMethod} ;
		} elsif (exists $conf{InternalMethod}) {
			$predict_internal_method = $conf{InternalMethod} ;
		} else {
			die "Either PredictInternalMethod or InternalMethod must be given for DoubleMatched/TwoSteps predicting" ;
		}
		$extra_params .= " --internal_method $predict_internal_method" ;
	}
	$extra_params .= " --extraFeatures $conf{ExtraFeatures}" if (exists $conf{ExtraFeatures}) ;	
	
	my $pred_dir = (exists $conf{LearnOutDir}) ? $conf{LearnOutDir} : $conf{WorkDir} ;
	map {die "Required key \'$_\' missing." if (! exists $conf{$_})} @required_keys ;

	my $out_dir = (exists $conf{PredictOutDir}) ? $conf{PredictOutDir} : $conf{WorkDir} ;
	my $runner_file_name = "$out_dir/$conf{CondorPredictSubFile}" ;
	my $sub_file_info = {queue_list => [], dir => $out_dir, run => $runner_file_name};
	$sub_file_info->{req} = $conf{CondorPredictReq} if (exists $conf{CondorPredictReq}) ;
	$sub_file_info->{mem_req} = $conf{CondorPredictMemReq} if (exists $conf{CondorPredictMemReq}) ;
	$sub_file_info->{rank} = $conf{CondorPredictRank} if (exists $conf{CondorPredictRank}) ;

	if (! exists $conf{SkipSplitPredicting} or $conf{SkipSplitPredicting} eq "N") {
		my @required_keys = qw/SplitN/ ;
		map {die "Required key \'$_\' missing." if (! exists $conf{$_})} @required_keys ;

		my $data_dir = (exists $conf{SplitDir}) ? $conf{SplitDir} : $conf{WorkDir} ;
		my $type = $conf{TrainingMatrixSuffix} ;
		
		for my $i (1..$conf{SplitN}) {
			for my $gender (@genders) {
				my $learn_gender = ($combined_learn) ? "combined" : $gender ;
				my %queue ;
				my $header = "$gender-$conf{Method}-PredictionOnTest$i" ;
				$queue{executable} = $execs{predict};
				$queue{initialdir} = $out_dir;
				$queue{in_size} = stat("$data_dir/$gender\_$type.test$i.bin")->size unless ($no_run);
				$queue{arguments} = "--binFile $data_dir/$gender\_$type.test$i.bin ".
									"--predictorFile learn_split_$learn_gender\_predictor$i ".
									"--outliersFile learn_split_$learn_gender\_outliers$i ".
									"--completionFile learn_split_$learn_gender\_completion$i ".
									"--logFile SplitPredLog.$gender$i ".
									"--featuresSelection $conf{FeatureParams} ".
									"--method $predict_method ".
									"--info $header ".
									"--predictOutFile split_predictions.$gender$i".
									" $extra_params" ;
				$queue{arguments} .= " $conf{PredictExtraParams}" if exists($conf{PredictExtraParams}) ;
				$queue{transfer_input_files} = "$pred_dir/learn_split_$learn_gender\_predictor$i,$pred_dir/learn_split_$learn_gender\_outliers$i,$pred_dir/learn_split_$learn_gender\_completion$i" ;
				if (exists $conf{IncidenceFilesDir} and exists $conf{SplitPredictIncidencePrefix}) {
					$queue{arguments} .= " --incidence $conf{SplitPredictIncidencePrefix}.$gender" ;
					$queue{transfer_input_files} .= ",$conf{IncidenceFilesDir}/$conf{SplitPredictIncidencePrefix}.$gender" ;
				}
				$queue{transfer_output_files} = "SplitPredLog.$gender$i,split_predictions.$gender$i" ;
				$queue{error} = "split_predict_$gender.stderr$i" ;
				$queue{log} = "$conf{CondorPredictSubFile}.log" ;

				push @{$sub_file_info->{queue_list}}, \%queue;
			}
		}
	}
	
	if (! exists $conf{SkipExternalPredicting} or $conf{SkipExternalPredicting} eq "N") {
		my @required_keys = qw/ExternalMatrixSuffix ExternalNames/ ;
		map {die "Required key \'$_\' missing." if (! exists $conf{$_})} @required_keys ;
		
		my $data_dir = (exists $conf{ExternalMatrixDir}) ? $conf{ExternalMatrixDir} : $conf{WorkDir} ;
		my $data_suffix = $conf{ExternalMatrixSuffix} ;
		my $data_names = $conf{ExternalNames} ;
		my $out_dir = (exists $conf{PredictOutDir}) ? $conf{PredictOutDir} : $conf{WorkDir} ;
		
		my @data_dir = split ",",$data_dir ;
		my @data_suffix = split ",",$data_suffix ;
		my @data_names = split ",",$data_names ;
		my @age_prior_prefix = (exists $conf{ExternalAgePriorsPrefix}) ? (split ",",$conf{ExternalAgePriorsPrefix}) : @data_dir ;
		die "Length mismatch of external validation inputs" if (scalar(@data_dir) != scalar(@data_suffix) or scalar(@data_dir) != scalar(@data_names) or scalar(@data_dir) != scalar(@age_prior_prefix)) ;
		
		for my $i (0..$#data_dir) {
			for my $gender (@genders) {
				my $learn_gender = ($combined_learn) ? "combined" : $gender ;
				my %queue ;
				my $data_file = "$data_dir[$i]/$gender\_$data_suffix[$i].bin" ;
				my $header = "$gender-$conf{Method}-Prediction-on-$data_names[$i]" ;
				$queue{executable} = $execs{predict};
				$queue{initialdir} = $out_dir;
				$queue{in_size} = stat($data_file)->size unless ($no_run);
				$queue{arguments} = "--binFile $data_file ".
									"--predictorFile learn_$learn_gender\_predictor ".
									"--outliersFile learn_$learn_gender\_outliers ".
									"--completionFile learn_$learn_gender\_completion ".
									"--logFile ExternalValidationPredLog$i.$gender ".
									"--featuresSelection $conf{FeatureParams} ".
									"--method $predict_method ".
									"--info $header ".
									"--predictOutFile $data_names[$i]\_predictions.$gender" .
									" $extra_params" ;

				$queue{arguments} .= " $conf{PredictExtraParams}" if exists($conf{PredictExtraParams}) ;
				$queue{transfer_input_files} = "$pred_dir/learn_$learn_gender\_predictor,$pred_dir/learn_$learn_gender\_outliers,$pred_dir/learn_$learn_gender\_completion" ;
				if (exists $conf{IncidenceFilesDir} and exists $conf{ExternalPredictIncidencePrefix}) {
					$queue{arguments} .= " --incidence $conf{ExternalPredictIncidencePrefix}.$gender" ;
					$queue{transfer_input_files} .= ",$conf{IncidenceFilesDir}/$conf{ExternalPredictIncidencePrefix}.$gender" ;
				}				
				$queue{transfer_output_files} = "ExternalValidationPredLog$i.$gender,$data_names[$i]\_predictions.$gender" ;
				$queue{error} = $data_names[$i]."_predict.$i.$gender.stderr" ;
				$queue{log} = "$conf{CondorPredictSubFile}.log" ;

				push @{$sub_file_info->{queue_list}}, \%queue;
			}
		}
	}
	
	if (! exists $conf{SkipInternalPredicting} or $conf{SkipInternalPredicting} eq "N") {
		my @required_keys = qw/InternalMatrixSuffix InternalNames/ ;
		map {die "Required key \'$_\' missing." if (! exists $conf{$_})} @required_keys ;
		
		my $data_dir = (exists $conf{InternalMatrixDir}) ? $conf{InternalMatrixDir} : $conf{WorkDir} ;
		my $data_suffix = $conf{InternalMatrixSuffix} ;
		my $data_names = $conf{InternalNames} ;
		my $out_dir = (exists $conf{PredictOutDir}) ? $conf{PredictOutDir} : $conf{WorkDir} ;
		
		my @data_dir = split ",",$data_dir ;
		my @data_suffix = split ",",$data_suffix ;
		my @data_names = split ",",$data_names ;
		my @age_prior_prefix = (exists $conf{InternalAgePriorsPrefix}) ? (split ",",$conf{ExternalAgePriorsPrefix}) : @data_dir ;
		die "Length mismatch of internal validation inputs" if (scalar(@data_dir) != scalar(@data_suffix) or scalar(@data_dir) != scalar(@data_names) or scalar(@data_dir) != scalar(@age_prior_prefix)) ;
		
		for my $gender (@genders) {
			my $learn_gender = ($combined_learn) ? "combined" : $gender ;
			for my $i (0..$#data_dir) {
				my %queue ;
				my $data_file = "$data_dir[$i]/$gender\_$data_suffix[$i].bin" ;
				print STDERR "Data file: $data_file\n";
				my $header = "$gender-$conf{Method}-Prediction-on-$data_names[$i]" ;
				$queue{executable} = $execs{predict};
				$queue{initialdir} = $out_dir;
				$queue{in_size} = stat($data_file)->size unless ($no_run);
				$queue{arguments} = "--binFile $data_file ".
									"--predictorFile learn_$learn_gender\_predictor ".
									"--outliersFile learn_$learn_gender\_outliers ".
									"--completionFile learn_$learn_gender\_completion ".
									"--logFile InternalValidationPredLog$i.$gender ".
									"--featuresSelection $conf{FeatureParams} ".
									"--method $predict_method ".
									"--info $header ".
									"--predictOutFile $data_names[$i]\_predictions.$gender" .
									" $extra_params" ;

				$queue{arguments} .= " $conf{PredictExtraParams}" if exists($conf{PredictExtraParams}) ;
				$queue{transfer_input_files} = "$pred_dir/learn_$learn_gender\_predictor,$pred_dir/learn_$learn_gender\_outliers,$pred_dir/learn_$learn_gender\_completion" ;	
				if (exists $conf{IncidenceFilesDir} and exists $conf{InternalPredictIncidencePrefix}) {
					$queue{arguments} .= " --incidence $conf{InternalPredictIncidencePrefix}.$gender" ;
					$queue{transfer_input_files} .= ",$conf{IncidenceFilesDir}/$conf{InternalPredictIncidencePrefix}.$gender" ;
				}
				$queue{transfer_output_files} = "InternalValidationPredLog$i.$gender,$data_names[$i]\_predictions.$gender" ;
				$queue{error} = $data_names[$i]."_predict.$i.$gender.stderr" ;
				$queue{log} = "$conf{CondorPredictSubFile}.log" ;

				push @{$sub_file_info->{queue_list}}, \%queue;
			}
		}
	}

	process_submit_info($sub_file_info);
	
	# Unite split predictions from all same-gender splits
	if (! exists $conf{SkipUniteSplitPreds} or $conf{SkipUniteSplitPreds} eq "N") {
		my @required_keys = qw/SplitN SplitFilesUnionPref/ ; 
		map {die "Required key \'$_\' missing." if (! exists $conf{$_})} @required_keys ;
		
		my $union = $conf{SplitFilesUnionPref} ;
		for my $gender (@genders) {
			my @gender_files = map {"$pred_dir/split_predictions.$gender$_"} (1..$conf{SplitN}) ;
			unite_preds(\@gender_files,"$pred_dir/$union\_predictions.$gender") unless ($no_run) ;
		}
	}
		
	# Combine split predictions for both genders	
	if (! exists $conf{SkipUniteSplitPreds} or $conf{SkipUniteSplitPreds} eq "N") {
		my @required_keys = qw/SplitFilesUnionPref/ ; 
		map {die "Required key \'$_\' missing." if (! exists $conf{$_})} @required_keys ;
		
		my $union = $conf{SplitFilesUnionPref} ;
		my @combine_files = map {"$pred_dir/$union\_predictions.$_"} @genders ;
		unite_preds(\@combine_files, "$pred_dir/$union\_predictions.combined") unless ($no_run) ;
	}
	
	# Combine FullCV predictions for both genders
	if (! exists $conf{SkipUniteFullCVPreds} or $conf{SkipUniteFullCVPreds} eq "N") {
		my @required_keys = qw/FullCVN/ ; 
		map {die "Required key \'$_\' missing." if (! exists $conf{$_})} @required_keys ;
		
		for my $id (1..$conf{FullCVN}) {
			my @combine_files = map {"$pred_dir/full_cv_predictions.$_$id"} @genders ;
			unite_preds(\@combine_files, "$pred_dir/full_cv_predictions.combined$id") unless ($no_run) ;
		}
	}
	
	# Combine Internal predictions for both genders
	if (! exists $conf{SkipUniteInternalPreds} or $conf{SkipUniteInternalPreds} eq "N") {
		my @required_keys = qw/InternalNames/ ; 
		map {die "Required key \'$_\' missing." if (! exists $conf{$_})} @required_keys ; 
		
		my @names = split ",",$conf{InternalNames} ;
		foreach my $name (@names) {
			my @combine_files = map {"$pred_dir/$name\_predictions.$_"} @genders ;
			unite_preds(\@combine_files, "$pred_dir/$name\_predictions.combined") unless ($no_run) ;
		}
	}
	
	# Combine External predictions for both genders
	if (! exists $conf{SkipUniteExternalPreds} or $conf{SkipUniteExternalPreds} eq "N") {
		my @required_keys = qw/ExternalNames/ ; 
		map {die "Required key \'$_\' missing." if (! exists $conf{$_})} @required_keys ; 
		
		my @names = split ",",$conf{ExternalNames} ;
		foreach my $name (@names) {
			my @combine_files = map {"$pred_dir/$name\_predictions.$_"} @genders ;
			unite_preds(\@combine_files, "$pred_dir/$name\_predictions.combined") unless ($no_run) ;
		}
	}
	
	print stderr "Successfully completed stage: Predict\n";
	my $datestring = localtime();
	print stderr "Time: $datestring\n";
	print stderr "-------------------------------------------\n\n"	;
}

# Stage 4 - Shift
if ($start_stage <= $stages{Shift} and $end_stage >= $stages{Shift} and not (exists $conf{SkipShift} and $conf{SkipShift} eq "Y")) {
	my @reauired_keys = qw/CondorShiftSubFile ShiftAgeRange ShiftTimeWindow ShiftFirstDate ShiftLastDate ShiftAnalysisParamsFile AnalysisDirectionsDir AnalysisDirectionsFile AnalysisCensorDir AnalysisCensorFile
						   AnalysisRegistryDir AnalysisRegistryFile SplitFilesUnionPref ShiftAnalysisFile ShiftFP ShiftScoreTarget ShiftParamsFile PreShiftSuffix/ ;
	map {die "Required key \'$_\' missing." if (! exists $conf{$_})} @required_keys ;
	
	my $union = $conf{SplitFilesUnionPref} ;		
	my $in_dir = (exists $conf{PredictOutDir}) ? $conf{PredictOutDir} : $conf{WorkDir} ;	
	my $out_dir = (exists $conf{ShiftOutDir}) ? $conf{ShiftOutDir} :  $conf{WorkDir} ;
	
	my $runner_file_name = "$out_dir/$conf{CondorShiftSubFile}" ;
	my $sub_file_info = {queue_list => [], dir => $out_dir, run => $runner_file_name};
	$sub_file_info->{req} = $conf{CondorShiftReq} if (exists $conf{CondorShiftReq}) ;
	$sub_file_info->{mem_req} = $conf{CondorShiftMemReq} if (exists $conf{CondorShiftMemReq}) ;
	$sub_file_info->{rank} = $conf{CondorShiftRank} if (exists $conf{CondorShiftRank}) ;	
	
	# Create Params File
	open (PRMS,">$out_dir/$conf{ShiftAnalysisParamsFile}") or die "Cannot open $out_dir/$conf{ShiftAnalysisParamsFile} for writing" ;
	print PRMS "TimeWindow $conf{ShiftTimeWindow}\n" ;
	print PRMS "AgeRange $conf{ShiftAgeRange}\n" ;
	print PRMS "FirstDate $conf{ShiftFirstDate}\n" ;
	print PRMS "LastDate $conf{ShiftLastDate}\n" ;
	close PRMS ;
	
	# Run Analysis
	run_cmd("cp -f $conf{AnalysisRegistryDir}/$conf{AnalysisRegistryFile} $out_dir") ;
	run_cmd("cp -f $conf{AnalysisRegistryDir}/$conf{AnalysisDirectionsFile} $out_dir") ;
	run_cmd("cp -f $conf{AnalysisRegistryDir}/$conf{AnalysisByearsFile} $out_dir") ;
	run_cmd("cp -f $conf{AnalysisRegistryDir}/$conf{AnalysisCensorFile} $out_dir") ;	
					
	my %queue ;
	$queue{executable} = $execs{analyze};
	$queue{initialdir} = $out_dir;
	$queue{in_size} = stat("$in_dir/$union\_predictions.combined")->size unless ($no_run);
	$queue{arguments} = "--in $union\_predictions.combined --out $conf{ShiftAnalysisFile} --params $conf{ShiftAnalysisParamsFile} --period -1 ".
						" --reg $conf{AnalysisRegistryFile} --byear $conf{AnalysisByearsFile} --censor $conf{AnalysisCensorFile} --dir $conf{AnalysisDirectionsFile}" ;
	$queue{transfer_input_files} = "$in_dir/$union\_predictions.combined,$out_dir/$conf{ShiftAnalysisParamsFile},$out_dir/$conf{AnalysisRegistryFile},$out_dir/$conf{AnalysisByearsFile},".
								   "$out_dir/$conf{AnalysisCensorFile},$out_dir/$conf{AnalysisDirectionsFile}" ;
	$queue{transfer_output_files} = "$conf{ShiftAnalysisFile}" ;
	$queue{output} = "ShiftAnalysis.stdout" ;
	$queue{error} = "ShiftAnalysis.stderr" ;
	$queue{log} = "$conf{CondorShiftSubFile}.log" ;

	push @{$sub_file_info->{queue_list}}, \%queue;
	process_submit_info($sub_file_info);
	
	# Build Shift File
	open (ANL,"$out_dir/$conf{ShiftAnalysisFile}") or die "Cannot open $out_dir/$conf{ShiftAnalysisFile} for reading" ;
	my @data ;
	while (<ANL>) {
		chomp; 
		my @line = split /\t/,$_ ;
		push @data,\@line ;
	}
	die "ShiftAnalysis file should have 2 lines" if (@data != 2) ;

	my ($col) = grep {$data[0]->[$_] eq "SCORE\@FP$conf{ShiftFP}-Mean"} (0..scalar(@{$data[0]})-1) ;
	my $score = $data[1]->[$col] ;
	
	open (OUT,">$out_dir/$conf{ShiftParamsFile}") or die "Cannot open $out_dir/$conf{ShiftParamsFile} for writing" ;
	print OUT "$score\t$conf{ShiftScoreTarget}\n" ;
	close OUT ;
	
	# Shift Predictions
	my @shift_genders = @genders ;
	push @shift_genders,"combined" if ($conf{AnalyzeCombined} eq "Y") ;
	
	my $orig = $conf{PreShiftSuffix} ;
	if (! exists $conf{SkipFullCVShift} or $conf{SkipFullCVShift} eq "N") {
		my @required_keys = qw/FullCVN/ ; 
		map {die "Required key \'$_\' missing." if (! exists $conf{$_})} @required_keys ;
		
		my $in_dir = (exists $conf{PredictOutDir}) ? $conf{PredictOutDir} : $conf{WorkDir} ;
		
		run_cmd("cp -f $conf{AnalysisParamsDir}/$conf{AnalysisParamsFile} $out_dir") ;
		
		for my $i (1..$conf{FullCVN}) {
			for my $gender (@shift_genders) {
				run_cmd("mv $in_dir/full_cv_predictions.$gender$i $in_dir/full_cv_predictions.$gender$i.$orig") ;
				run_cmd("$execs{shift_preds} $in_dir/full_cv_predictions.$gender$i.$orig $in_dir/full_cv_predictions.$gender$i $score $conf{ShiftScoreTarget}") ;
			}
		}
	}
	
	if (! exists $conf{SkipSplitShift} or $conf{SkipSplitShift} eq "N") {
		my @required_keys = qw/SplitN/ ; 
		map {die "Required key \'$_\' missing." if (! exists $conf{$_})} @required_keys ;
		
		my $in_dir = (exists $conf{PredictOutDir}) ? $conf{PredictOutDir} : $conf{WorkDir} ;
		for my $i (1..$conf{SplitN}) {
			for my $gender (@genders) {
				run_cmd("mv $in_dir/split_predictions.$gender$i $in_dir/split_predictions.$gender$i.$orig") ;
				run_cmd("$execs{shift_preds} $in_dir/split_predictions.$gender$i.$orig $in_dir/split_predictions.$gender$i $score $conf{ShiftScoreTarget}") ;
			}
		}
	}
	
	if (! exists $conf{SkipSplitUnionShift} or $conf{SkipSplitUnionShift} eq "N") {
		my @required_keys = qw/SplitFilesUnionPref/ ; 
		map {die "Required key \'$_\' missing." if (! exists $conf{$_})} @required_keys ;
		
		my $union = $conf{SplitFilesUnionPref} ;		
		my $in_dir = (exists $conf{PredictOutDir}) ? $conf{PredictOutDir} : $conf{WorkDir} ;
		
		for my $gender (@shift_genders) {
			run_cmd("mv $in_dir/$union\_predictions.$gender $in_dir/$union\_predictions.$gender.$orig") ;
			run_cmd("$execs{shift_preds} $in_dir/$union\_predictions.$gender.$orig $in_dir/$union\_predictions.$gender $score $conf{ShiftScoreTarget}") ;		
		}
	}
	
	if (! exists $conf{SkipInternalValidationShift} or $conf{SkipInternalValidationShift} eq "N") {
		my @required_keys = qw/InternalNames/ ; 
		map {die "Required key \'$_\' missing." if (! exists $conf{$_})} @required_keys ;
		
		my $in_dir = (exists $conf{PredictOutDir}) ? $conf{PredictOutDir} : $conf{WorkDir} ;
		my @names = split ",",$conf{InternalNames} ;
		
		for my $i (0..$#names) {
			my $name = $names[$i] ;
	
			for my $gender (@shift_genders) {
				run_cmd("mv $in_dir/$name\_predictions.$gender $in_dir/$name\_predictions.$gender.$orig") ;
				run_cmd("$execs{shift_preds} $in_dir/$name\_predictions.$gender.$orig $in_dir/$name\_predictions.$gender $score $conf{ShiftScoreTarget}") ;
			}
		}
	}
	
	if (! exists $conf{SkipExternalValidationShift} or $conf{SkipExternalValidationShift} eq "N") {
		my @required_keys = qw/ExternalNames/ ; 
		map {die "Required key \'$_\' missing." if (! exists $conf{$_})} @required_keys ;
		
		my $in_dir = (exists $conf{PredictOutDir}) ? $conf{PredictOutDir} : $conf{WorkDir} ;
		my @names = split ",",$conf{ExternalNames} ;

		for my $i (0..$#names) {
			my $name = $names[$i] ;
	
			for my $gender (@shift_genders) {
				run_cmd("mv $in_dir/$name\_predictions.$gender $in_dir/$name\_predictions.$gender.$orig") ;
				run_cmd("$execs{shift_preds} $in_dir/$name\_predictions.$gender.$orig $in_dir/$name\_predictions.$gender $score $conf{ShiftScoreTarget}") ;
			}
		}
	}

	print stderr "Successfully completed stage: Shift\n";
	my $datestring = localtime();
	print stderr "Time: $datestring\n";
	print stderr "-------------------------------------------\n\n"	;	
}
	
# Stage 5 - Analyzing Scores
if ($start_stage <= $stages{Analyze} and $end_stage >= $stages{Analyze}) {
	my @required_keys = qw/CondorAnalysisSubFile AnalysisParamsDir AnalysisParamsFile 
							AnalysisDirectionsDir AnalysisCensorDir AnalysisRegistryDir 
							AnalysisByearsDir AnalysisDirectionsFile AnalysisCensorFile 
							AnalysisRegistryFile AnalysisByearsFile AnalyzeCombined/ ; 
	map {die "Required key \'$_\' missing." if (! exists $conf{$_})} @required_keys ;
	
	my $out_dir = (exists $conf{AnalysisOutDir}) ? $conf{AnalysisOutDir} :  $conf{WorkDir} ;

	my $runner_file_name = "$out_dir/$conf{CondorAnalysisSubFile}" ;
	my $sub_file_info = {queue_list => [], dir => $out_dir, run => $runner_file_name};
	$sub_file_info->{req} = $conf{CondorAnalysisReq} if (exists $conf{CondorAnalysisReq}) ;
	$sub_file_info->{mem_req} = $conf{CondorAnalysisMemReq} if (exists $conf{CondorAnalysisMemReq}) ;
	$sub_file_info->{rank} = $conf{CondorAnalysisRank} if (exists $conf{CondorAnalysisRank}) ;
	
	my @analysis_genders = @genders ;
	push @analysis_genders,"combined" if ($conf{AnalyzeCombined} eq "Y") ;
	
	my $nruns = 0 ;

	my $params ;
	$params = "--reg $conf{AnalysisRegistryFile} --byear $conf{AnalysisByearsFile} --censor $conf{AnalysisCensorFile} --dir $conf{AnalysisDirectionsFile}" ;
	$params .= " $conf{AnalysisParams}" if (exists $conf{AnalysisParams}) ;
	
	run_cmd("cp -f $conf{AnalysisRegistryDir}/$conf{AnalysisRegistryFile} $out_dir") ;
	run_cmd("cp -f $conf{AnalysisDirectionsDir}/$conf{AnalysisDirectionsFile} $out_dir") ;
	run_cmd("cp -f $conf{AnalysisByearsDir}/$conf{AnalysisByearsFile} $out_dir") ;
	run_cmd("cp -f $conf{AnalysisCensorDir}/$conf{AnalysisCensorFile} $out_dir") ;
	run_cmd("cp -f $conf{AnalysisParamsDir}/$conf{AnalysisParamsFile} $out_dir") ;
	
	if (! exists $conf{SkipFullCVAnalysis} or $conf{SkipFullCVAnalysis} eq "N") {
		my @required_keys = qw/FullCVN/ ; 
		map {die "Required key \'$_\' missing." if (! exists $conf{$_})} @required_keys ;
		
		my $in_dir = (exists $conf{PredictOutDir}) ? $conf{PredictOutDir} : $conf{WorkDir} ;
		
		for my $i (1..$conf{FullCVN}) {
			for my $gender (@analysis_genders) {
				
				my %queue ;			
				$queue{executable} = $execs{analyze};
				$queue{initialdir} = $out_dir;
				$queue{in_size} = stat("$in_dir/full_cv_predictions.$gender$i")->size unless ($no_run);
				$queue{arguments} = "--in full_cv_predictions.$gender$i --out Analysis.FullCV$i.$gender --params $conf{AnalysisParamsFile} $params" ;
				$queue{transfer_input_files} = "$in_dir/full_cv_predictions.$gender$i,$out_dir/$conf{AnalysisParamsFile},$out_dir/$conf{AnalysisRegistryFile},$out_dir/$conf{AnalysisByearsFile},".
											   "$out_dir/$conf{AnalysisCensorFile},$out_dir/$conf{AnalysisDirectionsFile}" ;
				if (exists $conf{IncidenceFilesDir} and exists $conf{FullCVAnalysisIncidencePrefix}) {
					$queue{arguments} .= " --prbs $conf{FullCVAnalysisIncidencePrefix}.$gender" ;
					$queue{transfer_input_files} .= ",$conf{IncidenceFilesDir}/$conf{FullCVAnalysisIncidencePrefix}.$gender" ;
				}					
				$queue{transfer_output_files} = 
					join(",", map {"Analysis.FullCV$i.$gender$_"} ("", ".AutoSim", ".PeriodicAutoSim", ".Raw"));
				$queue{output} = "analysis.$gender.FullCV.stdout$i" ;
				$queue{error} = "analysis.$gender.FullCV.stderr$i" ;
				$queue{log} = "$conf{CondorAnalysisSubFile}.log" ;
				
				push @{$sub_file_info->{queue_list}}, \%queue;
				$nruns ++ ;
			}
		}
	}
	
	if (! exists $conf{SkipSplitAnalysis} or $conf{SkipSplitAnalysis} eq "N") {
		my @required_keys = qw/SplitN/ ; 
		map {die "Required key \'$_\' missing." if (! exists $conf{$_})} @required_keys ;
		
		my $in_dir = (exists $conf{PredictOutDir}) ? $conf{PredictOutDir} : $conf{WorkDir} ;
		for my $i (1..$conf{SplitN}) {
			for my $gender (@genders) {

				my %queue ;
				$queue{executable} = $execs{analyze};
				$queue{initialdir} = $out_dir;
				$queue{in_size} = stat("$in_dir/split_predictions.$gender$i")->size unless ($no_run);
				$queue{arguments} = "--in split_predictions.$gender$i --out Analysis.Split$i.$gender --params $conf{AnalysisParamsFile} $params" ;
				$queue{transfer_input_files} = "$in_dir/split_predictions.$gender$i,$out_dir/$conf{AnalysisParamsFile},$out_dir/$conf{AnalysisRegistryFile},$out_dir/$conf{AnalysisByearsFile},".
											   "$out_dir/$conf{AnalysisCensorFile},$out_dir/$conf{AnalysisDirectionsFile}" ;
				if (exists $conf{IncidenceFilesDir} and exists $conf{SplitAnalysisIncidencePrefix}) {
					$queue{arguments} .= " --prbs $conf{SplitAnalysisIncidencePrefix}.$gender" ;
					$queue{transfer_input_files} .= ",$conf{IncidenceFilesDir}/$conf{SplitAnalysisIncidencePrefix}.$gender" ;
				}
				$queue{transfer_output_files} = 
					join(",", map {"Analysis.Split$i.$gender$_"} ("", ".AutoSim", ".PeriodicAutoSim", ".Raw"));				
				$queue{output} = "analysis.$gender$i.stdout" ;
				$queue{error} = "analysis.$gender$i.stderr" ;
				$queue{log} = "$conf{CondorAnalysisSubFile}.log" ;

				push @{$sub_file_info->{queue_list}}, \%queue;
				$nruns ++ ;
			}
		}
	}
	
	if (! exists $conf{SkipSplitUnionAnalysis} or $conf{SkipSplitUnionAnalysis} eq "N") {
		my @required_keys = qw/SplitFilesUnionPref/ ; 
		map {die "Required key \'$_\' missing." if (! exists $conf{$_})} @required_keys ;
		
		my $union = $conf{SplitFilesUnionPref} ;		
		my $in_dir = (exists $conf{PredictOutDir}) ? $conf{PredictOutDir} : $conf{WorkDir} ;
		
		for my $gender (@analysis_genders) {
				
			my %queue ;
			$queue{executable} = $execs{analyze};
			$queue{initialdir} = $out_dir;
			$queue{in_size} = stat("$in_dir/$union\_predictions.$gender")->size unless ($no_run);
			$queue{arguments} = "--in $union\_predictions.$gender --out Analysis.$union.$gender --params $conf{AnalysisParamsFile} $params" ;
			$queue{transfer_input_files} = "$in_dir/$union\_predictions.$gender,$out_dir/$conf{AnalysisParamsFile},$out_dir/$conf{AnalysisRegistryFile},$out_dir/$conf{AnalysisByearsFile},".
										   "$out_dir/$conf{AnalysisCensorFile},$out_dir/$conf{AnalysisDirectionsFile}" ;
			if (exists $conf{IncidenceFilesDir} and exists $conf{SplitAnalysisIncidencePrefix}) {
				$queue{arguments} .=  " --prbs $conf{SplitAnalysisIncidencePrefix}.$gender" ;
				$queue{transfer_input_files} .= ",$conf{IncidenceFilesDir}/$conf{SplitAnalysisIncidencePrefix}.$gender" ;
			}
			$queue{transfer_output_files} = 
				join(",", map {"Analysis.$union.$gender$_"} ("", ".AutoSim", ".PeriodicAutoSim", ".Raw"));							
			$queue{output} = "analysis.$gender.$union.stdout" ;
			$queue{error} = "analysis.$gender.$union.stderr" ;
			$queue{log} = "$conf{CondorAnalysisSubFile}.log" ;

			push @{$sub_file_info->{queue_list}}, \%queue;
			$nruns ++ ;
		}
	}
	
	if (! exists $conf{SkipInternalValidationAnalysis} or $conf{SkipInternalValidationAnalysis} eq "N") {
		my @required_keys = qw/InternalNames/ ; 
		map {die "Required key \'$_\' missing." if (! exists $conf{$_})} @required_keys ;
		
		my $in_dir = (exists $conf{PredictOutDir}) ? $conf{PredictOutDir} : $conf{WorkDir} ;
		my @names = split ",",$conf{InternalNames} ;
			
		my (@param_dirs,@param_files) ;
		if (exists $conf{InternalAnalysisParamsDir}) {
			@param_dirs = split ",",$conf{InternalAnalysisParamsDir} ;
		} else {
			@param_dirs = ($conf{AnalysisParamsDir}) x (scalar @names) ;
		}
		if (exists $conf{InternalAnalysisParamsFile}) {
			@param_files = split ",",$conf{InternalAnalysisParamsFile} ;
		} else {
			@param_files = ($conf{AnalysisParamsFile}) x (scalar @names) ;
		}
		
		my @inc ;
		@inc = split ",",$conf{InternalAnalysisIncidencePrefix} if (exists $conf{InternalAnalysisIncidencePrefix}) ;
		
		for my $i (0..$#names) {
			my $name = $names[$i] ;
			my ($param_dir,$param_file) = ($param_dirs[$i],$param_files[$i]);
			run_cmd("cp -f $param_dir/$param_file $out_dir") ;
			
			for my $gender (@analysis_genders) {
			
				my %queue ; 
				$queue{executable} = $execs{analyze};
				$queue{initialdir} = $out_dir;
				$queue{in_size} = stat("$in_dir/$name\_predictions.$gender")->size unless ($no_run);
				$queue{arguments} = "--in $name\_predictions.$gender --out Analysis.$name.$gender --params $param_file $params" ;
				$queue{transfer_input_files} = "$in_dir/$name\_predictions.$gender,$out_dir/$param_file,$out_dir/$conf{AnalysisRegistryFile},$out_dir/$conf{AnalysisByearsFile},".
											   "$out_dir/$conf{AnalysisCensorFile},$out_dir/$conf{AnalysisDirectionsFile}" ;
				if (exists $conf{IncidenceFilesDir} and @inc) {
					$queue{arguments} .= " --prbs $inc[$i].$gender" ;
					$queue{transfer_input_files} .= ",$conf{IncidenceFilesDir}/$inc[$i].$gender" ;
				}
				$queue{transfer_output_files} = 
					join(",", map {"Analysis.$name.$gender$_"} ("", ".AutoSim", ".PeriodicAutoSim", ".Raw"));								
				$queue{output} = "analysis.$gender.$name.stdout" ;
				$queue{error} = "analysis.$gender.$name.stderr" ;
				$queue{log} = "$conf{CondorAnalysisSubFile}.log" ;
				
				push @{$sub_file_info->{queue_list}}, \%queue;
				$nruns ++ ;
			}
		}
	}
	
	if ($nruns) {
	    process_submit_info($sub_file_info);
	}
	
	print stderr "Successfully completed stage: Analyze\n";
	my $datestring = localtime();
	print stderr "Time: $datestring\n";
	print stderr "-------------------------------------------\n\n"	;	
 }

# Stage 6 - Validate Cutoffs
if ($start_stage <= $stages{Validate} and $end_stage >= $stages{Validate}) {
	my @required_keys = qw/CondorValidationSubFile ValidationParamsDir ValidationParamsFile ValidationDirectionsFile ValidationCensorFile ValidationRegistryFile ValidationByearsFile
							 ValidationDirectionsDir ValidationCensorDir ValidationRegistryDir ValidationByearsDir ValidateCombined BoundsDir BoundsFilePrefix InternalNames/ ; 
	map {die "Required key \'$_\' missing." if (! exists $conf{$_})} @required_keys ;
	
	my $out_dir = (exists $conf{ValidationOutDir}) ? $conf{ValidationOutDir} :  $conf{WorkDir} ;
	run_cmd("cp -f $conf{ValidationRegistryDir}/$conf{ValidationRegistryFile} $out_dir") ;
	run_cmd("cp -f $conf{ValidationDirectionsDir}/$conf{ValidationDirectionsFile} $out_dir") ;
	run_cmd("cp -f $conf{ValidationByearsDir}/$conf{ValidationByearsFile} $out_dir") ;
	run_cmd("cp -f $conf{ValidationCensorDir}/$conf{ValidationCensorFile} $out_dir") ;
	
	my $bnds_file_prefix = "$conf{BoundsDir}/$conf{BoundsFilePrefix}" ;

	my @validation_genders = @genders ;
	push @validation_genders,"combined" if ($conf{ValidateCombined} eq "Y") ;
	
	if (! exists $conf{SkipBoundsExtraction} or $conf{SkipBoundsExtraction} eq "N") {
		my @required_keys = qw/AnalysisFileForBoundsPrefix BoundsDefinition/ ;
		map {die "Required key \'$_\' missing." if (! exists $conf{$_})} @required_keys ;

		# Parse BoundsDefinition
		my $all_points ;
		my %points ;
		if ($conf{BoundsDefinition} eq "ALL") {
			$all_points = 1 ;
		} else {
			$all_points = 0 ;
			foreach my $point (split ",",$conf{BoundsDefinition}) {
				if ($point =~ /SENS(\S+)/) {
					$points{$1} = 1 ;
				} elsif ($point =~ /FP\S+/) {
					$points{$point} = 1 ;
				} else {
					die "Cannot parse validation point $point" ;
				}
			}
		}
		
		# Create Cutoff-files
		create_cutoffs_files(\@validation_genders,$bnds_file_prefix,$all_points,\%points) unless ($no_run) ;
		create_cutoffs_files_autosim(\@validation_genders,$bnds_file_prefix,$all_points,\%points) unless ($no_run) ;
	}
	
	
	# Validate
	my $runner_file_name = "$out_dir/$conf{CondorValidationSubFile}" ;
	my $sub_file_info = {queue_list => [], dir => $out_dir, run => $runner_file_name};
	$sub_file_info->{req} = $conf{CondorValidationReq} if (exists $conf{CondorValidationReq}) ;
	$sub_file_info->{mem_req} = $conf{CondorValidationMemReq} if (exists $conf{CondorValidationMemReq}) ;
	$sub_file_info->{rank} = $conf{CondorValidationRank} if (exists $conf{CondorValidationRank}) ;
	
	my $in_dir = (exists $conf{PredictOutDir}) ? $conf{PredictOutDir} : $conf{WorkDir} ;
	my @names = split ",",$conf{InternalNames} ;
	
	my @param_dirs = split ",",$conf{ValidationParamsDir} ;
	my @param_files = split ",",$conf{ValidationParamsFile} ;
	

	my $params ;
	$params = "--reg $conf{ValidationRegistryFile} --byear $conf{ValidationByearsFile} --censor $conf{ValidationCensorFile} --dir $conf{ValidationDirectionsFile}" ;
	$params .= " $conf{ValidationParams}" if (exists $conf{ValidationParams}) ;		
		
	for my $i (0..$#names) {
		my $name = $names[$i] ;
		my $param_file = $param_files[$i] ;
		my $param_dir = $param_dirs[$i] ;
		run_cmd("cp -f $param_dir/$param_file $out_dir") ;

		for my $gender (@validation_genders) {
			my %queue ; 
			$queue{executable} = $execs{validate};
			$queue{initialdir} = $out_dir;
			$queue{in_size} = stat("$in_dir/$name\_predictions.$gender")->size unless ($no_run);
			$queue{arguments} = "--in $name\_predictions.$gender --bnds $conf{BoundsFilePrefix}.$gender --out Validation.$gender.$name --params $param_file $params" ;
			$queue{transfer_input_files} = "$in_dir/$name\_predictions.$gender,$out_dir/$param_file,$bnds_file_prefix.$gender,$bnds_file_prefix.$gender.AutoSim,".
											"$out_dir/$conf{ValidationCensorFile},$out_dir/$conf{ValidationRegistryFile},$out_dir/$conf{ValidationByearsFile},$out_dir/$conf{ValidationDirectionsFile}" ;
			$queue{transfer_output_files} = "Validation.$gender.$name" ;
			$queue{output} = "validation.$gender.$name.stdout" ;
			$queue{error} = "validation.$gender.$name.stderr" ;
			$queue{log} = "$conf{CondorValidationSubFile}.log" ;
			
			push @{$sub_file_info->{queue_list}}, \%queue;
		}
	}
	process_submit_info($sub_file_info);	

	# Remove previous external validation results (if exist) and create external validation input directory (possibly more than one)
	for my $ext_name (split(/,/, $conf{ExternalNames})){
		for my $ext_type (qw(Analysis Validation)) {
			for my $gender (qw(men women combined)) {
				my $fn = "$conf{WorkDir}/$ext_type.$ext_name.$gender";
				if (-e $fn) {
					print STDERR "Removing previous external validation results in file $fn\n";
					run_cmd("rm -f $fn");
				}
			}
		}
		
		my $ext_dir = $conf{WorkDir} . "/ExternalValidationDir_" . $ext_name;
		run_cmd("mkdir -p $ext_dir");
		# map {run_cmd("cp -f $execs{$_} $ext_dir")} qw(analyze validate); # Even if script runs on unix, the executables for Maccabi external validation performed by Esma should be the windows x64 ones.
		run_cmd("cp -f $conf{ProjectRoot}/AnalyzeScores/x64/Release/bootstrap_analysis.exe $ext_dir");
		run_cmd("cp -f $conf{ProjectRoot}/AnalyzeScores/x64/Release/validate_cutoffs.exe $ext_dir");
		
		run_cmd("cp -f $conf{WorkDir}/$conf{AnalysisParamsFile} $ext_dir");
		map { run_cmd("cp -f $conf{WorkDir}/ValidationBounds.$_ $ext_dir") } qw(men women combined);
		map { run_cmd("cp -f $conf{WorkDir}/ValidationBounds.$_.AutoSim $ext_dir") } qw(men women combined);
		
		run_cmd("cp -f $conf{ValidationDirectionsDir}/$conf{ValidationDirectionsFileForExternal} $ext_dir");
		run_cmd("cp -f $conf{ValidationCensorDir}/$conf{ValidationCensorFile} $ext_dir");
		run_cmd("cp -f $conf{ValidationByearsDir}/$conf{ValidationByearsFile} $ext_dir");
		
		for my $gender (qw(men women combined)) {
			run_cmd("cp -f $in_dir/$ext_name\_predictions.$gender $ext_dir") ;
			run_cmd("cp -f $conf{IncidenceFilesDir}/$conf{ExternalIncidencePrefix}.$gender $ext_dir") if (exists $conf{ExternalIncidencePrefix}) ;
		}
	}
	
	print stderr "Successfully completed stage: Validate cutoffs\n";
	my $datestring = localtime();
	print stderr "Time: $datestring\n";
	print stderr "-------------------------------------------\n\n";
}

# Stage 7 - Re-running analysis with inclusion files, for comparison purposes

## In case of a significant change in population, re-run analysis part 
##  using a specified inclusion file (prepared seperatly) & specified parameters_file.
## The new analysis will be used only for comparison against GoldStandard.
	
if ($start_stage <= $stages{ReAnalyzeForCompare} and $end_stage >= $stages{ReAnalyzeForCompare}) {
	if (exists $conf{SkipAnalysisForCompare} and $conf{SkipAnalysisForCompare} eq "N") {	
		my @required_keys = qw/InclusionFilesDir  
								 
								AnalysisForCompareRegistryDir AnalysisForCompareRegistryFile
								AnalysisForCompareDirectionsDir AnalysisForCompareDirectionsFile
								AnalysisForCompareByearsDir AnalysisForCompareByearsFile
								AnalysisForCompareCensorDir AnalysisForCompareCensorFile
								AnalysisForCompareParamsDir AnalysisForCompareParamsFile/ ; 
		map {die "Required key \'$_\' missing." if (! exists $conf{$_})} @required_keys ;
		
		my $out_dir = (exists $conf{AnalysisForCompareOutDir}) ? $conf{AnalysisForCompareOutDir} :  $conf{WorkDir} ;
		my $in_dir = (exists $conf{PredictOutDir}) ? $conf{PredictOutDir} : $conf{WorkDir} ;
		my $runner_file_name = "$out_dir/$conf{AnalysisForCompareCondorSubFile}" ;
		
		# Take condor requirements as used by 'Analyze' stage
		my $sub_file_info = {queue_list => [], dir => $out_dir, run => $runner_file_name};
		$sub_file_info->{req} = $conf{CondorAnalysisReq} if (exists $conf{CondorAnalysisReq}) ;
		$sub_file_info->{mem_req} = $conf{CondorAnalysisMemReq} if (exists $conf{CondorAnalysisMemReq}) ;
		$sub_file_info->{rank} = $conf{CondorAnalysisRank} if (exists $conf{CondorAnalysisRank}) ;
		
		# Set genders for re-analysis
		my @analysis_genders = @genders ;
		push @analysis_genders,"combined" if ($conf{CompareCombined} eq "Y") ;
		
		# Set general params for bootstrap run.
		my $params ;
		$params = "--reg $conf{AnalysisForCompareRegistryFile} --byear $conf{AnalysisForCompareByearsFile} --censor $conf{AnalysisForCompareCensorFile} --dir $conf{AnalysisForCompareDirectionsFile}" ;
		$params .= " $conf{AnalysisParams}" if (exists $conf{AnalysisParams}) ;
		
		run_cmd("cp -f $conf{AnalysisForCompareRegistryDir}/$conf{AnalysisForCompareRegistryFile} $out_dir") ;
		run_cmd("cp -f $conf{AnalysisForCompareDirectionsDir}/$conf{AnalysisForCompareDirectionsFile} $out_dir") ;
		run_cmd("cp -f $conf{AnalysisForCompareByearsDir}/$conf{AnalysisForCompareByearsFile} $out_dir") ;
		run_cmd("cp -f $conf{AnalysisForCompareCensorDir}/$conf{AnalysisForCompareCensorFile} $out_dir") ;
		run_cmd("cp -f $conf{AnalysisForCompareParamsDir}/$conf{AnalysisForCompareParamsFile} $out_dir") ;
		
		my $nruns = 0 ;
		
		if (! exists $conf{SkipSplitUnionReAnalyze} or $conf{SkipSplitUnionReAnalyze} eq "N") {		
			my @required_keys = qw/SplitFilesUnionPref InclusionFilePrefixSplitUnion/ ; 
			map {die "Required key \'$_\' missing." if (! exists $conf{$_})} @required_keys ;
			my $union = $conf{SplitFilesUnionPref} ;		
			
			for my $gender (@analysis_genders) {
					
				my %queue ;
				$queue{executable} = $execs{analyze};
				$queue{initialdir} = $out_dir;
				$queue{in_size} = stat("$in_dir/$union\_predictions.$gender")->size unless ($no_run);
				$queue{arguments} = "--in $union\_predictions.$gender --out AnalysisForComparison.$union.$gender --params $conf{AnalysisForCompareParamsFile} ".
									"$params --inc $conf{InclusionFilesDir}/$conf{InclusionFilePrefixSplitUnion}.$gender" ;
				$queue{transfer_input_files} = "$in_dir/$union\_predictions.$gender,$out_dir/$conf{AnalysisForCompareParamsFile},$out_dir/$conf{AnalysisForCompareRegistryFile},".
												"$out_dir/$conf{AnalysisForCompareByearsFile},$out_dir/$conf{AnalysisForCompareCensorFile},$out_dir/$conf{AnalysisForCompareDirectionsFile},".
												"$conf{InclusionFilesDir}/$conf{InclusionFilePrefixSplitUnion}.$gender" ;
				if (exists $conf{IncidenceFilesDir} and exists $conf{SplitAnalysisIncidencePrefix}) {
					$queue{arguments} .=  " --prbs $conf{SplitAnalysisIncidencePrefix}.$gender" ;
					$queue{transfer_input_files} .= ",$conf{IncidenceFilesDir}/$conf{SplitAnalysisIncidencePrefix}.$gender" ;
				}
				$queue{transfer_output_files} = 
					join(",", map {"AnalysisForComparison.$union.$gender$_"} ("", ".AutoSim", ".PeriodicAutoSim", ".Raw"));							
				$queue{output} = "analysisForComparison.$gender.$union.stdout" ;
				$queue{error} = "analysisForComparison.$gender.$union.stderr" ;
				$queue{log} = "$conf{AnalysisForCompareCondorSubFile}.log" ;

				push @{$sub_file_info->{queue_list}}, \%queue;
				$nruns ++ ;
			}
		}
				
		if (! exists $conf{SkipInternalReAnalyze} or $conf{SkipInternalReAnalyze} eq "N") {
			my @required_keys = qw/InternalNames InclusionFilePrefixInternal/ ; 
			map {die "Required key \'$_\' missing." if (! exists $conf{$_})} @required_keys ;
			my @names = split ",",$conf{InternalNames} ;
				
			my (@param_dirs,@param_files) ;
			if (exists $conf{AnalysisForCompareInternalParamsDir}) {
				@param_dirs = split ",",$conf{AnalysisForCompareInternalParamsDir} ;
			} else {
				@param_dirs = ($conf{AnalysisForCompareParamsDir}) x (scalar @names) ;
			}
			if (exists $conf{AnalysisForCompareInternalParamsFile}) {
				@param_files = split ",",$conf{AnalysisForCompareInternalParamsFile} ;
			} else {
				@param_files = ($conf{AnalysisForCompareParamsFile}) x (scalar @names) ;
			}
			
			my @inc ;
			@inc = split ",",$conf{InternalAnalysisIncidencePrefix} if (exists $conf{InternalAnalysisIncidencePrefix}) ;
			
			for my $i (0..$#names) {
				my $name = $names[$i] ;
				my ($param_dir,$param_file) = ($param_dirs[$i],$param_files[$i]);
				
				# Copy parameter file to comparison working directory
				run_cmd("cp -f $param_dir/$param_file $out_dir") ;
				
				for my $gender (@analysis_genders) {
				
					my %queue ; 
					$queue{executable} = $execs{analyze};
					$queue{initialdir} = $out_dir;
					$queue{in_size} = stat("$in_dir/$name\_predictions.$gender")->size unless ($no_run);
					$queue{arguments} = "--in $in_dir/$name\_predictions.$gender --out AnalysisForComparison.$name.$gender --params $param_file ".
										"$params --inc $conf{InclusionFilesDir}/$conf{InclusionFilePrefixInternal}.$gender" ;
					$queue{transfer_input_files} = "$in_dir/$name\_predictions.$gender,$param_file,$out_dir/$conf{AnalysisForCompareRegistryFile},".
													"$out_dir/$conf{AnalysisForCompareByearsFile},$out_dir/$conf{AnalysisForCompareCensorFile},$out_dir/$conf{AnalysisForCompareDirectionsFile},".
													"$conf{InclusionFilesDir}/$conf{InclusionFilePrefixInternal}.$gender" ;
					if (exists $conf{IncidenceFilesDir} and @inc) {
						$queue{arguments} .= " --prbs $inc[$i].$gender" ;
						$queue{transfer_input_files} .= ",$conf{IncidenceFilesDir}/$inc[$i].$gender" ;
					}
					$queue{transfer_output_files} = 
						join(",", map {"AnalysisForComparison.$name.$gender$_"} ("", ".AutoSim", ".PeriodicAutoSim", ".Raw"));								
					$queue{output} = "analysisForComparison.$gender.$name.stdout" ;
					$queue{error} = "analysisForComparison.$gender.$name.stderr" ;
					$queue{log} = "$conf{AnalysisForCompareCondorSubFile}.log" ;
					
					push @{$sub_file_info->{queue_list}}, \%queue;
					$nruns ++ ;
				}
			}
		}
		
		
		# Run analysis via condor
		if ($nruns) {
			process_submit_info($sub_file_info);
		}
		
		# For analysis of external source, prepare a folder with all needed files
		if (! exists $conf{SkipExternalReAnalyze} or $conf{SkipExternalReAnalyze} eq "N") {
			my @required_keys = qw/InternalNames InclusionFilePrefixExternal/ ; 
			map {die "Required key \'$_\' missing." if (! exists $conf{$_})} @required_keys ;		
		
			for my $ext_name (split(/,/, $conf{ExternalNames})){
				my $ext_dir = $conf{AnalysisForCompareOutDir} . "/ExternalValidationDir_" . $ext_name;
				run_cmd("mkdir -p $ext_dir");
				run_cmd("cp -f $execs{analyze} $ext_dir");
				run_cmd("cp -f $conf{AnalysisForCompareParamsDir}/$conf{AnalysisForCompareParamsFile} $ext_dir");
				run_cmd("cp -f $conf{AnalysisForCompareDirectionsDir}/$conf{AnalysisDirectionsFile} $ext_dir") ;
				run_cmd("cp -f $conf{AnalysisForCompareByearsDir}/$conf{AnalysisForCompareByearsFile} $ext_dir") ;
				run_cmd("cp -f $conf{AnalysisForCompareCensorDir}/$conf{AnalysisForCompareCensorFile} $ext_dir") ;
		
				run_cmd("cp -f $conf{InclusionFilesDir}/$conf{AnalysisForCompareCensorFile} $ext_dir") ;
				
				for my $gender (@analysis_genders) {
					# Copy prediction files
					run_cmd("cp -f $in_dir/$ext_name\_predictions.$gender $ext_dir") ;
					# Copy incidence file
					run_cmd("cp -f $conf{IncidenceFilesDir}/$conf{ExternalIncidencePrefix}.$gender $ext_dir") if (exists $conf{ExternalIncidencePrefix} and exists $conf{IncidenceFilesDir}) ;
					# Copy inclusion files
					run_cmd("cp -f $conf{InclusionFilesDir}/$conf{InclusionFilePrefixExternal}.$gender $ext_dir") if (exists $conf{InclusionFilePrefixExternal} and exists $conf{InclusionFilesDir}) ;
				}
			}
		}
		
		print stderr "Successfully completed analyze-for-comparison\n" ;
		my $datestring = localtime();
		print stderr "Time: $datestring\n";	
		print stderr "-------------------------------------------\n\n" ;	
	}	
}

# Stage 8 - Comparing to Gold-Standard
if ($start_stage <= $stages{Compare} and $end_stage >= $stages{Compare}) {
	my @required_keys = qw/CompareCombined/ ; 
	map {die "Required key \'$_\' missing." if (! exists $conf{$_})} @required_keys ;
		
	my $in_dir = (exists $conf{AnalysisOutDir}) ? $conf{AnalysisOutDir} :  $conf{WorkDir} ;
	my $re_analyze_suffix = "";
	
	if (exists $conf{SkipAnalysisForCompare} and $conf{SkipAnalysisForCompare} eq "N") {
		$in_dir = (exists $conf{AnalysisForCompareOutDir}) ? $conf{AnalysisForCompareOutDir} :  $conf{WorkDir} ;
		$re_analyze_suffix = "ForComparison";
	}
	
	my $out_dir = (exists $conf{CompareOutDir}) ? $conf{CompareOutDir} : $conf{WorkDir} ;
	if ( !-d $out_dir ) { make_path $out_dir or die "Failed to create directory: $out_dir"; }
	my $allow_diff_checksum = (exists $conf{AllowDifferentChecksums} and $conf{AllowDifferentChecksums} eq "Y") ? 1 : 0 ;
	my $allow_diff_list= (exists $conf{AllowDifferentLists} and $conf{AllowDifferentLists} eq "Y") ? 1 : 0 ;
	
	my @compare_genders = @genders ;
	push @compare_genders,"combined" if ($conf{CompareCombined} eq "Y") ;
	
	my $list_file = "$out_dir/CurrentFilesList" ;
	open (LIST,">$list_file") or die "Cannot open CurrentFilesList for writing (Exact path: $list_file)" ;
	
	if ((! exists $conf{SkipSplitCompare} or $conf{SkipSplitCompare} eq "N") and
		(exists $conf{SkipAnalysisForCompare} and $conf{SkipAnalysisForCompare} eq "N")) {
		
		my @required_keys = qw/SplitN/ ; 
		map {die "Required key \'$_\' missing." if (! exists $conf{$_})} @required_keys ;
		
		for my $i (1..$conf{SplitN}) {
			for my $gender (@genders) {
				print LIST "LearningSet-Split$i\t$gender\t$in_dir/Analysis$re_analyze_suffix.Split$i.$gender\n" ;
			}
		}
	} else { 
		print STDERR "Skipping split comparison\n"; 
		print STDERR "Re-analysis of splits not yet supported, therefor split comparison cannot be performed\n" 
			if (exists $conf{SkipAnalysisForCompare} and $conf{SkipAnalysisForCompare} eq "N" and 
				exists $conf{SkipSplitCompare} and $conf{SkipSplitCompare} eq "N");
		# TODO: add re-analysis of splits using inclusion files
	}
	
	if (! exists $conf{SkipSplitUnionCompare} or $conf{SkipSplitUnionCompare} eq "N") {
		my @required_keys = qw/SplitFilesUnionPref/ ; 
		map {die "Required key \'$_\' missing." if (! exists $conf{$_})} @required_keys ;
		
		my $union = $conf{SplitFilesUnionPref} ;	
		for my $gender (@compare_genders) {
			print LIST "LearningSet\t$gender\t$in_dir/Analysis$re_analyze_suffix.$union.$gender\n" ;
		}
	} else { print STDERR "Skipping split-union comparison\n"; }
		
	if (! exists $conf{SkipInternalCompare} or $conf{SkipInternalCompare} eq "N") {	
		my @required_keys = qw/InternalNames/ ; 
		map {die "Required key \'$_\' missing." if (! exists $conf{$_})} @required_keys ;

		my @names = split ",",$conf{InternalNames} ;
		
		foreach my $name (@names) {	
			for my $gender (@compare_genders) {
				print LIST "$name\t$gender\t$in_dir/Analysis$re_analyze_suffix.$name.$gender\n" ;
			}
		}
	}  else { print STDERR "Skipping internal validation comparison\n"; }
	
	if (! exists $conf{SkipExternalCompare} or $conf{SkipExternalCompare} eq "N") {	
		my @required_keys = qw/ExternalNames/ ; 
		map {die "Required key \'$_\' missing." if (! exists $conf{$_})} @required_keys ;

		my @names = split ",",$conf{ExternalNames} ;
		
		foreach my $name (@names) {	
			for my $gender (@compare_genders) {
				print LIST "$name\t$gender\t$in_dir/Analysis$re_analyze_suffix.$name.$gender\n" ;
			}
		}
	} 	else { print STDERR "Skipping external validation comparison\n"; }
	
	# FullCV - Depricated
	if (! exists $conf{SkipFullCVCompare} or $conf{SkipFullCVCompare} eq "N") {	
		my @required_keys = qw/FullCVN/ ; 
		map {die "Required key \'$_\' missing." if (! exists $conf{$_})} @required_keys ;
		
		for my $i (1..$conf{FullCVN}) {
			for my $gender (@compare_genders) {
				print LIST "LearningSetCV$i\t$gender\t$in_dir/Analysis.FullCV$i.$gender\n" ;
			}
		}
	}	else { print STDERR "Skipping full cv comparison\n"; }
	
	close LIST ;
	
	if (! exists $conf{SkipCompare} or $conf{SkipCompare} eq "N") {
		my @required_keys = qw/GoldFilesList CompareOutFile CompareSummaryFile CompareMeasures/ ; 
		map {die "Required key \'$_\' missing." if (! exists $conf{$_})} @required_keys ;

		my $compare_in_file = "$out_dir/CompareFile" ;
		open (CMP,">$compare_in_file") or die "Cannot open $compare_in_file for reading" ;
		print CMP "GoldStandard\t$conf{GoldFilesList}\n" ;
		print CMP "Current\t$list_file\n" ;
		close CMP ;
		
		CompareAnalysis::compare_analysis($compare_in_file,
											"$out_dir/$conf{CompareOutFile}",
											"$out_dir/$conf{CompareSummaryFile}",
											$allow_diff_checksum,
											$allow_diff_list,
											$conf{CompareMeasures},
											"$out_dir/compare_analysis.stderr") unless ($no_run) ;	
	}	
	
	print stderr "Successfully completed stage: Compare\n";
	my $datestring = localtime();
	print stderr "Time: $datestring\n";
	print stderr "-------------------------------------------\n\n";		
}

# Stage 9 - Export to SPS (Study-Performance-System)
if ($start_stage <= $stages{Export} and $end_stage >= $stages{Export}) {  

	my $date = strftime("%Y-%m-%d",localtime) ;
	my $in_dir = (exists $conf{AnalysisOutDir}) ? $conf{AnalysisOutDir} :  $conf{WorkDir} ;	

	if (! exists $conf{SkipFullCVExport} or $conf{SkipFullCVExport} eq "N") {
		my @required_keys = qw/ExportDir ExportGraphResolution ExportCombined ExportFields TrainingPopulationName FeatureParams/ ; 
		map {die "Required key \'$_\' missing." if (! exists $conf{$_})} @required_keys ;  
		
		my @export_genders = @genders ;
		push @export_genders,"combined" if ($conf{ExportCombined} eq "Y") ;
		
		my $out_dir = $conf{ExportDir} ;
		
		die "Required keys - either FullCVN or FullCVExportId" if (! exists $conf{FullCVN} and ! exists $conf{FullCVExportId}) ;
		
		my ($minId,$maxId) ;
		if (exists  $conf{FullCVExportId}) {
			$minId = $maxId = $conf{FullCVExportId} ;
		} else {
			$minId = 1 ;
			$maxId = $conf{FullCVN} ;
		}
		
		my @fields = split /\s+/,$conf{ExportFields} ;
		for my $i ($minId..$maxId) {
			for my $gender (@export_genders) {
				PrepareDataForSPS::prepare_data_for_SPS("$in_dir/Analysis.FullCV$i.$gender","$out_dir/SPS.FullCV$i.$gender",$conf{ExportGraphResolution},"Population","$conf{TrainingPopulationName}.CV$i",
														"Gender",$gender,"Date",$date,"Features",$conf{FeatureParams},@fields) unless ($no_run) ;	
			}
		}
	}
	
	if (! exists $conf{SkipUnionExport} or $conf{SkipUnionExport} eq "N") {
		my @required_keys = qw/ExportDir ExportGraphResolution ExportCombined ExportFields TrainingPopulationName SplitFilesUnionPref/ ; 
		map {die "Required key \'$_\' missing." if (! exists $conf{$_})} @required_keys ;  
		
		my @export_genders = @genders ;
		push @export_genders,"combined" if ($conf{ExportCombined} eq "Y") ;
		
		my $out_dir = $conf{ExportDir} ;

		my @fields = split /\s+/,$conf{ExportFields} ;
		my $union = $conf{SplitFilesUnionPref} ;
		for my $gender (@export_genders) {
			PrepareDataForSPS::prepare_data_for_SPS("$in_dir/Analysis.$union.$gender","$out_dir/SPS.$union.$gender",$conf{ExportGraphResolution},"Population",$conf{TrainingPopulationName},
													"Gender",$gender,"Date",$date,"Features",$conf{FeatureParams},@fields) unless ($no_run) ;	
		}
	}
	
	if (! exists $conf{SkipInternalExport} or $conf{SkipInternalExport} eq "N") {
		my @required_keys = qw/ExportDir ExportGraphResolution ExportCombined ExportFields InternalNames/ ; 
		map {die "Required key \'$_\' missing." if (! exists $conf{$_})} @required_keys ;  
		
		my @export_genders = @genders ;
		push @export_genders,"combined" if ($conf{ExportCombined} eq "Y") ;
		
		my $out_dir = $conf{ExportDir} ;
		
		my @names = split ",",$conf{InternalNames} ;
		
		my @fields = split /\s+/,$conf{ExportFields} ;
		foreach my $name (@names) {	
			for my $gender (@export_genders) {	
				PrepareDataForSPS::prepare_data_for_SPS("$in_dir/Analysis.$name.$gender","$out_dir/SPS.$name.$gender",$conf{ExportGraphResolution},"Population",$name,"Gender",$gender,"Data",$date,@fields) unless ($no_run) ;	
			}
		}
	}
  	
	if (! exists $conf{SkipExternalExport} or $conf{SkipExternalExport} eq "N") {
		my @required_keys = qw/ExportDir ExportGraphResolution ExportCombined ExportFields ExternalNames/ ; 
		map {die "Required key \'$_\' missing." if (! exists $conf{$_})} @required_keys ;  
		
		my @export_genders = @genders ;
		push @export_genders,"combined" if ($conf{ExportCombined} eq "Y") ;
		
		my $out_dir = $conf{ExportDir} ;
		
		my @names = split ",",$conf{ExternalNames} ;
		
		my @fields = split /\s+/,$conf{ExportFields} ;
		foreach my $name (@names) {	
			for my $gender (@export_genders) {
				PrepareDataForSPS::prepare_data_for_SPS("$in_dir/Analysis.$name.$gender","$out_dir/SPS.$name.$gender",$conf{ExportGraphResolution},"Population",$name,"Gender",$gender,"Data",$date,@fields) unless ($no_run) ;	
			}
		}
	}
	
	print stderr "Successfully completed stage: Export\n";
	my $datestring = localtime();
	print stderr "Time: $datestring\n";
	print stderr "-------------------------------------------\n\n";		
}


# Stage 10 - PostProcessing
if ($start_stage <= $stages{PostProcess} and $end_stage >= $stages{PostProcess}) {   
	my @required_keys = qw/CondorPostProcessSubFile PostProcessParamsDir PostProcessParamsFile PostProcessParamsFileN PostProcessCombined
						   PostProcessDirectionsFile PostProcessCensorFile PostProcessRegistryFile PostProcessByearsFile PostProcessDirectionsDir PostProcessCensorDir PostProcessRegistryDir PostProcessByearsDir/ ;
	map {die "Required key \'$_\' missing." if (! exists $conf{$_})} @required_keys ;  
	
	my $nruns = 0 ;
	my $dir = (exists $conf{PredictOutDir}) ? $conf{PredictOutDir} : $conf{WorkDir} ;
	my $runner_file_name = "$dir/$conf{CondorPostProcessSubFile}" ;
	my $sub_file_info = {queue_list => [], dir => $dir, run => $runner_file_name};
	$sub_file_info->{req} = $conf{CondorPostProcessReq} if (exists $conf{CondorPostProcessReq}) ;
	$sub_file_info->{mem_req} = $conf{CondorPostProcessMemReq} if (exists $conf{CondorPostProcessMemReq}) ;
	$sub_file_info->{rank} = $conf{CondorPostProcessRank} if (exists $conf{CondorPostProcessRank}) ;
	
	my @postprocess_genders = @genders ;
	push @postprocess_genders,"combined" if ($conf{PostProcessCombined} eq "Y") ;
	
	my $params ;
	$params = "--reg $conf{PostProcessRegistryFile} --byear $conf{PostProcessByearsFile} --censor $conf{PostProcessCensorFile} --dir $conf{PostProcessDirectionsFile}" ;
	$params .= " $conf{PostProcessParams}" if (exists $conf{PostProcessParams}) ;		
		
	my @analysis_files = () ;
	if (! exists $conf{SkipFullCVPostProcess} or $conf{SkipFullCVPostProcess} eq "N") {
		my @required_keys = qw/FullCVN/ ; 
		map {die "Required key \'$_\' missing." if (! exists $conf{$_})} @required_keys ;

		for my $gender (@postprocess_genders) {
			for my $id (1..$conf{FullCVN}) {
				for my $iparam (1..$conf{PostProcessParamsFileN}) {
					my %queue ;			
					$queue{executable} = $execs{analyze};
					$queue{initialdir} = $dir;
					$queue{in_size} = stat("$dir/full_cv_predictions.$gender$id")->size unless ($no_run);
					$queue{arguments} = "--in full_cv_predictions.$gender$id --out FullAnalysis.$gender.FullCV$id.$iparam --params=$conf{PostProcessParamsFile}$iparam $params" ;
					$queue{transfer_input_files} = "$dir/full_cv_predictions.$gender$id,$conf{PostProcessParamsDir}/$conf{PostProcessParamsFile}$iparam,".
													"$conf{PostProcessCensorDir}/$conf{PostProcessCensorFile},$conf{PostProcessRegistryDir}/$conf{PostProcessRegistryFile},".
													"$conf{PostProcessByearsDir}/$conf{PostProcessByearsFile},$conf{PostProcessDirectionsDir}/$conf{PostProcessDirectionsFile}" ;
					$queue{output} = "full_analysis.$gender.FullCV$id.$iparam.stdout" ;
					$queue{error} = "full_analysis.$gender.FullCV$id.$iparam.stderr" ;
					$queue{log} = "$conf{CondorPostProcessSubFile}.log" ;
					
					if (exists $conf{IncidenceFilesDir} and exists $conf{InternalAnalysisIncidencePrefix}) {
						$queue{arguments} .= " --prbs $conf{InternalAnalysisIncidencePrefix}.$gender" ;
						$queue{transfer_input_files} .= ",$conf{IncidenceFilesDir}/$conf{InternalAnalysisIncidencePrefix}.$gender" ;
					}
					
					push @{$sub_file_info->{queue_list}}, \%queue;				
					$nruns ++ ;
				}
				push @analysis_files,"FullAnalysis.$gender.FullCV$id" ;
			}
		}
	}
	
	if (! exists $conf{SkipInternalPostProcess} or $conf{SkipInternalPostProcess} eq "N") {
		my @required_keys = qw/InternalNames/ ; 
		map {die "Required key \'$_\' missing." if (! exists $conf{$_})} @required_keys ;  

		my @names = split ",",$conf{InternalNames} ;
		
		foreach my $name (@names) {
			for my $gender (@postprocess_genders) {
				for my $iparam (1..$conf{PostProcessParamsFileN}) {
					my %queue ;			
					$queue{executable} = $execs{analyze};
					$queue{initialdir} = $dir;
					$queue{in_size} = stat("$dir/$name\_predictions.$gender")->size unless ($no_run);
					$queue{arguments} = "--in $name\_predictions.$gender --out FullAnalysis.$gender.$name.$iparam --params=$conf{PostProcessParamsFile}$iparam $params" ;
					$queue{transfer_input_files} = "$dir/$name\_predictions.$gender,$conf{PostProcessParamsDir}/$conf{PostProcessParamsFile}$iparam,".
													"$conf{PostProcessCensorDir}/$conf{PostProcessCensorFile},$conf{PostProcessRegistryDir}/$conf{PostProcessRegistryFile},".
													"$conf{PostProcessByearsDir}/$conf{PostProcessByearsFile},$conf{PostProcessDirectionsDir}/$conf{PostProcessDirectionsFile}" ;
					$queue{output} = "full_analysis.$gender.$name.$iparam.stdout" ;
					$queue{error} = "full_analysis.$gender.$name.$iparam.stderr" ;
					$queue{log} = "$conf{CondorPostProcessSubFile}.log" ;

					push @{$sub_file_info->{queue_list}}, \%queue;				
					$nruns ++ ;
				}
				push @analysis_files,"FullAnalysis.$gender.$name" ;
			}
		}
	}
	
	if (! exists $conf{SkipSplitPostProcess} or $conf{SkipSplitPostProcess} eq "N") {
		my @required_keys = qw/SplitN/ ;
		map {die "Required key \'$_\' missing." if (! exists $conf{$_})} @required_keys ;
		
		for my $i (1..$conf{SplitN}) {			
			for my $gender (@genders) {
				for my $iparam (1..$conf{PostProcessParamsFileN}) {
					my %queue ;			
					$queue{executable} = $execs{analyze};
					$queue{initialdir} = $dir;
					$queue{in_size} = stat("split_predictions.$gender$i")->size unless ($no_run);
					$queue{arguments} = "--in split_predictions.$gender$i --out FullAnalysis.$gender.split$i.$iparam --params=$conf{PostProcessParamsFile}$iparam $params" ;
					$queue{transfer_input_files} = "$dir/split_predictions.$gender$i,$conf{PostProcessParamsDir}/$conf{PostProcessParamsFile}$iparam,".
													"$conf{PostProcessCensorDir}/$conf{PostProcessCensorFile},$conf{PostProcessRegistryDir}/$conf{PostProcessRegistryFile},".
													"$conf{PostProcessByearsDir}/$conf{PostProcessByearsFile},$conf{PostProcessDirectionsDir}/$conf{PostProcessDirectionsFile}" ;
					$queue{output} = "full_analysis.$gender.split$i.$iparam.stdout" ;
					$queue{error} = "full_analysis.$gender.split$i.$iparam.stderr" ;
					$queue{log} = "$conf{CondorPostProcessSubFile}.log" ;
				
					push @{$sub_file_info->{queue_list}}, \%queue;				
					$nruns ++ ;
				}	
				push @analysis_files,"FullAnalysis.$gender.split$i" ;
			}
		}
	}
	
	if (! exists $conf{SkipSplitUnionPostProcess} or $conf{SkipSplitUnionPostProcess} eq "N") {
		my @required_keys = qw/SplitFilesUnionPref/ ; 
		map {die "Required key \'$_\' missing." if (! exists $conf{$_})} @required_keys ;
		
		my $union = $conf{SplitFilesUnionPref} ;
		
		for my $gender (@postprocess_genders) {
			for my $iparam (1..$conf{PostProcessParamsFileN}) {
				my %queue ;			
				$queue{executable} = $execs{analyze};
				$queue{initialdir} = $dir;
				$queue{in_size} = stat("$dir/$union\_predictions.$gender")->size unless ($no_run);
				$queue{arguments} = "--in $union\_predictions.$gender --out FullAnalysis.$gender.$union.$iparam --params=$conf{PostProcessParamsFile}$iparam $params" ;
				$queue{transfer_input_files} = "$dir/$union\_predictions.$gender,$conf{PostProcessParamsDir}/$conf{PostProcessParamsFile}$iparam,".
												"$conf{PostProcessCensorDir}/$conf{PostProcessCensorFile},$conf{PostProcessRegistryDir}/$conf{PostProcessRegistryFile},".
												"$conf{PostProcessByearsDir}/$conf{PostProcessByearsFile},$conf{PostProcessDirectionsDir}/$conf{PostProcessDirectionsFile}" ;
				$queue{output} = "full_analysis.$gender.$union.$iparam.stdout" ;
				$queue{error} = "full_analysis.$gender.$union.$iparam.stderr" ;
				$queue{log} = "$conf{CondorPostProcessSubFile}.log" ;
				
				push @{$sub_file_info->{queue_list}}, \%queue;				
				$nruns ++ ;
			}
			push @analysis_files,"FullAnalysis.$gender.$union" ;
		}
	}
	
	if ($nruns) {
	    process_submit_info($sub_file_info);	    
	}
	
	# Combine And Clean
	unless ($no_run) {
		foreach my $file (@analysis_files) {
			open (OUT,">$dir/$file") or die "Cannot open $dir/$file for writing" ;
				
			my $head = 0 ;
			for my $iparam (1..$conf{PostProcessParamsFileN}) {
				open (IN,"$dir/$file.$iparam") or die "Cannot open $dir/$file.$iparam for reading" ;
				while (<IN>) {
					if (! /Time-Window/ or ! $head) {
						print OUT $_  ;
						$head = 1 ;
					}
				}
				close IN ;
			}
			close OUT ;
							
			open (OUT,">$dir/$file.Short") or die "Cannot open $dir/$file.Short for writing" ;
				
			$head = 0 ;
			for my $iparam (1..$conf{PostProcessParamsFileN}) {
				open (IN,"$dir/$file.$iparam.Short") or die "Cannot open $dir/$file.$iparam.Short for reading" ;
				while (<IN>) {
					if (! /Time-Window/ or ! $head) {
						print OUT $_  ;
						$head = 1 ;
					}
				}
				close IN ;
			}
			close OUT ;
		}
	}
	
	print stderr "Successfully completed stage: Postprocess\n";
	my $datestring = localtime();
	print stderr "Time: $datestring\n";
	print stderr "-------------------------------------------\n\n";		
}

# Stage 11 - History-less Prediction and Analysis
if ($start_stage <= $stages{HistoryAnalysis} and $end_stage >= $stages{HistoryAnalysis}) {
	my @required_keys = qw/FeatureParams Method CondorHistoryPredictSubFile TrainingMatrixSuffix SplitN 
							CondorHistoryAnalysisSubFile HistoryAnalysisParamsFile 
							HistoryAnalysisParamsDir HistoryAnalysisDirectionsFile HistoryAnalysisCensorFile 
							HistoryAnalysisRegistryFile HistoryAnalysisByearsFile HistoryAnalysisDirectionsDir HistoryAnalysisCensorDir 
							HistoryAnalysisRegistryDir HistoryAnalysisByearsDir HistorySplitFilesUnionPref HistoryPatterns
							CondorHistoryShiftSubFile ShiftAgeRange ShiftTimeWindow ShiftLastDate     
						    SplitFilesUnionPref ShiftAnalysisFile ShiftFP ShiftScoreTarget ShiftParamsFile PreShiftSuffix/ ;			   
	map {die "Required key \'$_\' missing." if (! exists $conf{$_})} @required_keys ;
	die "Unknown method \'$conf{Method}\'" if (! exists $methods{$conf{Method}}) ;
	
	die "Combined-learning with Gender-Flag set to 0. Are you sure ? Add \'IgnoreGender := Y\' to configuration file if so." 
		if ($combined_learn and ((!exists $conf{IgnoreGender}) or ($conf{IgnoreGender} ne "Y")) and $conf{FeatureParams} =~ m/^G0/) ;
	
	# Predict Without History
	my $data_dir = (exists $conf{SplitDir}) ? $conf{SplitDir} : $conf{WorkDir} ;
	my $pred_dir = (exists $conf{LearnOutDir}) ? $conf{LearnOutDir} : $conf{WorkDir} ;
	my $out_dir = (exists $conf{HistoryPredictOutDir}) ? $conf{HistoryPredictOutDir} : $conf{WorkDir} ;
	my $type = $conf{TrainingMatrixSuffix} ;
	my @patterns = split ",",$conf{HistoryPatterns} ;
		
	my $runner_file_name = "$out_dir/$conf{CondorHistoryPredictSubFile}" ;
	my $sub_file_info = {queue_list => [], dir => $out_dir, run => $runner_file_name};	
	$sub_file_info->{req} = $conf{CondorHistoryPredictReq} if (exists $conf{CondorHistoryPredictReq}) ;
	$sub_file_info->{mem_req} = $conf{CondorHistoryPredictMemReq} if (exists $conf{CondorHistoryPredictMemReq}) ;
	$sub_file_info->{rank} = $conf{CondorHistoryPredictRank} if (exists $conf{CondorHistoryPredictRank}) ;
	
	my $predict_method ;
	if (exists $conf{PredictMethod}) {
		$predict_method = $conf{PredictMethod} ;
	} elsif (exists $conf{Method}) {
		$predict_method = $conf{Method} ;
	} else {
		die "Either PredictMethod or Method must be given for predicting" ;
	}
	
	my $extra_params = "" ;
	if ($predict_method eq "DoubleMatched" or $predict_method eq "TwoSteps") {
		my $predict_internal_method ;
		if (exists $conf{PredictInternalMethod}) {
			$predict_internal_method = $conf{PredictInternalMethod} ;
		} elsif (exists $conf{InternalMethod}) {
			$predict_internal_method = $conf{InternalMethod} ;
		} else {
			die "Either PredictInternalMethod or InternalMethod must be given for DoubleMatched/TwoSteps predicting" ;
		}
		$extra_params .= " --internal_method $predict_internal_method" ;
	}
	$extra_params .= " --extraFeatures $conf{ExtraFeatures}" if (exists $conf{ExtraFeatures}) ;	
	$extra_params .= " $conf{PredictExtraParams}" if exists($conf{PredictExtraParams}) ;
	
	for my $i (1..$conf{SplitN}) {
	
		for my $gender (@genders) {
			my $learn_gender = ($combined_learn) ? "combined" : $gender ;	
		
			for my $pat (@patterns) {
				my %queue ;
				my $header = "$gender-$conf{Method}-PredictionOnTest$i" ;
				$queue{executable} = $execs{predict};
				$queue{initialdir} = $out_dir;
				$queue{in_size} = stat("$data_dir/$gender\_$type.test$i.bin")->size unless ($no_run);
				$queue{in_size} = stat("$data_dir/$gender\_$type.test$i.bin")->size unless ($no_run);
				$queue{arguments} = "--binFile $data_dir/$gender\_$type.test$i.bin ".
									"--predictorFile learn_split_$learn_gender\_predictor$i ".
									"--outliersFile learn_split_$learn_gender\_outliers$i ".
									"--completionFile learn_split_$learn_gender\_completion$i ".
									"--logFile SplitPredLog.$gender$i.Ptrn$pat ".
									"--featuresSelection $conf{FeatureParams} ".
									"--method $predict_method ".
									"--info $header ".
									"--predictOutFile split_predictions_history.$gender$i.Ptrn$pat ". 
									"$extra_params ".
									"--historyPattern $pat" ;
				$queue{transfer_input_files} = "$pred_dir/learn_split_$learn_gender\_predictor$i,$pred_dir/learn_split_$learn_gender\_outliers$i,$pred_dir/learn_split_$learn_gender\_completion$i" ;
				if (exists $conf{IncidenceFilesDir} and exists $conf{InternalPredictIncidencePrefix}) {
					$queue{arguments} .= " --incidence $conf{InternalPredictIncidencePrefix}.$gender" ;
					$queue{transfer_input_files} .= ",$conf{IncidenceFilesDir}/$conf{InternalPredictIncidencePrefix}.$gender" ;
				}
				$queue{transfer_output_files} = "SplitPredLog.$gender$i.Ptrn$pat,split_predictions_history.$gender$i.Ptrn$pat " ;
				$queue{error} = "history_split_predict_$gender.stderr$i.Ptrn$pat" ;
				$queue{log} = "$conf{CondorHistoryPredictSubFile}.log" ;

				push @{$sub_file_info->{queue_list}}, \%queue;
			}
		}
	}
		
	process_submit_info($sub_file_info);	    
	
	# Unite
	my $union = $conf{HistorySplitFilesUnionPref} ;
	foreach my $pat (@patterns) {
		my @men_files = map {"$out_dir/split_predictions_history.men$_.Ptrn$pat"} (1..$conf{SplitN}) ;
		unite_preds(\@men_files,"$out_dir/$union\_predictions.men.Ptrn$pat") ;
		my @women_files = map {"$out_dir/split_predictions_history.women$_.Ptrn$pat"} (1..$conf{SplitN}) ;
		unite_preds(\@women_files,"$out_dir/$union\_predictions.women.Ptrn$pat") ;	
		my @combined_files = (@men_files,@women_files) ;
		unite_preds(\@combined_files,"$out_dir/$union\_predictions.combined.Ptrn$pat") ;
	}

	# Shift
	#my $in_dir = $out_dir;
	#$out_dir = (exists $conf{ShiftOutDir}) ? $conf{ShiftOutDir} :  $conf{WorkDir} ;
	#$runner_file_name = "$out_dir/$conf{CondorHistoryShiftSubFile}" ;
	#$sub_file_info = {queue_list => [], dir => $out_dir, run => $runner_file_name};
	#$sub_file_info->{req} = $conf{CondorHistoryShiftReq} if (exists $conf{CondorHistoryShiftReq}) ;
	#$sub_file_info->{mem_req} = $conf{CondorShiftMemReq} if (exists $conf{CondorShiftMemReq}) ;
	#$sub_file_info->{rank} = $conf{CondorHistoryShiftRank} if (exists $conf{CondorHistoryShiftRank}) ;
	# TODO: continue writing shift part...
	
	# Analyze
	$out_dir = (exists $conf{HistoryAnalysisOutDir}) ? $conf{HistoryAnalysisOutDir} : $conf{WorkDir} ;
	$runner_file_name = "$out_dir/$conf{CondorHistoryAnalysisSubFile}" ;
	$sub_file_info = {queue_list => [], dir => $out_dir, run => $runner_file_name};
	$sub_file_info->{req} = $conf{CondorHistoryAnalysisReq} if (exists $conf{CondorHistoryAnalysisReq}) ;
	$sub_file_info->{mem_req} = $conf{CondorHistoryAnalysisMemReq} if (exists $conf{CondorHistoryAnalysisMemReq}) ;
	$sub_file_info->{rank} = $conf{CondorHistoryAnalysisRank} if (exists $conf{CondorHistoryAnalysisRank}) ;
	
	my $params ;
	$params = "--reg $conf{HistoryAnalysisRegistryFile} --byear $conf{HistoryAnalysisByearsFile} --censor $conf{HistoryAnalysisCensorFile} --dir $conf{HistoryAnalysisDirectionsFile}" ;
	$params .= " $conf{HistoryAnalysisParams}" if (exists $conf{HistoryAnalysisParams}) ;	
	
	for my $gender (@genders,"combined") {
		foreach my $pat (@patterns) {
			if ($pat==1) {
				my %queue ;			
				$queue{executable} = $execs{analyze};
				$queue{initialdir} = $out_dir;
				$queue{in_size} = stat("$out_dir/$union\_predictions.$gender.Ptrn$pat")->size unless ($no_run);
				$queue{arguments} = "--in $union\_predictions.$gender.Ptrn$pat --out Analysis.History.$gender.Ptrn$pat --params $conf{HistoryAnalysisParamsFile} $params" ;
				$queue{transfer_input_files} = "$out_dir/$union\_predictions.$gender.Ptrn$pat,$conf{HistoryAnalysisParamsDir}/$conf{HistoryAnalysisParamsFile},".
												"$conf{HistoryAnalysisCensorDir}/$conf{HistoryAnalysisCensorFile},$conf{HistoryAnalysisRegistryDir}/$conf{HistoryAnalysisRegistryFile},".
												"$conf{HistoryAnalysisByearsDir}/$conf{HistoryAnalysisByearsFile},$conf{HistoryAnalysisDirectionsDir}/$conf{HistoryAnalysisDirectionsFile}" ;
				$queue{output} = "analysis.history.$gender.Ptrn$pat.stdout" ;
				$queue{error} = "analysis.history.$gender.Ptrn$pat.stderr" ;
				$queue{log} = "$conf{CondorHistoryAnalysisSubFile}.log" ;
				
				push @{$sub_file_info->{queue_list}}, \%queue;	
			}
		}
	}

	process_submit_info($sub_file_info);
	
	print stderr "Successfully completed stage: History Analysis\n";
	print stderr "-------------------------------------------\n\n";		
}


##########################
#       FUNCTIONS
##########################

sub run_cmd {
	my ($command) = @_ ;
	
	print STDERR "Running \'$command\'\n" ;
	(system($command) == 0 or die "\'$command\' Failed" ) unless ($no_run) ;
	
	return ;
}

sub create_condor_header {
	my ($req,$exec,$dir,$mem_req,$rank) = @_ ;
	
	my $header =  "universe = vanilla\n" ;
	$header .= "requirements = $req\n" ;
	# header .= "environment = path=c:\winnt\system32\n" ;
	$header .= "executable = $exec\n\n" if ($exec ne "");
	$header .= "initialdir = $dir\n" if ($dir ne "");
	$header .= "rank = $rank\n" if ($rank ne "") ;
	$header .= "request_memory = $mem_req\n" if ($mem_req ne "") ;
	$header .= "should_transfer_files = YES\n" ;
	$header .= "when_to_transfer_output = ON_EXIT\n\n" ;

	return $header ;
}
	
sub add_condor_command {
	my ($hash)	= @_ ;
	
	# remove output files that already exist in order to avoid output file corruptions
	my @of_list;
	push @of_list, split(/\s*,\s*/, $hash->{transfer_output_files}) if (exists $hash->{transfer_output_files});
	push @of_list, $hash->{output} if (exists $hash->{output});
	push @of_list, $hash->{error} if (exists $hash->{error});
	for my $of (@of_list) {
		# print STDERR "Checking if output file $of already exists ...\n";
		if (not ($hash->{use_completions} and $of =~ m/completion/)) {
			if (-e $of) {
				print STDERR "Outout file $of already exists and is removed.\n";
				my $rc = unlink($of);
				die "Removal of $of failed" if ($rc != 1 or -e $of);
			}
		}
	}
	
	my $header = join "\n", (map {"$_ = ".correct_path_for_condor($hash->{$_})} keys %$hash) ;
	$header .= "\nqueue\n\n" ;

	$header =~ s/in_size/\# in_size/;
	$header =~ s/use_completions/\# use_completions/;
	
	return $header ;
}

sub process_submit_info {
    my ($info) = @_;
    
	return if (scalar(@{$info->{queue_list}})==0) ;
	
	if ($^O eq "linux") {
		$info->{req} =~ s/WINDOWS/LINUX/;
	}
	
	
	map {$info->{$_} = "" if (! exists $info->{$_})} qw/mem_req rank/ ;
    my $sub_txt = create_condor_header($info->{req}, "", $info->{dir},$info->{mem_req},$info->{rank});

	my $num_cmd = 0;
    for my $q (sort {$b->{in_size} <=> $a->{in_size}} @{$info->{queue_list}}) {
		$sub_txt .= add_condor_command($q);
		$num_cmd ++;
    }
    
    my $sub_fn = $info->{run};
    open (SUB,">$sub_fn") or die "Cannot open $sub_fn for writing" ;
    print SUB $sub_txt ;
    close SUB ;
	
	my $sub_log_fn = "$sub_fn.log";
	if (-e $sub_log_fn) {
			print STDERR "Condor runner log file $sub_log_fn already exists and is removed.\n";
			my $rc = unlink($sub_log_fn);
			die "Removal of $sub_log_fn failed" if ($rc != 1 or -e $sub_log_fn);
		}
    run_cmd("condor_submit $sub_fn") ;
    run_cmd("condor_wait $sub_log_fn") ;
	my $count_good_cmd = "cat $sub_log_fn | grep \"return value 0\" | wc -l";
	my $num_good =`$count_good_cmd`;
	die "Failed counting number of normal terminations with command: $count_good_cmd" unless ($? == 0);
    chomp $num_good;
	die "Only $num_good out of $num_cmd commands in $sub_fn terminated successfully, aborting now" unless ($num_good == $num_cmd);
}

sub read_configuration_file {
	my ($file,$conf) = @_ ;
	
	open (IN,$file) or die "Cannot open \'$file\' for reading" ;
	
	while (my $line = <IN>) {
		chomp $line ;
		$line =~ s/\r$//;
		$line =~ s/^\s+// ;
		$line =~ s/\s+$// ;
		next if ($line eq "" or $line =~ /^#/) ;	
		
		my @line = split /\s*:=\s*/,$line ;
		die "Cannot parse \'$line\'" if (@line != 2) ;
		
		my $key = shift @line ;
		die "Illegal variable \'$key\' in \'$line\'" if ($key =~ /\$/) ;
		die "Redifinition of variable \'$key\' in \'$line\'" if (exists $conf->{$key}) ;

		my $value = shift @line ;
		while ($value =~ /\$\{(\S+?)\}/) {
			die "Unknown Reference to key \$\{$1\}" if (! exists $conf->{$1}) ;
			$value =~ s/\$\{(\S+?)\}/$conf->{$1}/ ;
		}
		
		# check if value is a path or list of paths and convert accordingly under Linux
		if ($^O eq "linux") {
			while ($value =~ m/(\S:(\/[^\/, ]*)+)/g) {
				my $origPath = $1;
				my $cvtPath = correct_path_for_condor($origPath);
				$cvtPath =~ s|\\|/|g;
				$value =~ s/$origPath/$cvtPath/;
			}
		}
		
		$conf->{$key} = $value ;
	}

	return ;
}

sub unite_preds {
	my ($files,$out) = @_ ;
	
	open (OUT,">$out") or die "Cannot open $out for writing" ;
	print OUT "United Predictions\n" ;
	
	my %ids ;
	foreach my $file (@$files) {
	
		open (IN,$file) or die "Cannot open $file for reading" ;
		print STDERR "Reading $file\n" ;
	
		my $header = 1;
		while (my $line = <IN>) {
			chomp $line ;
			if ($header) {
				$header = 0 ;
			} else {
				my ($id) = split /\s+/,$line ;
				if (! exists $ids{$id} or $ids{$id} eq $file) {
					$ids{$id} = $file ;
					print OUT "$line\n" ;
				}
			}
		}
		close IN ;
	}

	close OUT ;	
	return ;
}
			
sub create_cutoffs_files {

	my ($validation_genders,$bnds_file_prefix,$all_points,$points) = @_ ;

	my %points = %$points ;
	
	foreach my $gender (@$validation_genders) {
		my $analysis_dir = (exists $conf{ValidateOutDir}) ? $conf{ValidateOutDir} :  $conf{WorkDir} ;
		my $analysis_file = "$analysis_dir/$conf{AnalysisFileForBoundsPrefix}.$gender" ;
		
		open (IN,$analysis_file) or die "Cannot open $analysis_file for reading" ;
		open (OUT,">$bnds_file_prefix.$gender") or die "Cannot open $bnds_file_prefix.$gender for writing" ;
		print STDERR "$analysis_file -> $bnds_file_prefix.$gender\n" ;
	
		my $header = 1 ;
		my ($tw_col,$ar_col);
		my %cols ;
		
		print OUT "MinDays\tMaxDays\tMinAge\tMaxAge\tScore\tTargetSens\tTargetSpec\n" ;
		
		while (<IN>) {
			chomp ;
			my @line = split  ;
			if ($header) {
				$header = 0 ;
				
				foreach my $i (0..$#line) {
					if ($line[$i] eq "Time-Window") {
						$tw_col = $i ;
					} elsif ($line[$i] eq "Age-Range") {
						$ar_col = $i ;
					} elsif ($line[$i] =~ /SCORE\@(\S+)-Mean/ and ($all_points==1 or exists $points{$1})) {
						$cols{$1}->{score} = $i ;
					} elsif ($line[$i] =~ /SENS\@(\S+)-Mean/ and ($all_points==1 or exists $points{$1})) {
						$cols{$1}->{sens} = $i ;
					} elsif ($line[$i] =~ /SPEC\@(\S+)-Mean/ and ($all_points==1 or exists $points{$1})) {
						$cols{$1}->{spec} = $i ;	
					}
				}
				
				die "Prbolem parsing $analysis_file" if (! defined $tw_col or ! defined $ar_col) ;
				
			} else {
				$line[$tw_col] =~ /(\d+)\-(\d+)/ or die "Cannot parse time window" ;
				my ($min_days,$max_days) = ($1,$2) ;
				$line[$ar_col] =~ /(\d+)-(\d+)/ or die "Cannot parse age range" ;
				my ($min_age,$max_age) = ($1,$2) ;
				
				my ($spec,$sens,$score) ;
				foreach my $point (keys %cols) {
					if ($point =~ /FP(\S+)/) {
						$spec = 100 - $1 ;
						($score,$sens) = ($line[$cols{$point}->{score}],$line[$cols{$point}->{sens}]) ;
					} else {
						$sens = $point ;
						($score,$spec) = ($line[$cols{$point}->{score}],$line[$cols{$point}->{spec}]) ;
					}
					print OUT "$min_days\t$max_days\t$min_age\t$max_age\t$score\t$sens\t$spec\n" ;
				}
			}			
		}
		close IN ;
		close OUT ;
		
		
		
		
	}
}	


sub create_cutoffs_files_autosim {

	my ($validation_genders,$bnds_file_prefix,$all_points,$points) = @_ ;

	my %points = %$points ;
	
	foreach my $gender (@$validation_genders) {
		my $analysis_dir = (exists $conf{ValidateOutDir}) ? $conf{ValidateOutDir} :  $conf{WorkDir} ;
		my $analysis_file = "$analysis_dir/$conf{AnalysisFileForBoundsPrefix}.$gender.AutoSim" ;
		
		open (IN,$analysis_file) or die "Cannot open $analysis_file for reading" ;
		open (OUT,">$bnds_file_prefix.$gender.AutoSim") or die "Cannot open $bnds_file_prefix.$gender for writing" ;
		print STDERR "$analysis_file -> $bnds_file_prefix.$gender.AutoSim\n" ;
	
		my $header = 1 ;
		my ($ar_col);
		my %cols ;
		
		print OUT "MinAge\tMaxAge\tScore\tTargetSens\tTargetSpec\tTargetEarlySens1\tTargetEarlySens2\tTargetEarlySens3\n" ;
		
		while (<IN>) {
			chomp ;
			my @line = split  ;
			if ($header) {
				$header = 0 ;
				
				foreach my $i (0..$#line) {
					if ($line[$i] eq "Age-Range") {
						$ar_col = $i ;
					} elsif ($line[$i] =~ /SCORE\@FP(\S+)-Mean/ and ($all_points==1 or exists $points{$1})) {
						$cols{$1}->{score} = $i ;
					} elsif ($line[$i] =~ /SENS\@FP(\S+)-Mean/ and ($all_points==1 or exists $points{$1})) {
						$cols{$1}->{sens} = $i ;
					} elsif ($line[$i] =~ /SPEC\@FP(\S+)-Mean/ and ($all_points==1 or exists $points{$1})) {
						$cols{$1}->{spec} = $i ;	
					} elsif ($line[$i] =~ /EarlySens1\@FP(\S+)-Mean/ and ($all_points==1 or exists $points{$1})) {
						$cols{$1}->{EarlySens1} = $i ;	
					} elsif ($line[$i] =~ /EarlySens2\@FP(\S+)-Mean/ and ($all_points==1 or exists $points{$1})) {
						$cols{$1}->{EarlySens2} = $i ;	
					} elsif ($line[$i] =~ /EarlySens3\@FP(\S+)-Mean/ and ($all_points==1 or exists $points{$1})) {
						$cols{$1}->{EarlySens3} = $i ;	
					}
				}
				
				die "Prbolem parsing $analysis_file" if (! defined $ar_col) ;
				
			} else {
				$line[$ar_col] =~ /(\d+)-(\d+)/ or die "Cannot parse age range" ;
				my ($min_age,$max_age) = ($1,$2) ;
				
				my ($spec,$sens,$score,$EarlySens1 , $EarlySens2 , $EarlySens3) ;
				foreach my $point (sort {$a <=> $b} keys %cols) {
					$spec = 100 - $point ;
					$score = $line[$cols{$point}->{score}];
					$sens = $line[$cols{$point}->{sens}];
					$EarlySens1 = $line[$cols{$point}->{EarlySens1}];
					$EarlySens2 = $line[$cols{$point}->{EarlySens2}];
					$EarlySens3 = $line[$cols{$point}->{EarlySens3}];
					print OUT join ("\t", $min_age,$max_age,$score,$sens,$spec,$EarlySens1 , $EarlySens2 , $EarlySens3)."\n" ;
				}
			}			
		}
		close IN ;
		close OUT ;
	}
}	



