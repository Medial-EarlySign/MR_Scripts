#!/bin/bash
set -e
# Change to the directory of this script
cd ${0%/*}

AM_CONFIG_PATH=${1-/app/LGI-Flag-ButWhy-3.1.2-Scorer/LGI-ColonFlag-3.1.amconfig}
PORT=${2-1234}

# Make sure paths exists, under "data" folder:
if [ ! -f "data$AM_CONFIG_PATH" ]; then
    echo "Error: AM_CONFIG_PATH '$AM_CONFIG_PATH' does not exist."
    exit 1
fi
AM_DIR=$(dirname "$AM_CONFIG_PATH")
if [ ! -f "data$AM_DIR/lib/libdyn_AlgoMarker.so" ]; then
    echo "Error: data$AM_CONFIG_PATH/lib/libdyn_AlgoMarker.so does not exist. Please put the library there."
    exit 1
fi

# Generate a Dockerfile from the template
sed -e "s|\${AM_CONFIG_PATH}|${AM_CONFIG_PATH}|g" -e "s|\${PORT}|${PORT}|g" Dockerfile.template > Dockerfile

# Run build
podman build -t lgiflag_app --no-cache .