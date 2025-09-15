#!/usr/bin/env perl 
use strict;
use Getopt::Long;
use FileHandle;

my $user;

BEGIN {
die "Unsupported operating system name: $^O" unless ($^O eq "MSWin32" or $^O eq "linux");
$user = `whoami`; chomp $user;
print STDERR "User $user is invoking script $0 on a $^O machine\n";
}

use strict;
use lib "//nas1/UsersData/$user/MR/Projects/Scripts/Perl-modules" ;

use MedialUtils;

### main ###
my $p = {
	id2nr_file => "W:/CRC/THIN_MAR2014/ID2NR",
	pat_files =>  "T:/THIN/EPIC\ 65/MedialResearch_pat.csv, W:/CRC/NewCtrlTHIN/new_pat.csv", 
	ahd_files =>  "T:/THIN/EPIC\ 65/MedialResearch_ahd.csv, W:/CRC/NewCtrlTHIN/new_ahd.csv", 
	med2desc_file => "T:/THIN/EPIC\ 88/Ancillary\ files/Readcodes1205.txt",
	};

$p = {
	id2nr_file => "/server/Work/Users/Ido/THIN_ETL/ID2NR",
	pat_files =>  "/server/Data/THIN/EPIC\ 65/MedialResearch_pat.csv, /server/Work/CRC/NewCtrlTHIN/new_pat.csv", 
	ahd_files =>  "/server/Data/THIN/EPIC\ 65/MedialResearch_ahd.csv, /server/Work/CRC/NewCtrlTHIN/new_ahd.csv", 
	med2desc_file => "/server/Data/THIN/EPIC\ 88/Ancillary\ files/Readcodes1205.txt",
	};

	
GetOptions($p,
	"id2nr_file=s", # ID2NR file for THIN (cases from Old + ctrls from New)
	"pat_files=s",  # comma-separated list of patient info files 	
	"ahd_files=s",  # comma-separated list of AHD files
	"med2desc_file=s", # file with descriptions of medcodes
);
	
# read ID2NR translation table	
my $id2nr = {};
my $nfh = MedialUtils::open_file($p->{id2nr_file}, "r");
while (<$nfh>) {
	chomp;
	my ($id, $nr) = split(/\t/);
	# print "$_ : #$id,#$nr#\n";
	$id2nr->{$id} = $nr;
}
$nfh->close;
printf STDERR "Read %d id2nr records\n", scalar(keys %$id2nr);
	
# prepare demographics	
my $demog = {}; 	
for my $pat_fn (split(/,\s*/, $p->{pat_files})) {
	my $pfh = MedialUtils::open_file($pat_fn, "r");
	while (<$pfh>) {
		chomp;
		my @F = split(/,/);
		my $id = $F[0] . $F[1];
		next unless (exists $id2nr->{$id});
		my $nr = $id2nr->{$id};
		my $prt = (exists $demog->{$nr});
		# print STDERR "Duplicate records for nr $nr\n" if ($prt);
		# print STDERR MedialUtils::hash_to_str($demog->{$nr}) . "\n" if ($prt);
		$demog->{$nr} = {pracid => $F[0], patid => $F[1], yob => $F[3], gender => $F[5]};
		# print STDERR MedialUtils::hash_to_str($demog->{$nr}) . "\n" if ($prt);
	}
	$pfh->close;
}

# read descriptions of medcodes
my $med2desc = {};
my $mfh = MedialUtils::open_file($p->{med2desc_file}, "r");
while (<$mfh>) {
	chomp;
	my $medcode = substr($_, 0, 7);
	my $desc = substr($_, 7);
	$desc =~ s/\s+$//;
	# print STDERR "##$medcode##$desc##\n";
	$med2desc->{$medcode} = $desc;
}
$mfh->close;


# output header
print join("\t", qw(numerator yob sex evntdate data1 data2 data5 data6 medcode desc)) . "\n";				

# traverse AHD records with code 1003040000 (smoking)
my $smx_record_nr_date = {};
for my $ahd_fn (split(/,\s*/, $p->{ahd_files})) {
	my $afh = MedialUtils::open_file($ahd_fn, "r");
	while (<$afh>) {
		chomp;
		my @F = split(/,/);
		my ($pracid, $patid, $date, $ahdcode, 
			$data1, $data2, $data3, $data4, $data5, $data6,
			$medcode) = @F[0..3, 5..10, 11];
		next unless ($ahdcode eq "1003040000"); 	
		my $id = $pracid . $patid;
		next unless (exists $id2nr->{$id});
		my $nr = $id2nr->{$id};
		next if (exists $smx_record_nr_date->{$nr . "_" . $date} and 
				$smx_record_nr_date->{$nr . "_" . $date} ne $ahd_fn); # record already seen in another file
		$smx_record_nr_date->{$nr . "_" . $date} = $ahd_fn;		
		die "Missing dempgraphy for NR $nr" unless (exists $demog->{$nr});
		die "Missing description for medcode $medcode" unless (exists $med2desc->{$medcode});
		print join("\t", $nr, $demog->{$nr}{yob}, $demog->{$nr}{gender}, $date,
						 $data1, $data2, $data5, $data6, $medcode, $med2desc->{$medcode}) . "\n";
	}
	$afh->close;
}
