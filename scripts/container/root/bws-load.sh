#!/bin/bash
# Bitwarden Secrets Manager loader.
#
# Sourced by ~/.bashrc on interactive container entry, and re-runnable any time via the
# `bws-load` shell function (defined in .bashrc) to refresh secrets WITHOUT restarting the
# container.
#
# Reads ONLY the access token (+ project id) from the mounted /srv/.env, then re-execs bash
# under `bws run` so every project secret is injected as a native env var (JSON values need no
# escaping). Auth is probed first so a failing last command is not mistaken for a bws failure;
# on auth/offline failure it returns without replacing the shell, so the container is never
# locked out. Set BWS_SKIP=1 (before entry) to bypass entirely.
#
# Must be SOURCED, not executed — it exec's into the injected shell in place.

set -a
# shellcheck source=/dev/null
[ -f /srv/.env ] && source /srv/.env
set +a

if [ -z "$BWS_ACCESS_TOKEN" ]; then
  echo "WARN: BWS_ACCESS_TOKEN not set; secrets NOT loaded (see docs/bitwarden-secrets-setup.md)" >&2
elif bws run ${BWS_PROJECT_ID:+--project-id "$BWS_PROJECT_ID"} -- true >/dev/null 2>&1; then
  # Probe (`-- true`) succeeded, so bws can authenticate: hand off to the injected shell.
  export BWS_LOADED=1
  exec bws run ${BWS_PROJECT_ID:+--project-id "$BWS_PROJECT_ID"} -- bash
else
  echo "WARN: bws run failed (auth/offline); continuing WITHOUT injected secrets (set BWS_SKIP=1 to silence)" >&2
fi
