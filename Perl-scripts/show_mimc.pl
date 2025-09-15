#!/usr/bin/env perl 

# Show full info for a mimic ID

die "Usage : $0 ICUSTAY_ID" if (@ARGV != 1) ;

my $icuStayID = $ARGV[0] ;
print STDERR "Working on ICUSTAY ID $icuStayID\n" ;

# Get SUBJECTID
my $transFile = "//server/Work/Users/yaron/ICU/Mimic/ParseData/ICUSTAYEVENTS" ;
open (IN,$transFile) or die "Cannot open $transFile for reading" ;

my $subjectID ;
while (<IN>) {
	my ($subject,$stay) = split ",",$_ ;
	if ($stay == $icuStayID) {
		$subjectID = $subject ;
		last ;
	}
}
close IN ;

die "Cannot find Subject ID for ICUSTAY ID $icuStayID" if (! defined $subjectID) ;
print STDERR "Subject ID is $subjectID\n" ;

# Read All Maps
my $mapDir = "//server/Work/ICU/Mimic/Definitions/" ;
my %mapFiles = (CareGivers => "D_CAREGIVERS.txt", ChartItems => "D_CHARTITEMS.txt", IOItems => "D_IOITEMS.txt", MedItems => "D_MEDITEMS.txt", CodeItems => "D_CODEDITEMS.txt", LabItems => "D_LABITEMS.txt") ;

my %maps ;
foreach my $map (keys %mapFiles) {
	my $file = "$mapDir/$mapFiles{$map}" ;
	open (IN,$file) or die "Cannot open $file for reading" ;
	
	while (<IN>) {
		chomp ;
		my ($code,@line) = split /\,/,$_ ;
		$maps{$map}->{$code} = join "/",@line ;
	}
	
	close IN ;
}
		

# Read All Data Files
my $fullID = sprintf("%05d",$subjectID) ;
my $dir = substr($fullID,0,2) ;
my $fullDir = "//server/Work/ICU/Mimic/$dir/$fullID" ;

# ICU STAY DETAILS
my $file = "$fullDir/ICUSTAY_DETAIL-$fullID.txt" ;
open (IN,$file) or die "Cannot open $file for reading" ;

my %cols ;
my $hadmID ;
while (<IN>) {
	chomp ;
	my @data = split ",",$_ ;
	if (! %cols) {
		map {$cols{$data[$_]} = $_} (0..$#data) ;
	} else {
		if ($data[$cols{ICUSTAY_ID}] == $icuStayID) {
			$hadmID = $data[$cols{HADM_ID}] ;
			print STDERR "admission ID is $hadmID\n" ;
			map {print "$_ $data[$cols{$_}]\n" if ($_ !~ /_ID$/)} keys %cols ;
		}
	}
}
close IN ;

# Demographics
my $file = "$fullDir/DEMOGRAPHIC_DETAIL-$fullID.txt" ;
open (IN,$file) or die "Cannot open $file for reading" ;

%cols = ();
my $hadmCol ;
while (<IN>) {
	chomp ;
	my @data = split ",",$_ ;
	if (! %cols) {
		for my $i (0..$#data) {
			$cols{$1} = $i if ($data[$i] =~ /(\S+)_DESCR/) ;
			$hadmCol = $i if ($data[$i] eq "HADM_ID") ;
		}
	} elsif ($data[$hadmCol] == $hadmID) {
		map {print "$_ $data[$cols{$_}]\n"} keys %cols ;
	}
}
close IN ;

# Comorbidities
my $file = "$fullDir/COMORBIDITY_SCORES-$fullID.txt" ;
open (IN,$file) or die "Cannot open $file for reading" ;

%cols = ();
while (<IN>) {
	chomp ;
	my @data = split ",",$_ ;
	if (! %cols) {
		for my $i (0..$#data) {
			$cols{$i} = $data[$i] ;
			$hadmCol = $i if ($data[$i] eq "HADM_ID") ;
		}
	} elsif ($data[$hadmCol] == $hadmID) {
		map {print "CoMorbidity : $cols{$_}\n" if ($data[$_] > 0)} (3..$#data) ;
	}
}
close IN ;

# ICD9
my $file = "$fullDir/ICD9-$fullID.txt" ;
open (IN,$file) or die "Cannot open $file for reading" ;

%cols = ();
while (<IN>) {
	chomp ;
	my @data = split ",",$_ ;
	if (! %cols) {
		map {$cols{$data[$_]} = $_} (0..$#data) ;
	} elsif ($data[$cols{HADM_ID}] == $hadmID) {
		print "ICD9 : ".$data[$cols{DESCRIPTION}]."\n" ;
	}
}
close IN ;

# Desiease-Related-Group Events
my $file = "$fullDir/DRGEVENTS-$fullID.txt" ;
open (IN,$file) or die "Cannot open $file for reading" ;

%cols = ();
while (<IN>) {
	chomp ;
	my @data = split ",",$_ ;
	if (! %cols) {
		map {$cols{$data[$_]} = $_} (0..$#data) ;
	} elsif ($data[$cols{HADM_ID}] == $hadmID) {
		my $itemID = $data[$cols{ITEMID}] ;
		die "Cannot find itemID $itemID" if (! exists $maps{CodeItems}->{$itemID}) ;
		my $item = $maps{CodeItems}->{$itemID} ;
		
		print "DRG Event : $item\n"
	}
}
close IN ;

my @events ;
# LabEvents
my $file = "$fullDir/LABEVENTS-$fullID.txt" ;
open (IN,$file) or die "Cannot open $file for reading" ;

%cols = ();
while (<IN>) {
	chomp ;
	my @data = split ",",$_ ;
	if (! %cols) {
		map {$cols{$data[$_]} = $_} (0..$#data) ;
	} elsif ($data[$cols{HADM_ID}] == $hadmID) {
		my $itemID = $data[$cols{ITEMID}] ;
		die "Cannot find LabItem $itemID" if (! exists $maps{LabItems}->{$itemID}) ;
		my $item = $maps{LabItems}->{$itemID} ;
		push @events,[$data[$cols{CHARTTIME}],"LAB: $item=".$data[$cols{VALUE}]] ;
	}
}
close IN ;

# ChartEvents
my $file = "$fullDir/CHARTEVENTS-$fullID.txt" ;
open (IN,$file) or die "Cannot open $file for reading" ;

%cols = ();
while (<IN>) {
	chomp ;
	my @data = split ",",$_ ;
	if (! %cols) {
		map {$cols{$data[$_]} = $_} (0..$#data) ;
	} elsif ($data[$cols{ICUSTAY_ID}] == $icuStayID) {
		my $itemID = $data[$cols{ITEMID}] ;
		die "Cannot find ChartItem $itemID" if (! exists $maps{ChartItems}->{$itemID}) ;
		my $item = $maps{ChartItems}->{$itemID} ;
		my $value1 = ($data[$cols{VALUE1NUM}] ne "") ? $data[$cols{VALUE1NUM}] : $data[$cols{VALUE1}] ;
		my $value2 = ($data[$cols{VALUE2NUM}] ne "") ? $data[$cols{VALUE2NUM}] : $data[$cols{VALUE2}] ;

		if ($value2 eq "") {
			push @events,[$data[$cols{CHARTTIME}],"CHART: $item=$value1"] ;
		} else {
			push @events,[$data[$cols{CHARTTIME}],"CHART: $item=$value1/$value2"] ;
		}

	}
}
close IN ;

# IOEvents
my $file = "$fullDir/IOEVENTS-$fullID.txt" ;
open (IN,$file) or die "Cannot open $file for reading" ;

%cols = ();
while (<IN>) {
	chomp ;
	my @data = split ",",$_ ;
	if (! %cols) {
		map {$cols{$data[$_]} = $_} (0..$#data) ;
	} elsif ($data[$cols{ICUSTAY_ID}] == $icuStayID) {
		my $itemID = $data[$cols{ITEMID}] ;
		die "Cannot find IOItem $itemID" if (! exists $maps{IOItems}->{$itemID}) ;
		my $item = $maps{IOItems}->{$itemID} ;
		push @events,[$data[$cols{CHARTTIME}],"IO: $item=".$data[$cols{VOLUME}]] ;
	}
}
close IN ;

# MedEvents
my $file = "$fullDir/MEDEVENTS-$fullID.txt" ;
open (IN,$file) or die "Cannot open $file for reading" ;

%cols = ();
while (<IN>) {
	chomp ;
	my @data = split ",",$_ ;
	if (! %cols) {
		map {$cols{$data[$_]} = $_} (0..$#data) ;
	} elsif ($data[$cols{ICUSTAY_ID}] == $icuStayID) {
		my $itemID = $data[$cols{ITEMID}] ;
		die "Cannot find MedItem $itemID" if (! exists $maps{MedItems}->{$itemID}) ;
		my $item = $maps{MedItems}->{$itemID} ;
		
		my $solutionID = $data[$cols{SOLUTIONID}] ;
		die "Cannot find MedItem $itemID" if (! exists $maps{MedItems}->{$solutionID}) ;
		my $solution = $maps{MedItems}->{$solutionID} ;	
		
		my $info = "$item (".$data[$cols{DOSE}].",$solution)" ;
		push @events,[$data[$cols{CHARTTIME}],"MED: $info"] ;
	}
}
close IN ;

# Microbiology
my $file = "$fullDir/MICROBIOLOGYEVENTS-$fullID.txt" ;
open (IN,$file) or die "Cannot open $file for reading" ;

%cols = ();
while (<IN>) {
	chomp ;
	my @data = split ",",$_ ;
	if (! %cols) {
		map {$cols{$data[$_]} = $_} (0..$#data) ;
	} elsif ($data[$cols{HADM_ID}] == $hadmID) {
		my $id1 = $data[$cols{SPEC_ITEMID}] ;
		die "Cannot find CodeItem $id1" if (! exists $maps{CodeItems}->{$id1}) ;
		my $item1 = $maps{CodeItems}->{$id1} ;
		
		my $id2 = $data[$cols{ORG_ITEMID}] ;
		die "Cannot find CodeItem $id1" if (! exists $maps{CodeItems}->{$id2}) ;
		my $item2 = $maps{CodeItems}->{$id2} ;

		my $id3 = $data[$cols{AB_ITEMID}] ;
		die "Cannot find CodeItem $id1" if (! exists $maps{CodeItems}->{$id3}) ;
		my $item3 = $maps{CodeItems}->{$id3} ;		

		my $item = "$item1/$item2/".$data[$cols{ISOLATE_NUM}]."/$item3" ;
		my $value = join ",", map {$data[$cols{$_}]} qw/DILUTION_COMPARISON DILUTION_AMOUNT INTERPRETATION/ ;
		
		push @events,[$data[$cols{CHARTTIME}],"MICROB: $item= $value"] ;
	}
}
close IN ;

# Additives
my $file = "$fullDir/ADDITIVES-$fullID.txt" ;
open (IN,$file) or die "Cannot open $file for reading" ;

%cols = ();
while (<IN>) {
	chomp ;
	my @data = split ",",$_ ;
	if (! %cols) {
		map {$cols{$data[$_]} = $_} (0..$#data) ;
	} elsif ($data[$cols{ICUSTAY_ID}] == $icuStayID) {
		my $itemID = $data[$cols{ITEMID}] ;
		die "Cannot find MedItem $itemID" if (! exists $maps{MedItems}->{$itemID}) ;
		my $item = $maps{MedItems}->{$itemID} ;
		
		my $IOItemID = $data[$cols{IOITEMID}] ;
		die "Cannot find IOItems $IOItemID" if (! exists $maps{IOItems}->{$IOItemID}) ;
		my $io = $maps{MedItems}->{$IOItemID} ;	
		
		my $info = "$item/$io ".$data[$cols{AMOUNT}]. "(".$data[$cols{ROUTE}].")" ;
		push @events,[$data[$cols{CHARTTIME}],"ADD: $info"] ;	
	}
}
close IN ;

# Deliveries
my $file = "$fullDir/DELIVERIES-$fullID.txt" ;
open (IN,$file) or die "Cannot open $file for reading" ;

%cols = ();
while (<IN>) {
	chomp ;
	my @data = split ",",$_ ;
	if (! %cols) {
		map {$cols{$data[$_]} = $_} (0..$#data) ;
	} elsif ($data[$cols{ICUSTAY_ID}] == $icuStayID) {
		my $IOItemID = $data[$cols{IOITEMID}] ;
		die "Cannot find IOItems $IOItemID" if (! exists $maps{IOItems}->{$IOItemID}) ;
		my $io = $maps{MedItems}->{$IOItemID} ;	
		
		my $info = "$io ".$data[$cols{RATE}]. "(".$data[$cols{SITE}].")" ;
		push @events,[$data[$cols{CHARTTIME}],"DEL: $info"] ;	
	}
}
close IN ;

# Procedures
my $file = "$fullDir/PROCEDUREEVENTS-$fullID.txt" ;
open (IN,$file) or die "Cannot open $file for reading" ;

%cols = ();
while (<IN>) {
	chomp ;
	my @data = split ",",$_ ;
	if (! %cols) {
		map {$cols{$data[$_]} = $_} (0..$#data) ;
	} elsif ($data[$cols{HADM_ID}] == $hadmID) {
		my $itemID = $data[$cols{ITEMID}] ;
		die "Cannot find itemID $itemID" if (! exists $maps{CodeItems}->{$itemID}) ;
		my $item = $maps{CodeItems}->{$itemID} ;
		
		push @events,[$data[$cols{PROC_DT}],"Procedure: $item"] ;		
	}
}
close IN ;

# Note Events
my $file = "$fullDir/NOTEEVENTS-$fullID.txt" ;
open (IN,$file) or die "Cannot open $file for reading" ;

%cols = ();
my $inside_quat = 0 ;
my $print_data = 0 ;

while (my $line = <IN>) {
	chomp $line ;
	$line .= " " ;
	if (! %cols) {
		my @data = split ",",$line ;
		map {$cols{$data[$_]} = $_} (0..$#data) ;
	} else {
		my @fullData = split /\"/,$line ;
		if (!$inside_quat) {	
			my @data = split ",",$fullData[0] ;
			$print_data = ($data[$cols{HADM_ID}] == $hadmID) ? 1 : 0 ;
			$inside_quat = (scalar(@fullData)%2 == 0) ? 1:0 ;
			
			if ($print_data) {
				my $out = join ",",map {$fullData[$_]} (1..$#fullData) ;
				push @events,[$data[$cols{CHARTTIME}],"\"$out\n"] ;
			}
		} else {
			$events[-1]->[1] .= "$line\n" if ($print_data) ;
			$inside_quat = (scalar(@fullData)%2 == 0) ? 0:1 ;
		}
	}
}
close IN ;

# POE Events
my $file = "$fullDir/POE_ORDER-$fullID.txt" ;
open (IN,$file) or die "Cannot open $file for reading" ;

%cols = ();
while (<IN>) {
	chomp ;
	my @data = split ",",$_ ;
	if (! %cols) {
		map {$cols{$data[$_]} = $_} (0..$#data) ;
	} elsif ($data[$cols{HADM_ID}] == $hadmID) {
		my $info = $data[$cols{MEDICATION}]." (".$data[$cols{START_DT}]." -> ".$data[$cols{STOP_DT}].")" ;
		push @events,[$data[$cols{ENTER_DT}],"POE: $info"] ;		
	}
}
close IN ;

# Print
print "+++++++++++++++\n" ;
foreach my $event (sort {$a->[0] cmp $b->[0]} @events) {
	my @rec = @{$event} ;
	print "@rec\n" ;
}
