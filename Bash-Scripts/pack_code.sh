#!/bin/bash
set -e
APP_DIR=${1-$MR_ROOT/Tools/Flow}
APP_NAME=${APP_DIR##*/}
BASE_DIR=$(realpath $APP_DIR/..)

#echo "APP_DIR=${APP_DIR}, APPNAME=${APP_NAME}, BASE_DIR=${BASE_DIR}"

pushd $MR_ROOT > /dev/null

find Libs/Internal -readable \( -name '*.h' -o -name '*.cpp' -o -name '*.c' -o -name '*.vcxproj' -o -name '*.sln' -o -name '*.hpp' -o -name '*.txt' \) ! -path '*/CMakeBuild/*' ! -path '*/CMakeFiles/*' ! -path '*/Release/*' ! -path '*/Debug/*' ! -name CMakeLists.txt > /tmp/file_code_list
find Libs/External -readable \( -name '*.h' -o -name '*.cpp' -o -name '*.c' -o -name '*.vcxproj' -o -name '*.sln' -o -name '*.hpp' -o -name '*.txt' \) ! -path '*/CMakeBuild/*' ! -path '*/CMakeFiles/*' ! -path '*/Release/*' ! -path '*/Debug/*' ! -name CMakeLists.txt >> /tmp/file_code_list

popd > /dev/null

pushd $BASE_DIR > /dev/null

find ${APP_NAME} -readable \( -name '*.h' -o -name '*.cpp' -o -name '*.c' -o -name '*.vcxproj' -o -name '*.sln' -o -name '*.hpp' -o -name '*.txt' \) ! -path '*/CMakeBuild/*' ! -path '*/CMakeFiles/*' ! -path '*/Release/*' ! -path '*/Debug/*' ! -name CMakeLists.txt > /tmp/file_code_list_app

popd > /dev/null

OUTPUT_PATH=/server/Linux/${USER%-*}/code.tar.bz2
UNCOMPRESSED=${OUTPUT_PATH%.*}

tar -cSf ${UNCOMPRESSED} -C $MR_ROOT -T /tmp/file_code_list
tar -rSf ${UNCOMPRESSED} -C ${BASE_DIR} -T /tmp/file_code_list_app
bzip2 -z ${UNCOMPRESSED} -f

echo "The files are in: ${OUTPUT_PATH}"
