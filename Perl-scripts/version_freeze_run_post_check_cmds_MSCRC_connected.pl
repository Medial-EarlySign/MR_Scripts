#!/usr/bin/env perl 

my $user;
BEGIN {
die "Unsupported operating system name: $^O. (Supports Windows only)" unless ($^O eq "MSWin32");
$user = `whoami`; chomp $user;
print STDERR "User $user is invoking script $0 on a $^O machine\n";
}

use strict;
use Getopt::Long;
use FileHandle;
use File::Copy;

use lib "//nas1/UsersData/$user/MR/Projects/Scripts/Perl-modules" ;
use VersionFreezeUtils;
use CompareAnalysis;

####################################
##           Functions            ##
####################################

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

sub check_dll_version_consistency {
	my ($dll_rc, $dll_h, $rc_file_ver, $rc_prod_ver, $h_dll_ver) = @_;
	my ($rc1, $rc2, $h1);
	
	# Go over MeScorer.rc file, extract file/ product version 
	while (<$dll_rc>) {
		chomp;
		my $line = $_;
		$line =~ s/\0//g;
		my $i = index($line, $rc_file_ver);
		if ($i != -1) {
			$line =~ /$rc_file_ver(.*?)"/;
			$rc1 = $1;
		} 
				
		$i = index($line, $rc_prod_ver);
		if ($i != -1) {
			$line =~ /$rc_prod_ver(.*?)"/;
			$rc2 = $1;
			last;
		}
	}
	
	# Go over version.h file, extract file/ product version 
	while (<$dll_h>) {
		chomp;
		my $line = $_;
		$line =~ s/\0//g;
		my $i = index($line, $h_dll_ver);
		if ($i != -1) {
			$line =~ /$h_dll_ver(.*?)"/;
			$h1 = $1;
		} 
	}
	return (($h1 eq $rc1 and $h1 eq $rc2) ? 0 : -1, $h1);
}

sub sample_files {
	my ($dir,$prefix,$new_prefix,$p) = @_ ;
	
	print_debug("sampling $prefix files to $new_prefix files") ;
	
	# Sample Demographics file
	my $in_dem = open_file("$dir/$prefix.Demographics.txt", "r");
	my $out_dem = open_file("$dir/$new_prefix.Demographics.txt", "w");

	my %ids ;
	while (<$in_dem>) {
		if (rand() < $p) {
			$out_dem->print($_) ;
			my ($id) = split /\s+/,$_ ;
			$ids{$id} = 1 ;
		}
	}
	
	$in_dem->close ;
	$out_dem->close ;
	
	# Intersect Data file
	my $in_data = open_file("$dir/$prefix.Data.txt", "r");
	my $out_data = open_file("$dir/$new_prefix.Data.txt", "w");

	while (my $line = <$in_data>) {
		my ($id) = split /\s+/,$line ;
		$out_data->print($line) if ($ids{$id}) ;;
	}
	
	$in_data->close ;
	$out_data->close ;
	
	# Copy codes
	safe_exec("cp $dir/$prefix.Codes.txt $dir/$new_prefix.Codes.txt") ;
}

sub compare_scores_subset{
	my ($dir,$complete_file,$subset_file,$out_file,$dll_range,$warn_flag) = @_ ;
	
	my ($dll_min,$dll_max)=split ",",$dll_range ;
	
	my $in_subset = open_file("$dir/$subset_file","r") ;
	my %subset_data ;
	while (<$in_subset>) {
		chomp ;
		my ($id,$date,$score,$codes) = split /\t/,$_ ;
		$codes = join " ",grep {$_>=$dll_min and $_ <= $dll_max} split " ",$codes ;
		$subset_data{$id} = join "\t",($id,$date,$score,$codes) ;
	}
	$in_subset->close ;
	
	my $in_complete = open_file("$dir/$complete_file","r") ;
	my $out_diff = open_file("$dir/$out_file","w") ;
	my $diff = 0 ;
	my %done ;
	
	while (<$in_complete>) {
		chomp;
		my ($id,$date,$score,$codes) = split /\t/,$_ ;
		if (exists $subset_data{$id}){
			$done{$id} = 1 ;
			$codes = join " ",grep {$_>=$dll_min and $_ <= $dll_max} split " ",$codes ;
			if ($_ ne $subset_data{$id}) {
				$out_diff->print("Subset:\t$subset_data{$id}\nComplete:\t$_\n-------\n") ;
				$diff = 1 ;
			}
		}
	}
	$in_complete->close ;
	
	foreach my $id (keys %subset_data) {
		if (! exists $done{$id}) {
			$out_diff->print("Subset:\t$subset_data{$id}\nComplete:--\n-------\n") ;
			$diff = 1 ;
		}
	}
	$out_diff->close ;
	
	if ($diff == 1) {
		die "Found diffenrence between web service and direct dll call. See $out_file for details\n" if (! $warn_flag) ;
		warn "Found diffenrence between web service and direct dll call. See $out_file for details\n" ;
	}
}
	

####################################
##             Main               ##
####################################

# Verify running on windows
die "Please run the script on a windows machine\n" unless ($^O eq "MSWin32");

my $p = {
	exe_root => "//nas1/UsersData/$user/Medial/Projects/ColonCancer",
	script_root => "//nas1/UsersData/$user/Medial/Perl-scripts",
	dll_root => "//nas1/UsersData/$user/Medial/Dlls",
	MHS_dir => "//nas1/Work/CancerData/BinFiles/MHS/build_FEB2016",
	THIN_dir => "//nas1/Work/CRC/THIN_MAR2014",
	demographics_path => "//nas1/Work/CancerData/AncillaryFiles/Demographics.FEB2016",
	method => "DoubleMatched",
	internal => "QRF",
	web_service_repository => "//nas1/UsersData/$user/Medial/Applications/MeScore_CRC_Connected/MSCRC.Connected",
	mscrc_tools_repository => "//nas1/UsersData/$user/Medial/Applications/MeScore_CRC_Connected/MSCRC.Tools",
	mscrc_utilities_repository => "//nas1/UsersData/$user/Medial/Applications/MeScore_CRC_Connected/MSCRC.Utilities",
	web_service_url => "http://192.168.1.69:5000",
	engine_ver => "DMQRF_MAR_2016",
	prev_ver_dir => "NULL",
	msr_file => "//nas1/UsersData/$user/Medial/Resources/check_MSCRC_status_files/MeasuresForComparison",
	warn_only_on_diff => 0,
	skip_install_and_export => 0,
	install_and_export_only => 0,
	only_diff_emulator_output => 0,
	allow_diffs_in_comparison => 0,
	combined => 0,
	skip_create_mhs_extrnlv_eng_input => 0,
	skip_eng_run_on_extrnlv => 0,
	skip_create_mhs_intrnlv_eng_input => 0,
	skip_eng_run_on_intrnlv => 0,
	skip_performance_on_intrnlv => 0,
	skip_web_service_run => 0,
	web_service_run_only => 0,
	#gold_dir => "P:/MeScore_CRC/FrozenVersions/GoldTestVector",
	min_age => 40,
	max_age => 120,
	not_last_cbc_error_code => 211,
	dll_error_codes => "201,299",
	web_service_sampling_p => 0.1,
};
	
GetOptions($p,
	"exe_root=s",         		# base location of executables
	"script_root=s",      		# location of perl scripts
	"dll_root=s",				# location of dll files
	"web_service_repository=s", # location of MSCRC web service repository
	"mscrc_tools_repository=s", # location of MSCRC tools repository
	"mscrc_utilities_repository", # location of MSCRC utilities repository
	"crypkey_sdk=s",			# location of installed crypkey SDK 
	"crypkey_sdk_setup=s",		# location of crypkey SDK setup file
	"web_service_url=s",		# url of web service, for batch-converter utility
	"MHS_dir=s",          		# directory with Maccabi bin files (under Train - IntrnlV - ExtrnlV subdirs)
	"THIN_dir=s",         		# directory with THIN bin files 
	"demographics_path=s",
	"check_MSCRC_dir=s",  		# directory of check_MSCRC_status run, should contain predictions by development version
	"method=s",			  		# method of prediction
	"internal=s",		  		# internal method for composite methods
	"work_dir=s",         		# working directory
	"engine_ver=s",       		# engine version identifier
	"prev_ver_dir=s",     		# directory with performance files from previous version, for comparison ("NULL" to skip comparison)
	"msr_file=s",         		# file with measurments for comparison
	"warn_only_on_diff",  		# only issue a warning when a comparison (predictor vs. engine) identifies any difference (default behavior is to exit)
	"skip_install_and_export",  # assume that MSCRC web service installation and export of engine version were already done	
	"install_and_export_only",  # quit after preparing files for installation of web service and exporting the engine version
	"only_diff_emulator_output",# perform only the steps after creating emulator output files (in case online creation was interrupted)
	"allow_diffs_in_comparison", # allow differences when comparing against previous version (set to true only if there is a good reason for changes in prediction sets)
	"combined", 				# engine combines men and women
	"skip_create_mhs_extrnlv_eng_input",
	"skip_eng_run_on_extrnlv",
	"skip_create_mhs_intrnlv_eng_input",
	"skip_eng_run_on_intrnlv",
	"skip_performance_on_intrnlv", # skip bootstrap_analysis run using MHS internal validation set and THIN validation sets
	"skip_web_service_run",
	"web_service_run_only",
	#"gold_dir=s",        		# directory with test vector used to verify the version
	"min_age=i",         		# minimal allowed age at time of test in MeScorer
	"max_age=i",         		# maximal allowed age at time of test in MeScorer
	"not_last_cbc_error_code=i", # error code in MeScore representing MESSAGE_NOT_LAST_CBC
	"dll_error_codes=s",		# Comma separated range (min,max) of error codes generated by the MeScorer dll
	"web_service_sampling_p=f",	# Porportion of validation data to sample for web service
);

print STDERR "Command line: $0 " . join(" ", @ARGV) . "\n";	
print STDERR "Parameters: " . join(", ", map {"$_ => $p->{$_}"} sort keys %$p) . "\n";

# Check some of the arguments
die "Name of check_MSCRC_dir must begin with CheckMSCRC, input name \"$p->{check_MSCRC_dir}\" is illegal" unless ($p->{check_MSCRC_dir} =~ m/\/CheckMSCRC/);
die "Name of work_dir must begin with PostCheckMSCRC, input name \"$p->{work_dir}\" is illegal" unless ($p->{work_dir} =~ m/\/PostCheckMSCRC/);
safe_exec("mkdir -p $p->{work_dir}");

# ForInstall Files
my $inst_dir = "$p->{work_dir}/ForInstall";
my $inst_dir_programs = "$inst_dir/Programs";
my $license_dir_for_install = "$inst_dir/License";

# DeploymentKit Files
my $medial_deploy_dir = "$p->{work_dir}/MedialDeploymentKit";
my $files_dir_for_deploy = "$medial_deploy_dir/Files";
my $eng_dir_for_deploy = "$files_dir_for_deploy/Engine";
my $license_dir_for_deploy = "$medial_deploy_dir/License";
my $crypkey_utils_for_deploy = "$medial_deploy_dir/CrypKeyUtils";
my $configuration_tool_for_deploy = "$medial_deploy_dir/MedialConfigurationTool";

if ($p->{web_service_run_only}) {
	$p->{skip_install_and_export} = 1;
	$p->{skip_create_mhs_extrnlv_eng_input} = 1;
	$p->{skip_eng_run_on_extrnlv} = 1;
	$p->{skip_create_mhs_intrnlv_eng_input} = 1;
	$p->{skip_eng_run_on_intrnlv} = 1;
	$p->{skip_performance_on_intrnlv} = 1;
}

# Verify dll version is same in version.h and MeScorer.rc
my $dll_rc = open_file("//nas1/UsersData/$user/Medial/Products/MeScorer/MeScorer/MeScorer.rc", "r");
my $dll_h = open_file("//nas1/UsersData/$user/Medial/Products/MeScorer/MeScorer/version.h", "r");
my $rc_file_ver = "VALUE \"FileVersion\", \"";
my $rc_prod_ver = "VALUE \"ProductVersion\", \"";
my $h_dll_ver = "define DLL_VERSION \"";
my ($consistent, $dll_version) = check_dll_version_consistency($dll_rc, $dll_h, $rc_file_ver, $rc_prod_ver, $h_dll_ver);
die "File/product version in MeScorer.rc does not match the one listed in version.h\n" unless ($consistent == 0);
print_debug("Verified dll-version is consistent (version = $dll_version)");
	
###########################################################
# Step 1: Prepare files for MSCRC web service installation
###########################################################

if (not $p->{skip_install_and_export}) {
	
	# Files are divided into 3 folders: 
	## (1) ForInstall - files/tools which are needed on the customer's computer and are not customer specific
	## (2) MedialDeploymentKit - files/tools which are needed on Medial's computer in order to support deployment
	## (3) FileBasedUtility
	
	# Prepare needed folders
	## ForInstall Files
	safe_exec("mkdir -p $inst_dir");
	safe_exec("mkdir -p $inst_dir/Files");
	safe_exec("mkdir -p $inst_dir_programs");
	safe_exec("mkdir -p $license_dir_for_install");

	## DeploymentKit Files
	safe_exec("mkdir -p $medial_deploy_dir");
	safe_exec("mkdir -p $files_dir_for_deploy");
	safe_exec("mkdir -p $eng_dir_for_deploy");
	safe_exec("mkdir -p $license_dir_for_deploy");
	safe_exec("mkdir -p $crypkey_utils_for_deploy");
	safe_exec("mkdir -p $configuration_tool_for_deploy");	
	
	## File based utility
	my $file_based_util = "$p->{work_dir}/FileBasedUtility";
	safe_exec("mkdir -p $file_based_util");
	
	# (1) Prepare ForInstall folder
	
	# (1.1) Prepare ForInstall/Programs
	safe_exec("rm -f -r $inst_dir_programs/*"); # Clean folder first
	safe_exec("cp -a $p->{web_service_repository}/MSCRC.WebApi/obj/x86/ForInstall/Package/PackageTmp/. $inst_dir_programs/");
	safe_exec("cp -a $p->{web_service_repository}/Files/web.config $inst_dir_programs/Web.config"); #Override Web.config file
	safe_exec("cp -f $p->{dll_root}/Win32/Release/MeScorer.dll $inst_dir_programs/bin/");
	
	# (1.2) Prepare ForInstall/License
	safe_exec("rm -f -r $license_dir_for_install/*"); # Clean folder first
	safe_exec("cp $p->{mscrc_tools_repository}/MSCRC.Tools.LicenseManager/bin/x86/ForInstall/* $license_dir_for_install/"); 
	safe_exec("cp $p->{mscrc_tools_repository}/License_Files/* $license_dir_for_install/");	
	
	# (1.3) Prepare ForInstall/CrypKeyDriver
	safe_exec("mkdir -p $inst_dir/CrypKeyDriver");
	safe_exec("cp -r '//nas1/Installations/CrypKey/CrypKey MSCRC Production Files V 1.2/CrypKey Driver/.' $inst_dir/CrypKeyDriver/");
	
	# (1.4) Prepare ForInstall/ConfigurationTools
	safe_exec("cp -r $p->{mscrc_tools_repository}/MedialKit/Deployment/ConfigurationTools $inst_dir");
	safe_exec("cp '//nas1/Installations/Microsoft/Visual Studio 2015/vc_redist/vc_redist.x86.exe' $inst_dir/ConfigurationTools/");
	
	# (1.5) Prepare ForInstall/Test
	safe_exec("mkdir -p $inst_dir/Test");
	safe_exec("cp //nas1/Installations/Tools/curl/curl.exe $inst_dir/Test/");
	safe_exec("cp //nas1/Installations/Tools/xmllint/* $inst_dir/Test/");
	safe_exec("cp $p->{web_service_repository}/Test/* $inst_dir/Test/");
	
	print_debug("Created ForInstall folder");
	
	# (2) Prepare MedialDeploymentKit
		
	# (2.1) Prepare MedialDeploymentKit/Files
	## Copy config and schema files
	safe_exec("cp -f $p->{web_service_repository}/Files/configuration.xml $files_dir_for_deploy/");
	# safe_exec("cp -f $p->{web_service_repository}/Files/package.xsd $files_dir_for_deploy/");
	safe_exec("mkdir -p $files_dir_for_deploy/Encrypted");
	
	## Create engine folder
	my @genders = qw/men women/ ;
	my @engine_genders = ($p->{combined}) ? ("combined") : @genders ;
	my $combined_flag = ($p->{combined}) ? "--combined" : "";
	if ($p->{method} eq "DoubleMatched") {
		# Prepare setup file needed for export-engine
		my $setup = "$eng_dir_for_deploy/Setup" ;
		my $setup_fh = open_file($setup, "w") ; 

		$setup_fh->print("Features\t//nas1/UsersData/$user/Medial/Resources/MSCRC_Version_freezing_files/features_list\n") ;
		$setup_fh->print("Extra\t//nas1/UsersData/$user/Medial/Resources/MSCRC_Version_freezing_files/engine_extra_params.txt\n") ;
		$setup_fh->print("Shift\t$p->{check_MSCRC_dir}/ShiftFile\n") ;
		
		foreach my $gender (@engine_genders) {
			$setup_fh->print($gender."Outliers\t$p->{check_MSCRC_dir}/learn_$gender\_outliers\n") ;
			$setup_fh->print($gender."Completion\t$p->{check_MSCRC_dir}/learn_$gender\_completion\n") ;
			$setup_fh->print($gender."Model\t$p->{check_MSCRC_dir}/learn_$gender\_predictor\n") ;
		}
		
		foreach my $gender (@genders) {
			$setup_fh->print($gender."Incidence\t//nas1/UsersData/$user/Medial/Resources/check_MSCRC_status_files/SEER_Incidence.$gender\n") ;
		}
		$setup_fh->close ;
		print_debug("Created setup file for export_engine");
		
		# Run export_engine exe
		safe_exec("//nas1/UsersData/$user/Medial/Projects/ColonCancer/predictor/x64/Release/export_engine.exe --method $p->{method} --setup $setup --dir $eng_dir_for_deploy --internal $p->{internal} $combined_flag --version $p->{engine_ver}") ;
		
		# Move Setup file outside of ForInstall
		safe_exec("mv $setup $p->{work_dir}/Setup.ForExportEngine");
		print_debug("Completed export_engine command");
	} else {
		die "Method $p->{method} is not implemented yet" ;
	}
	
	# (2.2) Prepare MedialDeploymentKit/License
	safe_exec("cp $p->{mscrc_tools_repository}/MedialKit/Deployment/LicensingTools/* $license_dir_for_deploy/");	
	
	# (2.3) Prepare MedialDeploymentKit/CrypKeyUtils
	safe_exec("mkdir -p $crypkey_utils_for_deploy/CrypKeyDriver");
	safe_exec("cp -r '//nas1/Installations/CrypKey/CrypKey MSCRC Production Files V 1.2/CrypKey Driver/.' $crypkey_utils_for_deploy/CrypKeyDriver/"); 
	safe_exec("cp -r '//nas1/Installations/CrypKey/CrypKey MSCRC Production Files V 1.2/Stealth' $crypkey_utils_for_deploy");
	safe_exec("mkdir -p $crypkey_utils_for_deploy/SiteKey&LicenseFileGenerator");
	safe_exec("cp -r '//nas1/Installations/CrypKey/CrypKey MSCRC Production Files V 1.2/SiteKey & LicenseFile Generator/.' $crypkey_utils_for_deploy/SiteKey&LicenseFileGenerator/");
	
	# (2.4) Prepare MedialDeploymentKit/ConfigurationTool
	safe_exec("cp -r $p->{mscrc_utilities_repository}/MSCRC.Utilities.ConfigurationTool/bin/x86/ForInstall/* $configuration_tool_for_deploy/"); 
	safe_exec("cp -r $p->{mscrc_tools_repository}/MSCRC.Tools.ProtectionManager/bin/x86/ForInstall/* $configuration_tool_for_deploy/"); 
	safe_exec("cp $p->{mscrc_tools_repository}/License_Files/crp32002.ngn $configuration_tool_for_deploy/");
	safe_exec("cp $p->{mscrc_tools_repository}/License_Files/MSCRC.LIC $configuration_tool_for_deploy/");
	safe_exec("cp '//nas1/Installations/Microsoft/Visual Studio 2015/vc_redist/vc_redist.x86.exe' $configuration_tool_for_deploy/");
	print_debug("Created MedialDeploymentKit folder");
	
	# (3) Prepare FileBasedUtility
	safe_exec("cp -r $p->{mscrc_utilities_repository}/MSCRC.Utilities.FileBased.ConsoleApp/bin/x86/ForInstall/* $file_based_util/"); 
	safe_exec("cp -r $p->{mscrc_utilities_repository}/MSCRC.Utilities.FileBased.ConsoleApp/Resources $file_based_util/"); 
	print_debug("Created FileBasedUtility folder");

	# Lastly, copy a special version of configuration file for freeze only
	safe_exec("cp -f $p->{web_service_repository}/Files/freeze_configuration.xml $p->{work_dir}/");
}

if ($p->{install_and_export_only}) {
	print_debug("Script completed successfully");
	exit(0) ;
}


###########################################################
# Step 2: Manual installation of service on VM
###########################################################


###########################################################
# Step 3: Create input data files for engine & web service
###########################################################

# create engine and product emulator input data files from MHS ExtrnlV and THIN Train bin files
my $utils_exe = "$p->{exe_root}/predictor/x64/Release/utils"; 

# will be used for comparison between engine and predictor (step 4)
if (not $p->{skip_create_mhs_extrnlv_eng_input}) {
	print_debug("Starting creation of input files for engine vs. predictor comparison");

	safe_exec("$utils_exe bin2txt $p->{MHS_dir}/ExtrnlV/men_validation.bin $p->{work_dir}/men_validation.txt");
	safe_exec("$utils_exe bin2txt $p->{MHS_dir}/ExtrnlV/women_validation.bin $p->{work_dir}/women_validation.txt");
	safe_exec("$utils_exe bin2txt $p->{THIN_dir}/Train/men_crc_and_stomach.bin $p->{work_dir}/men_thin_train.txt");
	safe_exec("$utils_exe bin2txt $p->{THIN_dir}/Train/women_crc_and_stomach.bin $p->{work_dir}/women_thin_train.txt");
	print_debug("Completed bin2txt commands on ExtrnlV and THIN train");
	
	VersionFreezeUtils::txt2eng("$p->{work_dir}/men_validation.txt", "$p->{work_dir}/men_validation.20140101.Data.txt");
	VersionFreezeUtils::txt2eng("$p->{work_dir}/women_validation.txt", "$p->{work_dir}/women_validation.20140101.Data.txt");
	VersionFreezeUtils::txt2eng("$p->{work_dir}/men_thin_train.txt", "$p->{work_dir}/men_thin_train.20140101.Data.txt");
	VersionFreezeUtils::txt2eng("$p->{work_dir}/women_thin_train.txt", "$p->{work_dir}/women_thin_train.20140101.Data.txt");
	
	safe_exec("sort -o $p->{work_dir}/men_validation.20140101.Data.txt $p->{work_dir}/men_validation.20140101.Data.txt");
	safe_exec("sort -o $p->{work_dir}/women_validation.20140101.Data.txt $p->{work_dir}/women_validation.20140101.Data.txt");
	safe_exec("sort -o $p->{work_dir}/men_thin_train.20140101.Data.txt $p->{work_dir}/men_thin_train.20140101.Data.txt");
	safe_exec("sort -o $p->{work_dir}/women_thin_train.20140101.Data.txt $p->{work_dir}/women_thin_train.20140101.Data.txt");
	print_debug("Completed txt2eng commands on ExtrnlV and THIN train");
	
	# dummy creation of demographics input files
	safe_exec("cp $p->{demographics_path} $p->{work_dir}/men_validation.20140101.Demographics.txt");
	safe_exec("cp $p->{demographics_path} $p->{work_dir}/women_validation.20140101.Demographics.txt");
	safe_exec("cp $p->{demographics_path} $p->{work_dir}/men_thin_train.20140101.Demographics.txt");
	safe_exec("cp $p->{demographics_path} $p->{work_dir}/women_thin_train.20140101.Demographics.txt");
	
	safe_exec("sort -o $p->{work_dir}/men_validation.20140101.Demographics.txt $p->{work_dir}/men_validation.20140101.Demographics.txt");
	safe_exec("sort -o $p->{work_dir}/women_validation.20140101.Demographics.txt $p->{work_dir}/women_validation.20140101.Demographics.txt");
	safe_exec("sort -o $p->{work_dir}/men_thin_train.20140101.Demographics.txt $p->{work_dir}/men_thin_train.20140101.Demographics.txt");
	safe_exec("sort -o $p->{work_dir}/women_thin_train.20140101.Demographics.txt $p->{work_dir}/women_thin_train.20140101.Demographics.txt");
	print_debug("Copied demographics files");

}

# will be used for comparison between engine and web service
if (not $p->{skip_create_mhs_intrnlv_eng_input}) {
	print_debug("Starting creation of input files for engine vs. product comparison");
	
	safe_exec("$utils_exe bin2txt $p->{MHS_dir}/IntrnlV/men_validation.bin $p->{work_dir}/MHS_intrnlv_men.txt");
	safe_exec("$utils_exe bin2txt $p->{MHS_dir}/IntrnlV/women_validation.bin $p->{work_dir}/MHS_intrnlv_women.txt");
	safe_exec("$utils_exe bin2txt $p->{THIN_dir}/IntrnlV/men_validation.bin $p->{work_dir}/THIN_intrnlv_men.txt");
	safe_exec("$utils_exe bin2txt $p->{THIN_dir}/IntrnlV/women_validation.bin $p->{work_dir}/THIN_intrnlv_women.txt");
	safe_exec("$utils_exe bin2txt $p->{THIN_dir}/ExtrnlV/men_validation.bin $p->{work_dir}/THIN_extrnlv_men.txt");
	safe_exec("$utils_exe bin2txt $p->{THIN_dir}/ExtrnlV/women_validation.bin $p->{work_dir}/THIN_extrnlv_women.txt");
	safe_exec("cat $p->{work_dir}/THIN_intrnlv_men.txt $p->{work_dir}/THIN_extrnlv_men.txt > $p->{work_dir}/THIN_validation_men.txt");
	safe_exec("cat $p->{work_dir}/THIN_intrnlv_women.txt $p->{work_dir}/THIN_extrnlv_women.txt > $p->{work_dir}/THIN_validation_women.txt");
	print_debug("Completed bin2txt commands on IntrnlV and THIN IntrnlV+ExtrnlV");
	
	# expand data (fictitious patient id, for each available CBC. E.g. if patient 123 has 3 available CBC's, 3 patients will be created: 123_1,123_2,123_3 each with a different CBC and all relevant history)
	VersionFreezeUtils::txt2expanded_eng("$p->{work_dir}/MHS_intrnlv_men.txt", 		"$p->{work_dir}/MHS_intrnlv_men.20140101.Data.txt",		 "$p->{demographics_path}", "$p->{work_dir}/MHS_intrnlv_men.20140101.Demographics.txt");
	VersionFreezeUtils::txt2expanded_eng("$p->{work_dir}/MHS_intrnlv_women.txt", 	"$p->{work_dir}/MHS_intrnlv_women.20140101.Data.txt",	 "$p->{demographics_path}", "$p->{work_dir}/MHS_intrnlv_women.20140101.Demographics.txt");
	VersionFreezeUtils::txt2expanded_eng("$p->{work_dir}/THIN_validation_men.txt", 	"$p->{work_dir}/THIN_validation_men.20140101.Data.txt",	 "$p->{demographics_path}", "$p->{work_dir}/THIN_validation_men.20140101.Demographics.txt");
	VersionFreezeUtils::txt2expanded_eng("$p->{work_dir}/THIN_validation_women.txt","$p->{work_dir}/THIN_validation_women.20140101.Data.txt","$p->{demographics_path}", "$p->{work_dir}/THIN_validation_women.20140101.Demographics.txt");
	
	# sort data & demographics files in place (just in case...)
	safe_exec("sort -o $p->{work_dir}/MHS_intrnlv_men.20140101.Data.txt $p->{work_dir}/MHS_intrnlv_men.20140101.Data.txt");
	safe_exec("sort -o $p->{work_dir}/MHS_intrnlv_women.20140101.Data.txt $p->{work_dir}/MHS_intrnlv_women.20140101.Data.txt");
	safe_exec("sort -o $p->{work_dir}/THIN_validation_men.20140101.Data.txt $p->{work_dir}/THIN_validation_men.20140101.Data.txt");
	safe_exec("sort -o $p->{work_dir}/THIN_validation_women.20140101.Data.txt $p->{work_dir}/THIN_validation_women.20140101.Data.txt");
	
	safe_exec("sort -o $p->{work_dir}/MHS_intrnlv_men.20140101.Demographics.txt $p->{work_dir}/MHS_intrnlv_men.20140101.Demographics.txt");
	safe_exec("sort -o $p->{work_dir}/MHS_intrnlv_women.20140101.Demographics.txt $p->{work_dir}/MHS_intrnlv_women.20140101.Demographics.txt");
	safe_exec("sort -o $p->{work_dir}/THIN_validation_men.20140101.Demographics.txt $p->{work_dir}/THIN_validation_men.20140101.Demographics.txt");
	safe_exec("sort -o $p->{work_dir}/THIN_validation_women.20140101.Demographics.txt $p->{work_dir}/THIN_validation_women.20140101.Demographics.txt");
	print_debug("Completed txt2expanded commands on MHS intrnlV, THIN validation");
	
	VersionFreezeUtils::eng2prod("$p->{work_dir}/MHS_intrnlv_men.20140101", "$p->{work_dir}/Test.2014-JAN-01.set1");
	VersionFreezeUtils::eng2prod("$p->{work_dir}/MHS_intrnlv_women.20140101", "$p->{work_dir}/Test.2014-JAN-01.set2");
	VersionFreezeUtils::eng2prod("$p->{work_dir}/THIN_validation_men.20140101", "$p->{work_dir}/Test.2014-JAN-01.set3");
	VersionFreezeUtils::eng2prod("$p->{work_dir}/THIN_validation_women.20140101", "$p->{work_dir}/Test.2014-JAN-01.set4");
	print_debug("Completed eng2prod commands on MHS intrnlV, THIN validation");
	
	# create code files for product (web sevrice, via batch processor)
	safe_exec("cp //nas1/UsersData/$user/Medial/Resources/MSCRC_Version_freezing_files/MSCRC.Codes.txt $p->{work_dir}/MHS_intrnlv_men.20140101.Codes.txt");
	safe_exec("cp //nas1/UsersData/$user/Medial/Resources/MSCRC_Version_freezing_files/MSCRC.Codes.txt $p->{work_dir}/MHS_intrnlv_women.20140101.Codes.txt");
	safe_exec("cp //nas1/UsersData/$user/Medial/Resources/MSCRC_Version_freezing_files/MSCRC.Codes.txt $p->{work_dir}/THIN_validation_men.20140101.Codes.txt");
	safe_exec("cp //nas1/UsersData/$user/Medial/Resources/MSCRC_Version_freezing_files/MSCRC.Codes.txt $p->{work_dir}/THIN_validation_women.20140101.Codes.txt");
	print_debug("Copied codes files");
	
}

###########################################################
# Step 4: Compare engine outputs to predictions
###########################################################

my $test_engine_exe = "$p->{exe_root}/TestProduct/Win32/Release/TestProduct.exe"; 

# Run engine on MHS external validation and THIN Train and comapre engine outputs and predictions
# TODO: use condor to decrease runtime...
if (not $p->{skip_eng_run_on_extrnlv}) {
	# 1/4: men_validation
	safe_exec("$test_engine_exe $eng_dir_for_deploy $p->{work_dir} men_validation.20140101 0");
	print_debug("Completed engine run (TestProduct) on men_validation");
	my $m1 = VersionFreezeUtils::mscrc_engine_match_w_predict("$p->{work_dir}/men_validation.20140101.Scores.txt", 
										   "$p->{check_MSCRC_dir}/MaccabiValidation_predictions.men",
										   "$p->{work_dir}/log.eng_vs_pred.men",
										   "$p->{work_dir}/men_validation.20140101.Demographics.txt",
										   $p->{min_age}, $p->{max_age}, $p->{not_last_cbc_error_code});
	if ($m1 != 0) {
		print STDERR "WARNING: mismatches between $p->{work_dir}/men_validation.20140101.Scores.txt and $p->{check_MSCRC_dir}/MaccabiValidation_predictions.men\n";
		exit(1) unless ($p->{warn_only_on_diff});
	}
	print_debug("Completed comparison engine vs. predictor on men_validation");
	
	# 2/4: women_validation
	safe_exec("$test_engine_exe $eng_dir_for_deploy $p->{work_dir} women_validation.20140101 0");
	print_debug("Completed engine run (TestProduct) on women_validation");
	my $m2 = VersionFreezeUtils::mscrc_engine_match_w_predict("$p->{work_dir}/women_validation.20140101.Scores.txt", 
										   "$p->{check_MSCRC_dir}/MaccabiValidation_predictions.women",
										   "$p->{work_dir}/log.eng_vs_pred.women",
										   "$p->{work_dir}/women_validation.20140101.Demographics.txt",
										   $p->{min_age}, $p->{max_age}, $p->{not_last_cbc_error_code});
	if ($m2 != 0) {
		print STDERR "WARNING: mismatches between $p->{work_dir}/women_validation.20140101.Scores.txt and $p->{check_MSCRC_dir}/MaccabiValidation_predictions.women\n";
		exit(1) unless ($p->{warn_only_on_diff});
	}	
	print_debug("Completed comparison engine vs. predictor on women_validation");

	# 3/4: men_thin_train
	safe_exec("$test_engine_exe $eng_dir_for_deploy $p->{work_dir} men_thin_train.20140101 0");
	print_debug("Completed engine run (TestProduct) on men_thin_train");
	my $m3 = VersionFreezeUtils::mscrc_engine_match_w_predict("$p->{work_dir}/men_thin_train.20140101.Scores.txt", 
										   "$p->{check_MSCRC_dir}/THIN_Train_predictions.men",
										   "$p->{work_dir}/log.eng_vs_pred.thin_men",
										   "$p->{work_dir}/men_thin_train.20140101.Demographics.txt",
										   $p->{min_age}, $p->{max_age}, $p->{not_last_cbc_error_code});
	if ($m3 != 0) {
		print STDERR "WARNING: mismatches between $p->{work_dir}/men_thin_train.20140101.Scores.txt and $p->{check_MSCRC_dir}/THIN_Train_predictions.men\n";
		exit(1) unless ($p->{warn_only_on_diff});
	}
	print_debug("Completed comparison engine vs. predictor on men_thin_train");
	
	# 4/4: women_thin_train
	safe_exec("$test_engine_exe $eng_dir_for_deploy $p->{work_dir} women_thin_train.20140101 0");
	print_debug("Completed engine run (TestProduct) on women_thin_train");
	my $m4 = VersionFreezeUtils::mscrc_engine_match_w_predict("$p->{work_dir}/women_thin_train.20140101.Scores.txt", 
										   "$p->{check_MSCRC_dir}/THIN_Train_predictions.women",
										   "$p->{work_dir}/log.eng_vs_pred.thin_women",
										   "$p->{work_dir}/women_thin_train.20140101.Demographics.txt",
										   $p->{min_age}, $p->{max_age}, $p->{not_last_cbc_error_code});
	if ($m4 != 0) {
		print STDERR "WARNING: mismatches between $p->{work_dir}/women_thin_train.20140101.Scores.txt and $p->{check_MSCRC_dir}/THIN_Train_predictions.women\n";
		exit(1) unless ($p->{warn_only_on_diff});
	}
	print_debug("Completed comparison of engine vs. predictor on women_thin_train");
}

###########################################################
# Step 5: Check performance on MHS IntrnlV, THIN validation
###########################################################

# Step 5A: run engine on expanded Maccabi IntrnlV and THIN IntrnlV + ExtrnlV
if (not $p->{skip_eng_run_on_intrnlv}) {
	safe_exec("$test_engine_exe $eng_dir_for_deploy $p->{work_dir} MHS_intrnlv_men.20140101 0 Short");
	safe_exec("$test_engine_exe $eng_dir_for_deploy $p->{work_dir} MHS_intrnlv_women.20140101 0 Short");
	safe_exec("$test_engine_exe $eng_dir_for_deploy $p->{work_dir} THIN_validation_men.20140101 0 Short");
	safe_exec("$test_engine_exe $eng_dir_for_deploy $p->{work_dir} THIN_validation_women.20140101 0 Short");
	print_debug("Completed engine run (TestProduct) on MHS_intrnlv_men/women, THIN_validation_men/women");
	
	# prepare expanded output of engine for performance measurements
	VersionFreezeUtils::de_expand_scores("$p->{work_dir}/MHS_intrnlv_men.20140101.Scores.txt","$p->{work_dir}/MHS_intrnlv_men.20140101.predictions") ;
	VersionFreezeUtils::de_expand_scores("$p->{work_dir}/MHS_intrnlv_women.20140101.Scores.txt","$p->{work_dir}/MHS_intrnlv_women.20140101.predictions") ;
	VersionFreezeUtils::de_expand_scores("$p->{work_dir}/THIN_validation_men.20140101.Scores.txt","$p->{work_dir}/THIN_validation_men.20140101.predictions") ;
	VersionFreezeUtils::de_expand_scores("$p->{work_dir}/THIN_validation_women.20140101.Scores.txt","$p->{work_dir}/THIN_validation_women.20140101.predictions") ;
	print_debug("Completed de_expand_scores commands on MHS_intrnlv_men/women, THIN_validation_men/women");
}

# Run bootstrap_analysis on Maccabi IntrnlV and THIN IntrnlV + ExtrnlV
if (not $p->{skip_performance_on_intrnlv}) {
	my $ba_exe = "$p->{exe_root}/AnalyzeScores/x64/Release/bootstrap_analysis";
	my $ancillary = "//nas1/Work/CancerData/AncillaryFiles";
	my $check_MSCRC_status_files = "//nas1/UsersData/$user/Medial/Resources/check_MSCRC_status_files";
	my $params_file_int = "$check_MSCRC_status_files/parameters_files/parameters_file"
	my $params_file_thin = "$check_MSCRC_status_files/parameters_files/parameters_file.THIN"
	my $ba_args = "--nbin_types=0 --dir=$ancillary/Directions.crc --byear=$ancillary/Byears.FEB2016 --censor=$ancillary/Censor.FEB2016 --reg=$ancillary/Registry.21Dec15";
	
	copy("$params_file_int","$p->{work_dir}") or die "Copy of parameter-file failed: $!";
	copy("$params_file_thin","$p->{work_dir}") or die "Copy of parameter-file failed: $!";
	
	my $inc = ($p->{prev_ver_dir} eq "NULL") ? "" : "--inc_from_pred --inc $p->{prev_ver_dir}/MHS_intrnlv_men.20140101.predictions" ;
	safe_exec("$ba_exe --in=$p->{work_dir}/MHS_intrnlv_men.20140101.predictions --out=$p->{work_dir}/Analysis.MHS_intrnlv_men.20140101 --params=$params_file_int --prbs=$check_MSCRC_status_files/SEER_Incidence.men $inc $ba_args 2> $p->{work_dir}/log.analysis.MHS_intrnlv_men.20140101"); 
	
	$inc = ($p->{prev_ver_dir} eq "NULL") ? "" : "--inc_from_pred --inc $p->{prev_ver_dir}/MHS_intrnlv_women.20140101.predictions" ;
	safe_exec("$ba_exe --in=$p->{work_dir}/MHS_intrnlv_women.20140101.predictions --out=$p->{work_dir}/Analysis.MHS_intrnlv_women.20140101 --params=$params_file_int --prbs=$check_MSCRC_status_files/SEER_Incidence.women $inc $ba_args 2> $p->{work_dir}/log.analysis.MHS_intrnlv_women.20140101"); 
	
	$inc = ($p->{prev_ver_dir} eq "NULL") ? "" : "--inc_from_pred --inc $p->{prev_ver_dir}/THIN_validation_men.20140101.predictions" ;
	safe_exec("$ba_exe --in=$p->{work_dir}/THIN_validation_men.20140101.predictions --out=$p->{work_dir}/Analysis.THIN_validation_men.20140101 --params=$params_file_thin --prbs=$check_MSCRC_status_files/SEER_Incidence.men $inc $ba_args 2> $p->{work_dir}/log.analysis.THIN_validation_men.20140101"); 
	
	$inc = ($p->{prev_ver_dir} eq "NULL") ? "" : "--inc_from_pred --inc $p->{prev_ver_dir}/THIN_validation_women.20140101.predictions" ;
	safe_exec("$ba_exe --in=$p->{work_dir}/THIN_validation_women.20140101.predictions --out=$p->{work_dir}/Analysis.THIN_validation_women.20140101 --params=$params_file_thin --prbs=$check_MSCRC_status_files/SEER_Incidence.women $inc $ba_args 2> $p->{work_dir}/log.analysis.THIN_validation_women.20140101"); 
	print_debug("Completed bootstrap_analysis jobs on MHS_intrnlv_men/women, THIN_validation_men/women");
	
	# Compare against performance metrics of a previous version
	if ($p->{prev_ver_dir} ne "NULL") {
	
		safe_exec("$ba_exe --in=$p->{prev_ver_dir}/MHS_intrnlv_men.20140101.predictions --out=$p->{work_dir}/Prev.Analysis.MHS_intrnlv_men.20140101 --params=$check_MSCRC_status_files/parameters_files/parameters_file --prbs=$check_MSCRC_status_files/SEER_Incidence.men --inc_from pred --inc=$p->{work_dir}/MHS_intrnlv_men.20140101.predictions  $ba_args  2> $p->{work_dir}/prev.log.analysis.MHS_intrnlv_men.20140101"); 
		print STDERR "\n";
		safe_exec("$ba_exe --in=$p->{prev_ver_dir}/MHS_intrnlv_women.20140101.predictions --out=$p->{work_dir}/Prev.Analysis.MHS_intrnlv_women.20140101 --params=$check_MSCRC_status_files/parameters_files/parameters_file --prbs=$check_MSCRC_status_files/SEER_Incidence.women --inc_from pred --inc=$p->{work_dir}/MHS_intrnlv_women.20140101.predictions $ba_args 2> $p->{work_dir}/prev.log.analysis.MHS_intrnlv_women.20140101"); 
		print STDERR "\n";
		safe_exec("$ba_exe --in=$p->{prev_ver_dir}/THIN_validation_men.20140101.predictions --out=$p->{work_dir}/Prev.Analysis.THIN_validation_men.20140101 --params=$check_MSCRC_status_files/parameters_files/parameters_file.THIN  --prbs=$check_MSCRC_status_files/SEER_Incidence.men --inc_from pred --inc=$p->{work_dir}/THIN_validation_men.20140101.predictions $ba_args 2> $p->{work_dir}/prev.log.analysis.THIN_validation_men.2014010"); 
		print STDERR "\n";
		safe_exec("$ba_exe --in=$p->{prev_ver_dir}/THIN_validation_women.20140101.predictions --out=$p->{work_dir}/Prev.Analysis.THIN_validation_women.20140101 --params=$check_MSCRC_status_files/parameters_files/parameters_file.THIN --prbs=$check_MSCRC_status_files/SEER_Incidence.women --inc_from pred --inc=$p->{work_dir}/THIN_validation_women.20140101.predictions $ba_args 2> $p->{work_dir}/prev.log.analysis.THIN_validation_women.20140101"); 
		print STDERR "\n";
		
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
			die "Candidate version is not as good as previous version in certain measures." if (@$errors > 0);
		}
		print_debug("Completed performance comparison on MHS_intrnlv_men/women, THIN_validation_men/women");
	}	
}
	
###########################################################
# Step 6: Get scores from web service & compare to engine
###########################################################

if (not $p->{skip_web_service_run}) {
	
	my @prefices = qw/MHS_intrnlv_men.20140101 MHS_intrnlv_women.20140101 THIN_validation_men.20140101 THIN_validation_women.20140101/ ;
	my $sampling_prefix = "Sampled" ;
	# Step 6A: Sample expanded input files
	foreach my $prefix (@prefices) {
		sample_files($p->{work_dir},$prefix,$sampling_prefix."_".$prefix,$p->{web_service_sampling_p}) ;
	}
	print_debug("Completed sampling (preperation for engine vs. web-service comparison)");

	# Step 6B: getting web service scores from 4 sampled input files and comparing web service output files with engine ouputs
	foreach my $prefix (@prefices) {
		my $sampled_prefix = $sampling_prefix."_".$prefix ;
		safe_exec("//nas1/UsersData/$user/Medial/Applications/MeScore_CRC_Connected/MSCRC.Utilities/MSCRC.Utilities.FileBased.BatchConverter/bin/x86/Release/BatchFileConverter.exe $p->{work_dir} $sampled_prefix $p->{web_service_url} 0 > log.batch_converter.$sampled_prefix");
		print_debug("Completed web service run (using BatchConverter) on $prefix");
		compare_scores_subset($p->{work_dir},"$prefix.Scores.txt","$sampled_prefix.WebService.Scores.txt","$prefix.Scores.diff_prod_vs_engin",$p->{dll_error_codes},$p->{warn_only_on_diff}) ;
		print_debug("Completed comparison of engine vs. web service on $prefix");
	}
	print_debug("Completed all comparisons of engine vs. web service");
}

###########################################################
# Step 7: Create GoldTestVector 
###########################################################

# TODO: check what Eldan needs exactly


print STDERR "\nScript completed successfully\n";

###########################################################





