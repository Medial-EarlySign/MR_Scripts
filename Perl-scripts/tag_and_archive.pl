#!/usr/bin/env perl 

use strict;
use Cwd ;

my $exe_flag = 1;

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

sub valid_file_name_format {
	my ($fn) = @_;
	
	my $fn_ok = ($fn =~ m/^[A-Z]:\// and not $fn =~ m/\\/);
	return $fn_ok;
}

my @required_files_to_archive = qw/AncFilesDir TrainingMatrixDir SplitDir ExternalMatrixDir InternalMatrixDir CheckMSCRCDir VerFreezeDir/ ;

die "Usage : $0 RepositoriesList TagName TempFile-FullPath [FilesToArchive ArchiveName]\nTo skip tagging part, give TagName = \'NULL\'\n" unless (@ARGV ==3 or @ARGV == 5) ;
my $tag_only = (@ARGV == 3) ? 1 : 0;
push @ARGV, ("", "") if ($tag_only);
my ($repFile,$tagName,$tempFile,$archFile,$archName) = @ARGV ;
my $skip_tag = ($tagName eq "NULL") ? 1 : 0;

if (not $skip_tag) {
	# Read Repositories
	my @reps ;
	open (IN,$repFile) or die "Cannot open $repFile for reading" ;
	while (<IN>) {
		chomp ;
		push @reps,$_ ;
	}
	close IN ;

	my $nrep = scalar @reps ;
	print STDERR "Read $nrep repositoties to tag\n" ;

	# Check Commit Status, Tag and push
	my $dir = getcwd() ;
	my $message = "Automatically tagged by $0" ;
	if ($tagName ne "NULL") {
		foreach my $rep (@reps) {
			chdir($rep) ;
			
			# Check that all files are commited
			system("git status > $tempFile") == 0 or die "Cannot status Repository $rep" ;

			open (IN,"$tempFile") or die "Cannot open $tempFile for reading" ;
			my @lines = <IN> ;
			close IN ;
			
			my $quit = 0 ;
			if ($lines[-1] !~ /nothing to commit, working directory clean/) {
				print STDERR "Not all files commited in $rep. Can not tag. Quitting (@lines)" ;
				$quit = 1 ;
			}
			
			system("rm -f $tempFile") == 0 or die "Cannot remove file $tempFile in $rep" ;
			die if ($quit) ;
		}

		foreach my $rep (@reps) {
			chdir($rep) ;
			# Tag and push repository
			print STDERR "Tagging $rep\n" ;
			safe_exec("git tag -a $tagName -m \"$message\"");
			print STDERR "Pushing $rep\n" ;
			safe_exec("git push --tags origin HEAD:MSCRC_Product_Versions");
		}
		chdir($dir);
	}
}

exit(0) if ($tag_only);

# Read list of files to archive
my %files ;
open (IN,$archFile) or die "Cannot open $archFile for reading" ;
while (<IN>) {
	chomp ;
	die "Cannot parse \'$_\' in $archFile" unless (/(\S+)\s*:=\s*(\S+)/) ;
	$files{$1} = $2 ;
}
close IN ;

map {die "$_ Missing in archiving file" if (! exists $files{$_})} @required_files_to_archive ;

my @files ;
foreach my $name (keys %files) {
	push @files, (split /\s*\,\s*/,$files{$name}) ;
}

my @files = values @files ;
my $narch = scalar @files ;
print STDERR "Read $narch files to archive\n" ;

# verify that all file names are in the standard format <drive>:/aaa/bbb/ccc
map {die "Illegal file name for archiving: $_" if (not valid_file_name_format($_))} @files; 

# need to uniqify file paths
my $uniq_fn = {};
foreach my $file (sort {length($a)<=>length($b)} @files) {
	$file =~ s/\/$//;
	my @path = split "/",$file ;	
	my $done = 0 ;
	for my $i (0..$#path) {
		my $sub_path = join "/",map {$path[$_]} (0..$i) ;
		if (exists $uniq_fn->{$sub_path}) {
			print STDERR "Ignoring $file because of $sub_path\n";
			$done = 1 ;
			last ;
		}
	}
	$uniq_fn->{$file} = 1 if (!$done) ;
}	
@files = sort keys %$uniq_fn;

# Archive
my @split = split "/",$archName ;
my $file = pop @split ;
chdir(join "/",@split)if (@split) ;

safe_exec("cp -f H:/Medial/Perl-scripts/git_tag_to_branch.pl .");
safe_exec("cp -f H:/Medial/Resources/MSCRC_Version_freezing_files/MSCRC_repositories .");
my @init_files = ("git_tag_to_branch.pl", "MSCRC_repositories");

safe_exec("tar -cvzf $file.init @init_files");
safe_exec("tar -cvzf $file @files");
