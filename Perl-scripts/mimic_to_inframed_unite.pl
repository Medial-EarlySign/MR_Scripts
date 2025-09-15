#!/usr/bin/env perl 

use strict(vars) ;
use FileHandle ;

die "Usage : $0 InDirFile OutDir" if (@ARGV!=2) ;
my ($inDirFile,$outDir) = @ARGV ;

# Read Directories
open(IN,$inDirFile) or die "Cannot open $inDirFile for reading" ;
my @inDirs ;
while (<IN>) {
	chomp ;
	push @inDirs,$_ ;
}
close IN ;

my $nDirs = scalar @inDirs ;
print STDERR "Read $nDirs input directories\n" ;

# Sanity check : Ids intersection
checkIdsIntersection(\@inDirs) ;

# Unite data files :
uniteDataFiles(\@inDirs,$outDir) ;

# Unite info files
uniteInfoFiles(\@inDirs,$outDir) ;

# Wait for all sorts to end
while (wait() != -1) {}

### FUNCTIONS ####

sub checkIdsIntersection {
	my ($dirs) = @_ ;
	
	my %ids ;
	foreach my $dir (@$dirs) {
		my $fileName = "$dir/ICU.ICU_STAYS_N" ;
		open (IN,$fileName) ;
		
		my %fileIds ;
		while (<IN>) {
			chomp ;
			my ($id) = split ;
			$fileIds{$id} = 1 ;
		}
		close IN ;
		
		my $nIds = scalar keys %fileIds ;
		print STDERR "SanityCheck : $nIds ids in $fileName\n" ;
		
		foreach my $id (keys %fileIds) {
			die "Id $id appears in $dir and in $ids{$dir}" if (exists $ids{$id}) ;
			$ids{$id} = $dir ;
		}
	}
	print STDERR "SanityCheck Passed\n" ;
	
}

sub uniteDataFiles {
	my ($dirs,$outDir) = @_ ;
	
	my $n = scalar @$dirs ;
	
	foreach my $fileName (qw/ICU.ChartEvents_N ICU.ChartEvents_S ICU.Comorbidities ICU.Demographics ICU.ExtraEvents ICU.ICD9 ICU.ICU_Stays_N ICU.ICU_Stays_S ICU.IOEvents_N ICU.IOEvents_S ICU.LabEvents_N
							ICU.LabEvents_S ICU.MedEvents_N ICU.MicroBiologyEvents_N ICU.PoeOrder_N ICU.PROCEDURES/) {
		
		print STDERR "Uniting $fileName\n" ;
		open (OUT,">$outDir/$fileName.tmp") or die "Failed openning\n" ;
		
		my $idx = 0 ; 
		
		foreach my $dir (@$dirs) {
			$idx ++ ;
			print STDERR "$idx/$n ... " ;
			open (IN,"$dir/$fileName") or die "Failed openning $dir/$fileName for reading" ;
			print OUT $_ while(<IN>) ;
			close IN;
		}
		print STDERR "Sorting\n" ;
		close OUT ;
		   
		my $pid = fork();
		if ($pid == -1) {
			die "Forking Failed" ;
		} elsif ($pid == 0) {
#			print STDERR "$outDir -- $fileName\n" ;
			exec "sort -n -k1,1 -S50% $outDir/$fileName.tmp > $outDir/$fileName" or die;
			exit() ;
		}
		
#		(system("sort -n -k1,1 -S50% $outDir/$fileName.tmp > $outDir/$fileName")==0) or die "Sorting of $fileName failed\n" ;
	}
}

# Unite info files
sub uniteInfoFiles {
	my ($dirs,$outDir) = @_ ;

	# SignalInfoFile
	my %signalInfo ;
	
	my $fileName = "SignalInfoFile" ;
	foreach my $dir (@$dirs) {
		open (IN,"$dir/$fileName") or die "Failed openning $dir/$fileName for reading" ;	
		while (my $line = <IN>) {
			my ($signal) = split /\t/,$line ;
			die "SignalInfo Mismatch for $signal" if (exists $signalInfo{$signal} and $signalInfo{$signal} ne $line) ;
			$signalInfo{$signal} = $line ;
		}
		close IN ;
	}
		
	open (OUT,">$outDir/$fileName") or die "Cannot open $outDir/$fileName\n" ;
	map {print OUT $signalInfo{$_}} keys %signalInfo ;
	close OUT ;
	
	# Dictionaries
	my (%def,%sets) ;

	
	my %mbDict ;
	my $maxDictVal = -1 ;
	# Microbiology dictionaries must be identical
	foreach my $dir (@$dirs) {
		my $file = "$dir/ICU.microbiology_dictionary" ;
		open (IN,$file) or die "Cannot open $file for reading\n" ;

		while (<IN>) {
			chomp ;
			my ($type,$val1,$val2) = split /\t/,$_ ;
			die "Inconsistent microbiology dictionary for $val1" if (exists $mbDict{$val1} and $mbDict{$val1} ne $val2) ;
			$mbDict{$val1} = $val2 ;
			$maxDictVal = $val1 if ($val1>$maxDictVal) ;
		}
	}
	
	open (OUT,">$outDir/ICU.microbiology_dictionary") or die "Cannot open $outDir/ICU.microbiology_dictionary for writing\n" ;
	foreach my $idx (sort {$a<=>$b} keys %mbDict) {
		print OUT "DEF\t$idx\t$mbDict{$idx}\n" ;
	}
	close OUT ;
		
	# Other dictionaries should be united
	foreach my $dir (@$dirs) {
		foreach my $file (qw/ICU.dictionary ICU.sets_dictionary/) {
			open (IN,"$dir/$file") or die "Cannot open $dir/$file for reading\n" ;
			while (<IN>) {
				chomp ;
				my ($type,$val1,$val2) = split /\t/,$_ ;
				if ($type eq "DEF") {
					$def{$val2} = 1 ;
				} else {
					$sets{$val1}->{$val2} = 1 ;
				}
			}
			close IN ;
		}
	}
	
	open (OUT,">$outDir/ICU.sets_dictionary") or die "Cannot open $outDir/ICU.sets_dictionary for writing\n" ;
	my $idx = $maxDictVal ;
	foreach my $set (keys %sets) {
		print OUT "DEF\t$idx\t$set\n" ;
		$def{$set} = $idx ++ ;
		map {print OUT "SET\t$set\t$_\n"} (keys %{$sets{$set}}) ;
	}
	close OUT ;
	
	open (OUT,">$outDir/ICU.dictionary") or die "Cannot open $outDir/ICU.dictionary for writing\n" ;
	
	foreach my $val (grep {! exists $sets{$_}} keys %def) {
		print OUT "DEF\t$idx\t$val\n" ;
		$def{$val} = $idx ++ ;
	}
	close OUT ;	

	# Signals
	my %types ;
	foreach my $dir (@$dirs) {
		open (IN,"$dir/ICU.signals") or die "Cannot open $dir/signals for reading\n" ;	
		
		while (<IN>) {
			chomp;
			my ($dummy,$name,$idx,$type) = split /\t/,$_ ;
			die "Inconsistent type for $name" if (exists $types{$name} and $type ne $types{$name}) ;
			$types{$name} = $type ;
		}
		close IN ;
	}
	
	open (OUT,">$outDir/ICU.signals") or die "Cannot open $outDir/ICU.signals for writing\n" ;
	foreach my $signal (keys %types) {
		die "signal $signal missing from dictionary" if (! exists $def{$signal}) ;
		print OUT "SIGNAL\t$signal\t$def{$signal}\t$types{$signal}\n" ;
	}
	close OUT ;
	
	# Codes TO Signal Names
	my %codes ;
	foreach my $dir (@$dirs) {
		open (IN,"$dir/ICU.codes_to_signal_names") or die "Cannot open $dir/codes_to_signal_names for reading\n" ;
		
		while (<IN>) {
			chomp;
			my ($code,$name) = split /\t/,$_ ;
			die "Inconsistent code for $name" if (exists $codes{$name} and $code ne $codes{$name}) ;
			$codes{$name} = $code ;
		}
		close IN ;
	}
	
	open (OUT,">$outDir/ICU.codes_to_signal_names") or die "Cannot open $outDir/ICU.codes_to_signal_names for writing\n" ;
	map {print OUT "$codes{$_}\t$_\n"} keys %codes ;
	close OUT ;	

	# fnames-prefix
	my %nums ;
	foreach my $dir (@$dirs) {
		open (IN,"$dir/ICU.fnames_prefix") or die "Cannot open $dir/fnames_prefix for reading\n" ;	
		
		while (<IN>) {
			chomp;
			my ($num,$name) = split /\t/,$_ ;
			die "Inconsistent num for $name" if (exists $nums{$name} and $num ne $nums{$name}) ;
			$nums{$name} = $num ;
		}
		close IN ;
	}
	
	open (OUT,">$outDir/ICU.fnames_prefix") or die "Cannot open $outDir/ICU.fnames_prefix for writing\n" ;
	map {print OUT "$nums{$_}\t$_\n"} keys %nums ;
	close OUT ;	
	
	# signals to files
	my %snums ;
	foreach my $dir (@$dirs) {
		open (IN,"$dir/ICU.signals_to_files") or die "Cannot open $dir/signals_to_files for reading\n"	;
		
		while (<IN>) {
			chomp;
			my ($num,$name) = split /\t/,$_ ;
			die "Inconsistent num for $name" if (exists $snums{$name} and $num ne $snums{$name}) ;
			$snums{$name} = $num ;
		}
		close IN ;
	}
	
	open (OUT,">$outDir/ICU.signals_to_files") or die "Cannot open $outDir/ICU.signals_to_files for writing\n" ;
	map {print OUT "$snums{$_}\t$_\n"} keys %snums ;
	close OUT ;	
	
	# Convert Config
	my %values ;
	foreach my $dir (@$dirs) {
		open (IN,"$dir/ICU.convert_config") or die "Cannot open $dir/convert_config for reading\n"	;
		
		while (<IN>) {
			chomp;
			my ($field,$value) = split /\t/,$_ ;
			$values{$field}->{$value} = 1 if ($field ne "DIR" and $field ne "OUTDIR") ;
		}
		close IN ;
	}
	
	open (OUT,">$outDir/ICU.convert_config") or die "Cannot open $outDir/ICU.convert_config for writing\n" ;
	print OUT "DIR\t$outDir\n" ;
	print OUT "OUTDIR\t$outDir\n" ;
	foreach my $field (keys %values) {
		map {print OUT "$field\t$_\n"} keys %{$values{$field}} ;
	}
	close OUT ;
}


