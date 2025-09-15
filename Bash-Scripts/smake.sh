#!/bin/bash

if [ ! -z "$1" ]
then
      touch $MR_ROOT/Libs/Internal/MedUtils/MedUtils/MedGitVersion.h
fi

version_txt=${1-"not\ built\ using\ scripts\ -\ please\ define\ GIT_HEAD_VERSION\ in\ compilation\ or\ use\ smake_rel.sh"}

pushd CMakeBuild/Linux/Release
time make -j 20 -e GIT_HEAD_VERSION="$version_txt"
popd

pushd CMakeBuild/Linux/Debug
time make -j 20 -e GIT_HEAD_VERSION="$version_txt"
popd