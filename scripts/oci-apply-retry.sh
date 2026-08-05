#!/bin/bash
#
# Applies one stage0 workspace, retrying while Oracle reports out of host capacity.
#
# Always Free A1 capacity is frequently unavailable in a home region, and the failure is
# transient rather than a configuration error, so it is the one condition worth looping
# on. Every other failure aborts immediately: retrying a bad credential or an over-quota
# plan just burns attempts.

set -euo pipefail

WORKSPACE="${1:-}"
if [[ -z "${WORKSPACE}" ]]; then
  echo "usage: $0 <stage0-workspace-name>" >&2
  exit 2
fi

# Overridable so a long unattended run and a quick check use the same script.
MAX_ATTEMPTS="${OCI_APPLY_MAX_ATTEMPTS:-30}"
SLEEP_SECONDS="${OCI_APPLY_SLEEP_SECONDS:-300}"

# Rejected rather than clamped: 0 would run no attempt at all and still report giving up
# on capacity, asserting a condition that was never tested.
if ! [[ "${MAX_ATTEMPTS}" =~ ^[1-9][0-9]*$ ]]; then
  echo "OCI_APPLY_MAX_ATTEMPTS must be a positive integer, got '${MAX_ATTEMPTS}'" >&2
  exit 2
fi

# Same reason, plus: a non-numeric value would otherwise reach `sleep` and abort the loop
# under set -e, minutes in, with sleep's error rather than this one.
if ! [[ "${SLEEP_SECONDS}" =~ ^[1-9][0-9]*$ ]]; then
  echo "OCI_APPLY_SLEEP_SECONDS must be a positive integer, got '${SLEEP_SECONDS}'" >&2
  exit 2
fi

cd "$(cd "$(dirname "${BASH_SOURCE[0]}")/../stage0" &>/dev/null && pwd)"

terraform init -input=false
terraform workspace select "${WORKSPACE}"

LOG=$(mktemp)
trap 'rm -f "${LOG}"' EXIT

for ((attempt = 1; attempt <= MAX_ATTEMPTS; attempt++)); do
  echo "==> attempt ${attempt}/${MAX_ATTEMPTS} on workspace ${WORKSPACE} at $(date -u '+%Y-%m-%dT%H:%M:%SZ')"

  # Tee rather than capture: the operator sees progress live, and the copy is what the
  # capacity test reads. set +e because a failed apply is the expected path here, and
  # PIPESTATUS because the pipe to tee would otherwise mask terraform's exit code.
  set +e
  terraform apply -input=false -auto-approve 2>&1 | tee "${LOG}"
  status="${PIPESTATUS[0]}"
  set -e

  if [[ "${status}" -eq 0 ]]; then
    echo "==> applied on attempt ${attempt}"
    exit 0
  fi

  # Oracle's wording, surfaced verbatim by the provider from the OCI API response. Echo
  # the real error too: if Oracle ever rewords it, this degrades to aborting on the first
  # attempt, and the operator needs to see why rather than just that it stopped.
  if ! grep -qF 'Out of host capacity' "${LOG}"; then
    echo "==> failed for a reason other than host capacity, not retrying" >&2
    grep -m3 'Error:' "${LOG}" >&2 || true
    exit "${status}"
  fi

  if [[ "${attempt}" -eq "${MAX_ATTEMPTS}" ]]; then
    break
  fi

  echo "==> out of host capacity, sleeping ${SLEEP_SECONDS}s"
  sleep "${SLEEP_SECONDS}"
done

echo "==> gave up after ${MAX_ATTEMPTS} attempts, still out of host capacity" >&2
exit 1
