#!/bin/bash

mkdir -p host-keys

# If ssh_host_rsa_key exists, it will not be overwritten
if [ ! -f host-keys/ssh_host_rsa_key ]; then
  ssh-keygen -t rsa -f host-keys/ssh_host_rsa_key -N "" -m PEM >/dev/null
fi

if [ ! -f host-keys/ssh_host_dsa_key ]; then
  ssh-keygen -t dsa -f host-keys/ssh_host_dsa_key -N "" -m PEM >/dev/null
fi

if [ ! -f host-keys/ssh_host_ecdsa_key ]; then
  ssh-keygen -t ecdsa -f host-keys/ssh_host_ecdsa_key -N "" -m PEM >/dev/null
fi

if [ ! -f host-keys/ssh_host_ed25519_key ]; then
  ssh-keygen -t ed25519 -f host-keys/ssh_host_ed25519_key -N "" -m PEM >/dev/null
fi

echo "{
\"ssh_host_rsa_key\": \"$(base64 -w 0 host-keys/ssh_host_rsa_key)\",
\"ssh_host_rsa_key.pub\": \"$(base64 -w 0 host-keys/ssh_host_rsa_key.pub)\",
\"ssh_host_dsa_key\": \"$(base64 -w 0 host-keys/ssh_host_dsa_key)\",
\"ssh_host_dsa_key.pub\": \"$(base64 -w 0 host-keys/ssh_host_dsa_key.pub)\",
\"ssh_host_ecdsa_key\": \"$(base64 -w 0 host-keys/ssh_host_ecdsa_key)\",
\"ssh_host_ecdsa_key.pub\": \"$(base64 -w 0 host-keys/ssh_host_ecdsa_key.pub)\",
\"ssh_host_ed25519_key\": \"$(base64 -w 0 host-keys/ssh_host_ed25519_key)\",
\"ssh_host_ed25519_key.pub\": \"$(base64 -w 0 host-keys/ssh_host_ed25519_key.pub)\"
}" | jq -r -c
