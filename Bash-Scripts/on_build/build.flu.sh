#!/bin/bash

GIT_MR_ROOT=/nas1/UsersData/git/MR
THREAD_NUM=20
TM_STR=`date +%d-%m-%Y_%H:%M:%S`

cd ${GIT_MR_ROOT}/Projects/Resources; git reset --hard origin/master; git pull --ff-only > /dev/null
cd ${GIT_MR_ROOT}/Projects/Scripts; git reset --hard origin/master; git pull --ff-only > /dev/null
cd ${GIT_MR_ROOT}/Libs; git reset --hard origin/master; git pull --ff-only > /dev/null
cd ${GIT_MR_ROOT}/Projects/Shared/AlgoMarkers/Influenza; git reset --hard origin/master; git pull --ff-only > /dev/null
#yaron prepare
cd ${GIT_MR_ROOT}/Projects/Shared/Influenza; git reset --hard origin/master; git pull --ff-only > /dev/null
#run_sim
cd ${GIT_MR_ROOT}/Projects/Shared/WildLands; git reset --hard origin/master; git pull --ff-only > /dev/null

#prepare note
pushd ${GIT_MR_ROOT}/Libs > /dev/null
git_libs_info=`git log -n 1 --no-notes --date=short --pretty=format:"\\\\\\\\n=>Libs Git Head: %H by %cn at %ad\\\\\\\\nLast Commit Note: %s"`
popd > /dev/null
pushd ${GIT_MR_ROOT}/Projects/Shared/AlgoMarkers/Influenza > /dev/null
git_tools_info=`git log -n 1 --no-notes --date=short --pretty=format:"\\\\\\\\n=>AlgoMarkers Influenza Git Head: %H by %cn at %ad\\\\\\\\nLast Commit Note: %s"`
popd > /dev/null
pushd ${GIT_MR_ROOT}/Projects/Shared/WildLands > /dev/null
git_sim_info=`git log -n 1 --no-notes --date=short --pretty=format:"\\\\\\\\n=>WildLands Git Head: %H by %cn at %ad\\\\\\\\nLast Commit Note: %s"`
popd > /dev/null
pushd ${GIT_MR_ROOT}/Projects/Shared/Influenza > /dev/null
git_flu_info=`git log -n 1 --no-notes --date=short --pretty=format:"\\\\\\\\n=>prepare_sample_influenza Git Head: %H by %cn at %ad\\\\\\\\nLast Commit Note: %s"`
popd > /dev/null
git_info=`echo -E Build on ${TM_STR}${git_libs_info}${git_tools_info}${git_sim_info}${git_flu_info}`

echo "About to print ${git_info}"
touch ${GIT_MR_ROOT}/Libs/Internal/MedUtils/MedUtils/MedGitVersion.h

#build:
cd ${GIT_MR_ROOT}/Projects/Shared/AlgoMarkers/Influenza/code/InfluenzaRegistry
${GIT_MR_ROOT}/Projects/Scripts/Perl-scripts/new_create_cmake_files.pl
pushd CMakeBuild/Linux/Release > /dev/null
git_escaped=$git_info
git_escaped=${git_escaped//\\\\n/\\n}
time make -j ${THREAD_NUM} -e GIT_HEAD_VERSION="\"${git_escaped}\""
popd  > /dev/null
pushd Linux/Release > /dev/null
#clean debug symbold:
git_readme=${git_info//\\\\/\\}
echo -e "Version Info:\n${git_readme}" > README
ls -l | egrep  "^\-" | awk '{print $NF}' | egrep -v "README|tar\.(gzip|bz2)$" | awk '{print " " $1}' | xargs -L1 strip
#wrap in gzip
ls -l | egrep  "^\-" | awk '{print $NF}' | egrep -v "tar\.(gzip|bz2)$" | tar -cvjSf flu_bin_apps.tar.bz2 -T -
popd > /dev/null