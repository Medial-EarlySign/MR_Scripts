#!/bin/bash
podman build -t ubuntu_algomarker .

# Run
# podman run --name test -it --rm ubuntu_algomarker  /bin/bash

# Copy files:
# podman create --name my-temp-container ubuntu_algomarker
# podman cp my-temp-container:/earlysign/app/MR_LIBS/Internal/AlgoMarker/Linux/Release/libdyn_AlgoMarker.so /tmp
# podman rm my-temp-container
