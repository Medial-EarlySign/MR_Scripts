#!/bin/bash
#podman build -t ubuntu_medpython .
podman build -t manylinux_medpython .

# Run
# podman run --name test -it --rm ubuntu_medpython  /bin/bash

# Copy files:
# podman create --name my-temp-container ubuntu_medpython
# podman cp my-temp-container:/earlysign/app/MR_LIBS/Internal/MedPyExport/generate_binding/Release/medial-python310 /tmp
# podman rm my-temp-container
