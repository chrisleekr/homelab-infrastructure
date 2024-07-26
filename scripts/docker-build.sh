#!/bin/bash

set -e

ARGS=${1:-""}

# shellcheck disable=SC2086
docker build . ${ARGS} --pull --progress plain -t chrisleekr/homelab-infrastructure:latest
