#!/bin/bash

GIT_MR_ROOT=/nas1/UsersData/ron-internal/MR_git
THREAD_NUM=20
TM_STR=`date +%d-%m-%Y_%H:%M:%S`

echo "git pull resources"
cd ${GIT_MR_ROOT}/Projects/Resources; git reset --hard origin/master; git pull --ff-only > /dev/null
echo "git pull resources done!"
echo "git pull scripts"
cd ${GIT_MR_ROOT}/Projects/Scripts; git reset --hard origin/master; git pull --ff-only > /dev/null
echo "git pull done!"
echo "git pull libs"
cd ${GIT_MR_ROOT}/Libs; git reset --hard origin/master; git pull --ff-only > /dev/null
echo "git pull libs done!"
echo "git pull nba"
cd ${GIT_MR_ROOT}/Projects/Shared/nba; git reset --hard origin/master; git pull --ff-only > /dev/null

#prepare note
echo "git pull nba done!"
pushd ${GIT_MR_ROOT}/Libs > /dev/null
git_libs_info=`git log -n 1 --no-notes --date=short --pretty=format:"\\\\\\\\n=>Libs Git Head: %H by %cn at %ad\\\\\\\\nLast Commit Note: %s"`
popd > /dev/null
pushd ${GIT_MR_ROOT}/Projects/Shared/nba > /dev/null
git_nba_info=`git log -n 1 --no-notes --date=short --pretty=format:"\\\\\\\\n=>NBA Git Head: %H by %cn at %ad\\\\\\\\nLast Commit Note: %s"`
popd > /dev/null
git_info=`echo -E Build on ${TM_STR}${git_libs_info}${git_nba_info}`

echo "About to print ${git_info}"
touch ${GIT_MR_ROOT}/Libs/Internal/MedUtils/MedUtils/MedGitVersion.h

#build:
cd ${GIT_MR_ROOT}/Projects/Shared/nba
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
ls -l | egrep  "^\-" | awk '{print $NF}' | egrep -v "README|tar\.gzip$" | awk '{print " " $1}' | xargs -L1 strip
#wrap in gzip
ls -l | egrep  "^\-" | awk '{print $NF}' | grep -v "tar\.gzip$" | tar -cvzf nba_bin_apps.tar.gzip -T -
popd > /dev/null