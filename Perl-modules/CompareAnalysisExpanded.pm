package CompareAnalysisExpanded ;
package CompareAnalysisExpanded ;
use Exporter qw(import) ;

use strict(vars) ;

my %cross_sections ;
my %age_ranges ;

our @EXPORT_OK = qw(compare_analysis) ;

sub compare_analysis {
	
	my @errors ;
	
	# Params:
	# 1. CompareInFile is a file that holds paths for "gold standard" results file list and "current" results file list
	# 2. CompareOutFile is the path+name for the detailed comparison results file
	# 3. CompareSummaryOutFile is the path+name for the summary comparison results file
	# 4. AllowDifferentChecksums is a Y/N flag stating whether population should be identical or not ('N' means the comparison will only work if populations in gold-standard and current are identical)
	# 5. AllowDifferentList is a Y/N flag stating whether the CurrentFilesList should be identical (dataset+gender) in gold-standard vs. current
	# 6. Measure is the path of a file that contains a list of measures to be compared
	
	my ($compare,$out,$smmry,$allow_diff_checksum,$allow_diff_list,$measures,$stderr) = @_ ;
	my $allow_diff_cross_section_list = 1;
	
	open (SMMRY, ">$smmry") or die "Cannot open $smmry for writing" ;
	open (OUT,">$out") or die "Cannot open $out for writing" ;
	open (ERR,">$stderr") or die "Cannot open $stderr for writing" ;

	# Read
	# Measures
	my %measures ;
	open (MSR,$measures) or die "Cannot open $measures for reading" ;
	while(<MSR>) {
		chomp ;
		my ($type,$measure) = split ;
		die "Measure type must be either \'autosim\' or \'windows\'" if ($type ne "autosim" and $type ne "windows") ;
		push @{$measures{$type}},$measure ;
	}
	print ERR "Read measures list from $measures.\n" ;
	close MSR ;

	# Compare File
	my %lists ;
	my @names ;
	open (LST,$compare) or die "Cannot open $compare for reading" ;
	while (<LST>) {
		chomp ;
		my ($name,$list_file) = split /\t/,$_ ;
		$lists{$name} = $list_file ;
		push @names,$name
	}
	die "Exactly two lines required in compare file $compare" if (scalar(@names) != 2) ;
	print ERR "Read lists to compare from $compare.\n" ;
	close LST ;

	# List Files
	my %data ;
	my %headers ;
	foreach my $name (@names) {
		my $list = $lists{$name} ;
		open (IN,$list) or die "Cannot open $list for reading" ;

		while (<IN>) {
			chomp ;
			my ($dataset,$gender,$file) = split /\t/,$_ ;
			$data{$name}->{$dataset}->{$gender} = read_file($file,\%headers) ;
		}
		close IN ;
		print ERR "Read list of $name files from $list.\n" ;
	}
	my ($data1,$data2) = map {$data{$_}} @names ;

	# Check Compatability of Measures and Data
	my @windows_header = split /\t/,$headers{windows} ;
	splice(@windows_header,0,4) ; # Remove first 4 headers
	my %windows_header = map {($windows_header[$_] => $_)} (0..$#windows_header) ;

	my @autosim_header = split /\t/,$headers{autosim} ;
	splice(@autosim_header,0,3) ; # Remove first 3 headers
	my %autosim_header = map {($autosim_header[$_] => $_)} (0..$#autosim_header) ;

	# Verify all required measures listed in $measures are included in headers,
	# and create map {%windows_measures} from measure name to associated header string
	my %windows_measures ;
	foreach my $measure (@{$measures{windows}}) {
		die "Windows-measure \'$measure\' not found in header" if (! exists $windows_header{"$measure-Obs"}) ;
		$windows_measures{$measure} = $windows_header{"$measure-Obs"} ;
	}
	print ERR "Required measures successfully found in windows file headers.\n" ;
	
	my %autosim_measures ;
	foreach my $measure (@{$measures{autosim}}) {
		die "Autosim-measure \'$measure\' not found in header" if (! exists $autosim_header{"$measure-Obs"}) ;
		$autosim_measures{$measure} = $autosim_header{"$measure-Obs"} ;
	}
	print ERR "Required measures successfully found in autosim file headers.\n" ;
	
	# Collect (Paired and UnPaired)
	my %paired ; # same measures calculated on exact same population (using checksum)
	my %unpaired ; # same measures calculated on different population (unequal checksum, empty if $allow_diff_checksum == 0)

	foreach my $dataset (keys %$data1) {
		foreach my $gender (keys %{$data1->{$dataset}}) {
			my $current1 = $data1->{$dataset}->{$gender} ;
		
			if (exists $data2->{$dataset}->{$gender}) {
				my $current2 = $data2->{$dataset}->{$gender} ;
				
				# Windows comparison
				foreach my $cs (keys %cross_sections) {
					if (! exists $current2->{windows}->{$cs}) {
						die "Missing cross-section $cs in one of the datasets\n" unless ($allow_diff_cross_section_list) ;
						next;
					}
					if ($current1->{windows}->{$cs}->{checksum} != $current2->{windows}->{$cs}->{checksum}) {
						die "Checksum mismatch at $dataset/$gender/$cs\n" unless ($allow_diff_checksum) ;
						push @{$unpaired{windows}->{$cs}},{gender => $gender, dataset => $dataset, data => [$current1->{windows}->{$cs}->{data},$current2->{windows}->{$cs}->{data}]} ;
					} else {
						push @{$paired{windows}->{$cs}},{gender => $gender, dataset => $dataset, data => [$current1->{windows}->{$cs}->{data},$current2->{windows}->{$cs}->{data}]} ;
					}
				}
			
				# Autosim comparison
				foreach my $ar (keys %age_ranges) {
					if (! exists $current2->{autosim}->{$ar}) {
						die "Missing age-range $ar in one of the datasets\n" unless ($allow_diff_cross_section_list) ;
						next;
					}
					if ($current1->{autosim}->{$ar}->{checksum} != $current2->{autosim}->{$ar}->{checksum}) {
						die "Checksum mismatch at $dataset/$gender/$ar\n" unless ($allow_diff_checksum) ;		
						push @{$unpaired{autosim}->{$ar}},{gender => $gender, dataset => $dataset, data => [$current1->{autosim}->{$ar}->{data},$current2->{autosim}->{$ar}->{data}]} ;
					} else {
						push @{$paired{autosim}->{$ar}},{gender => $gender, dataset => $dataset, data => [$current1->{autosim}->{$ar}->{data},$current2->{autosim}->{$ar}->{data}]} ;
					}
				}
			} else {
				die "$dataset-$gender only in \'$names[0]\'\n" unless ($allow_diff_list) ;
			}
		}
	}

	# Verify that both sources have same dataset+gender combinations,
	# unless $allow_diff_list = 1
	foreach my $dataset (keys %$data2) {
		foreach my $gender (keys %{$data2->{$dataset}}) {
			my $current2 = $data2->{$dataset}->{$gender} ;
			if (! exists $data1->{$dataset}->{$gender}) {
				die "$dataset-$gender only in \'$names[1]\'\n" unless ($allow_diff_list) ;
			}
		}
	}

	# Create Output
	print OUT "Dataset\tGender\tType\tCrossSection\tMeasure\t$names[0]\t$names[0]-lower\t$names[0]-upper\t$names[1]\t$names[1]-lower\t$names[1]-upper\tDirections\n" ;
	# Windows - Print
	foreach my $cs (keys %{$paired{windows}}) {
		foreach my $rec (@{$paired{windows}->{$cs}}) {	
			
			my $data1 = $rec->{data}->[0] ;
			my $data2 = $rec->{data}->[1] ;
			my ($dataset,$gender) = map {$rec->{$_}} qw/dataset gender/ ;
			print_paired($data1,$data2,$dataset,$gender,$cs,"Windows",\@windows_header) ;
		}
	}

	# AutoSim - Print
	foreach my $ar (keys %{$paired{autosim}}) {
		for my $rec (@{$paired{autosim}->{$ar}}) {
		
			my $data1 = $rec->{data}->[0] ;
			my $data2 = $rec->{data}->[1] ;
			my ($dataset,$gender) = map {$rec->{$_}} qw/dataset gender/ ;
			print_paired($data1,$data2,$dataset,$gender,$ar,"AutoSim",\@autosim_header) ;
		}
	}
	
	# UnPairedWindows - Print
	foreach my $cs (keys %{$unpaired{windows}}) {
		foreach my $rec (@{$unpaired{windows}->{$cs}}) {	
			
			my $data1 = $rec->{data}->[0] ;
			my $data2 = $rec->{data}->[1] ;
			my ($dataset,$gender) = map {$rec->{$_}} qw/dataset gender/ ;
			print_paired($data1,$data2,$dataset,$gender,$cs,"UnPairedWindows",\@windows_header) ;
		}
	}

	# UnPairedAutoSim - Print
	foreach my $ar (keys %{$unpaired{autosim}}) {
		for my $rec (@{$unpaired{autosim}->{$ar}}) {
		
			my $data1 = $rec->{data}->[0] ;
			my $data2 = $rec->{data}->[1] ;
			my ($dataset,$gender) = map {$rec->{$_}} qw/dataset gender/ ;
			print_paired($data1,$data2,$dataset,$gender,$ar,"UnPairedAutoSim",\@autosim_header) ;
		}
	}


	# Compare -Paired Data
	my $sdvnum_bnd = 1.0 ;

	my %comparisons ;
	my %nums ;

	# Windows - Collect
	foreach my $cs (keys %{$paired{windows}}) {
		for my $rec (@{$paired{windows}->{$cs}}) {	
			
			my $data1 = $rec->{data}->[0] ;
			my $data2 = $rec->{data}->[1] ;
			my ($dataset,$gender) = map {$rec->{$_}} qw/dataset gender/ ;
			
			my ($npos_obs1,$npos_mean1,$npos_sdv1,$npos_ci_lower1,$npos_ci_upper1) = map {$data1->[$_]} (0..4) ;
			my ($npos_obs2,$npos_mean2,$npos_sdv2,$npos_ci_lower2,$npos_ci_upper2) = map {$data2->[$_]} (0..4) ;
			die "NPOS mismatch in $cs ($dataset-$gender) - $npos_mean1 [$npos_ci_lower1,$npos_ci_upper1] vs $npos_mean2 [$npos_ci_lower2,$npos_ci_upper2]" 
					unless ($npos_mean1>=$npos_ci_lower2 and $npos_mean1<=$npos_ci_upper2 and $npos_mean2>=$npos_ci_lower1 and $npos_mean2<=$npos_ci_upper1) ;
		
			compare_paired($data1,$data2,$dataset,$gender,"Windows",$cs,\%windows_measures,\%nums,\%comparisons,\@names,$sdvnum_bnd) ;
		}
	}

	# AutoSim - Collect
	foreach my $ar (keys %{$paired{autosim}}) {
		for my $rec (@{$paired{autosim}->{$ar}}) {
		
			my $data1 = $rec->{data}->[0] ;
			my $data2 = $rec->{data}->[1] ;
			my ($dataset,$gender) = map {$rec->{$_}} qw/dataset gender/ ;
		
			compare_paired($data1,$data2,$dataset,$gender,"AutoSim",$ar,\%autosim_measures,\%nums,\%comparisons,\@names,$sdvnum_bnd) ;
		}
	}

	# Summarize
	my %scores = ("$names[0]AboveCI" => -3, "$names[0]Above1Sig" => -2, "$names[0]Higher" => -1, "Equalt" => 0, "$names[1]Higher" => 1, "$names[1]Above1Sig" => 2, "$names[1]AboveCI" => 3) ;
	print SMMRY "Paired Summary:\n" ;
	printf SMMRY "%30s\tNum\t$names[0]AboveCI\%\t<=$names[0]Above1Sig\%\t<=$names[0]Higher\%\tEqual\%\t>=$names[1]Higher\%\t>=$names[1]Above1Sig\%\t$names[1]AboveCI\%\tFinalScore\n","Class" ;

	foreach my $class (sort keys %nums) {
		$class =~ /\d+:(\S+)/ or die "$class ?" ;
		my $num = $nums{$class} ;
		printf SMMRY "%30s\t$num",$1 ;
		
		my $cnt = 0 ;
		my $score = 0 ;
		
		foreach my $comp ("$names[0]AboveCI","$names[0]Above1Sig","$names[0]Higher") {
			if (exists $comparisons{$class}->{$comp}) {
				$cnt += $comparisons{$class}->{$comp}  ;
				$score += $comparisons{$class}->{$comp} * $scores{$comp} ;
			}
			
			printf SMMRY "\t%.1f",100*$cnt/$num ;
		}
		
		$cnt = 0 ;
		$cnt += $comparisons{$class}->{Equal} if (exists $comparisons{$class}->{Equal}) ;
		printf SMMRY "\t%.1f",100*$cnt/$num ;
		
		my @cnts ;
		$cnt = 0 ;
		foreach my $comp ("$names[1]AboveCI","$names[1]Above1Sig","$names[1]Higher") {
			if (exists $comparisons{$class}->{$comp}) {
				$cnt += $comparisons{$class}->{$comp}  ;
				$score += $comparisons{$class}->{$comp} * $scores{$comp} ;
			}
			push @cnts,$cnt ;
		}
		map {printf SMMRY "\t%.1f",100*$_/$num} reverse @cnts ;
		printf SMMRY "\t%.2f\n",$score/$num ;
	}	
}

# Strict Comparison
# Input : map : Current/GoldStandard -> FileNames  ; MeasuresFile; [allow_diff flag]
# Output : Error Code + List of Errors
sub strict_compare_analysis {
	my ($files, $measures, $allow_diff_checksums,$allow_diff_numbers) = (undef, undef, 0,0);
	($files, $measures) = @_ if (@_ == 2);
	($files, $measures, $allow_diff_checksums,$allow_diff_numbers) = @_ if (@_ == 4);
	
	# Read
	# Measures
	my %measures ;
	open (MSR,$measures) or die "Cannot open $measures for reading" ;
	while(<MSR>) {
		print STDERR $_;
		chomp ;
		my ($type,$measure) = split ;
		die "Measure type must be either \'autosim\' or \'windows\'" if ($type ne "autosim" and $type ne "windows") ;
		push @{$measures{$type}},$measure ;
	}
	close MSR ;
	
	my @names = qw/Current GoldStandard/ ;
	map {die "$_ missing from files" if (! exists $files->{$_})} @names ;

	# List Files
	my %data ;
	my %headers ;
	foreach my $name (@names) {
		my $list = $files->{$name} ;
		open (IN,$list) or die "Cannot open $list for reading" ;

		while (<IN>) {
			chomp ;
			my ($dataset,$gender,$file) = split /\t/,$_ ;
			$data{$name}->{$dataset}->{$gender} = read_file($file,\%headers) ;
		}
		close IN ;
	}
	
	my $data1 = $data{GoldStandard} ;
	my $data2 = $data{Current} ;

	# Check Compatability of Measures and Data
	my @windows_header = split /\t/,$headers{windows} ;
	splice(@windows_header,0,4) ;
	my %windows_header = map {($windows_header[$_] => $_)} (0..$#windows_header) ;
	
	my @autosim_header = split /\t/,$headers{autosim} ;
	splice(@autosim_header,0,3) ;
	my %autosim_header = map {($autosim_header[$_] => $_)} (0..$#autosim_header) ;

	my %windows_measures ;
	foreach my $measure (@{$measures{windows}}) {
		die "Windows-measure \'$measure\' not found in header" if (! exists $windows_header{"$measure-Obs"}) ;
		$windows_measures{$measure} = $windows_header{"$measure-Obs"} ;
	}

	my %autosim_measures ;
	foreach my $measure (@{$measures{autosim}}) {
		die "Autosim-measure \'$measure\' not found in header" if (! exists $autosim_header{"$measure-Obs"}) ;
		$autosim_measures{$measure} = $autosim_header{"$measure-Obs"} ;
	}

	# Collect
	my %compare ;
	foreach my $dataset (keys %$data1) {
		foreach my $gender (keys %{$data1->{$dataset}}) {
			my $current1 = $data1->{$dataset}->{$gender} ;
		
			if (exists $data2->{$dataset}->{$gender}) {
				my $current2 = $data2->{$dataset}->{$gender} ;
				foreach my $cs (keys %cross_sections) {
					if ($current1->{windows}->{$cs}->{checksum} != $current2->{windows}->{$cs}->{checksum}) {
						return (-1,["Checksum at $dataset/$gender/$cs"]) unless ($allow_diff_checksums);
						print STDERR "WARNING: Checksum mismatch at $dataset/$gender/$cs\n";
					} 
					push @{$compare{windows}->{$cs}},{gender => $gender, dataset => $dataset, data => [$current1->{windows}->{$cs}->{data},$current2->{windows}->{$cs}->{data}]} ;
					
				}
			
				foreach my $ar (keys %age_ranges) {
					if ($current1->{autosim}->{$ar}->{checksum} != $current2->{autosim}->{$ar}->{checksum}) {
						return (-1,["Checksum at $dataset/$gender/$ar"]) unless ($allow_diff_checksums) ;
						print STDERR "WARNING: Checksum mismatch at $dataset/$gender/$ar\n" ;
					} 
					push @{$compare{autosim}->{$ar}},{gender => $gender, dataset => $dataset, data => [$current1->{autosim}->{$ar}->{data},$current2->{autosim}->{$ar}->{data}]} ;
				}
			} else {
				return (-1,["Missing $dataset/$gender/"]) ;
			}
		}
	}

	foreach my $dataset (keys %$data2) {
		foreach my $gender (keys %{$data2->{$dataset}}) {
			if (! exists $data1->{$dataset}->{$gender}) {
				return (-1,["Missing $dataset/$gender/"]) ;
			}
		}
	}

	# Compare
	my @errors ;
	# Windows - Collect
	foreach my $cs (keys %{$compare{windows}}) {
		for my $rec (@{$compare{windows}->{$cs}}) {	
			
			my $data1 = $rec->{data}->[0] ;
			my $data2 = $rec->{data}->[1] ;
			my ($dataset,$gender) = map {$rec->{$_}} qw/dataset gender/ ;
			
			my ($npos_obs1,$npos_mean1,$npos_sdv1,$npos_ci_lower1,$npos_ci_upper1) = map {$data1->[$_]} (0..4) ;
			my ($npos_obs2,$npos_mean2,$npos_sdv2,$npos_ci_lower2,$npos_ci_upper2) = map {$data2->[$_]} (0..4) ;
			unless ($npos_mean1>=$npos_ci_lower2 and $npos_mean1<=$npos_ci_upper2 and $npos_mean2>=$npos_ci_lower1 and $npos_mean2<=$npos_ci_upper1)  {
				return (-1,["NPOS at $dataset/$gender/$cs"]) unless($allow_diff_numbers) ;
				print STDERR "WARNING: Number mismatch at $dataset/$gender/$cs\n" ;
			}
			strict_compare($data1,$data2,$dataset,$gender,"Windows",$cs,\%windows_measures,\@errors) ;
		}
	}

	# AutoSim - Collect
	foreach my $ar (keys %{$compare{autosim}}) {
		for my $rec (@{$compare{autosim}->{$ar}}) {
		
			my $data1 = $rec->{data}->[0] ;
			my $data2 = $rec->{data}->[1] ;
			my ($dataset,$gender) = map {$rec->{$_}} qw/dataset gender/ ;
		
			strict_compare($data1,$data2,$dataset,$gender,"AutoSim",$ar,\%autosim_measures,\@errors) ;
		}
	}
	
	close ERR ;
	return (0,\@errors) ;
}

############################################################################
# Internal Functions
###########################

# Read bootstrap analysis result files
sub read_file {
	my ($name,$headers) = @_ ;
	
	my ($nwin,$nauto) = (0,0) ; # Not used
	
	my %data ;
	
	# Windows
	open (FL,$name) or die "Cannot open $name for reading" ;
	my $first = 1 ;
	
	while (my $line = <FL>) {
		$line =~ s/\r?\n$//; # Remove new line chars (both unix and windows)
		chomp $line ;
		$line =~ s/\r//g ; 
		
		next if ($line eq "") ;
		
		if ($first == 1) {
			$first = 0 ;
			$headers->{windows} = $line if (! exists $headers->{windows}) ;
			die "Header Mismatch at \'$name\ : $line vs. $headers->{windows}'" if ($line ne $headers->{windows}) ;
		} else {
			my ($time,$age,$checksum,$nbootstrap,@data_row) = split /\t/,$line ;
			$data{windows}->{"$time\_$age"} = {checksum => $checksum, data => \@data_row} ;
			# print STDERR "DEBUG: $time\_$age, checksum => $checksum, length-data => ".(scalar @data_row)."\n";
			$nwin ++ ;
		}
	}
	close FL ;

	# Autosim
	open (FL,"$name.Autosim") or die "Cannot open $name.Autosim for raeding" ;
	$first = 1 ;
	
	while (my $line = <FL>) {
		$line =~ s/\r?\n$//; # Remove new line chars (both unix and windows)
		chomp $line;
		$line =~ s/\r//g ;  
		
		next if ($line eq "") ;
		
		if ($first == 1) {
			$first = 0 ;
			$headers->{autosim} = $line if (! exists $headers->{autosim}) ;
			die "Header Mismatch at \'$name\'" if ($line ne $headers->{autosim}) ;
		} else {
			my ($age,$checksum,$nbootstrap,@data_row) = split /\t/,$line ;
			$data{autosim}->{$age} = {checksum => $checksum, data => \@data_row} ;
			$nauto++ ;
		}
	}
	close FL ;
	
	# First time, populate cross-sections hash with all time-window/age-range combinations in file {$name} as keys
	# If cross-sections is already populated, verify the new file contains the exact same set of time-window/age-range combinations
	if (%cross_sections) {
		map {print STDERR "CrossSection Mismatch at \'$name\' : $_ is new\n" if (! exists $cross_sections{$_})} keys %{$data{windows}} ;
		map {print STDERR "CrossSection Mismatch at \'$name\' : $_ is missing\n" if (! exists $data{windows}->{$_})} keys %cross_sections ;
	} else {
		map {$cross_sections{$_} = 1} keys %{$data{windows}} ;
	}
	
	# Similarily, verify all AutoSim files have same list of age-ranges
	if (%age_ranges) {
		map {print STDERR "AgeRange Mismatch at \'$name\' : $_ is new\n" if (! exists $age_ranges{$_})} keys %{$data{autosim}} ;
		map {print STDERR "AgeRange Mismatch at \'$name\' : $_ is missing\n" if (! exists $data{autosim}->{$_})} keys %age_ranges ;
	} else {
		map {$age_ranges{$_} = 1} keys %{$data{autosim}} ;
	}
	
	return \%data ;
}	
		
######################################
sub compare_paired {
	my ($data1,$data2,$dataset,$gender,$pref,$type,$measures,$nums,$comparisons,$names,$sdvnum_bnd) = @_ ;		

	my ($names0,$names1) = @$names ;
	
	foreach my $measure (keys %$measures) {
		my $col = $measures->{$measure} ;
		my $name = "$pref-$measure" ;	
	
		my ($obs1,$mean1,$sdv1,$ci_lower1,$ci_upper1) = map {$data1->[$col+$_]} (0..4) ;
		my ($obs2,$mean2,$sdv2,$ci_lower2,$ci_upper2) = map {$data2->[$col+$_]} (0..4) ;
		
		$nums->{"0:TOTAL"} ++ ;
		$nums->{"1:Type-$type"} ++ ;
		$nums->{"2:Measure-$name"} ++ ;
		$nums->{"3:DataSet-$dataset"} ++ ;
		$nums->{"4:Gender-$gender"} ++ ;
			
		my $comp ;
		my $delta = $mean1 - $mean2 ;
		my $sdv = sqrt(($sdv1*$sdv1 + $sdv2*$sdv2)/2);
		
		if ($mean1 > $ci_upper2) {
			$comp = $names0."AboveCI" ;
		} elsif ($delta/$sdv > $sdvnum_bnd) {
			$comp = $names0."Above1Sig" ;
		} elsif ($delta > 0) {
			$comp = $names0."Higher" ;
		} elsif ($mean2 > $ci_upper1) {
			$comp = $names1."AboveCI" ;
		} elsif (-$delta/$sdv > $sdvnum_bnd) {
			$comp = $names1."Above1Sig" ;
		} elsif ($delta < 0) {
			$comp = $names1."Higher" ;
		} else {
			$comp = "Equal" ;
		}
		
		$comparisons->{"0:TOTAL"}->{$comp} ++ ;
		$comparisons->{"1:Type-$type"}->{$comp} ++ ;
		$comparisons->{"2:Measure-$name"}->{$comp} ++ ;
		$comparisons->{"3:DataSet-$dataset"}->{$comp} ++ ;	
		$comparisons->{"4:Gender-$gender"}->{$comp} ++ ;
	}	
}

sub strict_compare {
	my ($data1,$data2,$dataset,$gender,$pref,$type,$measures,$errors) = @_ ;		

	foreach my $measure (keys %{$measures}) {
		my $col = $measures->{$measure} ;
		
		my $name = "$pref-$measure" ;	
	
		my ($obs1,$mean1,$sdv1,$ci_lower1,$ci_upper1) = map {$data1->[$col+$_]} (0..4) ; 
		my ($obs2,$mean2,$sdv2,$ci_lower2,$ci_upper2) = map {$data2->[$col+$_]} (0..4) ;
		
		print STDERR ("$pref-$measure at $gender/$dataset. (obs1=$obs1,mean1=$mean1,sdv1=$sdv1,$ci_lower1,$ci_upper1) (obs2=$obs2,mean2=$mean2,sdv2=$sdv2,$ci_lower2,$ci_upper2) started at col $col\n");
		push @$errors,"$pref-$measure at $gender/$dataset. $mean2 < $ci_lower1" if ($mean2 < $ci_lower1) ;
	}
}


sub print_paired {
	my ($data1,$data2,$dataset,$gender,$cs,$pref,$header,) = @_ ;
	
	for (my $i=0; $i<scalar(@$data1); $i+=5) {
		my ($obs1,$mean1,$sdv1,$lower1,$upper1) = map {$data1->[$_]} ($i..$i+4) ;
		my ($obs2,$mean2,$sdv2,$lower2,$upper2) = map {$data2->[$_]} ($i..$i+4) ;
		
		my $name = $header->[$i+1] ;
		$name =~ s/-Mean// ;
		
		print OUT "$dataset\t$gender\t$pref\t$cs\t$name\t$mean1\t$lower1\t$upper1\t$mean2\t$lower2\t$upper2" ;
		
		my $direction ;
		if ($name =~ /SCORE/ or $name =~/NLR/ or $name =~/NPOS/ or $name =~/NNEG/ or $name =~ /TP@/ or $name =~/FP@/) {
			$direction = "NotForComparison" ;
		} elsif ($mean1 eq 'NA' or $mean2 eq 'NA') {
			$direction = "NA";
		} else {
			$direction = "" ; 
			if ($mean2 > $upper1 or $mean1 < $lower2) {
				$direction = "+++" ;
			} elsif ($mean2 > $mean1 + $sdv1 or $mean1 < $mean2 - $sdv2) {
				$direction = "++" ;
			} elsif ($mean2 > $mean1) {
				$direction = "+" ;
			} elsif ($mean1 > $upper2 or $mean2 < $lower1) {
				$direction = "---" ;
			} elsif ($mean1 > $mean2 + $sdv2 or $mean2 < $mean1 - $sdv1) {
				$direction = "--" ;
			} elsif ($mean1 > $mean2) {
				$direction = "-" ;
			}
		}
		print OUT "\t$direction\n" ;
	}
}