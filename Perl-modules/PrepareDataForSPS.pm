# Read Analysis (base + raw) files and prepare for input to Study-Performance-System.

package PrepareDataForSPS ;
use Exporter qw(import) ;

our @EXPORT_OK = qw(prepare_data_for_SPS) ;

sub prepare_data_for_SPS {
	my ($inPrefix,$outPrefix,$resolution,@xml_fields) = @_ ;

	# Write Info
	open (INFO,">$outPrefix.info.xml") or die "Cannot open information file for writing" ;
	print INFO "<?xml version=\"1.0\"?>\n" ;
	print INFO "<Info>\n" ;

	for (my $idx=0; $idx<$#xml_fields; $idx+=2) {
		my ($key,$value) = ($xml_fields[$idx],$xml_fields[$idx+1]) ;
		print INFO "\t<$key>$value</$key>\n" ;
	}

	print INFO "</Info>\n" ;
	close INFO ;

	# Base 
	open (ANL,$inPrefix) or die "Cannot open $inPrefix for reading" ;
	open (DATA,">$outPrefix.data.txt") or die "Canont open data file for writing" ;

	my $header = 1 ;
	while (<ANL>) {
		if ($header == 1) {
			s/Age-Range/Age_Range/ ;
			s/Time-Window/Time_Window/ ;
			s/CI-Upper/CI_Upper/g ;
			s/CI-Lower/CI_Lower/g ;
			
			s/FP1.0/FP1/g ; # For Old Versions
			s/FP5.0/FP5/g ; # For Old Versions
			
			$header = 0 ;
		}
		print DATA $_ ;
	}
	close ANL ;
	close DATA ;

	# Raw -> Cureves
	open (RAW,"$inPrefix.Raw") or die "Cannot open $inPrefix.Raw for reading" ;
	open (CRV,">$outPrefix.curves.xml") or die "Canont open data file for writing" ;

	print CRV "<?xml version=\"1.0\"?>\n" ;
	print CRV "<Curves>\n" ;

	my %data ;
	my @tags ;
	while (<RAW>) {
		chomp ;
		my ($tag,$score,$label) = split ;
		push @tags,$tag if (! exists $data{$tag}) ;
		push @{$data{$tag}},[$score,$label] ;
	}
	close RAW ;

	foreach my $tag (@tags) {
		
		$tag =~ /(\d+-\d+)-(\d+-\d+)/ or die "Cannot parse tag $tag\n" ;
		my ($time_window,$age_range) = ($1,$2) ;
		
		my @points = sort {$b->[0] <=> $a->[0]} @{$data{$tag}} ;
		my $n = scalar @points ;
		my $np = scalar (grep {$_->[1] == 1} @points) ;
		my $nn = $n - $np ;
		my $p = $resolution/$n ;
		
		# FP and TP
		my @stats = ([0,0]) ;
		foreach my $point (@points) {
			push @stats,[$stats[-1]->[0],$stats[-1]->[1]] ;
			$stats[-1]->[$point->[1]] ++ ;
		}
		push @stats,[$nn,$np] ;

		# ROC
		print CRV "\t<Curve>\n" ;
		print CRV "\t\t<Name>ROC curve</Name>\n" ;
		print CRV "\t\t<TimeWindow>$time_window</TimeWindow>\n" ;
		print CRV "\t\t<AgeRange>$age_range</AgeRange>\n" ;
		print CRV "\t\t<XLabel>False Positive Rate</XLabel>\n" ;
		print CRV "\t\t<YLabel>True Positive Rate</YLabel>\n" ;
		print CRV "\t\t<Points>\n" ;
		
		foreach my $i (0..$#stats) {
			if ($i==0 or $i==$#stats or rand() < $p) {
				my $fpr = $stats[$i]->[0]/$nn ;
				my $tpr = $stats[$i]->[1]/$np ;
				print CRV "\t\t\t$fpr,$tpr\n" ;
			}
		}
		print CRV "\t\t</Points>\n" ;
		print CRV "\t</Curve>\n" ;

		# Recall-Precision
		print CRV "\t<Curve>\n" ;
		print CRV "\t\t<Name>Recall-Precision curve</Name>\n" ;
		print CRV "\t\t<TimeWindow>$time_window</TimeWindow>\n" ;
		print CRV "\t\t<AgeRange>$age_range</AgeRange>\n" ;
		print CRV "\t\t<XLabel>Recall</XLabel>\n" ;
		print CRV "\t\t<YLabel>Precision</YLabel>\n" ;
		print CRV "\t\t<Points>\n" ;
		
		foreach my $i (0..$#stats) {
			if ($i!=0 and ($i==$#stats or rand() < $p)) {
				my $recall = $stats[$i]->[1]/$np ;
				my $precision = $stats[$i]->[1]/($stats[$i]->[0]+$stats[$i]->[1]) ;
				print CRV "\t\t\t$recall,$precision\n" ;
			}
		}
		print CRV "\t\t</Points>\n" ;
		print CRV "\t</Curve>\n" ;
	}
	print CRV "</Curves>\n" ;
	close CRV ;
}