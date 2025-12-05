#!/bin/bash
set -e

SETUP_PATH=/earlysign/app

mkdir -p ${SETUP_PATH} && cd ${SETUP_PATH}

git clone https://github.com/Medial-EarlySign/MR_Tools.git
git clone https://github.com/Medial-EarlySign/medpython.git MR_LIBS

#sed -i 's|#set(BOOST_ROOT.*|set(BOOST_ROOT "/earlysign/Boost")|g' MR_Tools/AllTools/CMakeLists.txt
export BOOST_ROOT="/earlysign/Boost"
sed -i 's|-G "Unix Makefiles"|-DCMAKE_POLICY_VERSION_MINIMUM=3.5 -DCMAKE_CXX_FLAGS="-std=c++17" -G "Unix Makefiles"|g' MR_Tools/AllTools/full_build.sh

MR_Tools/AllTools/full_build.sh

# Prepare executables to be able to run with "lib" defined as relative path:
patchelf --set-rpath '$ORIGIN/lib' /earlysign/app/MR_Tools/AllTools/Linux/Release/*

mkdir -p /earlysign/app/MR_Tools/AllTools/Linux/Release/lib

cp -r /earlysign/app/MR_LIBS/External/xgboost/lib/libxgboost.so /earlysign/app/MR_LIBS/External/LightGBM_2.2.3/LightGBM-2.2.3/lib_lightgbm.so /earlysign/Boost/lib/* /earlysign/app/MR_Tools/AllTools/Linux/Release/lib

echo "All Done, you can copy executables from (with "lib" folder inside): /earlysign/app/MR_Tools/AllTools/Linux/Release"
echo "Packing all in Zip file"

tar -cvjf /earlysign/all_tools.tar.bz2 -C /earlysign/app/MR_Tools/AllTools/Linux Release

echo "Final Path: /earlysign/all_tools.tar.bz2"