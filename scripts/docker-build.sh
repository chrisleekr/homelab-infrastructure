#!/bin/bash

set -e

mkdir -p container
cp -r scripts/container/* container

# "$@" forwards every argument from `task docker:build -- ...`, not just the first.
# --load required for Docker Buildx to load image into local Docker daemon
docker build . "$@" --pull --load --progress plain -t chrisleekr/homelab-infrastructure:latest
