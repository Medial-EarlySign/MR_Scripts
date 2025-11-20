#!/bin/bash
#podman build -t ubuntu_algomarker_wrapper .
podman build -t manylinux_algomarker_wrapper .

# Run
# podman run --name test -it --rm ubuntu_algomarker_wrapper  /bin/bash

# Copy files:
# podman create --name my-temp-container ubuntu_algomarker_wrapper
# podman cp my-temp-container:/earlysign/app/MR_Tools/AlgoMarker_python_API/ServerHandler/Linux/Release/AlgoMarker_Server /tmp
# podman rm my-temp-container
