#!/cygdrive/w/Applications/Perl64/bin/cygwin_perl 

use strict;
my $i;


my $f_in = $ARGV[0];

# open file
open (INF, "<", $f_in) or die "Cannot open $f_in for reading" ;

my %throw0;
$throw0{10000} = 0;
$throw0{10001} = 1;
$throw0{10002} = 0;
$throw0{10003} = 0;
$throw0{10004} = 1;
$throw0{10005} = 1;
$throw0{10006} = 1;
$throw0{10007} = 1;
$throw0{10008} = 0;
$throw0{10500} = 0;
$throw0{10501} = 1;
$throw0{10502} = 0;
$throw0{10503} = 0;
$throw0{10504} = 1;
$throw0{10505} = 1;
$throw0{10506} = 1;
$throw0{10507} = 1;
$throw0{10508} = 0;
$throw0{10159} = 0;
$throw0{10160} = 0;

while (<INF>) {

	chomp;
	my @f = split /\,/,$_;
	
	my $bad_comment = 1;
	
	$bad_comment = 0 if ($f[5] =~ /^NEGATIVE/);
	$bad_comment = 0 if ($f[5] =~ /^POSITIVE/);
	$bad_comment = 0 if ($f[5] =~ /^NORMAL/);
	$bad_comment = 0 if ($f[5] =~ /^        /);
	
	next if ($bad_comment == 1);
	next if ($f[3] == 0 && $throw0{$f[1]}==1);
	next if ($f[3] < 5 && ($f[1] == 10002 || $f[1] == 10502));
	
	print "$_\n";
	
}
























