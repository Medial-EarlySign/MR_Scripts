#!/bin/bash

urlencode() {
    # urlencode <string>
    old_lc_collate=$LC_COLLATE
    LC_COLLATE=C
    
    local length="${#1}"
    for (( i = 0; i < length; i++ )); do
        local c="${1:i:1}"
        case $c in
            [a-zA-Z0-9.~_-]) printf "$c" ;;
            *) printf '%%%02X' "'$c" ;;
        esac
    done
    
    LC_COLLATE=$old_lc_collate
}

urldecode() {
    # urldecode <string>

    local url_encoded="${1//+/ }"
    printf '%b' "${url_encoded//%/\\x}"
}

# Read Password
echo -n Your git username: 
read GIT_USER
echo -n Your git password: 
read -s GIT_PASS
echo
echo -n "AM GIT tag to build(can be 'master' or 'lc_1_140719'):"
read GIT_TAG

CONTAINER_NAME=medbuild_algomarker2:${GIT_USER}_build

if [[ ! "$(docker images -q ${CONTAINER_NAME} 2> /dev/null)" == "" ]]; then
  echo "Delete older build of ${CONTAINER_NAME}"
  docker rmi ${CONTAINER_NAME}
fi

GIT_PASS=`urlencode "${GIT_PASS}"`
GIT_USER=`urlencode "${GIT_USER}"`

docker build --build-arg GIT_TAG="$GIT_TAG" --build-arg GIT_USER="${GIT_USER}" --build-arg GIT_PASS="${GIT_PASS}" -t ${CONTAINER_NAME} . && \
retVal=$?
if [ "$retVal" = "0" ]; then
  echo "(II) docker build returned '$retVal'"
else
  echo "ERROR: Build returned '$retVal'"
  exit 1
fi
if [[ ! "$(docker images -q ${CONTAINER_NAME} 2> /dev/null)" == "" ]]; then
  SO_FILE="./Release/libdyn_AlgoMarker.2.${GIT_TAG}.so"
  TESTER_FILE="./Release/AMApiTester.2.${GIT_TAG}"
  mkdir -p ./Release/
  rm -f ${SO_FILE} ${TESTER_FILE}
  echo "(II) Extracting SO to ${SO_FILE}"
  docker run --rm --entrypoint cat ${CONTAINER_NAME} /Release/libdyn_AlgoMarker.2.so > ${SO_FILE}
  echo "(II) Extracting ApiTester to ${TESTER_FILE}"
  docker run --rm --entrypoint cat ${CONTAINER_NAME} /Release/AMApiTester.2 > ${TESTER_FILE}
else
  echo "ERROR: Cannot extract files from '${CONTAINER_NAME}', image doesn't exist"
fi
