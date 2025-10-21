#!/bin/bash
podman build -t ubuntu_tools .

# Run
# podman run --name test -it --rm ubuntu_tools  /bin/bash

# Copy files:
# podman create --name my-temp-container ubuntu_tools
# podman cp my-temp-container:/earlysign/all_tools.tar.bz2 /tmp
# podman rm my-temp-container
