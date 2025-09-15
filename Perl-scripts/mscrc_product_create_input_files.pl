#!/usr/bin/env perl 
use strict(vars) ;
use Getopt::Long;
use FileHandle;
use Dumpvalue;

my $dumper = new Dumpvalue;

sub open_file {
    my ($fn, $mode) = @_;
    
	print STDERR "Opening file $fn in mode $mode\n";
    $fn = "/dev/stdin" if ($fn eq "-");
    my $fh = FileHandle->new($fn, $mode) or die "Cannot open $fn in mode $mode: $!";

	return $fh;
}

sub get_mac_fixed_info {

	my $mac_codes_txt = 
<< "EOT";
1	5041	10*6/micl
1	5048	10*3/micl
1	50221	mic*3
1	50223	g/dl
1	50224	%
1	50225	fl
1	50226	pg/cell
1	50227	g/dl
1	50228	%
1	50229	10*3/micl
1	50230	#
1	50232	%
1	50234	%
1	50235	%
1	50236	%
1	50237	#
1	50239	#
1	50241	#
1	50233	%
1	50238	#
EOT

	my $code2desc = {
		5041 =>		"RBC",
		5048 =>		"WBC",
		50221 =>	"MPV",
		50223 =>	"Hemoglobin",
		50224 =>	"Hematocrit",
		50225 =>	"MCV",
		50226 =>	"MCH",
		50227 =>	"MCHC-M",
		50228 =>	"RDW",
		50229 =>	"Platelets",
		50230 =>	"Eosinophils #",
		50232 =>	"Neutrophils %",
		50233 =>	"Lymphocytes %",
		50234 =>	"Monocytes %",
		50235 =>	"Eosinophils %",
		50236 =>	"Basophils %",
		50237 =>	"Neutrophils #",
		50238 =>	"Lymphocytes #",
		50239 =>	"Monocytes #",
		50240 =>	"Platelets Hematocrit",
		50241 =>	"Basophils #",
	};

	my $cbc_test_order = [5041, 5048, 50221, 50223, 50224, 50225, 50226, 50227, 50228, 50229, 
							50230, 50232, 50234, 50235, 50236, 50237, 50239, 50241, 50233, 50238];
	
	return [$mac_codes_txt, $code2desc, $cbc_test_order];
}

my $month_name ={"01" => "JAN", "02" => "FEB", "03" => "MAR", "04" => "APR",
                 "05" => "MAY", "06" => "JUN", "07" => "JUL", "08" => "AUG",
				 "09" => "SEP", "10" => "OCT", "11" => "NOV", "12" => "DEC"};
				 
sub date2mscrc {
	my ($date) = @_;
	my ($y, $m, $d) = (substr($date, 0, 4), substr($date, 4, 2), substr($date, 6, 2));

	return sprintf("%s-%s-%s", $y, $month_name->{$m}, $d);
}

sub process_single_ind_cbc_info {
	my ($id, $ind_cbc_info, $params, $cbc_test_order,
		$dmg_info, $reg_info, $crc_info,
		$set_demog_fh, $set_dat_fh, $label_fh) = @_;
	
	# output relevant CBC tests
	my @ind_cbc_dates = sort {$a <=> $b} keys %$ind_cbc_info;
	printf STDERR "Working on %d with CBCs on: %s\n", $id, join(", ", @ind_cbc_dates);
	return 0 if (exists $reg_info->{$id} and ! exists $crc_info->{$id}); # affected with other cancer
		
	my $dob = $dmg_info->{$id}{yob} * 10000 + 701;
	print STDERR "Date of birth for $id is $dob\n";

	if (exists $crc_info->{$id}) { # take the latest CBC before (first) registry date and all preceeding CBCs
		my @ind_crc_dates = sort {$a <=> $b} @{$crc_info->{$id}};
		my $first_crc_date = $ind_crc_dates[0];
		print STDERR "First CRC date for $id is $first_crc_date\n";
		my @ind_cbc_before_crc_dates_in_win = 
			grep {$_ <= ($first_crc_date - $params->{min_days}) and ($_ + $params->{max_days}) >= $first_crc_date} @ind_cbc_dates;
		return 0 if (@ind_cbc_before_crc_dates_in_win == 0);
		my $last_cbc_before_crc_date_in_win = $ind_cbc_before_crc_dates_in_win[-1];
		print STDERR "Latest CBC before CRC registry in time window for $id is at $last_cbc_before_crc_date_in_win\n"; 
		# check that age at time of last CBC before CRC registry in window is in range, otherwise drop this individual
		my $age = ($last_cbc_before_crc_date_in_win - $dob) / 10000.0;
		print STDERR "Age of $id at time of latest CBC before CRC within window is $age\n";
		return 0 unless ($age >= $params->{min_age} and $age <= $params->{max_age});
		for my $d (grep {$_ <= $last_cbc_before_crc_date_in_win} @ind_cbc_dates) {
			map {$set_dat_fh->print(join("\t", 1, $id, $cbc_test_order->[$_], date2mscrc($d), $ind_cbc_info->{$d}[$_]) . "\n")} (0 .. 19);
		}
		$label_fh->print("$id\t1\n");
	}
	else { # choose one CBC in the valid age range at random and add all preceeding CBCs
		my @ind_cbc_ages = map {($_ - $dob) / 10000.0} @ind_cbc_dates;
		printf STDERR "Ages of %d at times of CBCs: %s\n", $id, join(", ", @ind_cbc_ages);
		my @ind_cbc_ages_in_range = grep {$ind_cbc_ages[$_] >= $params->{min_age} and $ind_cbc_ages[$_] <= $params->{max_age}} (0 .. $#ind_cbc_ages); #index array
		return 0 if (@ind_cbc_ages_in_range == 0);
		printf STDERR "CBCs of %d within age range: %s (ages: %s)\n", $id, join(", ", @ind_cbc_dates[@ind_cbc_ages_in_range]), join(", ", @ind_cbc_ages[@ind_cbc_ages_in_range]);
		my $rand_last_date = $ind_cbc_dates[$ind_cbc_ages_in_range[0] + int(@ind_cbc_ages_in_range * rand())];
		print STDERR "No CRC, last CBC taken from $rand_last_date\n";
		for my $d (@ind_cbc_dates) {
			last if ($d > $rand_last_date);
			print STDERR "Writing CBC $id @ $d to Data file\n";
			map {$set_dat_fh->print(join("\t", 1, $id, $cbc_test_order->[$_], date2mscrc($d), $ind_cbc_info->{$d}[$_]) . "\n")} (0 .. 19);
		}		
		$label_fh->print("$id\t0\n");
	}
	
	# output demographics
	$set_demog_fh->print(join("\t", 1, $id, $dmg_info->{$id}{yob}, $dmg_info->{$id}{gender}) . "\n");
	
	return 1;
}

# === main ===

# processing paramters
my $P = [
	"cbc_fn | s | matrix file in txt format | \"W:/CRC/Maccabi_JUN2013/IntrnlV/women_validation.txt\"",
	"dmg_fn | s | demographics file | \"W:/CRC/AllDataSets/Demographics\"",
	"dir_fn | s | directions file | \"W:/CRC/AllDataSets/Directions.crc\"",
	"reg_fn | s | registry file | \"W:/CRC/AllDataSets/Registry\"",
	"seed | i | seed for randomizing last CBC date for controls | 314159",
	"min_age | i | minimal age at date of CBC | 50",
	"max_age | i | maximal age at date of CBC | 75",
	"min_days | i | minimal number of days before registry | 30",
	"max_days | i | maximal number of days before registry | 180", 
	"codes_mscrc_fn | s | MSCRC Codes input file | \"Test.2014-JAN-08.set1.Codes.txt\"",
	"dat_mscrc_fn | s | MSCRC Data input file | \"Test.2014-JAN-08.set1.Data.txt\"",
	"demog_mscrc_fn | s | MSCRC Demographics input file | \"Test.2014-JAN-08.set1.Demographics.txt\"",
	"label_fn | s | labels of individuals in MSCRC Data input files (auxiliary file for computing performance parameters) | \"Test.2014-JAN-08.set1.Labels.txt\"",
 ];

if ($ARGV[0] eq "\-h" || $ARGV[0] eq "\-\-help") {
	print STDERR "$0 version 1.0.13\nUsage:\n";
	map {my @F = split(/ \| /, $_); print STDERR "\-\-" . $F[0] . " (" . $F[1] . ") : " . $F[2] . (($F[3] ne  "") ? (" (default: " . $F[3] . ")") : "") . "\n";} @$P;
	exit(0);
}
	
my $params;
my $getopt_txt = "\$params = \{\n";
map {my @F = split(/ \| /, $_); $getopt_txt .= "\t" . $F[0] . " => " . $F[3] . ",\n" if ($F[3] ne "")} @$P;
$getopt_txt .= "\t};\n\n";

$getopt_txt .= "GetOptions(\$params,\n";
map {my @F = split(/ \| /, $_); $getopt_txt .= "\t\"" . $F[0] . "=" . $F[1] . "\",\t # " . $F[2] . "\n"} @$P;
$getopt_txt .= "\t);\n";
print STDERR "code for getopt:\n$getopt_txt\n";

eval($getopt_txt);   
print STDERR "Paramaters: " . join("; ", map {"$_ => $params->{$_}"} sort keys %$params) . "\n";

# initializations
srand($params->{seed});

my $cbc_fh = open_file($params->{cbc_fn}, "r");
my $dmg_fh = open_file($params->{dmg_fn}, "r");
my $dir_fh = open_file($params->{dir_fn}, "r");
my $reg_fh = open_file($params->{reg_fn}, "r");

my $set_codes_fh = open_file($params->{codes_mscrc_fn}, "w");
my $set_dat_fh = open_file($params->{dat_mscrc_fn}, "w");
my $set_demog_fh = open_file($params->{demog_mscrc_fn}, "w");
my $label_fh = open_file($params->{label_fn}, "w");

my ($mac_codes_txt, $code2desc, $cbc_test_order) = @{get_mac_fixed_info()};
$set_codes_fh->print($mac_codes_txt);
$set_codes_fh->close;

# read demographics
my $dmg_info = {};
map {chomp; my @F = split; $dmg_info->{$F[0]} = {yob => $F[1], gender => $F[2]};} <$dmg_fh>;

# read CRC directions
my $dir_info = {};
map {chomp; my @F = split(/\t/); $dir_info->{$F[0]} = 1 if ($F[1] == 1); print STDERR $F[0] . "\n";} <$dir_fh>;

# read and process registry entries
my $reg_info = {};
my $crc_info = {};
my $num_bad_dates = 0;
while (<$reg_fh>) {
	chomp;
	my @F = split(/,/);
	my ($id, $date) = @F[0, 5];
	my @D = split(/\//, $date);
	next if ($date eq "date"); # header line
	do {$num_bad_dates ++; next;} unless ($D[2] >= 1900 && $D[1] >= 0 && $D[1] <= 31 && $D[0] >= 1 && $D[0] <= 12);
	$D[1] = 1 if ($D[1] == 0); # fixing day in month
	$date = sprintf("%4d%02d%02d", $D[2], $D[0], $D[1]);
	my @mac_cancer_types = @F[14, 15, 16];
	# print STDERR join("\t", $id, $date, join(",", @mac_cancer_types)) . "\n";
	push @{$reg_info->{$id}}, $date;
	next unless (exists $dir_info->{join(",", @mac_cancer_types)});
	push @{$crc_info->{$id}}, $date;
}
printf STDERR "Removed %d registry entries due to illegal dates\n", $num_bad_dates; 
printf STDERR "Number of CRC cases in universal registry: %d\n", scalar(keys %$crc_info);

# traverse CBC tests (grouped by date);
# assuming that file is sorted by id
my $cbc_info = {};
my $prev_id = -1;
while (<$cbc_fh>) {
	chomp;
	my @F = split(/\t/);
	my ($id, $date) = (int($F[0]), int($F[1]));
	if ($id != $prev_id)  {
		process_single_ind_cbc_info($prev_id, $cbc_info, $params, $cbc_test_order,
									$dmg_info, $reg_info, $crc_info,
									$set_demog_fh, $set_dat_fh, $label_fh) if (keys %$cbc_info > 0);
		$prev_id = $id;
		$cbc_info = {};
	}
	my @D = (substr($date, 4, 2), substr($date, 6, 2), substr($date, 0, 4));
	die "Illegal date in CBC: $date" unless ($D[2] >= 1900 && $D[1] >= 1 && $D[1] <= 31 && $D[0] >= 1 && $D[0] <= 12);
	
	my $cbc_vals = [@F[9 .. 28]];
	
	# print STDERR "CBC values for $id @ $date:\n";
	# map {print STDERR join("\t", $cbc_test_order->[$_], $code2desc->{$cbc_test_order->[$_]}, $cbc_vals->[$_]) . "\n"} (0 .. 19);
	$cbc_info->{$date} = $cbc_vals unless (scalar(grep {$_ == -1.0} @$cbc_vals) == 20);
}
process_single_ind_cbc_info($prev_id, $cbc_info, $params, $cbc_test_order,
							$dmg_info, $reg_info, $crc_info,
							$set_demog_fh, $set_dat_fh, $label_fh) if (keys %$cbc_info > 0);










