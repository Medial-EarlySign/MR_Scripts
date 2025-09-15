#!/bin/bash
version_txt=$1
if [ ! -z "$1" ]
then
      #touch $MR_ROOT/Libs/Internal/MedUtils/MedUtils/MedGitVersion.h
	  echo "Version Info:\n${version_txt}"
else
	version_txt=`get_git_status_text.py | sed 's|"||g' | awk -F"\t" '{print "\"" $1 "\""}'`
	echo -e "Git version info:\n${version_txt}"
fi

touch ${MR_ROOT}/Libs/Internal/MedUtils/MedUtils/MedGitVersion.h

pushd CMakeBuild/Linux/Release
time make -j 20 -e GIT_HEAD_VERSION="$version_txt"
popd