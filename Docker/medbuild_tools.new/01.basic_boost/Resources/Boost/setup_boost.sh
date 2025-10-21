#!/bin/bash

# Download Boost
VERSION=1.85.0
VERSION_2=$(echo ${VERSION} | awk -F. '{print $1 "_" $2 "_" $3}')
wget https://archives.boost.io/release/${VERSION}/source/boost_${VERSION_2}.tar.bz2

# Extract files
tar -xjf boost_${VERSION_2}.tar.bz2
rm -f boost_${VERSION_2}.tar.bz2

# Set up Boost install directory in current dir
WORK_BUILD_FOLDER=$(realpath .)
cd boost_${VERSION_2}

# Configure and clean
./bootstrap.sh
./b2 --clean

# Build static libraries
./b2 cxxflags="-march=x86-64" link=static variant=release linkflags=-static-libstdc++ -j8 cxxflags="-fPIC" --stagedir="${WORK_BUILD_FOLDER}/Boost" --with-program_options --with-system --with-regex --with-filesystem

mkdir -p ${WORK_BUILD_FOLDER}/Boost/include

# Link headers to Boost/include
ln -sf ${WORK_BUILD_FOLDER}/boost_${VERSION_2}/boost  ${WORK_BUILD_FOLDER}/Boost/include

# Build shared libraries (not needed for AlgoMarker, but needed for MES tools if you choose to compile)
./b2 cxxflags="-march=x86-64" link=shared variant=release linkflags=-static-libstdc++ -j8 cxxflags="-fPIC" --stagedir="${WORK_BUILD_FOLDER}/Boost" --with-program_options --with-system --with-regex --with-filesystem