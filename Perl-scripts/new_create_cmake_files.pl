#!/usr/bin/perl 
use strict;
use Getopt::Long;
use FileHandle;
use File::Temp qw/tempfile/;
use File::Basename;
use Cwd qw();
use Cwd 'abs_path';

### functions

sub open_file {
    my ($fn, $mode) = @_;
    
	#print STDERR "Opening file $fn in mode $mode\n";
    $fn = "/dev/stdin" if ($fn eq "-");
    my $fh = FileHandle->new($fn, $mode) or die "Cannot open $fn in mode $mode: $!";

	return $fh;
}

sub read_text_from_file {
	my ($fn) = @_;
	
	my $fh = open_file($fn, "r");
	my $res = join("", <$fh>);
	$fh->close;
	
	return $res;
}

sub write_text_to_file {
	my ($fn, $txt) = @_;
	
	my $fh = open_file($fn, "w");
	$fh->print($txt);
	$fh->close;
}

sub safe_exec {
	my ($cmd, $warn) = ("", 0);
	my $cdir = Cwd::cwd();
	
	($cmd, $warn) = @_ if (@_ == 2);
	($cmd) = @_ if (@_ == 1);
	die "Wrong number of arguments fo safe_exec()" if (@_ > 2);
	
	print STDERR "\"$cmd\" starting on " . `date` ;
	my $rc = system($cmd);
	print STDERR "\"$cmd\" finished execution on " . `date`;
	print STDERR "Current Dir " . $cdir . "\n" if ($rc != 0);
	die "Bad exit code $rc" if ($rc != 0 and $warn == 0);
	warn "Bad exit code $rc" if ($rc != 0);
}

sub safe_backtick {
	my ($cmd) = @_;
	
	# print STDERR "\"$cmd\" backticking starting on " . `date` ;
	my $out = qx($cmd);
	my $rc = $?;
	# print STDERR "\"$cmd\" backticking finished execution on " . `date`;
	die "Bad exit code $rc for backticked command \"$cmd\"" if ($rc != 0);
	
	return $out;
}

### main ###
my $p = {
	cmake_top_level_templ => "$ENV{MR_ROOT}/Projects/Resources/CMakeUtils/CmakeTopLevelTemplate.ubuntu.txt",
	cmake_base_level_templ => "$ENV{MR_ROOT}/Projects/Resources/CMakeUtils/CmakeBaseLevelTemplate.txt",
	skip_sol_list => "",
	run_make => 0,
	j_make => 4,
	shared_libs => 0,
	log_infra => 0,
	new_compiler => 1,
	shared_lib_folder => ""
};
	
GetOptions($p,
	"cmake_top_level_templ=s",   # file name with template for top level CMakeLists.txt in library repositories (VS solution)
	"cmake_base_level_templ=s",   # file name with template for base level CMakeLists.txt in library repositories (VS project)
	"skip_sol_list=s",            # list of solutions to ignore (comma separated, no spaces)
	"run_make", 	# whether to run 'make' after generating the Makefiles
	"j_make=i",       # number of threads for make
	"shared_libs",  # add build of shared libraries
	"log_infra", # whather or not print and log infra libs compilation 
	"new_compiler", #if compile with the new compiler
	"shared_lib_folder=s" #library to compiler and work with
);

if ($p->{shared_lib_folder} eq "") {
	if ($p->{new_compiler} == 1) {
		$p->{shared_lib_folder} = "/nas1/Work/SharedLibs/linux/ubuntu/";
	}
	else {
		$p->{shared_lib_folder} = "/nas1/Work/SharedLibs/linux/lib64/";
	}
}
	
print STDERR "Command line: $0 " . join(" ", @ARGV) . "\n";	
print STDERR "Parameters: " . join(", ", map {"$_ => $p->{$_}"} sort keys %$p) . "\n";

# list of Medial Libs to skip
my $skipMedialLibs = {AlgoLib => 1};

# list of libraries to ignore as dependencies
my $ignoreLibsStr = "kernel32.lib;user32.lib;gdi32.lib;winspool.lib;comdlg32.lib;advapi32.lib;shell32.lib;ole32.lib;oleaut32.lib;uuid.lib;odbc32.lib;odbccp32.lib;dmlccore.lib;dmlc.lib";
$ignoreLibsStr =~ s/\.lib//g;
my $ignoreLibAsDep = {};
map {$ignoreLibAsDep->{$_} = 1} split(/;/, $ignoreLibsStr); 

# list of external libraries that appear as named dependencies in vcxproj files
my $extNamedLibs = {libxl => $ENV{LIBXL_LIB}};

# read CMakeLists.txt templates
my $cmakeTopLevelTxt = read_text_from_file($p->{cmake_top_level_templ});
my $cmakeBaseLevelTxt = read_text_from_file($p->{cmake_base_level_templ});

my ($tmp_fh, $tmp_fn) = tempfile();
safe_exec("find $ENV{MR_ROOT}/Libs -name \'*.vcxproj\' > $tmp_fn");
$tmp_fh = FileHandle->new($tmp_fn, "r");
my @libFiles;
while (<$tmp_fh>) {
	next if (/AutoRecover/);
	chomp;
	push @libFiles, $_;
}
$tmp_fh->close; unlink($tmp_fn);

my ($tmp_fh2, $tmp_fn2) = tempfile();
safe_exec("find . -name \'*.sln\' > $tmp_fn2");
$tmp_fh2 = FileHandle->new($tmp_fn2, "r");
my @slnFiles;
while (<$tmp_fh2>) {
	next if (/AutoRecover/);
	chomp;
	push @slnFiles, $_;
}
$tmp_fh2->close; unlink($tmp_fn2);
if ($p->{log_infra} > 0) {
	print STDERR join(", ", @slnFiles) . "\n";
}

my $solCmake = {};

# insert given list of solutions to skip
map {$solCmake->{$_}{ignore} = 1} split(/,/, $p->{skip_sol_list});

my @dSolList;

my $projCmake = {};
my $medialLibPath = {};
for my $libPrj (@libFiles) {
	next unless($libPrj);
	my $inMedialLibs = 1;
	if ($libPrj =~ /xgboost/) {$inMedialLibs = 0;}
	if ($libPrj =~ /AlgoMarker/) {$inMedialLibs = 0;}
	my $projText = read_text_from_file($libPrj);
	my $isLib = ($projText =~ /Library<\/ConfigurationType/) ? 1 : 0;
	my  $projName = basename(dirname($libPrj));
	
	if ($isLib and $inMedialLibs) {
	#		$medialLibPath->{$projName} = "$projName/$projName";
			my $path_to = $libPrj;
			$path_to =~ s/\/([^\/]+)\.vcxproj$//;
			if ($p->{log_infra} > 0) {
				print STDERR "debug: path_to: $path_to\n";
			}
			$medialLibPath->{$projName} = $path_to;
			#print $projName . " => " . $path_to . "\n";
	}	
}

for my $sln (@slnFiles) {
	my @vcxprojFiles;
	next unless($sln);
	my $fullPath_sln = abs_path(dirname($sln));
	$fullPath_sln =~ s/^\/server\//\/nas1\//g;
	print "Scanning Solution " . $sln . " Solution Dir: " . $fullPath_sln . "\n";
	open my $fh, '<:encoding(UTF-8)', $sln or die;
	$solCmake->{$sln}{name} = $sln;
	$solCmake->{$sln}{path} = $fullPath_sln;
    while (my $line = <$fh>) {
        if ($line =~ /^Project/) {
            #print $line;
			my ($proj_path) = $line =~ /, "(.*\.vcxproj)",/;
			my $inMedialLibs = ($proj_path =~ /[\/\\]Libs[\/\\]/) ? 1 : 0;
			next if ($inMedialLibs);
			next unless ($proj_path);
			$proj_path =~ s/\\/\//g;
			if ($p->{log_infra} > 0) {
				print "In Project " . $proj_path . "\n";
			}
			push @vcxprojFiles, $proj_path;
        }
    }
	
	for my $vcx (@vcxprojFiles) {
		die "Wrong vcxproj path: $vcx" unless ($vcx =~ /\/([^\/]+)\.vcxproj$/);
		#my ($basePath, $projName) = ($1, $2);
		my $projName = basename(dirname($vcx));
		my $fullPath = abs_path(dirname($vcx));
		$fullPath =~ s/^\/server\//\/nas1\//g;
		my $inMedialLibs = ($vcx =~ /\/Libs/) ? 1 : 0;
		my $inDesiredSol = ($projName ~~ @dSolList) ? 1 : 0;
		if ($3 ne $4) {
			if ($p->{log_infra} > 0 || $inDesiredSol) {
				print STDERR "WARNING: Incompatibe Project dir and vcxproj names: $vcx, $1, $2, $3!=$4\n";
			}
			next;
		}
		
		if ($p->{log_infra} > 0 || $inDesiredSol) {
			print STDERR "\nProcessing file $vcx\n"; 
		
			print STDERR "debug: projName: $projName\n";
			print STDERR "debug: 12: 1: $1 2: $2\n";
		}
		
		my $projText = read_text_from_file($vcx);
		#print STDERR "\nProcessing file $projName => $vcx => $fullPath\n"; 
		
		if ($vcx =~ /xgboost/) {$inMedialLibs = 0;}
		my $isLib = ($projText =~ /Library<\/ConfigurationType/) ? 1 : 0;
		if ($p->{log_infra} > 0 || $inDesiredSol) {
			print "Project: $projName \tinMedialLibs: $inMedialLibs\tisLib: $isLib\n";
		}
		if ($isLib and $inMedialLibs and exists $skipMedialLibs->{$projName}) {
			$solCmake->{$sln}{ignore} = 1;
			if ($p->{log_infra} > 0 || $inDesiredSol) {
				print STDERR "Solution $projName under MEDIAL_LIBS relies on a MEDIAL_LIBS libarary $projName which is not included in the list of applicable MEDIAL_LIBS; Solution is ignored\n"; 
			}
			next;
		}
		
		# assumes that there are no two same-named libraries in different MEDIAL_LIBS repositories
		if ($isLib and $inMedialLibs) {
	#		$medialLibPath->{$projName} = "$projName/$projName";
			my $path_to = $vcx;
			$path_to =~ s/\/([^\/]+)\.vcxproj$//;
			if ($p->{log_infra} > 0 || $inDesiredSol) {
				print STDERR "debug: path_to: $path_to\n";
			}
			$medialLibPath->{$projName} = $path_to;
		}	
		
		push @{$solCmake->{$sln}{projList}}, "$projName";
		$projCmake->{"$projName"}{name} = $projName;
		$projCmake->{"$projName"}{path} = $fullPath;
		$projCmake->{"$projName"}{isLib} = $isLib;
		$projCmake->{"$projName"}{inMedialLibs} = $inMedialLibs;
		$projCmake->{"$projName"}{inDesiredSol} = $inDesiredSol;
		
		if ($p->{log_infra} > 0 || $inDesiredSol) {
			print STDERR "debug: ",$projCmake->{"$projName"}{path}, $projCmake->{"$projName"}{name}, $projCmake->{"$projName"}{isLib}, $projCmake->{"$projName"}{inMedialLibs}, "\n";
		}
		
		if (not $isLib) { # executable
			while ($projText =~ /<AdditionalDependencies>(\S+)<\/AdditionalDependencies>/g) {
				if ($p->{log_infra} > 0) {
					print STDERR "Dependencies for $projName: $1\n";
				}
				
				my $depStr = $1;
				$projCmake->{"$projName"}{depAllInternal} = ($depStr =~ s/\$\(MR_LIBS_NAME\);*//) ? 1 : 0;

				while ($depStr =~ /(\S+?)\.lib(;*)/g) {
					my $depLib = $1;
					if ($p->{log_infra} > 0) {
						print STDERR "debug: depStr: $depStr :: $depLib\n";
					}
					if (exists $ignoreLibAsDep->{$depLib}) {
						if ($p->{log_infra} > 0) {
							print STDERR "Ignoring $depLib as a dependency.\n";
						}
					}
					elsif (exists $extNamedLibs->{$depLib}) {
						$projCmake->{$projName}{extDepList}{$depLib} = 1;
					}
					else {
						if ($depLib ne $projName) {
							$projCmake->{$projName}{depList}{$depLib} = 0;
							if ($p->{log_infra} > 0) {
							     print "Add DEP: $projName => $depLib\n";
							}
						}
					}
				}
			}
			$projCmake->{"$projName"}{depBoostPO} = ($projText =~ /boost/i) ? 1 : 0;
			$projCmake->{"$projName"}{depXGBoostPO} = ($projText =~ /xgboost/i) ? 1 : 0;
			#$projCmake->{"$projName"}{depXGBoostPO} = 1;
			$projCmake->{"$projName"}{depVWPO} = ($projText =~ /libvw/i) ? 1 : 0;			
			
			if ($projCmake->{"$projName"}{depAllInternal}) {
				my @internal_libs = split /.lib(;*)/, $ENV{MR_LIBS_NAME};
				#print "in $projName var=  $ENV{MR_LIBS_NAME}\n";
				for my $lib_name (@internal_libs) {
					#if ($p->{log_infra} > 0) {
					#	print "Adding $lib_name to $projName\n";
					#}
					$projCmake->{$projName}{depList}{$lib_name} = 1;
					#$solCmake->{$projName}{depList}{$lib_name} = 1;
				}
				$projCmake->{"$projName"}{depXGBoostPO} = 1;
				#print "For $projName :\n";
				#map {print "$_\n"} keys %{$projCmake->{"$projName"}{depList}} ;
			}
		}	
	}
}
print STDERR "Finished scanning vcxproj files\n";

my @solList = sort keys %$solCmake;

my $topTxt = $cmakeTopLevelTxt;	
my $addSubdirTxt = "";

#Regenerate all Libs h, cpp files:
for my $libPrj (@libFiles) {
	next unless($libPrj);
		
	my $baseTxt = $cmakeBaseLevelTxt;
	my $projName = basename(dirname($libPrj));
	my $projPath = abs_path(dirname($libPrj));
	#$projPath =~ s/^\/server\//\/nas1\//g;
	my $projText = read_text_from_file($libPrj);
	my $isSharedLib = ($projText =~ /DynamicLibrary<\/ConfigurationType/) ? 1 : 0;
		
	my $h_files_txt = safe_backtick("find $projPath -name \"*.h\" -o -name \"*.hpp\" | sort");

	my @h_files = split(/\n/, $h_files_txt);
	for my $hfile (@h_files) {
		chomp $hfile;
		$hfile =~ s/$projPath\///;
	}
		
	$h_files_txt =~ s/$projPath\//\t/g;
	my $src_files_txt = safe_backtick("find $projPath -name \"*.c\" -o -name \"*.cpp\"| sort");
	$src_files_txt =~ s/$projPath\//\t/g;
		
	$baseTxt =~ s/_H_FILES_TXT_/$h_files_txt/;
	$baseTxt =~ s/_SRC_FILES_TXT_/$src_files_txt/;
			
	my $addTargetTxt = "";
	$addTargetTxt .= "add_library($projName STATIC \${H_FILES} \${SRC_FILES})\n";
	if ($p->{shared_libs} || $isSharedLib == 1) {
		$addTargetTxt .= "add_library(dyn_$projName SHARED \${H_FILES} \${SRC_FILES})\n";
	}
		
	$baseTxt =~ s/_ADD_TARGET_TXT_/$addTargetTxt/;
	write_text_to_file("$projPath/CMakeLists.txt", $baseTxt);
}
print STDERR "Finished update all Libs headers,source files\n";

for my $solName (@solList) {
	#print "Now with \"$solName\"\n";
	if (exists $solCmake->{$solName}{ignore}) {
		print STDERR "\nSkipping solution $solName \n";
		next;
	}
	
	
	my $printed_sol_name = 0;
	
	
	
	my %uniqueFullName;
	my %uniq_dep;
	my %uniq_sub_path;
	for my $uniqProjName (@{$solCmake->{$solName}{projList}}) {
		my $projName = $projCmake->{$uniqProjName}{name};
		
		$projCmake->{$projName}{depList}{$projName} = 1; # mark local dependencies
		if (not exists $uniqueFullName{$projName}) {
			#$addSubdirTxt .= "add_subdirectory($projName)\n";
			$addSubdirTxt .= "add_subdirectory(" . $projCmake->{$projName}{path} . " " . $projName . ")\n";
			#print STDERR "SUBDIRECTORY:1: $projCmake->{$projName}{path}\n";
			#$addSubdirTxt .= "add_subdirectory(" . $projCmake->{$projName}{path} . ")\n";
			$uniqueFullName{$projName} = 1;
			$uniq_sub_path{$projCmake->{$projName}{path}} = 1;
			#print STDERR "Added $projCmake->{$projName}{path}\n"
		}
		#print "Sol: $solName, projName= $projName, path= $projCmake->{$projName}{path} \n";
		my $baseTxt = $cmakeBaseLevelTxt;
		
		# get the lists of header and source files and plug into the project level (base) CMake file
		my $projPath = $projCmake->{$uniqProjName}{path};
		my $h_files_txt = safe_backtick("find $projPath -name \"*.h\" -o -name \"*.hpp\" | sort");

		my @h_files = split(/\n/, $h_files_txt);
		if ($p->{log_infra} > 0 || $projCmake->{$uniqProjName}{inDesiredSol} ) {
			print STDERR "@h_files\n";
		}
		for my $hfile (@h_files) {
			chomp $hfile;
			$hfile =~ s/$projPath\///;
		}
		if ($p->{log_infra} > 0 || $projCmake->{$uniqProjName}{inDesiredSol}) {
			print STDERR "@h_files\n";
		}
		
		$h_files_txt =~ s/$projPath\//\t/g;
		my $src_files_txt = safe_backtick("find $projPath -name \"*.c\" -o -name \"*.cpp\"| sort");
		$src_files_txt =~ s/$projPath\//\t/g;
		
		$baseTxt =~ s/_H_FILES_TXT_/$h_files_txt/;
		$baseTxt =~ s/_SRC_FILES_TXT_/$src_files_txt/;
			
		my $addTargetTxt = "";
		
		if ($p->{log_infra} > 0 || $projCmake->{$uniqProjName}{inDesiredSol}) {
			if ($printed_sol_name == 0) {
				print STDERR "\nWorking on solution $solName ($solCmake->{$solName}{path})\n";
				$printed_sol_name = 1;
			}
			print STDERR "debug 235: projCmake=$projCmake uniqProjName=$uniqProjName isLib $projCmake->{$uniqProjName}{isLib}\n";
		}
		if ($projCmake->{$uniqProjName}{isLib} == 1) {
			$addTargetTxt .= "add_library($projName STATIC \${H_FILES} \${SRC_FILES})\n";
			if ($p->{shared_libs}) {
				$addTargetTxt .= "add_library(dyn_$projName SHARED \${H_FILES} \${SRC_FILES})\n";
			}
		}
		else { # executable
			$addTargetTxt .= "add_executable($projName \${H_FILES} \${SRC_FILES})\n";
			my @linkLibList;
			my @internalLibList;
			if (exists $projCmake->{$uniqProjName}{depList}) {
				# LOCAL or in MEDIAL_LIBS
				my @depLibList =  grep  {(not $projCmake->{$uniqProjName}{depList}{$_}) or exists $medialLibPath->{$_}} sort keys %{$projCmake->{$uniqProjName}{depList}} ;
				@internalLibList = (@depLibList);
				if ($p->{log_infra} > 0) {
					for my $projDep (@internalLibList) {
					#for my $projDep (keys %{$projCmake->{$uniqProjName}{depList}}) {
					#for my $projDep (%{$medialLibPath}) {
						print "DEBUG_DEP $uniqProjName => $projDep \n";
					}
				}
			}
						
			# external libraries - special treatment for Boost program_options library which does not appear explicitly in the vcxproj files
			if (exists $projCmake->{$uniqProjName}{extDepList}) {
				my @extDepList = sort keys %{$projCmake->{$uniqProjName}{extDepList}};
				map {push @linkLibList, $extNamedLibs->{$_}} @extDepList;
				#print "DEBG: $projCmake->{$uniqProjName}{extDepList}\n";
			}
				
			if ($projCmake->{$uniqProjName}{depBoostPO}) {
				push @linkLibList, "libboost_regex.so";
				push @linkLibList, "libboost_program_options.so";
				push @linkLibList, "libboost_filesystem.so";
				push @linkLibList, "libboost_system.so";
				
				#push @linkLibList, "\$ENV{BOOST_PO_LIB_\${CMAKE_BUILD_TYPE}}";
				#push @linkLibList, "\$ENV{BOOST_FS_LIB_\${CMAKE_BUILD_TYPE}}";
				#push @linkLibList, "\$ENV{BOOST_RE_LIB_\${CMAKE_BUILD_TYPE}}";
				#push @linkLibList, "\$ENV{BOOST_SYS_LIB_\${CMAKE_BUILD_TYPE}}";
			}
			if ($projCmake->{$uniqProjName}{depXGBoostPO}) {
				my $dir = $p->{shared_lib_folder}."\${CMAKE_BUILD_TYPE}";
				
				push @linkLibList, "$dir/libxgboost.so";
				push @linkLibList, "$dir/lib_lightgbm.so";
			}
			
			if (@linkLibList) {
				$addTargetTxt .= "target_link_libraries($projName \${ADDITIONAL_LINK_FLAGS} -Wl,--start-group " . join(" ", (@internalLibList)) . " -Wl,--end-group " . join(" ", @linkLibList)  . ")\n"; 
			}
		}
		
		$baseTxt =~ s/_ADD_TARGET_TXT_/$addTargetTxt/;
		write_text_to_file("$projPath/CMakeLists.txt", $baseTxt);
		
		# we assume that a project depends only on libraries under MEDIAL_LIBS or in-solution libraries or libraries in , and not libraries from other MEDIAL_PROJECTS solutions
		if (exists $projCmake->{$uniqProjName}{depList}) {
			# need to handle correctly MEDIAL_LIBS vs. in-solution
			for my $solDep (sort keys %{$projCmake->{$uniqProjName}{depList}}) {
				my $depNotLocal = $projCmake->{$uniqProjName}{depList}{$solDep}; # local (in-solution) libraries have already been added as direct subdirs 
				if ($depNotLocal) { 
					# $solDep must now be either a MEDIAL_LIBS library or an unsupported external library;
					# an unsupported library is ignored and the CMake file for the solution is incomplete, but this solution is actually not aplicable for the type of build provided by this script
					if (not exists $medialLibPath->{$solDep}) {
						if ($p->{log_infra} > 0) {
							print STDERR "Dependency \'$solDep\' for project \'$uniqProjName\' is not under MEDIAL_LIBS and is skipped\n";
						}
					}
					else {
						if (not exists $uniq_dep{$solDep}) {
							if (not exists $uniq_sub_path{$medialLibPath->{$solDep}}) {
	#							$addSubdirTxt .= "add_subdirectory(/\$" . "ENV{MR_ROOT}" . "/Libs/$medialLibPath->{$solDep} $solDep)\n"; # adding as indirect subdir
								$addSubdirTxt .= "add_subdirectory($medialLibPath->{$solDep} $solDep)\n"; # adding as indirect subdir
								#print STDERR "SUBDIRECTORY:2: $medialLibPath->{$solDep}\n";
								$uniq_dep{$solDep} = 1;
								$uniq_sub_path{$medialLibPath->{$solDep}} = 1;
								#print STDERR "Added Lib $medialLibPath->{$solDep}\n"
							}
						}
					}
				}
				#else {
				#	print STDERR "DEBUG_LOCAL_DEP $solDep\n";
				#}
			}
		}
	}

	$topTxt =~ s/_projName_/$solName/;
	$topTxt =~ s/_ADD_SUBDIR_TXT_/$addSubdirTxt/;
	if ($p->{new_compiler} > 0) {
		$topTxt =~ s/(.*include_directories[^\n\r]*)/$1\ninclude_directories(SYSTEM \/server\/Work\/Libs\/Boost\/boost_1_67_0-fPIC.ubuntu)/;
	}
	#print "write to $solCmake->{$solName}{path}/CMakeLists.txt \n";
	write_text_to_file("$solCmake->{$solName}{path}/CMakeLists.txt", $topTxt);
}

# restricting CMake runs to a desired list of solutions, if required
if ($p->{desired_sol_list} ne "") {
	my @desSolList = split(/,/, $p->{desired_sol_list});
	map {die "Desired solution $_ is not in the list of solutions found in file system" if (not exists $solCmake->{$_})} @desSolList;
	@solList = @desSolList;
}
print STDERR "Going to work on solutions:\n" . join(", ", @solList) . "\n";

for my $solName (@solList) {
	if (exists $solCmake->{$solName}{ignore}) {
		print STDERR "\nSkipping solution $solName\n";
		next;
	}	
	print STDERR "\nRunning CMake on project $solName ($solCmake->{$solName}{path})\n";
	for my $buildType (qw(Release Debug)) {
		my $buildDir = "$solCmake->{$solName}{path}/CMakeBuild/Linux/$buildType";
		safe_exec("mkdir -p $buildDir");
		$buildDir = abs_path($buildDir);
		print "Build Dir: ".  $buildDir . "\n";
		safe_exec("mkdir -p $buildDir");
		chdir($buildDir) or die "can't change dir to $!\n";
		if ($p->{new_compiler} == 0) {
			safe_exec("cmake -DCMAKE_BUILD_TYPE=$buildType \"Unix Makefiles\" ../../../");
		}
		else {
			safe_exec("cmake -DCMAKE_BUILD_TYPE=$buildType -G \"Unix Makefiles\" ../../../");
			
			#safe_exec("cmake -DCMAKE_BUILD_TYPE=$buildType -DCMAKE_C_COMPILER=/usr/local/bin/gcc -DCMAKE_CXX_COMPILER=/usr/local/bin/c++ -DCMAKE_EXE_LINKER_FLAGS=\" -static-libstdc++\" \"Unix Makefiles\" ../../../");
		}
		if ($p->{run_make}) {
			print STDERR "\n>>>>>>>>> Start building project $solName in mode $buildType\n";
			safe_exec("make -j $p->{j_make}");
			print STDERR "<<<<<<<<< Finished building solution $solName in mode $buildType\n\n";
		}
	}
}
