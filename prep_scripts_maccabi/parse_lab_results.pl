#!/cygdrive/w/Applications/Perl64/bin/cygwin_perl 

use strict;
my $i;

#my @unsorted = (5,7,2,9,3,4,0,8,9,9);
#my @indexes = 0..$#unsorted;
#my @sorted_indexes = sort {$unsorted[$a] <=> $unsorted[$b]} @indexes;
#for ($i=0; $i<$#unsorted; $i++) {
#	print "$i $sorted_indexes[$i] $unsorted[$sorted_indexes[$i]]\n";
#}

my $n_args = @ARGV;
my $f_in = $ARGV[0];

# open file
open (INF, "<", $f_in) or die "Cannot open $f_in for reading" ;



my %dont_throw_0;
$dont_throw_0{3725} = 1;
$dont_throw_0{25651} = 1;
$dont_throw_0{50057} = 1;
$dont_throw_0{50087} = 1;

# go over file line by line
my $nline = 0;
while (<INF>) {

	chomp;
	my @f = split /\,/,$_;
	my $sig_code = $f[1];
	my $val = $f[3];
	my $rem_is_empty = 1;
	my $rem_has_100 = 0;
	my $rem_has_1000 = 0;
	
	if (index($f[4],"100%") != -1) {
		$rem_has_100 = 1;
		$rem_is_empty = 0;
	}
	
	if (index($f[4],"1000") != -1) {
		$rem_has_1000 = 1;
		$rem_is_empty = 0;
	}
	
	$rem_is_empty = 0 if (!($f[4] =~ /\A\ *\z/i));
	
	#print "||$_||\n";
	#print "##$f[1] || $f[3] || $f[4] || $rem_is_empty $rem_has_100 $rem_has_1000\n";
	$val = 100 if ($val == 0 && $rem_has_100 == 1);
	$val = 1000 if ($val == 0 && $rem_has_1000 == 1);
	
	next if ($rem_is_empty == 0 && $rem_has_100 == 0 & $rem_has_1000 == 0);
	next if ($val==0 && !exists $dont_throw_0{$f[1]});
	
	print "$f[0],$f[1],$f[2],$val\n";
	
	#print "##\n";
	
	
	
	
	$nline++;
#	last if ($nline > 1000);
}

























