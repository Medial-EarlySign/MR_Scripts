#!/bin/bash
set -e

SETUP_PATH=/earlysign/app

mkdir -p ${SETUP_PATH} && cd ${SETUP_PATH}

# apt-get install python3-pip -y
# ln -s $(which python3) /usr/bin/python

git clone https://github.com/Medial-EarlySign/MR_LIBS.git
git clone https://github.com/Medial-EarlySign/MR_Tools.git
cp -R MR_Tools/RepoLoadUtils/common/ETL_Infra MR_LIBS/Internal/MedPyExport/generate_binding/src/
# add pandas, ipython, plotly to requirements

export BOOST_ROOT="/earlysign/Boost"

sed -i 's|^dependencies = \[|dependencies = ["pandas", "plotly", "ipython",|g' MR_LIBS/Internal/MedPyExport/generate_binding/pyproject.toml
# sed -i 's|cmake |cmake -DCMAKE_POLICY_VERSION_MINIMUM=3.10 |g' MR_LIBS/Internal/MedPyExport/generate_binding/make-simple.sh
#-DSWIG_EXECUTABLE=/opt/python/cp314-cp314/bin/swig
#-DPython3_EXECUTABLE=

# ln -sf $(which python3.14) /usr/bin/python
# python -m pip install numpy
# python -m pip install "swig<4.3"
# MR_LIBS/Internal/MedPyExport/generate_binding/make-simple.sh

PYBINARIES=(
    "/usr/local/bin/python3.10"
    "/usr/local/bin/python3.11"
    "/usr/local/bin/python3.12"
    "/usr/local/bin/python3.13"
    "/usr/local/bin/python3.14"
)

cd MR_LIBS/Internal/MedPyExport/generate_binding

mkdir -p wheelhouse
mkdir -p dist

for PYBIN in "${PYBINARIES[@]}"; do
    echo "======================================================="
    echo "Building for ${PYBIN}"
    echo "======================================================="

    ${PYBIN} -m pip install numpy build
    ${PYBIN} -m pip install "swig<4.3"

    ${PYBIN} -m build --wheel --outdir dist/

    for whl in dist/*.whl; do
        auditwheel repair "$whl" --plat manylinux2014_x86_64 -w wheelhouse/
    done
    
    # Clean up the unrepaired wheel to save space
    rm dist/*.whl
done



# Prepare executables to be able to run with "lib" defined as relative path:
#tar -cvjf /earlysign/all_tools.tar.bz2 -C /earlysign/app/MR_Tools/AllTools/Linux Release

#echo "Final Path: /earlysign/all_tools.tar.bz2"