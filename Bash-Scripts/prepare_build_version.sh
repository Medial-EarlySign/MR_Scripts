#!/bin/bash
FAST_FLAG=${1-0}
version_txt=$2

if [ -z "$2" ]; then
	version_txt=`get_git_status_text.py | sed 's|"||g' | awk -F"\t" '{print "\"" $1 "\""}'`
fi

if [ $FAST_FLAG -lt 1 ]; then
	touch ${MR_ROOT}/Libs/Internal/MedUtils/MedUtils/MedGitVersion.h
fi

