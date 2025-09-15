#!/usr/bin/env perl 

use strict(vars) ;
use FileHandle;

sub safe_exec {
    my ($cmd) = @_;

    # print STDERR "\"$cmd\" starting on " . `date`;
	print STDOUT $cmd . "\n";
    # my $rc = system($cmd);
    # print STDERR "\"$cmd\" finished execution on " . `date`;
    # die "Bad exit code $rc, aborting" if ($rc != 0);
}

### Main ###

safe_exec("dos2unix Byears Censor Demographics ID2NR Registry CBC_Matrix");
safe_exec("mkdir -p All Train IntrnlV ExtrnlV");
my $tot = `wc -l ../NR_shuffle`;
chomp $tot;
$tot =~ s/ .*//;
print STDERR "Total number of patients is $tot\n";

my $trn = int(0.7 * $tot);
my $intrnlv = int(($tot - $trn)/3.0);
my $extrnlv = $tot - $trn - $intrnlv;
printf STDERR "Numbers of patients in Train, IntrnlV, ExtrnlV: %d, %d, %d\n", $trn, $intrnlv, $extrnlv;

safe_exec("cat ../NR_shuffle | head -$trn | tail -$trn | C:/medial/Perl-scripts/intersect.pl CBC_Matrix - > CBC_Train");
safe_exec("cat ../NR_shuffle | head -" . ($trn + $intrnlv) . " | tail -$intrnlv | C:/medial/Perl-scripts/intersect.pl CBC_Matrix - > CBC_IntrnlV");
safe_exec("cat ../NR_shuffle | head -$tot | tail -$extrnlv | C:/medial/Perl-scripts/intersect.pl CBC_Matrix - > CBC_ExtrnlV");

