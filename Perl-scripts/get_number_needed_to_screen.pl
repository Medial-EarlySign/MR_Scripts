#!/usr/bin/env perl  

use strict(vars) ;

die "Usage: $0 Prefix" if (@ARGV != 1) ;
my $predix = $ARGV[0] ;

# Read Data
my @data ;
while (<>) {
	chomp ;
	my ($current,$score,$label) = split ;
	push @data,[$score,$label] if ($current eq $section) ;
}

# Collect
my %nnts ;
my @sorted = sort {$b->[0] <=> $a->[0]} @data ;
	
my ($npos,$nneg) = (0,0) ;
for my $rec (@sorted) {
	if ($rec->[1] == 1) {
		$npos ++ ;
	} else {
		$nneg ++ ;
	}

	$nnts{$nneg} = ($npos > 0) ? ($nneg + $npos)/$npos : "INF" ;
}

# Print
my $data_file = "TempData" ;
open (OUT,">$data_file") or die "Cannot open $data_file for writing" ;

my $out = join "\t",("NNEG","NNTS") ;
print OUT "$out\n" ;

for my $nneg (sort {$a<=>$b} keys %nnts) {
	print OUT "$nneg $nnts{$nneg}\n" ;
}
close OUT ;

# R script
my $r_file = "$prefix.Script.R" ;
my $graph1_file = "$prefix.graph1.jpeg" ;
my $graph2_file = "$prefix.graph2.jpeg" ;
 
open (R,">$r_file") or die "Cannot open $r_file for writing" ;

print R "nnts <- read.table(\"$prefix.Data\",header=T) ; \n".
	    "total.nneg <- nnts\$NNEG[length(nnts\$NNEG)] ; \n".
	    "fpr <- 100*nnts\$NNEG/total.nneg ; \n".
	    "jpeg(\"$graph1_file\") ; \n".
	    "plot(fpr,nnts\$colon,type=\"l\",main=\"Number needed to screen to detect one .... cancer\\n(Time/Age window = $section)\",".
	    "ylab = \"Number\", xlab=\"False Positive Rate (%)\",col=\"$colors[0]\") ; \n".
		"lines(fpr,nnts\$CRC,col=\"$colors[1]\") ; \n".
		"lines(fpr,nnts\$lower,col=\"$colors[2]\") ; \n".
		"lines(fpr,nnts\$DIG,col=\"$colors[3]\") ; \n".
		"legend(\"topleft\",c($legend),col=c($colors),lty=1) ;\n".
		"dev.off() ; \n".
	    "jpeg(\"$graph2_file\") ; \n".
	    "plot(fpr,nnts\$colon,type=\"l\",xlim=c(0.1,2.5),ylim=c(0,20),main=\"Number needed to screen to detect one .... cancer\\n(Time/Age window = $section)\",".
	    "ylab = \"Number\", xlab=\"False Positive Rate (%)\",col=\"$colors[0]\") ; \n".
		"lines(fpr,nnts\$CRC,col=\"$colors[1]\") ; \n".
		"lines(fpr,nnts\$lower,col=\"$colors[2]\") ; \n".
		"lines(fpr,nnts\$DIG,col=\"$colors[3]\") ; \n".
		"legend(\"topleft\",c($legend),col=c($colors),lty=1) ;\n".
		"dev.off() ; \n" ;
close R ;

exec("W:\\Applications\\R\\R-latest\\bin\\R CMD BATCH --silent --slave $r_file\n") ;
	