#!/bin/bash
#export binary fully - with shared libs

if [ -z "$1" ]; then
	echo "please specify binary file"
else
	echo "preparing for $1"
	if [ -f $1 ]; then
		fld_name=${1%/*}/${1##*/}_standalone
		echo "creating dir $fld_name"
		mkdir -p $fld_name
		ldd $1 | awk '{ if ( index($0, "=>") > 0) {print $3} else {print $1} }' | egrep -v "^\(" | awk -v fld=$fld_name '{print " \""$0"\" "fld}' | xargs -L1 cp 
		pushd ${1%/*}
		tar -cvzf ${1##*/}.tar.gzip ${1##*/} ${1##*/}_standalone 
		popd
		rm -fr $fld_name
	else
		echo "$1 not exists"
	fi
fi
