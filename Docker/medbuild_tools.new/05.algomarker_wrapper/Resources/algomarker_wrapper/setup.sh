#!/bin/bash
set -e

SETUP_PATH=/earlysign/app

mkdir -p ${SETUP_PATH} && cd ${SETUP_PATH}

git clone https://github.com/Medial-EarlySign/MR_Tools.git

MR_Tools/AlgoMarker_python_API/ServerHandler/compile.sh