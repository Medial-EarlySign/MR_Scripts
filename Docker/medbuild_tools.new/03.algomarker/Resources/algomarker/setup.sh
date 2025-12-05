#!/bin/bash
set -e

SETUP_PATH=/earlysign/app

mkdir -p ${SETUP_PATH} && cd ${SETUP_PATH}

git clone https://github.com/Medial-EarlySign/medpython.git MR_LIBS

#sed -i 's|#set(BOOST_ROOT.*|set(BOOST_ROOT "/earlysign/Boost")|g' MR_LIBS/Internal/AlgoMarker/CMakeLists.txt
export BOOST_ROOT="/earlysign/Boost"

sed -i 's|-G "Unix Makefiles"|-DCMAKE_POLICY_VERSION_MINIMUM=3.5 -DCMAKE_CXX_FLAGS="-std=c++17" -G "Unix Makefiles"|g' MR_LIBS/Internal/AlgoMarker/full_build.sh

MR_LIBS/Internal/AlgoMarker/full_build.sh
# For certain reason need to rerun to link static boost
MR_LIBS/Internal/AlgoMarker/full_build.sh