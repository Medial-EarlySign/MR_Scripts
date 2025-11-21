#!/bin/bash
set -e

SETUP_PATH=/earlysign/app

mkdir -p ${SETUP_PATH} && cd ${SETUP_PATH}

# apt-get install python3-pip -y
# ln -s $(which python3) /usr/bin/python

ln -sf $(which python3.14) /usr/bin/python
python -m pip install numpy

git clone https://github.com/Medial-EarlySign/MR_LIBS.git

#sed -i 's|#set(BOOST_ROOT.*|set(BOOST_ROOT "/earlysign/Boost")|g' MR_LIBS/Internal/MedPyExport/generate_binding/CMakeLists.txt
export BOOST_ROOT="/earlysign/Boost"

python -m pip install "swig<4.3"
sed -i 's|cmake |cmake -DCMAKE_POLICY_VERSION_MINIMUM=3.10 -DSWIG_EXECUTABLE=/opt/python/cp314-cp314/bin/swig |g' MR_LIBS/Internal/MedPyExport/generate_binding/make-simple.sh


MR_LIBS/Internal/MedPyExport/generate_binding/make-simple.sh

# Prepare executables to be able to run with "lib" defined as relative path:
#tar -cvjf /earlysign/all_tools.tar.bz2 -C /earlysign/app/MR_Tools/AllTools/Linux Release

#echo "Final Path: /earlysign/all_tools.tar.bz2"