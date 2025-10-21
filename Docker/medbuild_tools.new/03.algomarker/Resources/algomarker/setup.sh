#!/bin/bash
set -e

SETUP_PATH=/earlysign/app

mkdir -p ${SETUP_PATH} && cd ${SETUP_PATH}

mkdir -p /root/.ssh
ssh-keyscan gitlab.com >> /root/.ssh/known_hosts

git clone https://github.com/Medial-EarlySign/MR_LIBS.git

sed -i 's|#set(BOOST_ROOT.*|set(BOOST_ROOT "/earlysign/Boost")|g' MR_LIBS/Internal/AlgoMarker/CMakeLists.txt

MR_LIBS/Internal/AlgoMarker/full_build.sh