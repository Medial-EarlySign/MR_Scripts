#!/bin/bash

set -e
GIT_MR_ROOT=/nas1/UsersData/git/MR
if [ -z "$MR_ROOT" ]; then
	export MR_ROOT=${GIT_MR_ROOT}
	export PATH=$PATH:${GIT_MR_ROOT}/Projects/Scripts/Python-scripts
fi
THREAD_NUM=20
TM_STR=`date +%d-%m-%Y_%H:%M:%S`
CANCEL_NAITE_OPT=${1-0}

cd ${GIT_MR_ROOT}/Projects/Resources; git reset --hard origin/master; git pull --ff-only > /dev/null
cd ${GIT_MR_ROOT}/Projects/Scripts; git reset --hard origin/master; git pull --ff-only > /dev/null
cd ${GIT_MR_ROOT}/Libs; git reset --hard origin/master; git pull --ff-only > /dev/null
cd ${GIT_MR_ROOT}/Tools; git reset --hard origin/master; git pull --ff-only > /dev/null

NAME_FINAL=bin_apps

cd ${GIT_MR_ROOT}/Tools/AllTools
if [ ${CANCEL_NAITE_OPT} -gt 0 ]; then
	NAME_FINAL=bin_apps.x86-64
	./full_build.x86_64.sh
else
	./full_build.sh
fi

pushd Linux/Release > /dev/null
#Add README
echo -e "Version Info:\n${version_txt}" > README
#clean debug symbold:
ls -l | egrep  "^\-" | awk '{print $NF}' | egrep -v "README|tar\.(gzip|bz2)$" | awk '{print " " $1}' | xargs -L1 strip
#wrap in gzip
ls -l | egrep  "^\-" | awk '{print $NF}' | egrep -v "tar\.(gzip|bz2)$" | tar -cvjSf ${NAME_FINAL}.tar.bz2 -T -
FULL_PATH=$(realpath ${NAME_FINAL}.tar.bz2)
popd > /dev/null

echo "Done ${FULL_PATH}"
