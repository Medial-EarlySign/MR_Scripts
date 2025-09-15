#!/bin/bash

#after build of All Tools - take all libs from tools
#tar --transform 's/.*\///g' -zcvf /server/Linux/alon/libs.tar.gzip /server/UsersData/git/MR/Projects/Shared/AllTools/CMakeBuild/Linux/Release/*/*.a /server/Work/SharedLibs/linux/lib64/Release/* /server/Work/Libs/Boost/boost_1_67_0/lib/libboost_filesystem.so.1.67.0 /server/Work/Libs/Boost/boost_1_67_0/lib/libboost_program_options.so.1.67.0 /server/Work/Libs/Boost/boost_1_67_0/lib/libboost_regex.so.1.67.0 /server/Work/Libs/Boost/boost_1_67_0/lib/libboost_system.so.1.67.0

#/lib64/libicudata.so.50.1.2
#/lib64/libicui18n.so.50.1.2
#/lib64/libicuuc.so.50.1.2

BOOST_BASE=/server/Work/Libs/Boost/boost_1_85_0/installation/lib

tar --transform 's/.*\///g' -cjSvf /server/Linux/${USER%-*}/libs.tar.bz2 /server/Work/SharedLibs/linux/ubuntu/Release/* ${BOOST_BASE}/libboost_filesystem.so.1.85.0 ${BOOST_BASE}/libboost_program_options.so.1.85.0 ${BOOST_BASE}/libboost_regex.so.1.85.0 ${BOOST_BASE}/libboost_system.so.1.85.0 ${BOOST_BASE}/libboost_atomic.so.1.85.0

echo "The files are in: /server/Linux/${USER%-*}/libs.tar.bz2"
