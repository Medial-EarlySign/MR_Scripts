#!/usr/bin/env perl 
use strict(vars);
use Getopt::Long;
use FileHandle;
use DirHandle;
use Cwd;

my $exe_flag = 1 ;

sub open_file {
    my ($fn, $mode) = @_;
    
	print STDERR "Opening file $fn in mode $mode\n";
    $fn = "/dev/stdin" if ($fn eq "-");
    my $fh = FileHandle->new($fn, $mode) or die "Cannot open $fn in mode $mode: $!";

	return $fh;
}

sub read_file_text {
	my ($fn, $skip) = @_;
	
	my $fh = open_file($fn, "r");
	map {my $line = <$fh>} (1 .. $skip);
	my $txt = join("", <$fh>);
	$fh->close;
	
	return $txt;
}

sub write_text_to_file {
	my ($txt, $fn) = @_;
	
	my $fh = open_file($fn, "w");
	$fh->print($txt);
	$fh->close;	
}

sub identical_text_files {
	my ($fn1, $fn2, $skip) = @_;
	
	my $txt1 = read_file_text($fn1, $skip);
	my $txt2 = read_file_text($fn2, $skip);
	
	return ($txt1 eq $txt2);
}

sub safe_exec {
	my ($cmd, $warn) = ("", 0);

	if ($exe_flag) {
		($cmd, $warn) = @_ if (@_ == 2);
		($cmd) = @_ if (@_ == 1);
		die "Wrong number of arguments fo safe_exec()" if (@_ > 2);
		
		print STDERR "\"$cmd\" starting on " . `date` ;
		my $rc = system($cmd);
		print STDERR "\"$cmd\" finished execution on " . `date`;
		die "Bad exit code $rc" if ($rc != 0 and $warn == 0);
		warn "Bad exit code $rc" if ($rc != 0);
	}
}

sub get_local_time {
	my @months = qw( Jan Feb Mar Apr May Jun Jul Aug Sep Oct Nov Dec );
	my @days = qw(Sun Mon Tue Wed Thu Fri Sat Sun);

	my ($sec,$min,$hour,$mday,$mon,$year,$wday,$yday,$isdst) = localtime();
	return "$mday $months[$mon] $days[$wday], $hour:$min";
}

sub print_debug {
	my $msg = @_[0];
	my $ts = get_local_time();
	print STDERR "*** DEBUG ($ts):\t$msg\n\n";
}

####################################
##             Main               ##
####################################

my $p = {
	exe_root => "H:/Medial/Projects/ColonCancer",
	script_root => "H:/Medial/Perl-scripts",
	etrxact_and_check_status_only => 0,
	skip_extract => 0,
	skip_check_status => 0,
	};
	
GetOptions($p,
	"arch_file=s",        # archive file (tgz format) of the freezed version for reconstruction
	"work_dir=s",         # working directory
	"exe_root=s",         # base location of executables
	"script_root=s",      # base location of scripts
	"engine_ver=s",       # engine version identifier
	"etrxact_and_check_status_only", 	# exit after extraction of archive and check-mscrc-status script
	"skip_extract",						# skip reconstruction of archive
	"skip_check_status",				# skip check-mscrc-status script
	"web_service_url=s",				# url of web service, for batch-converter utility
	);
	
print STDERR "Command line: $0 " . join(" ", @ARGV) . "\n";	
print STDERR "Parameters: " . join(", ", map {"$_ => $p->{$_}"} sort keys %$p) . "\n";

die "Missing required arguments" unless (defined $p->{arch_file} and defined $p->{work_dir} and defined $p->{engine_ver});

# Extract archive under working directory
if (not $p->{skip_extract}) {
	safe_exec("mkdir -p $p->{work_dir}/ARCH");
	chdir("$p->{work_dir}/ARCH");
	my $arch_fn = $p->{arch_file};
	if ($arch_fn =~ m/^([A-Z]):\/(\S+)/) { # windows path, convert to posix
		$arch_fn = "/cygdrive/$1/$2";
	}
	print STDERR "Going to extract $arch_fn\n";
	safe_exec("tar xvfz $arch_fn");
	print_debug("Completed step 1: extraction of archive.");
}

print STDERR "Changing directory to $p->{work_dir}\n";
chdir("$p->{work_dir}");
	
# Locate configuration file of check_MSCRC_status.pl 
my $fcf = "$p->{work_dir}/find_cfg_file";
safe_exec("find ARCH -path \"*/CheckMSCRC*/configuration_file\" > $fcf");
die "Failed to find or too many check_MSCRC_status configuratio_file" unless (`wc -l $fcf` == 1);
my $cfg_file = read_file_text($fcf, 0);
chomp $cfg_file; # holds the name of the check_MSCRC configuration file

my $arch_mscrc_dir = $cfg_file;
$arch_mscrc_dir =~ s/\/configuration_file//;
$arch_mscrc_dir = "$p->{work_dir}/$arch_mscrc_dir";

# Create folder for verification of CheckMSCRC (CheckMSCRCVerify)
my $mscrc_dir = "$p->{work_dir}/CheckMSCRCVerify";
safe_exec("mkdir -p $mscrc_dir");

# Modify configuration file: 
my $cfg_fh = open_file($cfg_file, "r");
my $new_cfg_fh = open_file("$mscrc_dir/configuration_file", "w");
my $new_base_dir = getcwd() . "/ARCH";
while (<$cfg_fh>) {
	# 1) Update work directory
	if (m/^WorkDir /) {
		my $wd_line = "WorkDir := $mscrc_dir\n";
		print STDERR "Modifying ExtraFiles line: $_   ==>   $wd_line";
		$new_cfg_fh->print($wd_line);		
	}
	# 2) NOT USED (Yaron?)
	elsif (/^ExtraFiles := (\S+)/) {
		print STDERR "Modifying ExtraFiles line: $_   ==>   ";
		my @extra_paths = split(/,/, $1);
		my @extra_names = map {my @parts = split(/\//, $_); $parts[-1]} @extra_paths;
		my $extra_line = "ExtraFiles := " . join(",", map {"$arch_mscrc_dir/$_"} @extra_names) . "\n";
		print STDERR $extra_line;
		$new_cfg_fh->print($extra_line);
	}
	# 3) Change W drive to ARCH folder in all places relevant
	elsif (m/ := W:/ and not m/^GoldFilesList/) {
		print STDERR "Modifying W: line: $_   ==>   ";
		s/ := W:/ := $new_base_dir/;
		print STDERR $_;
		$new_cfg_fh->print($_);
	}
	# 4) OPEN - GlobalRoot
	
	# Keep as is
	else {
		$new_cfg_fh->print($_);
	}
}
$cfg_fh-> close;
$new_cfg_fh-> close;

my $cfg_txt = read_file_text("$mscrc_dir/configuration_file", 0);
print_debug("Completed step 2: update of configuration file.");

# Launch check_MSCRC_status.pl run
if (not $p->{skip_check_status}) {
	chdir($mscrc_dir);
	safe_exec("perl ./check_MSCRC_status.pl configuration_file Validate Validate"); 
	print_debug("Completed step 3: learn to validate on reconstructed files.");

	safe_exec("cp -f $arch_mscrc_dir/Analysis.MaccabiValidation.* $mscrc_dir");
	safe_exec("cp -f $arch_mscrc_dir/Validation.*.MaccabiValidation $mscrc_dir");
	safe_exec("perl ./check_MSCRC_status.pl configuration_file Compare Compare"); 
	chdir($p->{work_dir});
	print_debug("Completed step 4: comapre analysis on reconstructed files.");

	# Compare archived and current check_MSCRC_status runs
	my $arch_mscrc_dh = DirHandle->new($arch_mscrc_dir) or die "Can't open directory $arch_mscrc_dir for listing";
	my $mscrc_dh = DirHandle->new($mscrc_dir) or die "Can't open directory $mscrc_dir for listing"; 

	# Prediction files should match except for the first header lines
	my @arch_pred_files = sort grep { m/(LearnPredict|THIN_Train|MaccabiValidation)_predictions\.(men|women|combined)$/} $arch_mscrc_dh->read();
	print STDERR "Found ".scalar(@arch_pred_files)." predictions files in original CheckMSCRC\n"; print join(", ", @arch_pred_files)."\n";
	
	my @pred_files = sort grep { m/(LearnPredict|THIN_Train|MaccabiValidation)_predictions\.(men|women|combined)$/} $mscrc_dh->read();
	print STDERR "Found ".scalar(@pred_files)." predictions files in reconstructed CheckMSCRCVerify\n"; print join(", ", @pred_files)."\n";
	
	die "No prediction files found" if (@pred_files == 0);
	die "Mismatching numbers of prediction files in archived CheckMSCRC dir vs. CheckMSCRCVerify dir" unless (@arch_pred_files == @pred_files);
	map {die "Mismatching names of prediction files: archived \'$arch_pred_files[$_]\' vs. verified \'$pred_files[$_]\'" unless ($arch_pred_files[$_] eq $pred_files[$_])} (0 .. $#pred_files);
	map {
		die "Mismatching contents of prediction files: archived \'$arch_pred_files[$_]\' vs. verified \'$pred_files[$_]\'" 
			unless (identical_text_files("$arch_mscrc_dir/$arch_pred_files[$_]", "$mscrc_dir/$pred_files[$_]", 1)); 
		} (0 .. $#pred_files);
	print_debug("Completed step 5: succesfully compared ".scalar(@arch_pred_files)." prediction files (reconstruction to original).");

	# anlaysis and validation files should match completely	
	$arch_mscrc_dh->rewind();
	$mscrc_dh->rewind();
	my @arch_perf_files = sort grep { m/^Analysis.*(men|women|combined)($|\.AutoSim$)/ or m/^Validation.*(THIN_Train|MaccabiValidation)$/ or m/^ValidationBounds.*/ } $arch_mscrc_dh->read();
	print STDERR "Found ".scalar(@arch_perf_files)." predictions files in original CheckMSCRC\n"; print join(", ", @arch_perf_files)."\n";
	
	my @perf_files = sort grep { m/^Analysis.*(men|women|combined)($|\.AutoSim$)/ or m/^Validation.*(THIN_Train|MaccabiValidation)/ or m/^ValidationBounds.*/ } $mscrc_dh->read();
	print STDERR "Found ".scalar(@perf_files)." predictions files in reconstructed CheckMSCRCVerify\n"; print join(", ", @perf_files)."\n";
	
	die "No performance files found" if (@perf_files == 0);
	die "Mismatching numbers of performance files in archived CheckMSCRC dir vs. CheckMSCRCVerify dir" unless (@arch_perf_files == @perf_files);
	map {die "Mismatching names of performance files: archived \'$arch_perf_files[$_]\' vs. verified \'$perf_files[$_]\'" unless ($arch_perf_files[$_] eq $perf_files[$_])} (0 .. $#perf_files);
	map {
		die "Mismatching contents of performance files: archived \'$arch_perf_files[$_]\' vs. verified \'$perf_files[$_]\'" 
			unless (identical_text_files("$arch_mscrc_dir/$arch_perf_files[$_]", "$mscrc_dir/$perf_files[$_]", 0)); 
		} (0 .. $#perf_files);
	print_debug("Completed step 6: succesfully compared ".scalar(@perf_files)." performance files (reconstruction to original).");
}

if ($p->{etrxact_and_check_status_only}) {
	print_debug("Script completed successfully");
	exit(0) ;
}

# Run version_freeze_run_post_check_cmds.pl
my $verfrz_dir = "$p->{work_dir}/PostCheckMSCRCVerify";
safe_exec("mkdir -p $verfrz_dir");
chdir($verfrz_dir);
die "MHS directory not found in configuration file" unless ($cfg_txt =~ m/TrainingMatrixDir :=\s+(\S+)\/Train\s*\n/);
my $mhs_dir = $1;
die "THIN directory not found in configuration file" unless ($cfg_txt =~ m/InternalMatrixDir :=\s+(\S+)\/Train\s*\n/);
my $thin_dir = $1;
die "Method not found in configuration file" unless ($cfg_txt =~ m/Method :=\s+(\S+)\s*\n/);
my $method = $1;
my $verfrz_cmd = "perl H:/Medial/Perl-scripts/version_freeze_run_post_check_cmds.pl --MHS $mhs_dir --THIN $thin_dir --method $method " . 
				 "--check_MSCRC_dir $mscrc_dir --work_dir $verfrz_dir --engine_ver $p->{engine_ver} " .
				 "--override_version --prev_ver NULL --combined --web_service_url $p->{web_service_url}";
print STDERR "Going to run $verfrz_cmd\n";
safe_exec($verfrz_cmd);
chdir($p->{work_dir});
print_debug("Completed step 7: post check validations on reconstructed files.");

# Locate archived version freezing directory
my $fvd = "$p->{work_dir}/find_verfrz_dir";
safe_exec("find ARCH -path \"*/PostCheckMSCRC*/women_validation.20140101.Data.txt\" > $fvd");
die "Failed to find or too many PostCheckMSCRC women_validation.20140101.Data.txt" unless (`wc -l $fvd` == 1);
my $fvd_text = read_file_text($fvd, 0);
chomp $fvd_text;

my $arch_verfrz_dir = $fvd_text;
$arch_verfrz_dir =~ s/\/women_validation\.20140101\.Data\.txt//;
$arch_verfrz_dir = "$p->{work_dir}/$arch_verfrz_dir";

# Scorer and emulator input and outputs should match completely (after removal of date-dependent entries)
my $arch_verfrz_dh = DirHandle->new($arch_verfrz_dir) or die "Can't open directory $arch_verfrz_dir for listing";
my $verfrz_dh = DirHandle->new($verfrz_dir) or die "Can't open directory $verfrz_dir for listing"; 

# Analysis and for_diff files should match completely
my @arch_verfrz_files = sort grep { m/^Analysis\..*/ or m/.*\.for_diff\..*/ } $arch_verfrz_dh->read();
my @verfrz_files = sort grep { m/^Analysis\..*/ or m/.*\.for_diff\..*/ } $verfrz_dh->read();

die "No applicable PostCheckMSCRC files found" if (@verfrz_files == 0);
die "Mismatching numbers of applicable files in archived PostCheckMSCRC dir vs. PostCheckMSCRCVerify dir" unless (@arch_verfrz_files == @verfrz_files);
map {die "Mismatching names of applicable PostCheckMSCRC files: archived \'$arch_verfrz_files[$_]\' vs. verified \'$verfrz_files[$_]\'" unless ($arch_verfrz_files[$_] eq $verfrz_files[$_])} (0 .. $#verfrz_files);
map {
	die "Mismatching contents of applicable PostCheckMSCRC files: archived \'$arch_verfrz_files[$_]\' vs. verified \'$verfrz_files[$_]\'" 
		unless (identical_text_files("$arch_verfrz_dir/$arch_verfrz_files[$_]", "$verfrz_dir/$verfrz_files[$_]", 0)); 
	} (0 .. $#verfrz_files);
print_debug("Completed step 8: succesfully compared ".scalar(@verfrz_files)." PostCheckMSCRC files (reconstruction to original).");
print_debug("Script completed successfully");
