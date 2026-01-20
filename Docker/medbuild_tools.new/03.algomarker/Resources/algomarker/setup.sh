#!/bin/bash
set -e

SETUP_PATH=/earlysign/app

mkdir -p ${SETUP_PATH} && cd ${SETUP_PATH}

git clone https://github.com/Medial-EarlySign/medpython.git MR_LIBS

sed -i 's|-G "Unix Makefiles"|-DCMAKE_CXX_FLAGS="-std=c++17" -G "Unix Makefiles"|g' MR_LIBS/Internal/AlgoMarker/full_build.sh

MR_LIBS/Internal/AlgoMarker/full_build.sh