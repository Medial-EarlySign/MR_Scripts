#!/bin/bash
set -e

SETUP_PATH=/earlysign/app

mkdir -p ${SETUP_PATH} && cd ${SETUP_PATH}

git clone https://github.com/Medial-EarlySign/MR_Tools.git

sed -i 's|#set(BOOST_ROOT.*|set(BOOST_ROOT "/earlysign/Boost")|g' MR_Tools/AlgoMarker_python_API/ServerHandler/CMakeLists.txt

MR_Tools/AlgoMarker_python_API/ServerHandler/compile.sh