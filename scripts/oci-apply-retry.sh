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
POLL_SECONDS="${OCI_CAPACITY_POLL_SECONDS:-30}"

# Rejected rather than clamped: 0 would run no attempt at all and still report giving up on
# capacity, asserting a condition that was never tested. Rejected up front rather than on use,
# because a non-numeric sleep would otherwise reach `sleep` and abort the loop under set -e,
# minutes in, with sleep's error rather than this one.
require_positive_int() {
  if ! [[ "$2" =~ ^[1-9][0-9]*$ ]]; then
    echo "$1 must be a positive integer, got '$2'" >&2
    exit 2
  fi
}

require_positive_int OCI_APPLY_MAX_ATTEMPTS "${MAX_ATTEMPTS}"
require_positive_int OCI_APPLY_SLEEP_SECONDS "${SLEEP_SECONDS}"
require_positive_int OCI_CAPACITY_POLL_SECONDS "${POLL_SECONDS}"

# Oracle's capacity report is one API call carrying no Terraform state, so it can be polled
# far more often than an apply. It is wired as a way to start the next attempt EARLY, never
# to cancel one: the report is known to disagree with reality
# (https://github.com/oracle/oci-cli/issues/748), so a false negative that skipped an apply
# would leave this worse than the fixed sleep it replaces.
#
# Every failure path here disables the pre-check rather than aborting. The script has to keep
# working outside the container, and on an account whose policy lacks the report grant.
setup_capacity_precheck() {
  command -v oci >/dev/null 2>&1 || return 1
  command -v jq >/dev/null 2>&1 || return 1
  [[ -n "${TF_VAR_stage0_oci_accounts:-}" && -n "${TF_VAR_stage0_oci_private_keys:-}" ]] || return 1

  local account
  account=$(jq -er '.account1' <<<"${TF_VAR_stage0_oci_accounts}") || return 1

  # Assigned without `local`: `local x=$(cmd)` reports local's own exit status, not the
  # command's, which would swallow every failure below.
  OCI_CLI_REGION=$(jq -er '.region' <<<"${account}") || return 1
  OCI_CLI_TENANCY=$(jq -er '.tenancy_ocid' <<<"${account}") || return 1
  OCI_CLI_USER=$(jq -er '.user_ocid' <<<"${account}") || return 1
  OCI_CLI_FINGERPRINT=$(jq -er '.fingerprint' <<<"${account}") || return 1
  # The documented alternative to key_file, so no signing key is written to one.
  # https://docs.oracle.com/en-us/iaas/Content/API/SDKDocs/clienvironmentvariables.htm
  # Piped from the printf builtin rather than a here-string: bash 3.2, still /bin/bash on
  # macOS, spools here-strings to a temp file, and this one would be the PEM.
  OCI_CLI_KEY_CONTENT=$(printf '%s' "${TF_VAR_stage0_oci_private_keys}" | jq -er '.account1') || return 1
  export OCI_CLI_REGION OCI_CLI_TENANCY OCI_CLI_USER OCI_CLI_FINGERPRINT OCI_CLI_KEY_CONTENT

  # The largest node is the hardest single placement, so one report on it is the strongest
  # signal a single call can give. It does not prove two nodes fit. That is deliberate: a
  # false positive costs one apply, which is what every attempt costs today anyway.
  #
  # The `// ` defaults mirror the optional() defaults in stage0/variables.tf. Terraform
  # applies those during type conversion, so an unset field is simply absent from the secret.
  #
  # `numbers` rejects a non-numeric field rather than passing it through: jq orders strings
  # above numbers, so a stray string would win `max` and reach the API as the probe shape.
  CAPACITY_OCPUS=$(jq -er '[.nodes[] | (.ocpus // 2)] | max | numbers' <<<"${account}") || return 1
  CAPACITY_MEMORY=$(jq -er '[.nodes[] | (.memory_gbs // 12)] | max | numbers' <<<"${account}") || return 1

  # CreateComputeCapacityReport is a tenancy-level call. The homelab compartment is rejected,
  # and the IAM grant it needs is `manage compute-capacity-reports in tenancy`, which is not
  # part of instance-family. See docs/stage0/oci-freetier.md step 5.
  CAPACITY_AD=$(oci iam availability-domain list \
    --compartment-id "${OCI_CLI_TENANCY}" \
    --query 'data[0].name' --raw-output 2>/dev/null) || return 1
  [[ -n "${CAPACITY_AD}" ]] || return 1

  # One probe before the loop claims to be armed. It proves the grant, the availability
  # domain and the response shape in one call. Without it, any wrong assumption here would
  # degrade to a pre-check that silently never fires while reporting itself as active.
  capacity_status >/dev/null || return 1
}

# Prints the report's availability status. Both key spellings are accepted: the CLI hyphenates
# its output, the raw API does not.
#
# The shape and the AD index track stage0/oci-freetier/compute.tf. Probing a different placement
# than the apply attempts would report capacity for an instance Terraform never asks for.
capacity_status() {
  local out
  out=$(oci compute compute-capacity-report create \
    --compartment-id "${OCI_CLI_TENANCY}" \
    --availability-domain "${CAPACITY_AD}" \
    --shape-availabilities "[{\"instanceShape\":\"VM.Standard.A1.Flex\",\"instanceShapeConfig\":{\"ocpus\":${CAPACITY_OCPUS},\"memoryInGBs\":${CAPACITY_MEMORY}}}]" \
    2>/dev/null) || return 1

  jq -er '(.data["shape-availabilities"] // .data.shapeAvailabilities // [])[0]
          | (.["availability-status"] // .availabilityStatus // empty)' <<<"${out}" 2>/dev/null || return 1
}

capacity_available() {
  local status
  if ! status=$(capacity_status); then
    # Said once: a full run polls hundreds of times, and the startup banner has already claimed
    # the pre-check is live, so a persistent mid-run failure has to correct that exactly once.
    if [[ "${CAPACITY_DEGRADED}" != "1" ]]; then
      CAPACITY_DEGRADED=1
      echo "==> capacity report unusable, no parsable availability status, falling back to fixed waits" >&2
    fi
    return 1
  fi
  [[ "${status}" == "AVAILABLE" ]]
}

# Waits SLEEP_SECONDS, cut short the moment the report turns positive.
#
# The budget is a wall-clock deadline, not a running sum of sleeps. Each poll is an API call
# costing real time, and counting only the sleeps overshoots the budget by that latency, which
# grows with the poll count. The loop exits at the deadline rather than polling once more,
# because the apply runs either way the moment this returns.
#
# The ceiling is soft by at most one report round trip: a poll that starts with a second left
# still runs to completion. Bounding it would cost more reaction time at the tail than the
# couple of seconds it saves.
wait_before_retry() {
  if [[ "${PRECHECK}" != "1" ]]; then
    sleep "${SLEEP_SECONDS}"
    return
  fi

  local deadline remaining step left
  deadline=$(($(date +%s) + SLEEP_SECONDS))
  while :; do
    remaining=$((deadline - $(date +%s)))
    # `return 0`, never a bare `return`: (( )) exits 1 when its expression is false, and a
    # bare `return` propagates that, so the normal end-of-budget path would abort the script
    # under set -e. Every return in this loop is ordinary completion, not failure.
    ((remaining > 0)) || return 0
    step=$((remaining < POLL_SECONDS ? remaining : POLL_SECONDS))
    sleep "${step}"
    left=$((deadline - $(date +%s)))
    ((left > 0)) || return 0
    capacity_available || continue
    echo "==> capacity report turned AVAILABLE with up to ${left}s of the wait left, retrying now"
    return 0
  done
}

# CDPATH is cleared because the operand is relative with no leading `./`: cd would otherwise resolve it
# against the caller's CDPATH and echo the directory it picked onto stdout.
CDPATH='' cd -- "$(dirname "${BASH_SOURCE[0]}")/../stage0"

terraform init -input=false
terraform workspace select "${WORKSPACE}"

LOG=$(mktemp)
trap 'rm -f "${LOG}"' EXIT

PRECHECK=0
CAPACITY_DEGRADED=0
if setup_capacity_precheck; then
  PRECHECK=1
  echo "==> capacity pre-check armed on ${CAPACITY_AD} for ${CAPACITY_OCPUS} OCPU / ${CAPACITY_MEMORY} GB, polling every ${POLL_SECONDS}s"
else
  echo "==> capacity pre-check unavailable, using fixed ${SLEEP_SECONDS}s waits"
fi

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

  echo "==> out of host capacity, waiting up to ${SLEEP_SECONDS}s"
  wait_before_retry
done

echo "==> gave up after ${MAX_ATTEMPTS} attempts, still out of host capacity" >&2
exit 1
