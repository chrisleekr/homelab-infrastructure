#!/bin/bash

set -e

DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" &>/dev/null && pwd)

# shellcheck source=/dev/null
[[ -f ".env" ]] && source ".env"

# shellcheck source=/dev/null
source "${DIR}/docker-build.sh"

docker stop "homelab-infrastructure" || true

docker run -it --rm -d \
  --name "homelab-infrastructure" \
  -v "$HOME/.ssh:/root/.ssh" \
  -v "$(pwd):/srv" \
  -v "$(pwd)/container/root:/root:rw" \
  chrisleekr/homelab-infrastructure:latest

echo "*******"
echo "You can now access to the container by executing the following command:"
echo " $ docker exec -it \"homelab-infrastructure\" /bin/bash"
echo "If you ran 'task docker:exec', you should see the container bash at /srv."
echo "*******"
