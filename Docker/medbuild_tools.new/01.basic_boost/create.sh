#!/bin/bash
podman build -t ubuntu_boost .

# Run
# podman run --name test -it --rm ubuntu_boost  /bin/bash