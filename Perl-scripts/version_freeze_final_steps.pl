#!/usr/bin/env perl 
use strict;
use Getopt::Long;
use FileHandle;

### functions ###
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

sub safe_exec {
	my ($cmd, $warn) = ("", 0);

	($cmd, $warn) = @_ if (@_ == 2);
	($cmd) = @_ if (@_ == 1);
	die "Wrong number of arguments fo safe_exec()" if (@_ > 2);
	
	print STDERR "\"$cmd\" starting on " . `date` ;
	my $rc = system($cmd);
	print STDERR "\"$cmd\" finished execution on " . `date`;
	die "Bad exit code $rc" if ($rc != 0 and $warn == 0);
	warn "Bad exit code $rc" if ($rc != 0);
}

### main ###
my $p = {
};
	
GetOptions($p,
	"tag_name=s",         # name of version tag
	"arch_name=s",        # archive name (full path)
	"work_dir=s",         # work dir of ReconstructAndVerify process 
);
	
print STDERR "Command line: $0 " . join(" ", @ARGV) . "\n";	
print STDERR "Parameters: " . join(", ", map {"$_ => $p->{$_}"} sort keys %$p) . "\n";

# creating the directory for the frozen versions and several subdirs
my $frz_ver_dir = "W:/CRC/FrozenVersions/$p->{tag_name}";

safe_exec("mkdir -p $frz_ver_dir");
safe_exec("mkdir -p $frz_ver_dir/CodeBase");
safe_exec("mkdir -p $frz_ver_dir/PrevPostCheckMSCRCDir");
safe_exec("mkdir -p $frz_ver_dir/ForInstall");
safe_exec("mkdir -p $frz_ver_dir/MedialDeploymentKit");
#safe_exec("mkdir -p $frz_ver_dir/GoldTestVector");
safe_exec("mkdir -p $frz_ver_dir/FilesForComparison");

# copy the archives
#safe_exec("cp -f $p->{arch_name} $frz_ver_dir");
#safe_exec("cp -f $p->{arch_name}.init $frz_ver_dir");

# copy the code base files
safe_exec("cp -rf H:/Medial $frz_ver_dir/CodeBase");

# copy PostCheckMSCRCDir files
safe_exec("cp -rf $p->{work_dir}/PostCheckMSCRCVerify/* $frz_ver_dir/PrevPostCheckMSCRCDir");

# locate ForInstall and MedialDeploymentKit directories under archived version freezing directory
my $fvd = "find_verfrz_dir";
safe_exec("find $p->{work_dir}/ARCH -path \"*ForInstall\" > $fvd");
die "Failed to find or too many PostCheckMSCRC/ForInstall. Found ".(`wc -l $fvd`)."\n" unless (`wc -l $fvd` == 1);
my $fvd_text = read_file_text($fvd, 0);
chomp $fvd_text;

my $arch_install_dir = $fvd_text;
safe_exec("cp -rf $arch_install_dir/* $frz_ver_dir/ForInstall");

# MedialDeploymentKit
safe_exec("find $p->{work_dir}/ARCH -path \"*MedialDeploymentKit\" > $fvd");
die "Failed to find or too many PostCheckMSCRC/MedialDeploymentKit. Found ".(`wc -l $fvd`)."\n" unless (`wc -l $fvd` == 1);
$fvd_text = read_file_text($fvd, 0);
chomp $fvd_text;

my $arch_med_deploy_dir = $fvd_text;
safe_exec("cp -rf $arch_med_deploy_dir/* $frz_ver_dir/MedialDeploymentKit");

=GoldTestVector - currently not included in freeze process (MeScore 2.0 - uluru_3)
safe_exec("find $p->{work_dir}/ARCH -path \"*GoldTestVector\" > $fvd");
die "Failed to find or too many PostCheckMSCRC/GoldTestVector. Found ".(`wc -l $fvd`)."\n" unless (`wc -l $fvd` == 1);
$fvd_text = read_file_text($fvd, 0);
chomp $fvd_text;

my $arch_gold_test_dir = $fvd_text;
safe_exec("cp -rf $arch_gold_test_dir/* $frz_ver_dir/GoldTestVector");
=cut

# copy files with boostrap_analysis results, for future comparisons
safe_exec("cp -f $p->{work_dir}/CheckMSCRCVerify/Analysis.* $frz_ver_dir/FilesForComparison");

# generate the appropriate CurrentFilesList file
my $old_cfl_fh = open_file("$p->{work_dir}/CheckMSCRCVerify/CurrentFilesList", "r");
my $new_cfl_fh = open_file("$frz_ver_dir/CurrentFilesList", "w");
while (<$old_cfl_fh>) {
	chomp;
	my @F = split(/\t/);
	my @N = split(/\//, $F[2]);
	$new_cfl_fh->print(join("\t", $F[0], $F[1], "W:/CRC/FrozenVersions/$p->{tag_name}/FilesForComparison/$N[-1]") . "\n");
}

print STDERR "Script finished succesfully.\n";
