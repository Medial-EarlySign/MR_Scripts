#!/bin/bash

# Read Password
echo -n Your git username: 
read GIT_USER
echo -n Your git password: 
read -s GIT_PASS
echo
echo -n "AM GIT tag to build(can be '25102018_1' (1.0.4) or 'AlgoMarker_1.0.5.0'):"
read GIT_TAG

CONTAINER_NAME=medbuild_algomarker1:${GIT_USER}_build


docker build --build-arg GIT_TAG="$GIT_TAG" --build-arg GIT_USER="${GIT_USER}" --build-arg GIT_PASS="${GIT_PASS}" -t ${CONTAINER_NAME} . && \
mkdir -p ./Release/
docker run --rm --entrypoint cat ${CONTAINER_NAME} /Release/libdyn_AlgoMarker.${GIT_TAG}.so > ./Release/libdyn_AlgoMarker.${GIT_TAG}.so
docker run --rm --entrypoint cat ${CONTAINER_NAME} /Release/AMApiTester.${GIT_TAG} > ./Release/AMApiTester.${GIT_TAG}
