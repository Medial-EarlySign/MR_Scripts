#!/bin/bash
set -e

SETUP_PATH=/earlysign/app

mkdir -p ${SETUP_PATH} && cd ${SETUP_PATH}

# apt-get install python3-pip -y
# ln -s $(which python3) /usr/bin/python

git clone https://github.com/Medial-EarlySign/medpython.git MR_LIBS
# add pandas, ipython, plotly to requirements

PYBINARIES=(
    #"/usr/local/bin/python3.10"
    #"/usr/local/bin/python3.11"
    "/usr/local/bin/python3.12"
    #"/usr/local/bin/python3.13"
    #"/usr/local/bin/python3.14"
)

cd MR_LIBS/Internal/MedPyExport/generate_binding

set +e
GIT_COMMIT_HASH=$(git rev-parse HEAD)
vesrion_in_toml=$(cat pyproject.toml | grep version | cut -d " " -f 3 | sed 's|"||g')
version_txt=$(date +'Version_'${vesrion_in_toml}'_Commit_'${GIT_COMMIT_HASH}'_Build_On_%Y%m%d_%H:%M:%S')
set -e
echo -e "Git version info:\n${version_txt}"
export GIT_HEAD_VERSION=$version_txt 

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
        auditwheel repair "$whl" --plat manylinux2014_aarch64 -w wheelhouse/
    done
    
    # Clean up the unrepaired wheel to save space
    rm dist/*.whl
done

# Generate dissourcet:
#${PYBINARIES[-1]} -m build --sdist --outdir wheelhouse/

# Prepare executables to be able to run with "lib" defined as relative path:
#tar -cvjf /earlysign/all_tools.tar.bz2 -C /earlysign/app/MR_Tools/AllTools/Linux Release

#echo "Final Path: /earlysign/all_tools.tar.bz2"