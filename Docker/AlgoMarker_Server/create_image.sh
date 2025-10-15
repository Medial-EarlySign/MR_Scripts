#!/bin/bash
set -e
CURR_DIR=${0%/*}
# Change to the directory of this script
cd ${CURR_DIR}

AM_CONFIG_PATH=${1}
AM_IMAGE_NAME=${2-test_app}
PORT=${3-1234}

if [ -z ${AM_CONFIG_PATH} ]; then
    echo "Usage: $0 <AM_CONFIG_PATH> [IMAGE_NAME] [PORT]"
    echo "  AM_CONFIG_PATH: Path to AlgoMarker config path (e.g., /path/to/.amconfig)"
    echo "  IMAGE_NAME: (Optional) Name for the Docker image (default: test_app)"
    echo "  PORT: (Optional) Port number for the server (default: 1234)"
    exit 1
fi

AM_CONFIG_PATH=$(realpath ${AM_CONFIG_PATH})
AM_CONFIG_PATH_DOCKER=$(realpath -s --relative-to="${CURR_DIR}/data" "${AM_CONFIG_PATH}")

# Make sure paths exists, under "data" folder:
if [ ! -f "${AM_CONFIG_PATH}" ]; then
    echo "Error: AM_CONFIG_PATH '$AM_CONFIG_PATH' does not exist."
    exit 1
fi
AM_DIR=$(dirname "$AM_CONFIG_PATH")
if [ ! -f "${AM_DIR}/lib/libdyn_AlgoMarker.so" ]; then
    echo "Error: $AM_CONFIG_PATH/lib/libdyn_AlgoMarker.so does not exist. Please put the library there."
    exit 1
fi

# Generate a Dockerfile from the template
sed -e "s|\${AM_CONFIG_PATH}|/${AM_CONFIG_PATH_DOCKER}|g" -e "s|\${PORT}|${PORT}|g" Dockerfile.template > Dockerfile

# Run build
podman build -t ${AM_IMAGE_NAME} --no-cache .