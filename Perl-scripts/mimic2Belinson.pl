#!/usr/bin/env perl 

use FileHandle ;
use strict(vars) ;

my $NIDS = 32809 ;
my @days2month = (0,31,59,90,120,151,181,212,243,273,304,334) ;

my @outFiles = qw/M_PatientDemographics M_PatientAdmission M_PatientSignal_IBP M_PatientSignals_medial3group5 M_PatientSignal/ ;
my %reader ;
my %headers ;
my %lookups ;

my $lookupsDir = "W:/ICU/Mimic/Definitions" ;

die "Usage : $0 inDir outDir outFile/ALL [idsList]" if (@ARGV != 3 and @ARGV != 4) ;

my $inDir = shift @ARGV ;
my $outDir = shift @ARGV ;
my $outFile = shift @ARGV ;

my %outFiles ;
if ($outFile eq "ALL") {
	map {$outFiles{$_} = 1} (@outFiles) ;
} else {
	$outFiles{$outFile} = 1 ;
}
	
my %ids ;
readIdsList($ARGV[0],\%ids) if (@ARGV) ;
init_headers() ;

my $nFiles = 0 ;
if (exists $outFiles{M_PatientDemographics}) {
	print STDERR "Handling Demographics\n" ;
	getDemographics($inDir,\%ids,$outDir)  ;
	$nFiles ++ ;
}

if (exists $outFiles{M_PatientAdmission}) {
	print STDERR "Handling Admissions\n" ;
	getAdmission($inDir,\%ids,$outDir)  ;
	$nFiles ++ ;
}

if (exists $outFiles{M_PatientSignal_IBP}) {
	print STDERR "Handling Signals-IBP\n" ;
	getSignalsIBP($inDir,\%ids,$outDir)  ;
	$nFiles ++ ;
}

if (exists $outFiles{M_PatientSignals_medial3group5}) {
	print STDERR "Handling Signals-medial3group5\n" ;
	getSignalsMedial3Group5($inDir,\%ids,$outDir)  ;
	$nFiles ++ ;
}

if (exists $outFiles{M_PatientSignal}) {
	print STDERR "Handling Signal\n" ;
	getSignal($inDir,\%ids,$outDir)  ;
	$nFiles ++ ;
}

die "Cannot Create File $outFile" if ($nFiles == 0) ;


#################################################################
sub getSignalsMedial3Group5 {
	my ($inDir,$ids,$outDir) = @_ ;
		
	open (OUT,">$outDir/M_PatientSignals_medial3group5.txt") or die "Cannot open demographics file \'$outDir/M_PatientSignals_medial3group5.txt\' for writing" ;	
	print OUT "MR_Number\tStay_number\tParameter_name\tSignal_Value\tSignal_Unit\tSignal_Time\n" ;
	
	my @chart_item_recs ;
	my @lab_item_recs ;
	my @io_item_recs ;
	my @icu_detail_recs ;
	
	restart_reader("$inDir/CHARTEVENTS") ;
	restart_reader("$inDir/LABEVENTS") ;
	
	my %labTargetItems = (
					   reverseLookFor("CRP BLOOD CHEMISTRY","D_LABITEMS") => "CReactiveProtein", 
					   reverseLookFor("FIBRINOGE BLOOD HEMATOLOGY 3255-7 Fibrinogen [Mass/volume] in Platelet poor plasma by Coagulation assay","D_LABITEMS") => "Fibrinogen",
					   reverseLookFor("ABS LYMPH BLOOD HEMATOLOGY 26474-7 Lymphocytes [#/volume] in Blood","D_LABITEMS") => "Lymphocytes",
					   reverseLookFor("MONO CT BLOOD HEMATOLOGY 26484-6 Monocytes [#/volume] in Blood","D_LABITEMS") => "Monocytes",
					   reverseLookFor("MONOS BLOOD HEMATOLOGY 26485-3 Monocytes/100 leukocytes in Blood","D_LABITEMS") => "MonocytesPerc",
					   reverseLookFor("ABS RET BLOOD HEMATOLOGY 14196-0 Reticulocytes [#/volume] in Red Blood Cells","D_LABITEMS") => "Reticulocytes",
					   reverseLookFor("RET MAN BLOOD HEMATOLOGY 31112-6 Reticulocytes/100 erythrocytes in Red Blood Cells by Manual","D_LABITEMS") => "ReticulocytesPerc",
					   reverseLookFor("RET AUT BLOOD HEMATOLOGY 17849-1 Reticulocytes/100 erythrocytes in Red Blood Cells by Automated count","D_LABITEMS") => "ReticulocytesPerc",
					   ) ;
					   
	my %chartTargetItems = (	
					   reverseLookFor("Neurologic SOFA Score LCP Calculated SOFA score due to neurologic failure (Glasgow coma score) - by the MIMIC2 team","D_CHARTITEMS") => ["GCS_SOFA",""],
					   reverseLookFor("NBP Mean","D_CHARTITEMS") => ["NIArtPressureMean",""],
					   reverseLookFor("Mech. Minute Volume","D_CHARTITEMS") => ["TotalMinuteVolume",""],
					   reverseLookFor("Minute Volume","D_CHARTITEMS") => ["TotalMinuteVolume",""],
					   reverseLookFor("Minute Volume (Set)","D_CHARTITEMS") => ["TotalMinuteVolume",""],
					   reverseLookFor("Minute Volume(Obser)","D_CHARTITEMS") => ["TotalMinuteVolume",""],
					   reverseLookFor("SaO2 ABG's","D_CHARTITEMS") => ["SaO2Systemic",""],
					   reverseLookFor("SvO2 Mixed Venous Gases","D_CHARTITEMS") => ["VenSaO2Systemic",""],					
					   ) ;

	my %signalUnits = (CReactiveProtein => "mg/dl", Fibrinogen => "mg/dL", Monocytes => "10^9/l", MonocytesPerc => "%", Lymphocytes => "K/micl", Reticulocytes => "K/micl", ReticulocytesPerc => "%",
					   GCS_SOFA => "", SaO2Systemic => "N/A", VenSaO2Systemic => "N/A", TotalMinuteVolume => "L/min", NIArtPressureMean => "mmHg"
					   ) ;
					   
	my %unitsTransformation ;
	$unitsTransformation{CReactiveProtein}->{"mg/l"} = 0.1;
#	$unitsTransformation{Fibrinogen}->{"mg/dl"} = 0.01 ;
	$unitsTransformation{Monocytes}->{"#/ul"} = 0.001 ;
	$unitsTransformation{MonocytesPerc}->{""} = 1.0 ;
	$unitsTransformation{Lymphocytes}->{"#/ul"} = 0.001 ;
	$unitsTransformation{Reticulocytes}->{"/mm3"} = 1 ;
	$unitsTransformation{SaO2Systemic}->{"%"} = 1.0 ;
	$unitsTransformation{VenSaO2Systemic}->{"%"} = 1.0 ;
	
	while (get_next_id("$inDir/LABEVENTS",$ids,\@lab_item_recs)) {
		my $id ;
		my %neutrophilsPercent ;

		# Lab Events
		foreach my $rec (@lab_item_recs) {
			$id = $rec->[$headers{LABEVENTS}->{SUBJECT_ID}] ; 
			my $stayID = $rec->[$headers{LABEVENTS}->{ICUSTAY_ID}] ;
			my $itemID = $rec->[$headers{LABEVENTS}->{ITEMID}] ;
				
			if (exists $labTargetItems{$itemID}) {
				my $time = transformTime($rec->[$headers{LABEVENTS}->{CHARTTIME}]) ;	
				
				my $signalName = $labTargetItems{$itemID} ;
				my $value = $rec->[$headers{LABEVENTS}->{VALUENUM}] ;	
				if ($value ne "") {
					my $unit = lc($rec->[$headers{LABEVENTS}->{VALUEUOM}]) ;
						
					if ($unit ne lc($signalUnits{$signalName})) {
						if (!exists $unitsTransformation{$signalName}->{$unit}) {
							print STDERR "Cannot transform from $signalName unit $unit to $signalUnits{$signalName} at $time/$id\n" 
						} else {
							$value *= $unitsTransformation{$signalName}->{$unit} ;
							print OUT "$id\t$stayID\t$signalName\t$value\t$signalUnits{$signalName}\t$time\n" ;
						}
					} else {
						print OUT "$id\t$stayID\t$signalName\t$value\t$signalUnits{$signalName}\t$time\n" ;
					}
				}
			} 
		}
		
		# Add Chart Events
		get_next_id("$inDir/CHARTEVENTS",$ids,\@chart_item_recs) ;
		
		foreach my $rec (@chart_item_recs) {
			my $current_id = $rec->[$headers{CHARTEVENTS}->{SUBJECT_ID}] ;
			if (defined $id) {
				die "ID inconsistency" if ($current_id != $id) ;
			} else {
				$id = $current_id ;
			}
			
			my $stayID = $rec->[$headers{CHARTEVENTS}->{ICUSTAY_ID}] ;
			my $itemID = $rec->[$headers{CHARTEVENTS}->{ITEMID}] ;
				
			if (exists $chartTargetItems{$itemID}) {
				my $time = transformTime($rec->[$headers{CHARTEVENTS}->{REALTIME}]) ;	
				
				if ($chartTargetItems{$itemID}->[0] ne "") {
					my $signalName = $chartTargetItems{$itemID}->[0] ;
					my $value = $rec->[$headers{CHARTEVENTS}->{VALUE1NUM}] ;

					if ($value ne "") {
						# Correct Non Invasive Arterial Blood Pressure
						if ($signalName eq "NIArtPressureMean") {
							$value = 89.1 + 18.0 * (($value-77.4)/15.3) ;
							print OUT "$id\t$stayID\t$signalName\t$value\t$signalUnits{$signalName}\t$time\n" ;
						} else {
							my $unit = lc($rec->[$headers{CHARTEVENTS}->{VALUE1UOM}]) ;
							
							if ($unit ne lc($signalUnits{$signalName})) {
								if (!exists $unitsTransformation{$signalName}->{$unit}) {
									print STDERR "Cannot transform from $signalName unit $unit to $signalUnits{$signalName} at $time/$id\n" 
								} else {
									$value *= $unitsTransformation{$signalName}->{$unit} ;
									print OUT "$id\t$stayID\t$signalName\t$value\t$signalUnits{$signalName}\t$time\n" ;
								}
							} else {
								print OUT "$id\t$stayID\t$signalName\t$value\t$signalUnits{$signalName}\t$time\n" ;
							}
						}
					}
				}
				
				if ($chartTargetItems{$itemID}->[1] ne "NONE") {
					my $signalName = $chartTargetItems{$itemID}->[1] ;
					my $value = $rec->[$headers{CHARTEVENTS}->{VALUE2NUM}] ;							
					my $unit = lc($rec->[$headers{CHARTEVENTS}->{VALUE2UOM}]) ;
					
					if ($value ne "") {
						if ($unit ne lc($signalUnits{$signalName})) {
							if (!exists $unitsTransformation{$signalName}->{$unit}) {
								print STDERR "Cannot transform from $signalName unit $unit to $signalUnits{$signalName} at $time/$id\n" 
							} else {
								$value *= $unitsTransformation{$signalName}->{$unit} ;
								print OUT "$id\t$stayID\t$signalName\t$value\t$signalUnits{$signalName}\t$time\n" ;
							}
						} else {
							print OUT "$id\t$stayID\t$signalName\t$value\t$signalUnits{$signalName}\t$time\n" ;
						}
					}
				}
			}
		}
	}
	close OUT ;
}

sub getSignal {
	my ($inDir,$ids,$outDir) = @_ ;
	
	open (OUT,">$outDir/M_PatientSignal.txt") or die "Cannot open demographics file \'$outDir/M_PatientSignals_medial3group5.txt\' for writing" ;	
	print OUT "MR_Number\tStay_number\tParameter_name\tSignal_Value\tSignal_Unit\tSignal_Time\n" ;
	
	my @chart_item_recs ;
	my @lab_item_recs ;
	my @io_item_recs ;
	my @icu_detail_recs ;
	
	restart_reader("$inDir/CHARTEVENTS") ;
	restart_reader("$inDir/LABEVENTS") ;
	restart_reader("$inDir/IOEVENTS") ;	
	restart_reader("$inDir/ICUSTAY_DETAIL") ;
	
	my %labTargetItems = (
					   reverseLookFor("WBC BLOOD HEMATOLOGY 26464-8 Leukocytes [#/volume] in Blood","D_LABITEMS") => "WhiteCellCount",
					   reverseLookFor(" WBC BLOOD HEMATOLOGY 26464-8 Leukocytes [#/volume] in Blood","D_LABITEMS") => "WhiteCellCount",
					   reverseLookFor(" LYMPH BLOOD HEMATOLOGY 26478-8 Lymphocytes/100 leukocytes in Blood","D_LABITEMS") => "LymphocytesPercent",
					   reverseLookFor("LYMPHS BLOOD HEMATOLOGY 26478-8 Lymphocytes/100 leukocytes in Blood","D_LABITEMS") => "LymphocytesPercent",		
					   reverseLookFor("ALBUMIN BLOOD CHEMISTRY 1751-7 Albumin [Mass/volume] in Serum or Plasma","D_LABITEMS") => "Albumin",
					   reverseLookFor("TOTAL CO2 BLOOD BLOOD GAS 1959-6 Bicarbonate [Moles/volume] in Blood","D_LABITEMS") => "Bicarbonate",
					   reverseLookFor("TCO2 BLOOD BLOOD GAS 1959-6 Bicarbonate [Moles/volume] in Blood","D_LABITEMS") => "Bicarbonate",
					   reverseLookFor("TOTAL CO2 BLOOD CHEMISTRY 1963-8 Bicarbonate [Moles/volume] in Serum","D_LABITEMS") => "Bicarbonate",
					   reverseLookFor("TOT BILI BLOOD CHEMISTRY 1975-2 Bilirubin [Mass/volume] in Serum or Plasma","D_LABITEMS") => "BilirubinTotal",
					   reverseLookFor("CREAT BLOOD CHEMISTRY 2160-0 Creatinine [Mass/volume] in Serum or Plasma","D_LABITEMS") => "Creatinine",
					   reverseLookFor("HGB BLOOD BLOOD GAS 718-7 Hemoglobin [Mass/volume] in Blood","D_LABITEMS") => "HaemoglobinTotal",
					   reverseLookFor("HGB BLOOD HEMATOLOGY 718-7 Hemoglobin [Mass/volume] in Blood","D_LABITEMS") => "Haemoglobin",
					   reverseLookFor("[Hgb] BLOOD CHEMISTRY 718-7 Hemoglobin [Mass/volume] in Blood","D_LABITEMS") => "Haemoglobin",
					   reverseLookFor("PLT COUNT BLOOD HEMATOLOGY 26515-7 Platelets [#/volume] in Blood","D_LABITEMS") => "Platelets", 
					   reverseLookFor("CL- BLOOD BLOOD GAS 2069-3 Chloride [Moles/volume] in Blood","D_LABITEMS") => "ChlorideABG",
					   reverseLookFor("CHLORIDE BLOOD CHEMISTRY 2069-3 Chloride [Moles/volume] in Blood","D_LABITEMS") => "ChlorideABG",
					   reverseLookFor("GLUCOSE BLOOD BLOOD GAS 2339-0 Glucose [Mass/volume] in Blood","D_LABITEMS") => "GlocuseABG", 
					   reverseLookFor("LACTATE BLOOD BLOOD GAS 32693-4 Lactate [Moles/volume] in Blood","D_LABITEMS") => "LactateABG",
					   reverseLookFor("NA+ BLOOD BLOOD GAS 2947-0 Sodium [Moles/volume] in Blood","D_LABITEMS") => "NaABG",
					   reverseLookFor("K+ BLOOD BLOOD GAS 6298-4 Potassium [Moles/volume] in Blood","D_LABITEMS") => "PotassiumABG",
					   reverseLookFor("PH BLOOD BLOOD GAS 11558-4 pH of Blood","D_LABITEMS") => "PHABG",
					   reverseLookFor("INR(PT) BLOOD HEMATOLOGY 34714-6 INR in Blood by Coagulation assay","D_LABITEMS") => "PtINR",
					   reverseLookFor("UREA N BLOOD CHEMISTRY 3094-0 Urea nitrogen [Mass/volume] in Serum or Plasma","D_LABITEMS") => "Urea",
					   reverseLookFor("PHOSPHATE BLOOD CHEMISTRY 2777-1 Phosphate [Mass/volume] in Serum or Plasma","D_LABITEMS") => "InorganicPhosphate",
					   reverseLookFor("O2 BLOOD BLOOD GAS 19994-3 Oxygen/Inspired gas setting [Volume Fraction] Ventilator","D_LABITEMS") => "InspiredOxygen"
					   ) ;
					   
	my %chartTargetItems = (				   
					   reverseLookFor("Hepatic SOFA Score LCP Calculated SOFA score due to hepatic failure (Bilirubin values) - by the MIMIC2 team","D_CHARTITEMS") => ["Bilirubin_SOFA",""],
					   reverseLookFor("Renal SOFA Score LCP Calculated SOFA score due to renal failure (Creatinine and Urine output) - by the MIMIC2 team","D_CHARTITEMS") => ["Creatinine_SOFA",""],
					   reverseLookFor("Respiratory SOFA Score LCP Calculated SOFA score due to respiratory failure (PaO2/FiO2 ratio) - by the MIMIC2 team","D_CHARTITEMS") => ["PaO2/FiO2_SOFA",""],
					   reverseLookFor("Hematologic SOFA Score LCP Calculated SOFA score due to hematologic failure (Platelet count) - by the MIMIC2 team","D_CHARTITEMS") => ["Platelets_SOFA",""],
					   reverseLookFor("Arterial PaCO2 ABG","D_CHARTITEMS") => ["PaCO2",""],
					   reverseLookFor("Venous PvCO2 VBG's","D_CHARTITEMS") => ["VenPaCO2",""],
					   reverseLookFor("Arterial PaO2 ABG","D_CHARTITEMS") => ["PaO2",""],
					   reverseLookFor("Venous PvO2 Mixed Venous Gases","D_CHARTITEMS") => ["VenPaO2",""],
					   reverseLookFor("SpO2","D_CHARTITEMS") => ["SpO2",""],
					   reverseLookFor("Heart Rate","D_CHARTITEMS") => ["HeartRate",""],
					   reverseLookFor("Temperature C","D_CHARTITEMS") => ["Temperature",""],
					   reverseLookFor("Temperature C (calc)","D_CHARTITEMS") => ["Temperature",""],
					   reverseLookFor("Base Excess","D_CHARTITEMS") => ["BaseExcess",""],
					   reverseLookFor("Venous Base Excess Venous ABG","D_CHARTITEMS") => ["VenBaseExcess",""],
					   reverseLookFor("Arterial Base Excess ABG","D_CHARTITEMS") => ["BaseExcess",""],
					   reverseLookFor("Venous Base Excess Venous ABG","D_CHARTITEMS") => ["BaseExcess",""],
					   reverseLookFor("Daily Weight","D_CHARTITEMS") => ["Weight",""],
					   reverseLookFor("Present Weight  (kg)","D_CHARTITEMS") => ["Weight",""],
					   reverseLookFor("Weight Kg","D_CHARTITEMS") => ["Weight",""],
					   ) ;
				
	my %urineProdItems = (
					   reverseLookFor("PACU Out PACU Urine","D_IOITEMS") => 1,
					   reverseLookFor("Urine Out Other","D_IOITEMS") => 1,
					   reverseLookFor("Urine Out Straight Cath","D_IOITEMS") => 1,
					   reverseLookFor("Urine Out Suprapubic","D_IOITEMS") => 1,
					   reverseLookFor("Urine Out Lt Nephrostomy","D_IOITEMS") => 1,
					   reverseLookFor("OR Out OR Urine","D_IOITEMS") => 1,
					   reverseLookFor("Urine Out Incontinent","D_IOITEMS") => 1,
					   reverseLookFor("Urine Out Condom Cath","D_IOITEMS") => 1,
					   reverseLookFor("Urine .","D_IOITEMS") => 1,
					   reverseLookFor("Urine Out Foley","D_IOITEMS") => 1,
					   reverseLookFor("Urine Out Rt Nephrostomy","D_IOITEMS") => 1,
					   reverseLookFor("OR Out PACU Urine","D_IOITEMS") => 1,
					   reverseLookFor("Urine Out Void","D_IOITEMS") => 1,
					   reverseLookFor("Urine Out IleoConduit","D_IOITEMS") => 1,
					   ) ;
					   
	my %dialysisItems ;
	getDialysisItems(\%dialysisItems) ;
			   
	my %signalUnits = (WhiteCellCount => "10^9/l", , LymphocytesPercent => "", Albumin => "g/dL", Bicarbonate => "mmol/l", BilirubinTotal => "mg/dL", Creatinine => "mg/dL", Haemoglobin => "g/dL", 
					   HaemoglobinTotal => "g/dL", Platelets => "10^9/l", ChlorideABG => "mEq/L", GlocuseABG => "mg%", LactateABG => "mg/dL", NaABG => "mmol/L", PotassiumABG => "mmol/L", PHABG => "N/A", 
					   Bilirubin_SOFA => "", Creatinine_SOFA => "", "PaO2/FiO2_SOFA" => "", Platelets_SOFA => "", GCS_SOFA => "", PaCO2 => "mmHg", VenPaCO2 => "mmHg", PaO2 => "mmHg", VenPaO2 => "mmHg",
					   SpO2 => "N/A", HeartRate => "bpm", PtINR => "N/A",Urea => "mmol/l", Temperature => "Deg. C", BaseExcess => "mmol/l", VenBaseExcess => "mmol/l", InspiredOxygen => "%", UrineProd => "ml",
					   Weight => "kg", InorganicPhosphate => "mmol/l") ;
					   
	my %unitsTransformation ;
	$unitsTransformation{WhiteCellCount}->{"k/ul"} = 1.0 ;
	$unitsTransformation{LymphocytesPercent}->{"%"} =1.0 ;
	$unitsTransformation{Bicarbonate}->{"meq/l"} = 1.0 ;
	$unitsTransformation{Platelets}->{"k/ul"} = 1.0 ;
	$unitsTransformation{GlocuseABG}->{"mg/dl"} = 1.0 ;
	$unitsTransformation{LactateABG}->{"mmol/l"} = 9.009 ;
	$unitsTransformation{NaABG}->{"meq/l"} = 1.0 ;
	$unitsTransformation{PotassiumABG}->{"meq/l"} = 1.0 ;
	$unitsTransformation{PHABG}->{"units"} = 1.0 ;
	$unitsTransformation{SpO2}->{"%"} = 1.0 ;
	$unitsTransformation{PtINR}->{""} = 1.0 ;
#	$unitsTransformation{Urea}->{"mg/dl"} = 0.357 ;
	$unitsTransformation{Urea}->{"mg/dl"} = 1.0/0.357 ;
	$unitsTransformation{BaseExcess}->{""} = 1.0 ;
	$unitsTransformation{VenBaseExcess}->{""} = 1.0 ;
	$unitsTransformation{InspiredOxygen}->{""} = 1.0 ;
#	$unitsTransformation{InorganicPhosphate}->{"mg/dl"} = 0.323 ;
	$unitsTransformation{InorganicPhosphate}->{"mg/dl"} = 1.0 ;
	$unitsTransformation{Weight}->{"gms"} = 0.001 ;
	
	#Special Cases
	my %neutrophilsPercentItems = (reverseLookFor("NEUTS BLOOD HEMATOLOGY 26505-8 Neutrophils.segmented/100 leukocytes in Blood","D_LABITEMS") => 1,
							  reverseLookFor("HYPERSEG BLOOD HEMATOLOGY 30450-1 Neutrophils.hypersegmented/100 leukocytes in Blood","D_LABITEMS") => 2,
							  reverseLookFor("BANDS BLOOD HEMATOLOGY 26508-2 Neutrophils.band form/100 leukocytes in Blood","D_LABITEMS") => 3) ;
	my @neutrophisPercentReqiredItems = (reverseLookFor("NEUTS BLOOD HEMATOLOGY 26505-8 Neutrophils.segmented/100 leukocytes in Blood","D_LABITEMS")) ;
	
	my %hemodynSofaItems = (reverseLookFor("Pressor Cardiovascular SOFA Score LCP Calculated SOFA score due to cardiovascular failure (Pressors) - by the MIMIC2 team","D_CHARTITEMS") => "Pressors",
							reverseLookFor("MAP Cardiovascular SOFA Score LCP Calculated SOFA score due to cardiovascular failure (MAP) - by the MIMIC2 team","D_CHARTITEMS") => "MAP") ;
	
	while (get_next_id("$inDir/LABEVENTS",$ids,\@lab_item_recs)) {
		my $id ;
		my %neutrophilsPercent ;
		
		# Lab Events
		foreach my $rec (@lab_item_recs) {
			$id = $rec->[$headers{LABEVENTS}->{SUBJECT_ID}] ; 
			my $stayID = $rec->[$headers{LABEVENTS}->{ICUSTAY_ID}] ;
			my $itemID = $rec->[$headers{LABEVENTS}->{ITEMID}] ;
				
			if (exists $labTargetItems{$itemID}) {
				my $time = transformTime($rec->[$headers{LABEVENTS}->{CHARTTIME}]) ;	
				
				my $signalName = $labTargetItems{$itemID} ;
				my $value = $rec->[$headers{LABEVENTS}->{VALUENUM}] ;	
				if ($value ne "") {
					my $unit = lc($rec->[$headers{LABEVENTS}->{VALUEUOM}]) ;
						
					if ($unit ne lc($signalUnits{$signalName})) {
						if (!exists $unitsTransformation{$signalName}->{$unit}) {
							print STDERR "Cannot transform from $signalName unit $unit to $signalUnits{$signalName} at $time/$id\n" 
						} else {
							$value *= $unitsTransformation{$signalName}->{$unit} ;
							print OUT "$id\t$stayID\t$signalName\t$value\t$signalUnits{$signalName}\t$time\n" ;
						}
					} else {
						print OUT "$id\t$stayID\t$signalName\t$value\t$signalUnits{$signalName}\t$time\n" ;
					}
				}
			} elsif (exists $neutrophilsPercentItems{$itemID}) {
				# Neutrophils Percent
				my $time = transformTime($rec->[$headers{LABEVENTS}->{CHARTTIME}]) ;
				my $value = $rec->[$headers{LABEVENTS}->{VALUENUM}] ;
				if (exists $neutrophilsPercent{$time}->{$neutrophilsPercentItems{$itemID}}) {
					my $prevValue = $neutrophilsPercent{$time}->{$neutrophilsPercentItems{$itemID}}->{value} ;
					print STDERR "Multiple entries for $itemID for $id at $time ($value vs. $prevValue) " ;
					if ($value+$prevValue > 0 and abs($value-$prevValue) > 5 and abs($value-$prevValue)/(($value+$prevValue)/2) > 0.2) {
						print STDERR "Ignoring\n" ;
						$neutrophilsPercent{$time}->{ignore} = 1 ;
					} else {
						print STDERR "Taking last\n" 
					}
				}
				$neutrophilsPercent{$time}->{$neutrophilsPercentItems{$itemID}} = {value => $value, stayID => $stayID} if ($value ne "") ;
			}
		}
		
		# Summarize Neutrophils Percent
		foreach my $time (keys %neutrophilsPercent) {
			my $stayID;
			foreach my $required (@neutrophisPercentReqiredItems) {
				if (! exists $neutrophilsPercent{$time}->{$neutrophilsPercentItems{$required}}) {
					print STDERR "Requrired item $required for Neutrophils percent missing for $id  at time $time. Ignoring all reads at that time\n" ;
					$neutrophilsPercent{$time}->{ignore} = 1 ;
					last ;
				} else {
					$stayID = $neutrophilsPercent{$time}->{$neutrophilsPercentItems{$required}}->{stayID} ;
				}
			}
			
			if (! exists $neutrophilsPercent{$time}->{ignore} ) {
				my $neutrophilsPercent ;
				foreach my $item (keys %{$neutrophilsPercent{$time}}) {
					die "stayID mismatch for neutrophil-precents at $time for $id" if ($neutrophilsPercent{$time}->{$item}->{stayID} != $stayID) ;			
					$neutrophilsPercent += $neutrophilsPercent{$time}->{$item}->{value} ;
				}
				print OUT "$id\t$stayID\tNeutrophilsPercent\t$neutrophilsPercent\tN/A\t$time\n" ;
			}
		}
		
		# Add Chart Events
		get_next_id("$inDir/CHARTEVENTS",$ids,\@chart_item_recs) ;
		
		foreach my $rec (@chart_item_recs) {
			my $current_id = $rec->[$headers{CHARTEVENTS}->{SUBJECT_ID}] ;
			if (defined $id) {
				die "ID inconsistency" if ($current_id != $id) ;
			} else {
				$id = $current_id ;
			}
			
			my $stayID = $rec->[$headers{CHARTEVENTS}->{ICUSTAY_ID}] ;
			my $itemID = $rec->[$headers{CHARTEVENTS}->{ITEMID}] ;
				
			if (exists $chartTargetItems{$itemID}) {
				my $time = transformTime($rec->[$headers{CHARTEVENTS}->{REALTIME}]) ;	
				
				if ($chartTargetItems{$itemID}->[0] ne "") {
					my $signalName = $chartTargetItems{$itemID}->[0] ;
					my $value = $rec->[$headers{CHARTEVENTS}->{VALUE1NUM}] ;		
					if ($value ne "") {
						my $unit = lc($rec->[$headers{CHARTEVENTS}->{VALUE1UOM}]) ;
						
						if ($unit ne lc($signalUnits{$signalName})) {
							if (!exists $unitsTransformation{$signalName}->{$unit}) {
								print STDERR "Cannot transform from $signalName unit $unit to $signalUnits{$signalName} at $time/$id\n" 
							} else {
								$value *= $unitsTransformation{$signalName}->{$unit} ;
								print OUT "$id\t$stayID\t$signalName\t$value\t$signalUnits{$signalName}\t$time\n" ;
							}
						} else {
							print OUT "$id\t$stayID\t$signalName\t$value\t$signalUnits{$signalName}\t$time\n" ;
						}
					}
				}
				
				if ($chartTargetItems{$itemID}->[1] ne "NONE") {
					my $signalName = $chartTargetItems{$itemID}->[1] ;
					my $value = $rec->[$headers{CHARTEVENTS}->{VALUE2NUM}] ;							
					my $unit = lc($rec->[$headers{CHARTEVENTS}->{VALUE2UOM}]) ;
					
					if ($value ne "") {
						if ($unit ne lc($signalUnits{$signalName})) {
							if (!exists $unitsTransformation{$signalName}->{$unit}) {
								print STDERR "Cannot transform from $signalName unit $unit to $signalUnits{$signalName} at $time/$id\n" 
							} else {
								$value *= $unitsTransformation{$signalName}->{$unit} ;
								print OUT "$id\t$stayID\t$signalName\t$value\t$signalUnits{$signalName}\t$time\n" ;
							}
						} else {
							print OUT "$id\t$stayID\t$signalName\t$value\t$signalUnits{$signalName}\t$time\n" ;
						}
					}
				}
			}
			
			# Cardiovascular/Hemodynamic SOFA
			if (exists $hemodynSofaItems{$itemID}) {
				my $value = $rec->[$headers{CHARTEVENTS}->{VALUE1NUM}] ;
				my $type = $hemodynSofaItems{$itemID} ;
				my $time = transformTime($rec->[$headers{CHARTEVENTS}->{REALTIME}]) ;	
				
				print OUT "$id\t$stayID\tHemodyn_SOFA\t$type.$value\t\t$time\n" ;
			}
		}

		# Add IO Events : Urine production ; Dialysis
		get_next_id("$inDir/IOEVENTS",$ids,\@io_item_recs) ;

		my %urineProd ;
		foreach my $rec (@io_item_recs) {
			my $current_id = $rec->[$headers{IOEVENTS}->{SUBJECT_ID}] ;
			if (defined $id) {
				die "ID inconsistency" if ($current_id != $id) ;
			} else {
				$id = $current_id ;
			}
			
			my $stayID = $rec->[$headers{IOEVENTS}->{ICUSTAY_ID}] ;
			my $itemID = $rec->[$headers{IOEVENTS}->{ITEMID}] ;
			
			if (exists $dialysisItems{$itemID}) {
				my $time = transformTime($rec->[$headers{IOEVENTS}->{REALTIME}]) ;	
				print OUT "$id\t$stayID\tCreatinine_SOFA\tDialys.\t\t$time\n" ;
			} elsif (exists $urineProdItems{$itemID}) {
				my $stopped = $rec->[$headers{IOEVENTS}->{STOPPED}] ;
				next if ($stopped) ;
				
				my $time = transformTime($rec->[$headers{IOEVENTS}->{REALTIME}]) ;	
				my $value = $rec->[$headers{IOEVENTS}->{VOLUME}] ;		
				if ($value ne "") {
					my $unit = lc($rec->[$headers{IOEVENTS}->{VOLUMEUOM}]) ;
					
					if ($unit ne lc($signalUnits{UrineProd})) {
						if (!exists $unitsTransformation{UrineProd}->{$unit}) {
							print STDERR "Cannot transform from UrineProd unit $unit to $signalUnits{UrineProd} at $time/$id\n" 
						} else {
							$value *= $unitsTransformation{UrineProd}->{$unit} ;
							$urineProd{$time}->{stayID} = $stayID ;
							$urineProd{$time}->{value} += $value ;
						}
					} else {
						$urineProd{$time}->{stayID} = $stayID ;
						$urineProd{$time}->{value} += $value ;
					}
				}
			}
		}

		foreach my $time (keys %urineProd) {
			my $stayID = $urineProd{$time}->{stayID} ;
			my $value = $urineProd{$time}->{value} ;
			print OUT "$id\t$stayID\tUrineProd\t$value\t$signalUnits{UrineProd}\t$time\n" ;
		}

		# Add Details from ICUSTAY_DETAILS
		get_next_id("$inDir/ICUSTAY_DETAIL",$ids,\@icu_detail_recs) ;
		
		foreach my $rec (@icu_detail_recs) {
			my $current_id = $rec->[$headers{IOEVENTS}->{SUBJECT_ID}] ;
			if (defined $id) {
				die "ID inconsistency" if ($current_id != $id) ;
			} else {
				$id = $current_id ;
			}
		
			my $stayID = $rec->[$headers{ICUSTAY_DETAIL}->{ICUSTAY_ID}] ;
			my $inTime = transformTime($rec->[$headers{ICUSTAY_DETAIL}->{ICUSTAY_INTIME}]) ;

			my $height = $rec->[$headers{ICUSTAY_DETAIL}->{HEIGHT}] ;			
			printf OUT "$id\t$stayID\tHeight\t%.2f\tm\t$inTime\n",$height/100 if ($height ne "") ;
			
			my $weight = $rec->[$headers{ICUSTAY_DETAIL}->{WEIGHT_FIRST}] ;
			print OUT "$id\t$stayID\tWeight\t$weight\tkg\t$inTime\n" if ($weight ne "") ;
		}
	}
	close OUT ;
}

sub getSignalsIBP {
	my ($inDir,$ids,$outDir) = @_ ;
	
	open (OUT,">$outDir/M_PatientSignal_IBP.txt") or die "Cannot open demographics file \'$outDir/M_PatientSignal_IBP.txt\' for writing" ;	
	print OUT "MR_Number\tStay_number\tParameter_name\tSignal_Value\tSignal_Unit\tSignal_Time\n" ;
	
	my @chart_item_recs ;
	
	restart_reader("$inDir/CHARTEVENTS") ;
	
	my %targetItems = (reverseLookFor("Arterial BP Mean","D_CHARTITEMS") => ["ArterialPressureMean",""] ,
				       reverseLookFor("Arterial BP","D_CHARTITEMS") => ["ArterialPressureSystolic","ArterialPressureDiastolic"]) ;	
	my %signalUnits = (ArterialPressureMean => "mmHg", ArterialPressureSystolic => "mmHg", ArterialPressureDiastolic => "mmHg") ;
	my %unitsTransformation = () ;
	
	while (get_next_id("$inDir/CHARTEVENTS",$ids,\@chart_item_recs)) {
		my $id ;
		foreach my $rec (@chart_item_recs) {
			$id = $rec->[$headers{CHARTEVENTS}->{SUBJECT_ID}] ; 
			my $stayID = $rec->[$headers{CHARTEVENTS}->{ICUSTAY_ID}] ;
			my $itemID = $rec->[$headers{CHARTEVENTS}->{ITEMID}] ;
				
			if (exists $targetItems{$itemID}) {
				my $time = transformTime($rec->[$headers{CHARTEVENTS}->{REALTIME}]) ;	
				
				if ($targetItems{$itemID}->[0] ne "") {
					my $signalName = $targetItems{$itemID}->[0] ;
					my $value = $rec->[$headers{CHARTEVENTS}->{VALUE1NUM}] ;	

					if ($value ne "") {
						my $unit = lc($rec->[$headers{CHARTEVENTS}->{VALUE1UOM}]);
						
						if ($unit ne lc($signalUnits{$signalName})) {
							if (!exists $unitsTransformation{$signalName}->{$unit}) {
								print STDERR "Cannot transform from $signalName unit $unit to $signalUnits{$signalName} at $time/$id\n" 
							} else {
								$value *= $unitsTransformation{$signalName}->{$unit} ;
								print OUT "$id\t$stayID\t$signalName\t$value\t$signalUnits{$signalName}\t$time\n" ;
							}
						} else {
							print OUT "$id\t$stayID\t$signalName\t$value\t$signalUnits{$signalName}\t$time\n" ;
						}
					}
				}
				
				if ($targetItems{$itemID}->[1] ne "NONE") {
					my $signalName = $targetItems{$itemID}->[1] ;
					my $value = $rec->[$headers{CHARTEVENTS}->{VALUE2NUM}] ;

					if ($value ne "") {					
						my $unit = lc($rec->[$headers{CHARTEVENTS}->{VALUE2UOM}]) ;
						
						if ($unit ne lc($signalUnits{$signalName})) {
							if (!exists $unitsTransformation{$signalName}->{$unit}) {
								print STDERR "Cannot transform from $signalName unit $unit to $signalUnits{$signalName} at $time/$id\n" 
							} else {
								$value *= $unitsTransformation{$signalName}->{$unit} ;
								print OUT "$id\t$stayID\t$signalName\t$value\t$signalUnits{$signalName}\t$time\n" ;
							}
						} else {
							print OUT "$id\t$stayID\t$signalName\t$value\t$signalUnits{$signalName}\t$time\n" ;
						}
					}
				}
			}
		}
	}
	close OUT ;
}
	
sub getAdmission {
	my ($inDir,$ids,$outDir) = @_ ;
	
	open (OUT,">$outDir/M_PatientAdmission.txt") or die "Cannot open demographics file \'$outDir/M_PatientAdmission.txt\' for writing" ;	
	print OUT "MR_number\tStay_number\tAdmission_date\tDuration_of_admission_Days\tDuration_of_admission_Hours\tDischarge_time\n" ;

	my @icu_detail_recs ;
	
	restart_reader("$inDir/ICUSTAY_DETAIL") ;
	
	while (get_next_id("$inDir/ICUSTAY_DETAIL",$ids,\@icu_detail_recs)) {
		my $id ;
		my %stayInfo ;
		foreach my $rec (@icu_detail_recs) {
			$id = $rec->[$headers{ICUSTAY_DETAIL}->{SUBJECT_ID}] ;
			my $stayID = $rec->[$headers{ICUSTAY_DETAIL}->{ICUSTAY_ID}] ;

			my $inTime = transformTime($rec->[$headers{ICUSTAY_DETAIL}->{ICUSTAY_INTIME}]) ;
			my $outTime = transformTime($rec->[$headers{ICUSTAY_DETAIL}->{ICUSTAY_OUTTIME}]) ; 
			my $lengthOfStay = $rec->[$headers{ICUSTAY_DETAIL}->{ICUSTAY_LOS}] ;
			my $lengthOfStayCalculated = getLengthOfStay($inTime,$outTime) ;
			print STDERR "Inconsistent Length of Stay - $lengthOfStay vs. Calculated $lengthOfStayCalculated\n" if ($lengthOfStay != $lengthOfStayCalculated) ;

			printf OUT "$id\t$stayID\t$inTime\t%.1f\t%.1f\t$outTime\n",$lengthOfStay/60/24,$lengthOfStay/60 ;
		}
	}
	
	close OUT ;
}

sub getDemographics {
	my ($inDir,$ids,$outDir) = @_ ;
	
	open (OUT,">$outDir/M_PatientDemographics.txt") or die "Cannot open demographics file \'$outDir/M_PatientDemographics.txt\' for writing" ;
	print OUT "MR_number\tStay_number\tValue\tUNIT\tParameter_name\tValidation_time\n" ;
	
	my @icu_detail_recs ;
	my @census_events_recs ;
	
	restart_reader("$inDir/ICUSTAY_DETAIL",$ids) ;
	restart_reader("$inDir/CENSUSEVENTS",$ids) ;
	
	while (get_next_id("$inDir/ICUSTAY_DETAIL",$ids,\@icu_detail_recs)) {
		my $id ;
		my %stayInfo ;
		foreach my $rec (@icu_detail_recs) {
			$id = $rec->[$headers{ICUSTAY_DETAIL}->{SUBJECT_ID}] ;
			my $stayID = $rec->[$headers{ICUSTAY_DETAIL}->{ICUSTAY_ID}] ;
			
			$stayInfo{$stayID}->{inTime} = transformTime($rec->[$headers{ICUSTAY_DETAIL}->{ICUSTAY_INTIME}]) ;
			$stayInfo{$stayID}->{outTime} = transformTime($rec->[$headers{ICUSTAY_DETAIL}->{ICUSTAY_OUTTIME}]) ;
			my $gender = $rec->[$headers{ICUSTAY_DETAIL}->{GENDER}] ;
					
			print OUT "$id\t$stayID\t$gender\t\tGender\t$stayInfo{$stayID}->{inTime}\n" ;
			
			my $age = int($rec->[$headers{ICUSTAY_DETAIL}->{ICUSTAY_ADMIT_AGE}]) ;
			print OUT "$id\t$stayID\t$age\tyears\tAge\t$stayInfo{$stayID}->{inTime}\n" ;
		}
		
		get_next_id("$inDir/CENSUSEVENTS",$ids,\@census_events_recs) ;
		foreach my $rec (@census_events_recs) {
			my $current_id = $rec->[$headers{CENSUSEVENTS}->{SUBJECT_ID}] ;
			if (defined $id) {
				die "ID inconsistency" if ($current_id != $id) ;
			} else {
				$id = $current_id ;
			}
			
			my $outTime = transformTime($rec->[$headers{CENSUSEVENTS}->{OUTTIME}]) ;
			my $stayID = $rec->[$headers{CENSUSEVENTS}->{ICUSTAY_ID}] ;
			if ($stayID eq "") {
				foreach my $testStayID (keys %stayInfo) {
					if ($outTime eq $stayInfo{$testStayID}->{outTime}) {
						$stayID = $testStayID ;
						last ;
					}
				}
			}
								
			if ($stayID ne "" and $outTime eq $stayInfo{$stayID}->{outTime}) {
				my $originCareUnitID = $rec->[$headers{CENSUSEVENTS}->{CAREUNIT}] ;
				$originCareUnitID = -1 if ($originCareUnitID eq "") ;
				my $destinationCareUnitID = $rec->[$headers{CENSUSEVENTS}->{DESTCAREUNIT}] ;
				$destinationCareUnitID = -1 if ($destinationCareUnitID eq "") ;
				
				if (exists $stayInfo{$stayID}->{destination} and $destinationCareUnitID ne $stayInfo{$stayID}->{destination}) {
					if ($originCareUnitID eq $stayInfo{$stayID}->{destination}) {
						print STDERR "Multiple CensusEvents correponding to out-time of $id/$stayID with inconsistent destination : Tracking $stayInfo{$stayID}->{destination} to $destinationCareUnitID\n" ;
						$stayInfo{$stayID}->{destination} = $destinationCareUnitID ;
					} elsif ($destinationCareUnitID eq $stayInfo{$stayID}->{origin}) {
						print STDERR "Multiple CensusEvents correponding to out-time of $id/$stayID with inconsistent destination : Tracking $destinationCareUnitID to $stayInfo{$stayID}->{destination}\n" ;
					} else {							
						print STDERR  "Multiple CensusEvents correponding to out-time of $id/$stayID with inconsistent destination . Unable to track; Taking Latest" ;
						$stayInfo{$stayID}->{destination} = $destinationCareUnitID ;
						$stayInfo{$stayID}->{origin} = $originCareUnitID ;	
					}
				} else {																				;			
					$stayInfo{$stayID}->{destination} = $destinationCareUnitID ;
					$stayInfo{$stayID}->{origin} = $originCareUnitID ;
				}
			}
		}
		
		foreach my $stayID (keys %stayInfo) {
			if (exists $stayInfo{$stayID}->{destination}) {
				my $destination = lookFor($stayInfo{$stayID}->{destination},"D_CAREUNITS") ;
				print OUT "$id\t$stayID\t$destination\t\tDischarge Destination\t$stayInfo{$stayID}->{outTime}\n" ;
			} else {
				print STDERR "Cannot find Discharge Destination for $id/$stayID\n" 
			}
		}
	}
	
	close OUT ;
}

sub readIdsList {
	my ($file,$ids) = @_ ;
	
	open (IN,$file) or die "Cannot open $file for reading" ;
	my $prev_id ;
	my $nids ;
	while (my $id = <IN>) {
		chomp $id ;
		if (! defined $prev_id) {
			$ids->{first} = $id ;
		} else {
			$ids->{next}->{$prev_id} = $id ;
		}
		$prev_id = $id ;
		$nids ++ ;
	}
	
	if (! exists $ids->{first}) {
		print STDERR "No IDs in file. Quitting\n" ;
		exit(1) ;
	}
	
	print STDERR "Read $nids IDs\n" ;
	
	return ;
}

sub restart_reader {
	my ($name) = @_ ;
	$reader{$name}->{current} = undef ;
}

sub get_next_id {
	my ($name,$ids,$info) = @_ ;
	
	@{$info} = () ;
	my $id ;
	if (!exists ($reader{$name}->{data_fh})) {
	
		$reader{$name}->{data_fh} = FileHandle->new($name,"r") or die "Cannot open \'$name\' for reading" ;
		$reader{$name}->{header} = $reader{$name}->{data_fh}->getline() ;
		$reader{$name}->{index} = read_index("$name.idx") ;
		
		if (exists $ids->{first}) {	
			$reader{$name}->{current} = $ids->{first} ;
		} else {
			$reader{$name}->{current} = 1 ;			
		}

	} else {
		if (! defined $reader{$name}->{current}) {
			$reader{$name}->{current} = (exists $ids->{first}) ? $ids->{first} : 1 ;
		} else {
			if (exists $ids->{first}) {
				return 0 if (! exists $ids->{next}->{$reader{$name}->{current}}) ;
				$reader{$name}->{current} = $ids->{next}->{$reader{$name}->{current}} ;
			} else {
				return 0 if ($reader{$name}->{current} == $NIDS) ;
				$reader{$name}->{current} ++ ;
			}
		}
	}
	
	my $from = $reader{$name}->{index}->[$reader{$name}->{current}] ;
	return 1 if ($from == -1) ;
	
	my $to = -1 ;
	if ($reader{$name}->{current} != $NIDS) {
		my $next = $reader{$name}->{current}+1 ;
		$next++ while ($next <= $NIDS and $reader{$name}->{index}->[$next] == -1) ;
		$to = $reader{$name}->{index}->[$next] if ($next <= $NIDS) ;
	}

	$reader{$name}->{data_fh}->seek($from,0) ;
	my $finish = 0 ;
	while (my $line = $reader{$name}->{data_fh}->getline()) {
		chomp $line ;
		my @fields = mySplit($line,",") ;
		push @{$info},\@fields ; 
		
		my $curr_pos = $reader{$name}->{data_fh}->tell();
		if ($curr_pos == $to) {
			$finish = 1 ;
			last ;
		}
	}
	
	if ($to != -1 and ! $finish) {
		print STDERR "Reached end of file for non-last id ($reader{$name}->{current}) in $name \n" ;
		exit(1) ;
	}
	
	my $nn = scalar(@{$info}) ;
	return 1 ;
}

sub read_index {
	my $name = shift @_ ;
	
	my $buffer ;
	open (IN,"<:raw",$name) or die "Cannot open \'$name\' for reading in binary mode" ;
	read (IN,$buffer,($NIDS+1)*8) == ($NIDS+1)*8 or die "Cannot read from \'$name\'" ;
	my $format = sprintf("q%d",$NIDS+1) ;
	my @index = unpack($format,$buffer) ;
	return \@index ; 
}
	
sub init_headers {
	$headers{ICUSTAY_DETAIL} = getHeader("SUBJECT_ID,ICUSTAY_ID,GENDER,DOB,DOD,EXPIRE_FLG,SUBJECT_ICUSTAY_TOTAL_NUM,SUBJECT_ICUSTAY_SEQ,HADM_ID,HOSPITAL_TOTAL_NUM,HOSPITAL_SEQ".
								 ",HOSPITAL_FIRST_FLG,HOSPITAL_LAST_FLG,HOSPITAL_ADMIT_DT,HOSPITAL_DISCH_DT,HOSPITAL_LOS,HOSPITAL_EXPIRE_FLG,ICUSTAY_TOTAL_NUM,ICUSTAY_SEQ,ICUSTAY_FIRST_FLG,ICUSTAY_LAST_FLG".
								 ",ICUSTAY_INTIME,ICUSTAY_OUTTIME,ICUSTAY_ADMIT_AGE,ICUSTAY_AGE_GROUP,ICUSTAY_LOS,ICUSTAY_EXPIRE_FLG,ICUSTAY_FIRST_CAREUNIT,ICUSTAY_LAST_CAREUNIT,ICUSTAY_FIRST_SERVICE,ICUSTAY_LAST_SERVICE,".
								 "HEIGHT,WEIGHT_FIRST,WEIGHT_MIN,WEIGHT_MAX,SAPSI_FIRST,SAPSI_MIN,SAPSI_MAX,SOFA_FIRST,SOFA_MIN,SOFA_MAX,MATCHED_WAVEFORMS_NUM") ;
								 	
	$headers{CENSUSEVENTS} = getHeader("SUBJECT_ID,CENSUS_ID,INTIME,OUTTIME,CAREUNIT,DESTCAREUNIT,DISCHSTATUS,LOS,ICUSTAY_ID") ;
	$headers{CHARTEVENTS} = getHeader("SUBJECT_ID,ICUSTAY_ID,ITEMID,CHARTTIME,ELEMID,REALTIME,CGID,CUID,VALUE1,VALUE1NUM,VALUE1UOM,VALUE2,VALUE2NUM,VALUE2UOM,RESULTSTATUS,STOPPED") ;
	$headers{LABEVENTS} = getHeader("SUBJECT_ID,HADM_ID,ICUSTAY_ID,ITEMID,CHARTTIME,VALUE,VALUENUM,FLAG,VALUEUOM") ;
	$headers{IOEVENTS} = getHeader("SUBJECT_ID,ICUSTAY_ID,ITEMID,CHARTTIME,ELEMID,ALTID,REALTIME,CGID,CUID,VOLUME,VOLUMEUOM,UNITSHUNG,UNITSHUNGUOM,NEWBOTTLE,STOPPED,ESTIMATE") ;
}

sub getHeader {
	my ($header) = @_ ;
	my @fields = mySplit($header,",") ;
	my %cols = map {($fields[$_] => $_)} (0..$#fields) ;
	return \%cols ;
}

sub getDays {
	my $date = shift @_ ;
	
	$date =~ /(\d\d)\/(\d\d)\/(\d\d\d\d)/ or die "Cannot parse date \'$date\'\n" ;
	my ($day,$month,$year) = ($1,$2,$3) ;
	
	my $days = 365 * ($year-2500) ;
	$days += int(($year-2497)/4) ;
	$days -= int(($year-2401)/100);

	$days += $days2month[$month-1] ;
	$days ++ if ($month>2 && ($year%4)==0 && (($year%100)!=0 || ($year%400)==0)) ;

	$days += ($day-1) ;
	return $days ;
}	
		
sub transformTime{
	my ($time) = @_ ;
	
	$time =~ /(\d\d\d\d)-(\d\d)-(\d\d)\s+(\d\d:\d\d:\d\d)/ or die "Illegal time format for $time" ;
	return "$3/$2/$1 $4" ;
}

sub transformDate{
	my ($date) = @_ ;
	
	$date =~ /(\d\d\d\d)-(\d\d)-(\d\d)/ or die "Illegal date format for $date" ;
	return "$3/$2/$1" ;
}

sub getMinutes {
	my ($dateAndTime) = @_ ;

	my ($date,$time) = split /\s+/,$dateAndTime ;
	my $days = getDays($date) ;
	
	$time =~ /(\d\d):(\d\d):(\d\d)/ or die "Cannot parse time \'$time\'\n" ;
	
	return $days*24*60 + $1*60 + $2 ;
}

sub readLookupTable {
	my ($table) = @_ ;
	
	my $file = "$lookupsDir/$table.txt" ;
	open (TBL,$file) or die "Cannot open \'$file\' for reading" ;
	
	while (<TBL>) {
		chomp ;
		my ($tempKey,@values) = mySplit ($_,",") ;
		my $value = join " ",@values ;
		$value =~ s/\s+$// ;
		$lookups{$table}->{forward}->{$tempKey} = $value ;
	}
	close TBL ;
}
		
sub lookFor {
	my ($key,$table) = @_ ;
	
	readLookupTable($table) if (! exists $lookups{$table}) ;	
	die "Cannot find $key in Lookup table $table" if (! exists $lookups{$table}->{forward}->{$key}) ;
	return $lookups{$table}->{forward}->{$key} ;
}

sub reverseLookupTable {
	my ($table) = @_ ;
	
	foreach my $key (keys %{$lookups{$table}->{forward}}) {
		my $value = $lookups{$table}->{forward}->{$key} ;
		die "Cannot reverse lookup table $table; $value has more than one key" if (exists $lookups{$table}->{reverse}->{$value}) ;
		
		$lookups{$table}->{reverse}->{$value} = $key ;
	}
}

sub reverseLookFor {
	my ($value,$table) = @_ ;
	
	readLookupTable($table) if (! exists $lookups{$table}) ;
	reverseLookupTable($table) if (! exists $lookups{$table}->{reverse}) ;
	
	die "Cannot find value $value in Lookup table $table" if (! exists $lookups{$table}->{reverse}->{$value}) ;
	return $lookups{$table}->{reverse}->{$value} ;	
}

sub getLengthOfStay {
	my ($inTime,$outTime) = @_ ;
	return getMinutes($outTime) - getMinutes($inTime) ;
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
	
sub getDialysisItems {
	my $dialysisItems = shift @_ ;
	
	my @items = ("hemodialysis output","HEMODIALYSIS","Hemodialysis removal","hemodialysis","dialysis output","Dialysis out","dialysis","DIALYSIS","dialysis off","Dialysis Output.","Hemodialysis",
				 "PERITONEAL DIALYSIS","hemodialysis out","dialysis intake Free Form Intake","dialysis in Free Form Intake","HEMODIALYSIS OUT","Dialysis Out","Hemodialysis Out","DIALYSIS OUTPUT",
				 "HemoDialysis","Dialysis output","Hemodialysis.","Dialysis Removed","peritoneal dialysis Free Form Intake","crystalloid/dialysis Free Form Intake","dialysis removal",
				 "dialysis/intake Free Form Intake","HEMODIALYSIS.","HEMODIALYSIS OFF","DIALYSIS TOTAL OUT","DIALYSIS REMOVED","hemodialysis crystal Free Form Intake","Hemodialysis OUT","HEMODIALYSIS O/P",
				 "Peritoneal dialysis","Dialysis 1.5% IN Free Form Intake","dialysis flush Free Form Intake","Dialysis In Free Form Intake","KCL-10 MEQ-DIALYSIS Free Form Intake","dialysis removed",
				 "Dialysis","Hemo dialysis out","hemodialysis off","dialysis net","Dialysis fluids Free Form Intake","dialysis- fluid off","hemodialysis ultrafe","CALCIUM-DIALYSIS Free Form Intake",
				 "Citrate - dialysis Free Form Intake","dialysis fluid off","DIALYSIS OFF","dialysis  out","HEMODIALYSIS OUTPUT","dialysis out","DIALYSIS OUT","Dialysis.","Hemodialysis out",
				 "Dialysis indwelling Free Form Intake") ;

	map {$dialysisItems->{reverseLookFor($_,"D_IOITEMS")} = 1} @items ;
}
				 