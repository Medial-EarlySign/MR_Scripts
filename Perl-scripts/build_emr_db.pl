#!/usr/bin/env perl 
use strict;
use Getopt::Long;
use FileHandle;
use DBI;

my $user;

BEGIN {
die "Unsupported operating system name: $^O" unless ($^O eq "MSWin32" or $^O eq "linux");
$user = `whoami`; chomp $user;
print STDERR "User $user is invoking script $0 on a $^O machine\n";
}

use strict;
use lib "//nas1/UsersData/$user/MR/Projects/Scripts/Perl-modules" ;

use MedialUtils;

### functions ###
sub std_path {
    my $net_drives = {"//server/work" => "W:", 
			  "//server/data" => "T:",
			  "//server/UsersData" => "U;",
			  "//server/products" => "P:",
			  "//server/temp" => "X:",
    };

    my ($in_path) = @_;
    my $out_path = $in_path;		      

    $out_path =~ s/\\/\//g;
    for my $d (keys %$net_drives) {
	my $e = (exists $ENV{OS} and $ENV{OS} eq "Windows_NT") ? ($net_drives->{$d}) : ("/cygdrive/" . lc substr($net_drives->{$d}, 0, 1));
	$out_path =~ s/$d/$e/i;
    } 
    print STDERR "Path $in_path converted to $out_path\n";

    return $out_path;
}

sub std_slash_ddmmyyyy_date {
    my ($date_str) = @_;

    if ($date_str =~ m/\-/) {
	$date_str =~ s/ .*//;
	$date_str = join("/", reverse split(/\-/, $date_str));
    }
    my $res = join("", reverse split(/\//, $date_str));
    die "$date_str => $res" unless ($res =~ m/^\d{8}$/);
    return $res;
}

sub init_db_handle {
	my ($database) = @_;
	
	my $driver   = "SQLite";
	my $dsn = "DBI:$driver:dbname=$database";
	my $userid = "";
	my $password = "";
	my $dbh = DBI->connect($dsn, $userid, $password, { RaiseError => 1 })
							or die $DBI::errstr;
	print STDERR "Opened database $database successfully\n";
	return $dbh;
}

sub prep_sql_stmt {
	my ($dbh, $stmt) = @_;
	print STDERR "Executing SQL statement:\n$stmt\n";
	
	my $start = time();
	my $sth = $dbh->prepare($stmt) or die $DBI::errstr;
#	my $rv = $sth->execute() or die $DBI::errstr;
# printf STDERR "SQL statment was executed in %d seconds.\n", time() - $start;
	return $sth;
}

sub do_sql_stmt {
	my ($dbh, $stmt) = @_;
	print STDERR "Doing SQL statement:\n$stmt\n";
	
	my $start = time();
	$dbh->do($stmt) or die $DBI::errstr;
	
	printf STDERR "SQL statment was done in %d seconds.\n", time() - $start;
	return 0;
}

sub scan_rows {
	my ($sth, $prt) = @_;
	
	my $start = time();
	my $rownum = 0;
	while(my @row = $sth->fetchrow_array()) {
		my ($src, $id, $lab_date, $age_group, $gender, $cancer_diff_group, $icd9_group, $stage_group, $val, $lab) = @row;
		$rownum ++;
		print STDERR join("\t", @row) . "\n" if ($prt);
		print STDERR "Scanned $rownum rows ...\n" if ($rownum % 1000000 == 0);
	}
	printf STDERR "Total of $rownum rows were scanned in %d seconds.\n", time() - $start;
	
	return $rownum;
}

sub process_one_lab_test_file {
    my ($path, $type, $ins_sth) = @_;

    my ($colId, $colDate, $colCode, $colVal) = ($type eq "cbc") ?
	(0, 3, 2, -1) : (2, -3, -2, -1);

    my $fh = MedialUtils::open_file(std_path($path), "r");
    my $nline = 0;
    while (<$fh>) {
	next if (m/RANDOM_ID/); # header line
	chomp;
	my @F = split(/\t/);
	die "Bad date-time format: $_, date string is $F[$colDate]" unless ($F[$colDate] =~ m/^\d{8}$/);
	$ins_sth->execute(@F[($colId, $colDate, $colCode, $colVal)]);
	print STDERR "Inserted $. records ...\n" if ($. % 3000000 == 0);
	$nline ++;
    }
    $fh->close;

    return $nline;
}

### main ###
my $p = {
	db_file => "emr_db.sl3",
	config_file => "/cygdrive/w/CancerData/BinFiles/MHS/MHS_OCT2014/mhs_23dec2014_combined_cfg_file.condor.txt",
	pat_info_file => "/cygdrive/w/CRC/Maccabi_JUL2014/RcvdDataUnzipped/StatusCustomer_ASCII.txt",
	mem_db => 0,
	write_mem_db_to_file => 0,
	cache_size => 800000,
	skip_ins_val => 0,
	skip_ins_pat => 0,
};
	
GetOptions($p,
	   "db_file=s",      # database file
	   "config_file=s",  # configuration file with types and paths of raw input files 
	   "pat_info_file=s", # patient information file
	   "mem_db",         # flag if to build database in memory
	   "write_mem_db_to_file",   # flag if to write memory database to disk
	   "cache_size=i",   # database cache size
	   "skip_ins_val",   # skip insertion of raw lab test values   
	   "skip_ins_pat",   # skipe insertion of patient info records
);
	
print STDERR "Command line: $0 " . join(" ", @ARGV) . "\n";	
print STDERR "Parameters: " . join(", ", map {"$_ => $p->{$_}"} sort keys %$p) . "\n";

# initialize database handle
my $dbh = ($p->{mem_db}) ? init_db_handle(":memory:") : init_db_handle($p->{db_file});
do_sql_stmt($dbh, "pragma cache_size = $p->{cache_size};");
	
# create a table for raw lab test values and insert records from text files listed in config file

if (not $p->{skip_ins_val}) {
    do_sql_stmt($dbh, "create table rawVals (uid int primary key autoincrement, 
                                         patUid int, 
                                         date int, 
                                         labCode int, 
                                         rawVal real);");	


    my $ins_sth = prep_sql_stmt($dbh, "insert into rawVals (patUid, date, labCode, rawVal) values(?, ?, ?, ?)");

    my $start_ins_val = time();
    my $cfg_fh = MedialUtils::open_file($p->{config_file}, "r");
    while (<$cfg_fh>) {
	next if (m/^#/); # comment line
	chomp;
	my ($type, $path) = split;
	next unless ($type eq "cbc" or $type eq "biochem");
	print STDERR "Processing raw lab test file $path of type $type ...\n";
	$dbh->begin_work() or die $DBI::errstr;
	my $start_ins_file = time();
	my $nlines = process_one_lab_test_file($path, $type, $ins_sth);
	$dbh->commit() or die $DBI::errstr;
	printf STDERR "Inserted $nlines records from file $path ($type) in %d seconds.\n", time() - $start_ins_file; 
    }
    printf STDERR "Lab test records were inserted in %d seconds.\n", time() - $start_ins_val;
} # skip_ins_val

# read patient information file and insert into patInfo table
if (not $p->{skip_ins_pat}) {
    do_sql_stmt($dbh, "create table patInfo (uid integer primary key autoincrement, 
                                         patUid int, 
                                         birthDate int, 
                                         gender text, 
                                         mhsStatusCode int,
                                         mhsReasonCode int,
                                         mhsStatusDate int,
                                         deathDate int,
                                         mhsBranchCode int,
                                         mhsDistrictCode int);");	

    my $pat_sth = prep_sql_stmt($dbh, "insert into patInfo (patUid, birthDate, gender, mhsStatusCode, mhsReasonCode, mhsStatusDate, deathDate, mhsBranchCode, mhsDistrictCode) values(?, ?, ?, ?, ?, ?, ?, ?, ?)");

    my $start_ins_pat = time();
    my $pat_fh = MedialUtils::open_file(std_path($p->{pat_info_file}), "r");
    
    $dbh->begin_work() or die $DBI::errstr;
    my $start_ins_pat = time();
    my $npat = 0;
    while (<$pat_fh>) {
	next if (m/RANDOM_ID/); # header line
	chomp;
	my @F = split(/\t/);
	my ($id, $bdate, $age, $sex, $status, $reason, $sdate, $ddate, $branch, $district) = @F;	
	($bdate, $sdate, $ddate) = 
	    map {std_slash_ddmmyyyy_date($_)} ($bdate, $sdate, $ddate);
	$pat_sth->execute($id, $bdate, $sex, $status, $reason, $sdate, $ddate, 
			  $branch, $district);
	print STDERR "Inserted $. patients ...\n" if ($. % 500000 == 0);
	$npat ++;
    }
    $dbh->commit() or die $DBI::errstr;
    $pat_fh->close;
    
    printf STDERR "$npat patient records were inserted in %d seconds.\n", time() - $start_ins_pat;
} # skip_ins_pat

# index	tables by patUid
my $start_idx_pat = time();
do_sql_stmt($dbh, "create unique index patInfo_patUid_idx on patInfo (patUid);");
do_sql_stmt($dbh, "create index rawVals_patUid_idx on rawVals (patUid);");

	
# write final database to disk, if required	
if ($p->{mem_db} and $p->{write_mem_db_to_file}) {
	my $start_write = time();
	$dbh->sqlite_backup_to_file($p->{db_file}) or die $DBI::errstr;
	printf STDERR "In-memory database was written to disk in %d seconds.\n", time() - $start_write;
}

$dbh->disconnect;

	
