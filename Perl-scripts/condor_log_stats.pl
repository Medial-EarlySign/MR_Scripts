#!/usr/bin/env perl 

my @days2month = (0,31,59,90,120,151,181,212,243,273,304,334) ;
my %hosts = ("192.168.1.102" => Condor2,
			   "192.168.1.101" => Condor1,
			   "192.168.1.1" => PC1,
			   "192.168.1.2" => Server,
			   "192.168.1.3" => PC3,
			   "192.168.1.4" => PC4,
			   "192.168.1.5" => PC5,
			   ) ;

use strict(vars) ;

die "Usage: condor_log_stats condor_file [-a]" if (@ARGV != 2 and @ARGV != 1) ;
my ($file,$all) ;
if (@ARGV == 1) {
	$all = 0 ;
	$file = $ARGV[0] ;
} else {
	$all = 1 ;
	if ($ARGV[0] eq "-a") {
		$file = $ARGV[1] ;
	} elsif ($ARGV[1] eq "-a") {
		$file = $ARGV[0] ;
	} else {
		die "Usage: condor_log_stats condor_file [-a]" ;
	}
}

open (IN,$file) or die "Cannot open $file for reading" ;

my %summary ;
while (<IN>) {
	if (/000 \((\S+)\) (\S+) (\S+) Job submitted from host: <(\S+)>/) {
		my ($process,$date,$time,$ip) = ($1,$2,$3,$4) ;
		my ($submission,$pid)  = split /\./,$process ;
		$summary{$submission}->{$pid}->{sub} = {from => $ip, at => get_time($date,$time)} ;
	} elsif (/001 \((\S+)\) (\S+) (\S+) Job executing on host: <(\S+)>/) {
		my ($process,$date,$time,$ip) = ($1,$2,$3,$4) ;
		my ($submission,$pid)  = split /\./,$process ;
		$summary{$submission}->{$pid}->{exe} = {in => $ip, at => get_time($date,$time)} ;		
	} elsif (/005 \((\S+)\) (\S+) (\S+) Job terminated/) {
		my ($process,$date,$time) = ($1,$2,$3) ;
		my ($submission,$pid)  = split /\./,$process ;
		$summary{$submission}->{$pid}->{term} = {at => get_time($date,$time)} ;
	} elsif (/009 \((\S+)\) (\S+) (\S+) Job was aborted by the user/) {
		my ($process,$date,$time) = ($1,$2,$3) ;
		my ($submission,$pid)  = split /\./,$process ;
		$summary{$submission}->{$pid}->{abort} = {at => get_time($date,$time)} ;
	}
}

my @submissions = sort {$a<=>$b} keys %summary;
@submissions = (pop @submissions) unless ($all) ;

my %summary_per_ip ;
my %summary_per_sub ;
my %summary_all ;

foreach my $submission (@submissions) {
	foreach my $pid (sort {$a<=>$b} keys %{$summary{$submission}}) {
		$summary_all{nsub} ++ ;
		$summary_per_sub{$submission}->{nsub} ++ ;
				
		if (exists $summary{$submission}->{$pid}->{exe}) {
			$summary_all{nexe} ++ ;
			$summary_per_sub{$submission}->{nexe}++ ;
			$summary_per_ip{$summary{$submission}->{$pid}->{exe}->{in}}->{nexe} ++ ;
			
			$summary_all{start} = $summary{$submission}->{$pid}->{exe}->{at} 
				if (! exists $summary_all{start} or $summary{$submission}->{$pid}->{exe}->{at} < $summary_all{start});
			$summary_per_sub{$submission}->{start} = $summary{$submission}->{$pid}->{exe}->{at} 
				if (! exists $summary_per_sub{$submission}->{start} or $summary{$submission}->{$pid}->{exe}->{at} < $summary_per_sub{$submission}->{start}) ;
			
			if (exists $summary{$submission}->{$pid}->{term}) {
				$summary_all{nterm} ++ ;
				$summary_per_sub{$submission}->{nterm} ++ ;
				$summary_per_ip{$summary{$submission}->{$pid}->{exe}->{in}}->{nterm} ++ ;
				
				my $time = ($summary{$submission}->{$pid}->{term}->{at} - $summary{$submission}->{$pid}->{exe}->{at}) ;
				if ($time < 0) {
					print STDERR "Running Time < 0 . Assuming we crossed a year bound ...\n" ;
					$time += 365*24*60*60 ;
					die " -- Didn't help. still at $time" if ($time < 0) ;
				}
				$summary_per_sub{$submission}->{tot_time} += $time ;
				$summary_per_ip{$summary{$submission}->{$pid}->{exe}->{in}}->{tot_time} += $time ;	
				$summary_all{tot_time} += $time ;
				
				$summary_per_sub{$submission}->{max_time} = $time if (!exists $summary_per_sub{$submission}->{max_time} or $summary_per_sub{$submission}->{max_time} < $time);
				$summary_per_ip{$summary{$submission}->{$pid}->{exe}->{in}}->{max_time} = $time 
							if (!exists $summary_per_ip{$summary{$submission}->{$pid}->{exe}->{in}}->{max_time} or $summary_per_ip{$summary{$submission}->{$pid}->{exe}->{in}}->{max_time} < $time);
				$summary_all{max_time} = $time if (!exists $summary_all{max_time} or $summary_all{max_time} < $time) ;
				
				$summary_all{end} = $summary{$submission}->{$pid}->{term}->{at} 
					if (! exists $summary_all{end} or $summary{$submission}->{$pid}->{term}->{at} > $summary_all{end});
				$summary_per_sub{$submission}->{end} = $summary{$submission}->{$pid}->{term}->{at} 
					if (! exists $summary_per_sub{$submission}->{end} or $summary{$submission}->{$pid}->{term}->{at} > $summary_per_sub{$submission}->{end}) ;
				
			} elsif (exists $summary{$submission}->{$pid}->{abort}) {
				$summary_all{nabort} ++ ;
				$summary_per_sub{$submission}->{nabort} ++ ;
				$summary_per_ip{$summary{$submission}->{$pid}->{exe}->{in}}->{nabort} ++ ;	
			}
		}
	}
}

my $mean_time = ($summary_all{nterm}) ? $summary_all{tot_time} / $summary_all{nterm}  : -1 ;
$summary_all{nsum} += 0 ;
$summary_all{nexe} += 0 ;
$summary_all{nterm} += 0 ;
$summary_all{nabort} += 0 ;
printf "Total : $summary_all{nsub} Sumbitted. $summary_all{nexe} Executed. $summary_all{nterm} Terminated at mean execution time = %.2f secs. $summary_all{nabort} Aborted\n",$mean_time ;

foreach my $submission (@submissions) {
	my $rec = $summary_per_sub{$submission} ;
	$rec->{nsum} += 0 ;
	$rec->{nexe} += 0 ;
	$rec->{nterm} += 0 ;
	$rec->{nabort} += 0 ;
	my $mean_time = ($rec->{nterm}) ? $rec->{tot_time} / $rec->{nterm} : -1 ;
	my $max_time = ($rec->{nterm}) ? $rec->{max_time} : -1 ;
	printf "Sumbission $submission : $rec->{nexe} Executed. $rec->{nterm} Terminated at mean execution time = %.2f secs (Max = %.2f secs). $rec->{nabort} Aborted\n",$mean_time,$max_time;

	if ($rec->{nterm} == $rec->{nexe}) {
		my $total_time = $summary_per_sub{$submission}->{end} - $summary_per_sub{$submission}->{start} ;
		printf "\t\tTotal Run Time = $total_time secs\n" ;
	}
}

foreach my $ip (sort keys %summary_per_ip) {
	my $host = $ip ;
	if (exists $hosts{$ip}) {
		$host = $hosts{$ip} ;
	} elsif ($ip =~ /(\S+):\S+/ and exists $hosts{$1}) {
		$host = $hosts{$1} ;
	} 

	my $rec = $summary_per_ip{$ip} ;
	my $mean_time = ($rec->{nterm}) ? $rec->{tot_time} / $rec->{nterm} : -1 ;
	$rec->{nsum} += 0 ;
	$rec->{nexe} += 0 ;
	$rec->{nterm} += 0 ;
	$rec->{nabort} += 0 ;
	my $mean_time = ($rec->{nterm}) ? $rec->{tot_time} / $rec->{nterm} : -1 ;
	printf "Host $host : $rec->{nexe} Executed. $rec->{nterm} Terminated at mean execution time = %.2f secs. $rec->{nabort} Aborted\n",$mean_time ;
}

##################################################

sub get_time {
	my ($date,$time) = @_ ;
	
	my ($month,$day) = split /\//,$date ;
	my ($hour,$minute,$second) = split ":",$time ;
	$month *= 1 ;
	
	my $days = $days2month[$month] + $day ;
	my $nsec = $second + 60*$minute + 60*60*$hour + 60*60*24*$days ;
	
	return $nsec ;
}
	
		
