#!/usr/bin/env perl 

use strict(vars) ;
use FileHandle ;

# First run: Create file of relevant strings.
# 	analyze_mimic3_notes.pl NotesFile StaysFile AdmissionsFile IdsList > SepsisInNotesFile
# Second run: Analyze File
#	analyze_mimic3_notes.pl NotesFile StaysFile AdmissionsFile IdsList SepsisInNotesFile > Sepsis.Notes

die "Usage : $0 notesFile staysFile AdmissionsFile IdsList [Substrings File]" if (@ARGV != 4 and @ARGV != 5) ;
my ($notesFile,$staysFile,$adminFile, $idsList,$subFile) = @ARGV ;

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

# Read ICU Stays and Admissions
my %origStays ;

open (IN,$staysFile) or die "Cannot open $staysFile for reading" ;
while (<IN>) {
	next if (/SUBJECT/) ;
	my @data = split /\,/,$_ ;
	$origStays{$data[1]}->{$data[2]}->{$data[3]} = {in => getDate($data[9]), out => getDate($data[10]), hadmin => $data[2]} ;
}
close IN ;
print STDERR "Read Stays\n" ;

open (IN,$adminFile) or die "Cannot open $adminFile for reading" ;
my %hadmins ;
while (<IN>) {
	next if (/SUBJECT/) ;
	my @data = split /\,/,$_ ;
	$hadmins{$data[1]}->{$data[2]} = {hin =>getDate($data[3]), hout => getDate($data[4])} ;
}
print STDERR "Read Admissions\n" ;

my %stays ;
foreach my $id (keys %origStays) {
	foreach my $hadmin(keys %{$origStays{$id}}) {
		die "Cannot find hadmin data for $id/$hadmin" if (! exists $hadmins{$id}->{$hadmin}) ;
		foreach my $stay (keys %{$origStays{$id}->{$hadmin}}) {
			map {$stays{$id}->{$stay}->{$_} = $origStays{$id}->{$hadmin}->{$stay}->{$_}} qw/in out hadmin/ ;
			map {$stays{$id}->{$stay}->{$_} = $hadmins{$id}->{$hadmin}->{$_}} qw/hin hout/ ;
		}
	}
}

# Read Notes
my %data ;
if (! $subFile) {
	open (IN,$notesFile) or die "Cannot open $notesFile for reading" ;

	my $idx = 1 ;
	while (<IN>) {
		next if (/SUBJECT/) ;
		chomp; 
		my @data = mySplit($_,"\,") ;

		my ($id,$hadmin,$date,$title,$info) = ($data[1],$data[2],getDate($data[3]),$data[6],lc($data[10])) ;
		next if (! exists $ids{$id}) ;
			
		my $offset = 0 ;
		my $res = get_next_pos($info,$offset) ;

		while($res != -1) {
			my $start = $res - 80 ;
			$start = 0 if ($start < 0) ;
			
			my $string = substr($info,$start,200) ;
			push @{$data{$id}->{$hadmin}->{$idx}->{strings}},$string ;
			$data{$id}->{$hadmin}->{$idx}->{date} = $date ;
			$data{$id}->{$hadmin}->{$idx}->{title} = $title ;
			print "$id\t$hadmin\t$idx\t$date\t$title\t$string\n" ; 
		
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
		my ($id,$hadmin,$idx,$date,$title,$string) = split /\t/,$_ ;
		push @{$data{$id}->{$hadmin}->{$idx}->{strings}},$string ;
		$data{$id}->{$hadmin}->{$idx}->{date} = $date ;
		$data{$id}->{$hadmin}->{$idx}->{title} = $title ;
		
		my @strings = @{$data{$id}->{$hadmin}->{$idx}->{strings}} ;
	}
}
exit() if (! $subFile) ;

my %sepsis ;
my %extraSepsisInfo ;
foreach my $id (keys %data) {
	foreach my $hadmin (keys %{$data{$id}}) {
		foreach my $idx (sort {$a<=>$b} keys %{$data{$id}->{$hadmin}}) {		
			my @strings = @{$data{$id}->{$hadmin}->{$idx}->{strings}} ;
			
			my $onAdmit = isOnAdmit(\@strings) ;
			my $date = $data{$id}->{$hadmin}->{$idx}->{date} ;
			my $title = $data{$id}->{$hadmin}->{$idx}->{title} ;
			my $ruleOut = isRuleOut(\@strings) ;
			my $uroSepsis = isUroSepsis(\@strings) ;
			my $septicEmboli = isSepticEmboli(\@strings) ;
			
			print STDERR "$id/$hadmin/$idx is OnAdmit and RuleOut\n" if ($onAdmit and $ruleOut) ;
			die  "$id/$hadmin/$idx is urosepsis and septic-emboli" if ($uroSepsis and $septicEmboli) ;
			
			my $whatIsIt = "sepsis" ;
			if ($uroSepsis) {
				$whatIsIt = "urosepsis" ;
			} elsif ($septicEmboli) {
				$whatIsIt = "septicEmboli" ;
			}
			
			if ($ruleOut) {
				addInfo($id,$hadmin,$idx,$date,$stays{$id},\%sepsis,\%extraSepsisInfo,"Rule out $whatIsIt") ;			
			} elsif ($onAdmit) {
				addInfo($id,$hadmin,$idx,$date,$stays{$id},\%sepsis,\%extraSepsisInfo,"$whatIsIt on admission") ;
			} else {
				addInfo($id,$hadmin,$idx,$date,$stays{$id},\%sepsis,\%extraSepsisInfo,"$whatIsIt in notes") ;
			}
		}
	}
}

foreach my $id (keys %sepsis) {
	foreach my $stay (keys %{$sepsis{$id}}) {
		foreach my $info (keys %{$sepsis{$id}->{$stay}}) {
			my $date = $sepsis{$id}->{$stay}->{$info} ;
			print "$id\t$stay\t$info\t$date\n" ;
		}
	}
}

foreach my $id (keys %extraSepsisInfo) {
	foreach my $stay (keys %{$extraSepsisInfo{$id}}) {
		foreach my $info (keys %{$extraSepsisInfo{$id}->{$stay}}) {
			if (! exists $sepsis{$id}->{$stay}->{$info}) {
				my $date = $extraSepsisInfo{$id}->{$stay}->{$info} ;
				print "$id\t$stay\t$info:Unmatched Stay\t$date\n" ;
			}
		}
	}
}

######################################
## Function							##
######################################

sub addInfo {
	my ($id,$hadmin,$idx,$date,$idStays,$sepsis,$extraSepsisInfo,$info) = @_ ;
	
	my @matched = matchStays($hadmin,$date,$idStays) ;
	if (@matched == 1 and $idStays->{$matched[0]}->{hadmin} == $hadmin) {
		print STDERR "Success in matching Sepsis info for $id/$hadmin/$idx\n" ;
		my $stay = $matched[0] ;
		$sepsis->{$id}->{$stay}->{$info} = $date if (! exists $sepsis->{$id}->{$stay}->{$info} or  $date < $sepsis->{$id}->{$stay}->{$info} ) ;
	} else {
		print STDERR "Problems in matching Sepsis info for $id/$hadmin/$idx\n" ;
		map {$extraSepsisInfo->{$id}->{$_}->{$info} = $date if (! exists $extraSepsisInfo->{$id}->{$_}->{$info} or  $date < $extraSepsisInfo->{$id}->{$_}->{$info})} @matched ; 
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
	my ($hadmin,$date,$idStays) = @_ ;
	
	my @idStays = keys %$idStays ;
	
	my @stays ;
	# Any stays with matching hadmin AND stayIn-stayOut
	foreach my $stay (@idStays) {
		push @stays,$stay if ($idStays->{$stay}->{hadmin} == $hadmin and $idStays->{$stay}->{in} <= $date and $idStays->{$stay}->{out} >= $date) ;
	}
	
	if (@stays) {
		print STDERR "Found ".(scalar @stays)." perfect matches\n" ;
		return @stays ;
	}
	
	# Any stays with matching stayIn-stayOut
	foreach my $stay (@idStays) {
		push @stays,$stay if ($idStays->{$stay}->{in} <= $date and $idStays->{$stay}->{out} >= $date) ;
	}	
	
	if (@stays) {
		print STDERR "Found ".(scalar @stays)." time matches\n" ;
		return @stays ;
	}
	
	# Any stays with matching hadmin AND hIn/hOut
	foreach my $stay (@idStays) {
		push @stays,$stay if ($idStays->{$stay}->{hadmin} == $hadmin and $idStays->{$stay}->{hin} <= $date and $idStays->{$stay}->{hout} >= $date) ;
	}
	
	if (@stays) {
		print STDERR "Found ".(scalar @stays)." Admin matches\n" ;
		return @stays ;
	}	
	
	# Any stays with matching hIn/hOut
	foreach my $stay (@idStays) {
		push @stays,$stay if ($idStays->{$stay}->{hin} <= $date and $idStays->{$stay}->{hout} >= $date) ;
	}
	
	if (@stays) {
		print STDERR "Found ".(scalar @stays)." Admin time matches\n" ;
		return @stays ;
	}	
	
	# Any stays with matching stayIn-stayOut
	foreach my $stay (@idStays) {
		push @stays,$stay if ($idStays->{$stay}->{in} <= $date and $idStays->{$stay}->{out} >= $date) ;
	}	
	
	if (@stays) {
		print STDERR "Found ".(scalar @stays)." time matches\n" ;
		return @stays ;
	}
	
	# Any stays with matching hadmin AND hIn/hOut + 1 Month
	foreach my $stay (@idStays) {
		push @stays,$stay if ($idStays->{$stay}->{hadmin} == $hadmin and $idStays->{$stay}->{hin} <= $date and $idStays->{$stay}->{hout} + 100 >= $date) ;
	}
	
	if (@stays) {
		print STDERR "Found ".(scalar @stays)." Admin laxmatches\n" ;
		return @stays ;
	}	
	
	# Any stays with matching hIn/hOut + 1 Month
	foreach my $stay (@idStays) {
		push @stays,$stay if ($idStays->{$stay}->{hin} <= $date and $idStays->{$stay}->{hout} + 100 >= $date) ;
	}
	
	if (@stays) {
		print STDERR "Found ".(scalar @stays)." Admin lax time matches\n" ;	
	} else {
		print STDERR "No matches found\n" ;
	}
	
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
		

	
