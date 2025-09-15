#!/usr/bin/env perl 

use strict(vars) ;
use FileHandle ;

# First run: Create file of relevant strings.
# 	analyze_mimic_notes.pl NotesFile StaysFile IdsList > SepsisInNotesFile
# Second run: Analyze File
#	analyze_mimic_notes.pl NotesFile StaysFile IdsList SepsisInNotesFile

die "Usage : $0 notesFile staysFile IdsList [Substrings File]" if (@ARGV != 3 and @ARGV != 4) ;
my ($notesFile,$staysFile,$idsList,$subFile) = @ARGV ;

# Read IdsList
my %ids ;
open (IN,$idsList) or die "Cannot open $idsList for reading" ;
while (<IN>) {
	chomp; 
	$ids{$_} = 1;
}
close IN ;

my $nIds = scalar keys %ids ;
print STDERR "Read $nIds ids\n" ;

# Read ICU Stays
open (IN,$staysFile) or die "Cannot open $staysFile for reading" ;

my %stays ;

while (<IN>) {
	next if (/SUBJECT/) ;
	my @data = split /\,/,$_ ;
	$stays{$data[0]}->{$data[1]} = {hin => getDate($data[13]), hout => getDate($data[14]), in => getDate($data[21]), out => getDate($data[22])} ;
}

# Read Notes
my %data ;
if (! $subFile) {
	open (IN,$notesFile) or die "Cannot open $notesFile for reading" ;

	my $idx = 1 ;
	while (<IN>) {
		chomp; 
		my @data = mySplit($_,"\,") ;

		my ($id,$stay,$time,$title,$info) = ($data[0],$data[2],$data[4],$data[9],lc($data[11])) ;
		$stay = "Missing" if ($stay eq "") ;
		
		next if (! exists $ids{$id}) ;
			
		my $offset = 0 ;
		my $res = get_next_pos($info,$offset) ;

		while($res != -1) {
			my $start = $res - 80 ;
			$start = 0 if ($start < 0) ;
			
			my $string = substr($info,$start,200) ;
			push @{$data{$id}->{$stay}->{$idx}->{strings}},$string ;
			$data{$id}->{$stay}->{$idx}->{time} = $time ;
			$data{$id}->{$stay}->{$idx}->{title} = $title ;
			print "$id\t$stay\t$idx\t$time\t$title\t$string\n" ; 
		
			$offset = $res + 1;
			$res = get_next_pos($info,$offset) ;
		}
		
		$idx ++ ;
	}
	close IN ;
} else {
	open (IN,$subFile) or die "Cannot open $subFile for reading" ;
	while (<IN>) {
		chomp;
		my ($id,$stay,$idx,$time,$title,$string) = split /\t/,$_ ;
		push @{$data{$id}->{$stay}->{$idx}->{strings}},$string ;
		$data{$id}->{$stay}->{$idx}->{time} = getDate($time) ;
		$data{$id}->{$stay}->{$idx}->{title} = $title ;
	}
}
exit() if (! $subFile) ;

my %sepsis ;
my %extraSepsisInfo ;
foreach my $id (keys %data) {
	foreach my $stay (keys %{$data{$id}}) {
		foreach my $idx (sort {$a<=>$b} keys %{$data{$id}->{$stay}}) {
		
			my @strings = @{$data{$id}->{$stay}->{$idx}->{strings}} ;
			my $onAdmit = isOnAdmit(\@strings) ;
			my $time = $data{$id}->{$stay}->{$idx}->{time} ;
			my $title = $data{$id}->{$stay}->{$idx}->{title} ;
			my $ruleOut = isRuleOut(\@strings) ;
			my $uroSepsis = isUroSepsis(\@strings) ;
			my $septicEmboli = isSepticEmboli(\@strings) ;
			
			print STDERR "$id/$stay/$idx is OnAdmit and RuleOut\n" if ($onAdmit and $ruleOut) ;
			die  "$id/$stay/$idx is urosepsis and septic-emboli" if ($uroSepsis and $septicEmboli) ;
			
			my $whatIsIt = "sepsis" ;
			if ($uroSepsis) {
				$whatIsIt = "urosepsis" ;
			} elsif ($septicEmboli) {
				$whatIsIt = "septicEmboli" ;
			}
			
			if ($ruleOut) {
				addInfo($id,$stay,$idx,$time,$stays{$id},\%sepsis,\%extraSepsisInfo,"Rule out $whatIsIt") ;			
			} elsif ($onAdmit) {
				addInfo($id,$stay,$idx,$time,$stays{$id},\%sepsis,\%extraSepsisInfo,"$whatIsIt on admission") ;
			} else {
				addInfo($id,$stay,$idx,$time,$stays{$id},\%sepsis,\%extraSepsisInfo,"$whatIsIt in notes") ;
			}
		}
	}
}

foreach my $id (keys %sepsis) {
	foreach my $stay (keys %{$sepsis{$id}}) {
		foreach my $info (keys %{$sepsis{$id}->{$stay}}) {
			my $time = $sepsis{$id}->{$stay}->{$info} ;
			print "$id\t$stay\t$info\t$time\n" ;
		}
	}
}

foreach my $id (keys %extraSepsisInfo) {
	foreach my $stay (keys %{$extraSepsisInfo{$id}}) {
		foreach my $info (keys %{$extraSepsisInfo{$id}->{$stay}}) {
			if (! exists $sepsis{$id}->{$stay}->{$info}) {
				my $time = $extraSepsisInfo{$id}->{$stay}->{$info} ;
				print "$id\t$stay\t$info:Unmatched Stay\t$time\n" ;
			}
		}
	}
}

######################################
## Function							##
######################################

sub addInfo {
	my ($id,$stay,$idx,$time,$stays,$sepsis,$extraSepsisInfo,$info) = @_ ;
	
	my @matched = matchStays($stay,$time,$stays) ;
	if ($stay ne "Missing") {
		if (@matched == 1 and $matched[0] == $stay) {
			print STDERR "Success in matching Sepsis info for $id/$stay/$idx\n" ;
			$sepsis->{$id}->{$stay}->{$info} = $time if (! exists $sepsis->{$id}->{$stay}->{$info} or  $sepsis->{$id}->{$stay}->{$info} < $time) ;
			last ;
		} else {
			print STDERR "Problems in matching Sepsis info for $id/$stay/$idx\n" ;
			map {$extraSepsisInfo->{$id}->{$_}->{$info} = $time if (! exists $extraSepsisInfo->{$id}->{$_}->{$info} or  $extraSepsisInfo->{$id}->{$stay}->{$_} < $time)} @matched ; 
		}
	} else {
		if (@matched == 1) {
			print STDERR "Success in matching Sepsis info for $id/$stay/$idx\n" ;
			$sepsis->{$id}->{$matched[0]}->{$info} = $time if (! exists $sepsis->{$id}->{$matched[0]}->{$info} or  $sepsis->{$id}->{$matched[0]}->{$info} < $time) ;
		} else {
			print STDERR "Problems in matching Sepsis info for $id/$stay/$idx\n" ;
			map {$extraSepsisInfo->{$id}->{$_}->{$info} = $time if (! exists $extraSepsisInfo->{$id}->{$_}->{$info} or  $extraSepsisInfo->{$id}->{$stay}->{$_} < $time)} @matched ; 			
		}
	}
}

sub isRuleOut {
	my ($strings) = @_ ;
	
	map {return 0 unless  ($_ =~ /r\/o sep/ or $_ =~/rule out sep/)} @$strings ;
	return 1;
}

sub isUroSepsis {
	my ($strings) = @_ ;
	
	foreach my $string (@$strings) {
		my $substr = substr($string,77,9); 
		return 0 if ($substr ne "urosepsis") ;
	}
	return 1 ;
}
	
sub isSepticEmboli {
	my ($strings) = @_ ;
	
	foreach my $string (@$strings) {
		my $substr = substr($string,80,13);
		return 0 if ($substr ne "septic emboli") ;
	}
	return 1 ;
}	
 	
sub isOnAdmit {
	my ($strings) = @_ ;
	
	foreach my $string (@$strings) {
		if ($string =~ /admitting diagnosis:(.*)sepsis.*newline/ and $1 !~ /newline/ and $1 !~ /r\/o/ and $! !~ /rule out/) {
#			print STDERR "Identified admission SEPSIS : $string\n" ;
			return 1 ;
		}
	}

	return 0 ;
}
		
sub matchStays {
	my ($iStay,$time,$stays) = @_ ;
	
	my @idStays = keys %$stays ;
	
	my @stays ;
	if (exists $stays->{$iStay}) {
		print STDERR "trying to match $iStay:$time to  $iStay:$stays->{$iStay}->{in} $stays->{$iStay}->{out}\n" ;
		push @stays,$iStay if ($time >= $stays->{$iStay}->{in} and $time <= $stays->{$iStay}->{out}) ;
	} else { 
		# Single entry and within hospital admission ?
		if (@idStays==1) { 
			print STDERR "trying to match $iStay:$time to  $idStays[0]:$stays->{$idStays[0]}->{in} $stays->{$idStays[0]}->{out} [$idStays[0]:$stays->{$idStays[0]}->{hin} $stays->{$idStays[0]}->{hout}]\n" ;
			push @stays,$idStays[0] if ($stays->{$idStays[0]}->{hin} ne "NONE" and $stays->{$idStays[0]}->{hout} ne "NONE" and $time >= $stays->{$idStays[0]}->{hin} and $time <= $stays->{$idStays[0]}->{hout}) ;
		} else {
			foreach my $stay (keys %$stays) {
				print STDERR "trying to match $iStay:$time to  $stay:$stays->{$stay}->{in} $stays->{$stay}->{out}\n" ;
				push @stays,$stay if ($time >= $stays->{$stay}->{in} and $time <= $stays->{$stay}->{out}) ;
			}
		}
		
		# Nothing : Try hin-hout
		if (! @stays) {
			foreach my $stay (keys %$stays) {
				print STDERR "retrying to match $iStay:$time to  $stay:$stays->{$stay}->{in} $stays->{$stay}->{out} [$stays->{$stay}->{hin} $stays->{$stay}->{hout}]\n" ;
				push @stays,$stay if ($stays->{$stay}->{hin} ne "NONE" and $stays->{$stay}->{hout} ne "NONE" and $time >= $stays->{$stay}->{hin} and $time <= $stays->{$stay}->{hout}) ;
			}
		}
		
		# Nothing : Try hin-hout/out+1Month
		if (! @stays) {
			foreach my $stay (keys %$stays) {
				print STDERR "retrying[2] to match $iStay:$time to  $stay:$stays->{$stay}->{in} $stays->{$stay}->{out} [$stays->{$stay}->{hin} $stays->{$stay}->{hout}]\n" ;
				push @stays,$stay if (($stays->{$stay}->{hin} ne "NONE" and $stays->{$stay}->{hout} ne "NONE" and $time >= $stays->{$stay}->{hin} and $time <= $stays->{$stay}->{hout}+100) or
									  ($time >= $stays->{$stay}->{in} and $time <= $stays->{$stay}->{out}+100)) ;
			}
		}	
	}
	
	print STDERR "-- Found ".(scalar @stays)."\n" ;
	return @stays ;
}

sub getDate {
	my ($in) = @_ ;
	
	if ($in eq "") {
		return "NONE" ;
	} else {
		$in =~ /(\d\d\d\d)-(\d\d)-(\d\d)/ or die "Cannot parse $in" ;
		return "$1$2$3" ;
	}
}

sub mySplit {
	my ($string,$separator) = @_ ;

	my @quotesSeparated = split /\"/,$string ;

	my @out ;
	for my $i (0..$#quotesSeparated) {
		if ($i%2==0) {
			if ($quotesSeparated[$i] ne $separator) {
				$quotesSeparated[$i] =~ s/^$separator// ;
				$quotesSeparated[$i] =~ s/$separator$// ;
				$quotesSeparated[$i] .= ($separator."Dummy") ;
				push @out,(split $separator,$quotesSeparated[$i]) ;
				pop @out ; 
			}
		} else {
			push @out,$quotesSeparated[$i] ;
		}
	}
	
	return @out; 
}
	
sub get_next_pos {
	my($info,$offset) = @_ ;
	
	# Sepsis
	my $res1 = index($info,"sepsis",$offset) ;
	
	# Septic (but not aseptic)
	my $res2 = index($info,"septic",$offset) ;
	$res2 = index($info,"septic",$res2+1)while ($res2 > 0 and substr($info,$res2-1,1) eq "a") ;
	
	if ($res1 == -1) {
		return $res2 ;
	} elsif ($res2 == -1) {
		return $res1 ;
	} else {
		return (($res1 < $res2) ? $res1 : $res2) ;
	}
}
		

	
