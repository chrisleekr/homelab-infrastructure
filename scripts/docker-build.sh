#!/bin/bash

set -e

ARGS=${1:-""}

mkdir -p container
cp -r scripts/container/* container

# shellcheck disable=SC2086
# --load required for Docker Buildx to load image into local Docker daemon
docker build . ${ARGS} --pull --load --progress plain -t chrisleekr/homelab-infrastructure:latest
