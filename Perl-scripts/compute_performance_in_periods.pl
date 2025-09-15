#!/usr/bin/env perl 
use strict(vars) ;
use Getopt::Long;
use FileHandle;
use Dumpvalue;
use Carp;

my $dumper = new Dumpvalue;

sub open_file {
    my ($fn, $mode) = @_;
    
	print STDERR "Opening file $fn in mode $mode\n";
    $fn = "/dev/stdin" if ($fn eq "-");
    my $fh = FileHandle->new($fn, $mode) or confess "Cannot open $fn in mode $mode";

	return $fh;
}

sub add_months_to_date {
	my ($d, $add_mon) = @_;
	
	my $y = int($d / 10000);
	my $m = int(($d - 10000 * $y) / 100);
	
	my $nm = ($y - 1900) * 12 + ($m - 1); # number of months since the begining of 1900
	$nm += $add_mon; # works well for negative numbers as well, provided initial and final dates are after 1900
	
	my $new_m = ($nm % 12) + 1;
	my $new_y = 1900 + int($nm/12);
	
	my $new_d = sprintf("%4d%02d%02d", $new_y, $new_m, 0);
	print STDERR "Adding $add_mon months to date $d, resulting in date $new_d\n";
	return $new_d;
}

# === main ===

print STDERR "Command line: $0 " . join(" ", @ARGV) . "\n";
# processing paramters
my $P = [
	"pred_fn | s | file holding per-CBC predictions | \"\"",
	"dmg_fn | s | demographics file | \"W:/CRC/AllDataSets/Demographics\"",
	"dir_fn | s | directions file | \"W:/CRC/AllDataSets/Directions.crc\"",
	"reg_fn | s | registry file | \"W:/CRC/AllDataSets/Registry\"",
	"fobt_fn | s | FOBT information file | \"U:/Ami/MAC_DEC_2013/mac4_data_trn_cmbnd_occ_bld.id_date\"",
	"clnscpy_fn | s | file with information about colonscopies | \"U:/Ami/MAC_DEC_2013/mac4_data_from_27dec2011_colonscopies.id_date\"", 	
	"first_cbc_period_start | i | start mobth of first CBC period | 20040100",
	"cbc_period_len | i | length in months of period where CBCs for prediction are taken from | 6",
	"crc_period_len | i | length in months of period after CBC period where occurence of target cancer is checked for | 18",
	"last_cbc_period_start | i | start month of last CBC period | 20090700",
	"fobt_period_len | i | length in months of period before CBC period where patients with FOBT are excluded | 12",
	"clnscpy_period_len | i | length in months of period before CBC period where parients with colonscopy are excluded | 120",
	"min_age | i | minimal age at date of CBC | 50",
	"max_age | i | maximal age at date of CBC | 75",
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

my $pred_fh = open_file($params->{pred_fn}, "r");
my $dmg_fh = open_file($params->{dmg_fn}, "r");
my $dir_fh = open_file($params->{dir_fn}, "r");
my $reg_fh = open_file($params->{reg_fn}, "r");

my $fobt_fh = open_file($params->{fobt_fn}, "r");
my $clnscpy_fh = open_file($params->{clnscpy_fn}, "r");

# read demographics
my $dmg_info = {};
map {chomp; my @F = split; $dmg_info->{$F[0]} = {yob => $F[1], gender => $F[2]};} <$dmg_fh>;

# read cancer directions
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
printf STDERR "Number of target cancer cases in universal registry: %d\n", scalar(keys %$crc_info);

my $eff_crc_month = {}; # the month of first target cancer registry, if no other cancer type occured before
for my $id (keys %$crc_info) {
	my @reg_dates = sort {$a <=> $b} @{$reg_info->{$id}};
	my @crc_dates = sort {$a <=> $b} @{$crc_info->{$id}};
	if ($crc_dates[0] <= $reg_dates[0]) {
		$eff_crc_month->{$id} = 100 * int($crc_dates[0] / 100);
		print STDERR "First CRC for $id on $crc_dates[0] (month $eff_crc_month->{$id}) out of CRC dates " . join(", ", @crc_dates) . ", with all registry dates " . join(", ", @reg_dates) . "\n";
	}
	else {
		print STDERR "Other cancer occured before first CRC date; CRC dates are " . join(", ", @crc_dates) . ", with all registry dates " . join(", ", @reg_dates) . "\n";
	}
}

# read dates of FOBTs
my $fobt_dates = {};
map {chomp; my ($id, $date) = split; push @{$fobt_dates->{$id}}, $date;} <$fobt_fh>;

# read dates of colnscopies
my $clnscpy_dates = {};
map {chomp; my ($id, $date) = split; push @{$clnscpy_dates->{$id}}, $date;} <$clnscpy_fh>;

# loop over periods, traverse predictions (must be REVERSE sorted by date)
my $pred_file_pos = 0;

my @period_starts;
for (my $period_start = $params->{first_cbc_period_start}; $period_start <= $params->{last_cbc_period_start}; 
		$period_start = add_months_to_date($period_start, $params->{cbc_period_len})) {
		push @period_starts, $period_start;
}
@period_starts = sort {$b <=> $a} @period_starts;
		
for my $period_start (@period_starts)  {		
	my $period_end = add_months_to_date($period_start, $params->{cbc_period_len});
	my $start_crc_period = $period_end;
	my $end_crc_period = add_months_to_date($start_crc_period, $params->{crc_period_len});
	
	my $start_fobt_exclude_period = add_months_to_date($period_start, - $params->{fobt_period_len});
	my $end_fobt_exclude_period = $period_start;
	my $start_clnscpy_exclude_period = add_months_to_date($period_start, - $params->{clnscpy_period_len});
	my $end_clnscpy_exclude_period = $period_start;
	
	print STDERR "Working on CBC period from $period_start until $period_end, CRC period from $start_crc_period until $end_crc_period, FOBT exclude period from $start_fobt_exclude_period to $end_fobt_exclude_period, Colonoscopy exclude period from $start_clnscpy_exclude_period to $end_clnscpy_exclude_period\n";
	
	$pred_fh->seek($pred_file_pos, 0);
	my $has_out_record = {};
	while (<$pred_fh>) {
		chomp;
		my @F = split;
		my ($id, $date, $score) = ($F[0], $F[1], $F[2]);
		
		if ($date < $period_start) { # no further work in this period, due to reverse sorting of dates
			print STDERR "Date for record $_ is $date, moving to an earlier period\n";
			last;
		}
		next unless ($date < $period_end);
		
		print STDERR "Date $date is in period\n";
		$pred_file_pos = $pred_fh->tell;
		
		if (exists $has_out_record->{$id}) {
			print STDERR "Skipping record $_ as a record for $id was already written\n";
		}
		next if (exists $has_out_record->{$id});
		
		if (exists $reg_info->{$id} and ! exists $eff_crc_month->{$id}) {
			print STDERR "Skipping record $_ as $id had a previous other type of cancer\n";
		}
		next if (exists $reg_info->{$id} and ! exists $eff_crc_month->{$id});
		
		my $dob = $dmg_info->{$id}{yob} * 10000 + 701; # date of birth is set to the middle of year of birth
		my $age_at_cbc = int(($date - $dob) / 10000);
		if ($age_at_cbc < $params->{min_age} or $age_at_cbc > $params->{max_age}) {
			print STDERR "Skipping record $_ as $id (born in $dob) is $age_at_cbc at time of CBC and is out of range\n";
		}
		next if ($age_at_cbc < $params->{min_age} or $age_at_cbc > $params->{max_age});
		
		# drop patients with CRC outside of the current CRC period
		next if (exists $eff_crc_month->{$id} and
						($eff_crc_month->{$id} <  $start_crc_period or 
						$eff_crc_month->{$id} >= $end_crc_period));
						
		# drop patients who had FOBT not too long before the CBC period
		my $did_fobt = 0;
		if (exists $fobt_dates->{$id}) {
			map {$did_fobt = 1 if ($_ > $start_fobt_exclude_period and $_ < $end_fobt_exclude_period)} @{$fobt_dates->{$id}};
		}
		print STDERR  "Skipping record $_ as $id had FOBT prior to $period_start; FOBT dates: " . join(", ", @{$fobt_dates->{$id}}) . "\n" if ($did_fobt == 1);
		next if ($did_fobt == 1);
		
		# drop patients who had colonscopy several years before the CBC period
		my $did_clnscpy = 0;
		if (exists $clnscpy_dates->{$id}) {
			map {$did_clnscpy = 1 if ($_ > $start_clnscpy_exclude_period and $_ < $end_clnscpy_exclude_period)} @{$clnscpy_dates->{$id}};
		}
		print STDERR  "Skipping record $_ as $id had colonscopy prior to $period_start; colonscopy dates: " . join(", ", @{$clnscpy_dates->{$id}}) . "\n" if ($did_clnscpy == 1);
		next if ($did_clnscpy == 1);
		
		# writing score and label to output
		my $label = 0;
		$label = 1 if (exists $eff_crc_month->{$id} and
						$eff_crc_month->{$id} >= $start_crc_period and 
						$eff_crc_month->{$id} < $end_crc_period);
		print join("\t", $period_start, $id, $score, $label) . "\n";
		$has_out_record->{$id} = 1;
	}
}

