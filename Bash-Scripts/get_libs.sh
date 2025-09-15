#!/bin/bash
TARGET_DIR=/nas1/UsersData/git/MR/Tools/AllTools/Linux/Release/Libs
mkdir -p ${TARGET_DIR}

pushd /nas1/Work/SharedLibs/linux/lib64/Release/ 2>&1 > /dev/null
cp -L lib_lightgbm.so libxgboost.so librabit.so ${TARGET_DIR}
popd 2>&1 > /dev/null

pushd /nas1/Work/Libs/Boost/boost_1_67_0/stage/lib 2>&1 > /dev/null
cp -L libboost_regex.so.1.67.0 libboost_program_options.so.1.67.0 libboost_filesystem.so.1.67.0 libboost_system.so.1.67.0 ${TARGET_DIR}
popd 2>&1 > /dev/null

#cp -L /lib64/libicudata.so.50 /lib64/libicui18n.so.50 /lib64/libicuuc.so.50 ${TARGET_DIR}

pushd /nas1/UsersData/git/MR/Libs/Internal/MedPyExport/generate_binding/Release/medial-python38/ 2>&1 > /dev/null
cp -L _medpython.so medpython.py med.py ${TARGET_DIR}
popd 2>&1 > /dev/null

pushd ${TARGET_DIR} 2>&1 > /dev/null
ls -l | egrep  "^\-" | awk '{print $NF}' | egrep -v "tar\.(gzip|bz2)$" | tar -cvjSf libs.tar.bz2 -T - 
popd 2>&1 > /dev/null

echo "libs are packed in ${TARGET_DIR}/libs.tar.bz2"