#!/cygdrive/w/Applications/Perl64/bin/perl.exe
# NOTE : Because of using perl.exe this script must be executed with full path H:/....

use strict(vars);
use Getopt::Long;

my $p = {
	rep_list => "H:/Medial/Resources/MSCRC_Version_freezing_files/MSCRC_repositories",
	};
	
GetOptions($p,
	"rep_list=s",		# File of reposirtories list
	"command=s",		# Command to execute on each repository
	);
	
print STDERR "Command line: $0 " . join(" ", @ARGV) . "\n";	
print STDERR "Parameters: " . join(", ", map {"$_ => $p->{$_}"} sort keys %$p) . "\n";

map {die "Missing required argument $_" unless (defined $p->{$_})} qw/rep_list command/ ;

# Read Repositories
my @reps ;
open (IN,$p->{rep_list}) or die "Cannot open $p->{rep_list} for reading" ;
while (<IN>) {
	chomp ;
	next if (/^#/);
	push @reps,$_ ;
}
close IN ;

my $nrep = scalar @reps ;
print STDERR "Read $nrep repositoties to $p->{command}\n" ;

# Do your stuff
foreach my $rep (@reps) {
	print STDERR "Working on $rep\n";
	chdir($rep) ;
	system("$p->{command}\n") == 0 or die "Cannot execute $p->{command} in $rep" ;
}