#!/usr/bin/env perl 

my $msbuild = "C:/Program Files (x86)/MSBuild/14.0/Bin/msbuild.exe" ;
my $isLinux = ($^O ne "MSWin32") ;
$user = `whoami`; chomp $user;

my ($file,$only_clean,$skip_clean) ;
if (@ARGV == 1) {
	$file = $ARGV[0] ;
	$only_clean = 0 ;
	$skip_clean = 0 ;
} elsif (@ARGV == 2 and $ARGV[1] eq "-onlyClean") {
	$file = $ARGV[0] ;
	$only_clean = 1 ;
	$skip_clean = 0 ;
} elsif (@ARGV == 2 and $ARGV[1] eq "-skipClean") {
	$file = $ARGV[0] ;
	$only_clean = 0 ;
	$skip_clean = 1 ;
} else {
	die "usage: $0 SlnFile [-onlyClean | -skipClean]"
}

open (IN,$file) or die "Cannot open $file for reading" ;
while (<IN>) {
	chomp ;
	next if (/^#/) ;
	my ($sln,@modes) = split ;
	
	my $cmake = 0 ;
	foreach my $mode (@modes) {
		my ($platform,$configuration,$deploy_flag) = split "/",$mode ;
		my $deploy_prop = (defined $deploy_flag ? "true" : "false");
		if ($isLinux) {
			die "Unknown Platform \'$platform\'" unless ($platform eq "Linux" or $platform eq "x64" or $platform eq "Win32" or $platform eq "x86") ;
			next unless ($platform eq "Linux") ;
			
			die "Unknown Configuration \'$configuration\'" unless ($configuration eq "Debug" or $configuration eq "Release") ;
		
			my @unixFullPath = split /\//,$sln ;
			pop @unixFullPath ;
			$unixFullPath[0] = "//server/UsersData/$user" ;
			my $sln_name = $unixFullPath[-1] ;
			my $unix_dir = join "/",@unixFullPath ;
			
			run("create_cmake_files.pl -des $sln_name") if ($cmake == 0) ;
			$camke = 1 ;
			
			run("pushd $unix_dir/CMakeBuild/Linux/Release && make clean ; popd  ; pushd $unix_dir/CMakeBuild/Linux/Debug && make clean ; popd") unless ($skip_clean) ;
			run("pushd $unix_dir/CMakeBuild/Linux/$configuration && make -j 8 ; popd") unless ($only_clean) ;
		} else {
			die "Unknown Platform \'$platform\'" unless ($platform eq "Linux" or $platform eq "x64" or $platform eq "Win32" or $platform eq "x86") ;
			next if ($platform eq "Linux") ;
			
			die "Unknown Configuration \'$configuration\'" unless ($configuration eq "Debug" or $configuration eq "Release" or $configuration eq "ForInstall"  or $configuration eq "Emulator") ;
			
			my $properties = "/p:Configuration=$configuration /p:Platform=\"$platform\" /p:DeployOnBuild=$deploy_prop" ;
			print STDERR "MR Message: Working on $sln in $mode\n" ;
			run("\"$msbuild\" /m $sln /t:Clean $properties") unless ($skip_clean) ;
			run("\"$msbuild\" /m $sln $properties") unless ($only_clean) ;
		}
	}
	
	print STDERR "\n----------------------- Completed: $sln -----------------------\n\n";
}

close IN ;


sub run {
	my $command = shift @_ ;
	print STDERR "Running $command\n" ;
	(system($command) == 0 or die "\'$command\' Failed" ) ;
}