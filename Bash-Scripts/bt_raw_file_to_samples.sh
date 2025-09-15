INPUT=$1
COHORT=$2

if [ -z $INPUT ]; then
	echo "Please provide bt raw file path"
	exit -1
fi

if [ ! -f $INPUT ]; then
	echo "Please provide path to legal bt raw file"
	exit -1
fi

set -eo pipefail

cat $INPUT | awk -F"\t" -v cohort="$COHORT" 'BEGIN {OFS="\t"; print "EVENT_FIELDS","id","time","outcome","outcomeTime","split","pred_0"} NR>1 && (cohort=="" || $1==cohort) {print "SAMPLE", $4,$5,$3,$6,$7,$2}'

