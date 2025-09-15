#!/bin/bash
THREAD_NUM=20
FAST_FLAG=${1-0}

pushd $MR_ROOT/Tools/AllTools

./full_build.sh ${FAST_FLAG}

popd
