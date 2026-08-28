#!/bin/bash
#
# End-to-end tests for scripts/oci-apply-retry.sh.
#
# Runs the real script with stubbed `terraform` and `oci` on PATH. Testing the functions in
# isolation is what let two bugs ship: a wait that overshot its budget because it summed
# sleeps instead of tracking a deadline, and a bare `return` after a false `(( ))` that
# aborted the whole script under set -e on the normal end-of-wait path. Both only appear
# when the script runs as a script.
#
# No cluster, no network, no credentials. Needs bash and jq.

set -uo pipefail

REPO_ROOT=$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)
SCRIPT="${REPO_ROOT}/scripts/oci-apply-retry.sh"
STUB_DIR=$(mktemp -d)
trap 'rm -rf "${STUB_DIR}"' EXIT

FAILURES=0

# Fails the way Oracle does, so the default stub exercises the capacity retry branch.
cat >"${STUB_DIR}/terraform" <<'STUB'
#!/bin/bash
case "$1" in
  init|workspace) exit 0 ;;
  apply) echo "| Error: 500-InternalError, Out of host capacity."; exit 1 ;;
esac
exit 0
STUB

# STUB_CAPACITY sets the reported status, STUB_API_LATENCY the per-call cost, and
# STUB_SHAPE_KEYS picks the response spelling. STUB_AVAILABLE_AFTER flips the report to
# AVAILABLE on the Nth call, so a mid-wait transition can be distinguished from a status that
# was already positive at the startup probe. The capacity-report command also carries
# --availability-domain, so match it first.
#
# Every report call appends its argv to STUB_LOG. Matching on a substring alone would let a
# wrong flag name or a malformed shape payload pass every "precheck=ON" assertion, which is
# exactly the edit that would silently disable the pre-check against the real CLI.
cat >"${STUB_DIR}/oci" <<'STUB'
#!/bin/bash
case "$*" in
  *compute-capacity-report*)
    printf '%s\n' "$*" >>"${STUB_LOG}"
    : "${OCI_CLI_TENANCY:?}" "${OCI_CLI_USER:?}" "${OCI_CLI_FINGERPRINT:?}" "${OCI_CLI_KEY_CONTENT:?}"
    sleep "${STUB_API_LATENCY:-0}"
    status="${STUB_CAPACITY:-OUT_OF_HOST_CAPACITY}"
    if [[ -n "${STUB_AVAILABLE_AFTER:-}" ]]; then
      n=$(($(cat "${STUB_COUNT}" 2>/dev/null || echo 0) + 1))
      echo "${n}" >"${STUB_COUNT}"
      if ((n >= STUB_AVAILABLE_AFTER)); then status=AVAILABLE; else status=OUT_OF_HOST_CAPACITY; fi
    fi
    # Starts refusing once the pre-check has already armed, which is the only way to reach the
    # degraded branch: a report that fails at startup disarms instead.
    if [[ -n "${STUB_FAIL_AFTER:-}" ]]; then
      n=$(($(cat "${STUB_COUNT}" 2>/dev/null || echo 0) + 1))
      echo "${n}" >"${STUB_COUNT}"
      ((n >= STUB_FAIL_AFTER)) && exit 1
    fi
    if [[ "${STUB_SHAPE_KEYS:-hyphen}" == "camel" ]]; then
      printf '{"data":{"shapeAvailabilities":[{"availabilityStatus":"%s"}]}}\n' "${status}"
    else
      printf '{"data":{"shape-availabilities":[{"availability-status":"%s"}]}}\n' "${status}"
    fi
    exit 0 ;;
  *availability-domain*) echo "brUk:AP-SYDNEY-1-AD-1"; exit 0 ;;
esac
exit 1
STUB

# A non-capacity failure. The script must abort on it rather than burn every attempt.
mkdir -p "${STUB_DIR}/authfail"
cat >"${STUB_DIR}/authfail/terraform" <<'STUB'
#!/bin/bash
case "$1" in
  init|workspace) exit 0 ;;
  apply) echo "| Error: 401-NotAuthenticated, The required information to complete authentication was not provided."; exit 1 ;;
esac
exit 0
STUB

# Out of capacity once, then succeeds. Pins PIPESTATUS in both directions in one run.
mkdir -p "${STUB_DIR}/flaky"
cat >"${STUB_DIR}/flaky/terraform" <<STUB
#!/bin/bash
case "\$1" in
  init|workspace) exit 0 ;;
  apply)
    if [[ -f "${STUB_DIR}/flaky/.tried" ]]; then echo "Apply complete!"; exit 0; fi
    touch "${STUB_DIR}/flaky/.tried"
    echo "| Error: 500-InternalError, Out of host capacity."; exit 1 ;;
esac
exit 0
STUB

# oci present and the availability domain resolves, but the report is refused. Stands in for
# a tenancy without `manage compute-capacity-reports in tenancy`.
mkdir -p "${STUB_DIR}/denied"
cat >"${STUB_DIR}/denied/oci" <<'STUB'
#!/bin/bash
case "$*" in
  *compute-capacity-report*) echo "NotAuthorizedOrNotFound" >&2; exit 1 ;;
  *availability-domain*) echo "brUk:AP-SYDNEY-1-AD-1"; exit 0 ;;
esac
exit 1
STUB

# oci absent entirely, standing in for running outside the container.
mkdir -p "${STUB_DIR}/no-oci"

for d in authfail flaky denied no-oci; do
  [[ -e "${STUB_DIR}/${d}/terraform" ]] || cp "${STUB_DIR}/terraform" "${STUB_DIR}/${d}/terraform"
  [[ -e "${STUB_DIR}/${d}/oci" ]] || cp "${STUB_DIR}/oci" "${STUB_DIR}/${d}/oci"
done
rm -f "${STUB_DIR}/no-oci/oci"
# After every stub exists: the copies above inherit the source's mode, which is 644 until now.
chmod +x "${STUB_DIR}"/terraform "${STUB_DIR}"/oci "${STUB_DIR}"/*/terraform "${STUB_DIR}"/*/oci

ACCOUNTS_JSON='{"account1":{"region":"ap-sydney-1","tenancy_ocid":"ocid1.tenancy.oc1..t","user_ocid":"ocid1.user.oc1..u","fingerprint":"aa:bb","nodes":{"n1":{"ocpus":2,"memory_gbs":12}}}}'
export TF_VAR_stage0_oci_accounts="${ACCOUNTS_JSON}"
export TF_VAR_stage0_oci_private_keys='{"account1":"key"}'

# The fallback cases below use a restricted PATH. jq must stay reachable on it, or they
# short-circuit at the jq guard and pass for the wrong reason: macOS has no system jq.
# Symlinked into each stub directory rather than by putting jq's own directory on PATH: that
# directory is a shared prefix on macOS and may also hold a real `oci`, which would send the
# "no oci binary" case to the live API with fabricated credentials.
command -v jq >/dev/null || { echo "jq is required" >&2; exit 1; }
for d in authfail flaky denied no-oci; do
  ln -s "$(command -v jq)" "${STUB_DIR}/${d}/jq"
done

# Where the oci stub records its argv, and its call counter for STUB_AVAILABLE_AFTER.
export STUB_LOG="${STUB_DIR}/oci-argv.log"
export STUB_COUNT="${STUB_DIR}/oci-calls"
: >"${STUB_LOG}"

pass() { printf 'ok   %-36s %s\n' "$1" "${2:-}"; }
fail() { printf 'FAIL %-36s %s\n' "$1" "$2"; FAILURES=$((FAILURES + 1)); }

# Seconds between the attempt 1 and attempt 2 banners. This is the number under test: total
# runtime also includes the one-time startup probe, which is not part of any wait budget.
# Seconds since midnight from a YYYY-MM-DDTHH:MM:SSZ banner. Parsed in bash rather than by
# `date`: BSD date needs -j -f, GNU date needs -d, and BusyBox date in the container rejects
# the ISO 8601 T and Z outright, which silently zeroed every gap here.
banner_secs() {
  local t=${1#*T} h m s
  t=${t%Z}
  h=${t%%:*}
  s=${t##*:}
  t=${t#*:}
  m=${t%%:*}
  # 10# forces base 10: an hour like 08 is not a valid octal literal.
  echo $((10#${h} * 3600 + 10#${m} * 60 + 10#${s}))
}

attempt_gap() {
  local out=$1 t1 t2 gap
  t1=$(grep -oE '[0-9]{4}-[0-9-]+T[0-9:]+Z' <<<"${out}" | sed -n 1p)
  t2=$(grep -oE '[0-9]{4}-[0-9-]+T[0-9:]+Z' <<<"${out}" | sed -n 2p)
  [[ -n "${t1}" && -n "${t2}" ]] || { echo "-1"; return; }
  gap=$(( $(banner_secs "${t2}") - $(banner_secs "${t1}") ))
  # A run straddling midnight would otherwise report a negative gap.
  ((gap < 0)) && gap=$((gap + 86400))
  echo "${gap}"
}

# check <label> <want_rc> <want_arm> <want_gap> <want_attempts> <want_final> <path> [env...]
# want_gap and want_final accept "-" to skip that assertion.
check() {
  local label=$1 want_rc=$2 want_arm=$3 want_gap=$4 want_attempts=$5 want_final=$6 path=$7
  shift 7
  local out rc arm gap attempts
  out=$(env PATH="${path}" "$@" "${SCRIPT}" homelab-stage0 2>&1)
  rc=$?
  arm=$(grep -q "pre-check armed" <<<"${out}" && echo ON || echo OFF)
  gap=$(attempt_gap "${out}")
  attempts=$(grep -c '^==> attempt ' <<<"${out}")

  local problems=()
  [[ "${rc}" == "${want_rc}" ]] || problems+=("rc=${rc} want ${want_rc}")
  [[ "${arm}" == "${want_arm}" ]] || problems+=("precheck=${arm} want ${want_arm}")
  [[ "${attempts}" == "${want_attempts}" ]] || problems+=("attempts=${attempts} want ${want_attempts}")
  # One second of slack: the banners are whole seconds and a poll can straddle a boundary.
  if [[ "${want_gap}" != "-" ]] && (( gap < want_gap || gap > want_gap + 1 )); then
    problems+=("gap=${gap}s want ${want_gap}s")
  fi
  if [[ "${want_final}" != "-" ]] && ! grep -qF "${want_final}" <<<"${out}"; then
    problems+=("missing final banner: ${want_final}")
  fi

  if (( ${#problems[@]} == 0 )); then
    pass "${label}" "rc=${rc} precheck=${arm} attempts=${attempts} gap=${gap}s"
  else
    fail "${label}" "${problems[*]}"
    grep -E '^==>' <<<"${out}" | sed 's/^/       /'
  fi
}

echo "== scripts/oci-apply-retry.sh =="

# The regression that matters most: reaching the end of a wait is normal completion. Before
# the fix this exited 1 here instead of starting attempt 2.
check "survives a full wait" 1 ON 3 2 "gave up after 2 attempts" \
  "${STUB_DIR}:${PATH}" OCI_APPLY_MAX_ATTEMPTS=2 OCI_APPLY_SLEEP_SECONDS=3 OCI_CAPACITY_POLL_SECONDS=1

# The wait is a wall-clock deadline. Summing sleeps overshoots by the API latency per poll.
check "latency does not extend the wait" 1 ON 4 2 "gave up after 2 attempts" \
  "${STUB_DIR}:${PATH}" OCI_APPLY_MAX_ATTEMPTS=2 OCI_APPLY_SLEEP_SECONDS=4 OCI_CAPACITY_POLL_SECONDS=1 STUB_API_LATENCY=2

# A positive report is the only thing that shortens a wait.
check "AVAILABLE cuts the wait short" 1 ON 1 2 "gave up after 2 attempts" \
  "${STUB_DIR}:${PATH}" OCI_APPLY_MAX_ATTEMPTS=2 OCI_APPLY_SLEEP_SECONDS=20 OCI_CAPACITY_POLL_SECONDS=1 STUB_CAPACITY=AVAILABLE

# The CLI hyphenates its output, the raw API does not. Both spellings must parse.
check "camelCase response parses" 1 ON 1 2 "gave up after 2 attempts" \
  "${STUB_DIR}:${PATH}" OCI_APPLY_MAX_ATTEMPTS=2 OCI_APPLY_SLEEP_SECONDS=20 OCI_CAPACITY_POLL_SECONDS=1 STUB_CAPACITY=AVAILABLE STUB_SHAPE_KEYS=camel

# The safety property: loop on capacity, abort on everything else. Without this an expired
# credential would burn every attempt instead of surfacing immediately.
check "non-capacity error aborts at once" 1 ON - 1 "not retrying" \
  "${STUB_DIR}/authfail:${PATH}" OCI_APPLY_MAX_ATTEMPTS=3 OCI_APPLY_SLEEP_SECONDS=2

# The success path, which pins PIPESTATUS[0]: reading tee's status instead of terraform's
# would either declare victory on every failure or never stop retrying.
check "succeeds on a later attempt" 0 ON 2 2 "applied on attempt 2" \
  "${STUB_DIR}/flaky:${PATH}" OCI_APPLY_MAX_ATTEMPTS=3 OCI_APPLY_SLEEP_SECONDS=2

# Every degraded path falls back to the fixed sleep rather than aborting.
check "no oci binary falls back" 1 OFF 2 2 "gave up after 2 attempts" \
  "${STUB_DIR}/no-oci:/usr/bin:/bin" OCI_APPLY_MAX_ATTEMPTS=2 OCI_APPLY_SLEEP_SECONDS=2

check "refused report falls back" 1 OFF 2 2 "gave up after 2 attempts" \
  "${STUB_DIR}/denied:/usr/bin:/bin" OCI_APPLY_MAX_ATTEMPTS=2 OCI_APPLY_SLEEP_SECONDS=2

# Reaches the secrets guard specifically, which is what protects a run outside `bws run`.
check "missing secrets falls back" 1 OFF 2 2 "gave up after 2 attempts" \
  "${STUB_DIR}:${PATH}" OCI_APPLY_MAX_ATTEMPTS=2 OCI_APPLY_SLEEP_SECONDS=2 TF_VAR_stage0_oci_accounts=

# The guard has two legs and each needs its own case, or a typo in one leg goes unnoticed.
check "missing private keys falls back" 1 OFF 2 2 "gave up after 2 attempts" \
  "${STUB_DIR}:${PATH}" OCI_APPLY_MAX_ATTEMPTS=2 OCI_APPLY_SLEEP_SECONDS=2 TF_VAR_stage0_oci_private_keys=

# Unset is not the same as empty: the guard defaults with `${VAR:-}` but the reads below it do
# not, so losing that default would abort the whole run under set -u instead of falling back.
check "unset accounts falls back" 1 OFF 2 2 "gave up after 2 attempts" \
  "${STUB_DIR}:${PATH}" env -u TF_VAR_stage0_oci_accounts OCI_APPLY_MAX_ATTEMPTS=2 OCI_APPLY_SLEEP_SECONDS=2

check "unset private keys falls back" 1 OFF 2 2 "gave up after 2 attempts" \
  "${STUB_DIR}:${PATH}" env -u TF_VAR_stage0_oci_private_keys OCI_APPLY_MAX_ATTEMPTS=2 OCI_APPLY_SLEEP_SECONDS=2

# The report must be re-read during the wait. A static AVAILABLE is already true at the startup
# probe, so the case above cannot tell a live poll from a cached first result.
: >"${STUB_COUNT}"
check "AVAILABLE mid-wait cuts the wait short" 1 ON 3 2 "gave up after 2 attempts" \
  "${STUB_DIR}:${PATH}" OCI_APPLY_MAX_ATTEMPTS=2 OCI_APPLY_SLEEP_SECONDS=20 OCI_CAPACITY_POLL_SECONDS=1 STUB_AVAILABLE_AFTER=4

# The documented trap: at or above the sleep budget the first step consumes the whole wait, so
# the pre-check arms but never fires. Counted, because the timing alone cannot show it.
polls_before=$(wc -l <"${STUB_LOG}")
check "poll at or above sleep never polls" 1 ON 3 2 "gave up after 2 attempts" \
  "${STUB_DIR}:${PATH}" OCI_APPLY_MAX_ATTEMPTS=2 OCI_APPLY_SLEEP_SECONDS=3 OCI_CAPACITY_POLL_SECONDS=3
polls=$(($(wc -l <"${STUB_LOG}") - polls_before))
if ((polls == 1)); then
  pass "poll at or above sleep polls only at startup"
else
  fail "poll at or above sleep polls only at startup" "${polls} report calls, want 1"
fi

# A report that starts failing mid-run must correct the armed banner exactly once, however many
# hundreds of polls follow.
: >"${STUB_COUNT}"
degraded=$(env PATH="${STUB_DIR}:${PATH}" OCI_APPLY_MAX_ATTEMPTS=2 OCI_APPLY_SLEEP_SECONDS=6 \
  OCI_CAPACITY_POLL_SECONDS=1 STUB_FAIL_AFTER=2 "${SCRIPT}" homelab-stage0 2>&1)
banners=$(grep -c 'capacity report unusable' <<<"${degraded}")
if [[ "${banners}" == "1" ]]; then
  pass "mid-run report failure warns once"
else
  fail "mid-run report failure warns once" "${banners} banners, want 1"
fi

# The stub matches on a substring, so the CLI contract needs asserting separately: a wrong
# subcommand, a dropped flag or a malformed shape payload would otherwise pass every case above.
report_argv=$(sed -n 1p "${STUB_LOG}")
contract=()
[[ "${report_argv}" == *"compute compute-capacity-report create"* ]] || contract+=("subcommand")
for flag in --compartment-id --availability-domain --shape-availabilities; do
  [[ "${report_argv}" == *"${flag}"* ]] || contract+=("${flag}")
done
# Probing a shape the apply never launches would report capacity for the wrong instance.
want_shape=$(sed -n 's/^ *shape *= *"\(.*\)".*/\1/p' "${REPO_ROOT}/stage0/oci-freetier/compute.tf" | sed -n 1p)
[[ -n "${want_shape}" ]] || contract+=("no shape found in compute.tf")
[[ "${report_argv}" == *"\"instanceShape\":\"${want_shape}\""* ]] || contract+=("shape != ${want_shape}")
sed -n 's/.*--shape-availabilities \(\[[^]]*\]\).*/\1/p' <<<"${report_argv}" \
  | jq -e '.[0] | (.instanceShape | strings) and (.instanceShapeConfig.ocpus | numbers)
           and (.instanceShapeConfig.memoryInGBs | numbers)' >/dev/null 2>&1 \
  || contract+=("shape payload")
if ((${#contract[@]} == 0)); then
  pass "report invocation matches the CLI contract"
else
  fail "report invocation matches the CLI contract" "${contract[*]}"
fi

# The jq defaults in the script mirror optional() in stage0/variables.tf. Assert the mirror
# rather than restate it: a change there would otherwise size the probe below the real node.
while read -r field want; do
  got=$(sed -n "s/.*${field} *= *optional(number, *\([0-9]*\)).*/\1/p" "${REPO_ROOT}/stage0/variables.tf")
  if [[ "${got}" == "${want}" ]]; then
    pass "stage0 default ${field}=${want}"
  else
    fail "stage0 default ${field}" "stage0/variables.tf says '${got}', script assumes ${want}"
  fi
done <<'DEFAULTS'
ocpus 2
memory_gbs 12
DEFAULTS

# check_precheck_banner <label> <needle> <env...>
# One attempt is enough: these assert what the startup probe reported, not the retry loop.
check_precheck_banner() {
  local label=$1 needle=$2 out
  shift 2
  out=$(env PATH="${STUB_DIR}:${PATH}" OCI_APPLY_MAX_ATTEMPTS=1 "$@" "${SCRIPT}" homelab-stage0 2>&1)
  if grep -qF "${needle}" <<<"${out}"; then
    pass "${label}"
  else
    fail "${label}" "$(grep -m1 'pre-check' <<<"${out}")"
  fi
}

# The probe must size to the largest node, and fall back to the stage0/variables.tf defaults
# for omitted fields. A smaller probe shape would report capacity that cannot hold the node.
check_precheck_banner "largest node sets the probe shape" "for 2 OCPU / 12 GB" \
  TF_VAR_stage0_oci_accounts='{"account1":{"region":"r","tenancy_ocid":"t","user_ocid":"u","fingerprint":"f","nodes":{"small":{"ocpus":1,"memory_gbs":6},"big":{}}}}'

# A non-numeric field must disable the pre-check, not reach the API as a shape.
check_precheck_banner "non-numeric shape is rejected" "pre-check unavailable" \
  TF_VAR_stage0_oci_accounts='{"account1":{"region":"r","tenancy_ocid":"t","user_ocid":"u","fingerprint":"f","nodes":{"n":{"ocpus":"9; rm -rf /","memory_gbs":12}}}}'

# All three tunables reject rather than clamp. A non-numeric sleep would otherwise reach
# `sleep` and abort the run minutes in, under set -e, with sleep's error rather than ours.
for var in OCI_APPLY_MAX_ATTEMPTS OCI_APPLY_SLEEP_SECONDS OCI_CAPACITY_POLL_SECONDS; do
  for bad in 0 -1 abc; do
    env PATH="${STUB_DIR}:${PATH}" "${var}=${bad}" "${SCRIPT}" homelab-stage0 >/dev/null 2>&1
    rc=$?
    if [[ "${rc}" -eq 2 ]]; then
      pass "${var}=${bad} rejected"
    else
      fail "${var}=${bad} rejected" "exit ${rc}, want 2"
    fi
  done
done

echo
if (( FAILURES > 0 )); then
  echo "${FAILURES} failure(s)"
  exit 1
fi
echo "all passed"
