#!/bin/bash
# Sync tool and component versions from their sources of truth into the docs.
#
# Sources of truth:
#   Dockerfile                        ARG *_VERSION  - the operator toolbox
#   stage1/inventories/inventory.yml  *_version      - what Ansible installs on the nodes
#
# Targets:
#   README.md                   legacy VERSIONS_START/END block + shields.io badges
#   docs/reference/versions.md  VERSIONS_START:<id> blocks
#   docs/**/*.md                <!--v:key-->value<!--/v--> inline spans
#
# Drift is detected by regenerating each block from source and diffing. Text
# outside a sentinel is never read, so prose mentioning an old version cannot
# produce a false positive. Prose that must not go stale opts in with a span.
#
# Usage: ./scripts/sync-versions.sh [--check]
#   --check: only report drift, exit 1 if anything is out of sync

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

DOCKERFILE="$REPO_ROOT/Dockerfile"
INVENTORY="$REPO_ROOT/stage1/inventories/inventory.yml"
README="$REPO_ROOT/README.md"
VERSIONS_DOC="$REPO_ROOT/docs/reference/versions.md"

# Reject anything that is not exactly `--check` or nothing. A typo'd flag must not
# fall through to apply mode: in CI that rewrites the tracked files and exits 0, so
# the gate would report success having checked nothing.
CHECK_ONLY=false
case "$#:${1:-}" in
  "0:") ;;
  "1:--check") CHECK_ONLY=true ;;
  *)
    echo "ERROR: usage: ${0##*/} [--check]" >&2
    exit 2
    ;;
esac

TMP_DIR=$(mktemp -d)
trap 'rm -rf "$TMP_DIR"' EXIT

# ---------------------------------------------------------------------------
# Extraction
# ---------------------------------------------------------------------------

# Every extracted value is spliced into a sed replacement string, where `|`, `&`
# and a newline are all metacharacters. A pin is a plain version string; anything
# else is a parse bug or an injection attempt, and both should stop the run.
require_version() {
  local name=$1 value=$2
  if [[ ! "$value" =~ ^[A-Za-z0-9._+-]+$ ]]; then
    echo "ERROR: ${name} is not a plain version string: '${value}'" >&2
    exit 1
  fi
}

# Dockerfile: `ARG KUBECTL_VERSION=1.36.3`
# `-f2-` rather than `-f2` so a value containing `=` is not truncated; `head -1`
# so a duplicated ARG cannot yield a two-line value.
extract_arg() {
  local value
  value=$(grep -E "^ARG ${1}=" "$DOCKERFILE" | head -1 | cut -d'=' -f2-) || true
  if [[ -z "$value" ]]; then
    echo "ERROR: no 'ARG ${1}=' in Dockerfile" >&2
    exit 1
  fi
  require_version "ARG $1" "$value"
  printf '%s\n' "$value"
}

# inventory.yml: `cilium_version: "<version>" # https://github.com/cilium/cilium/releases`
# Values are quoted or bare, with an optional trailing upstream-release comment.
# Anchoring on `^\s*key:` matches a YAML key rather than the same text appearing
# in a value or a comment, and stops a short key matching as the suffix of a
# longer one.
extract_inventory() {
  local value
  value=$(grep -E "^[[:space:]]*${1}:" "$INVENTORY" | head -1 |
    sed -E "s/^[^:]*:[[:space:]]*//; s/[[:space:]]*#.*\$//; s/^\"(.*)\"\$/\1/; s/^'(.*)'\$/\1/") || true
  if [[ -z "$value" ]]; then
    echo "ERROR: no '${1}:' in ${INVENTORY#"$REPO_ROOT"/}" >&2
    exit 1
  fi
  require_version "$1" "$value"
  printf '%s\n' "$value"
}

# The trailing comment is the upstream release page. Keeping it single-sourced
# means the generated table's links cannot drift from the pins they document.
extract_inventory_url() {
  grep -E "^[[:space:]]*${1}:" "$INVENTORY" | head -1 |
    sed -nE 's|.*#[[:space:]]*(https?://[^[:space:]]+).*|\1|p'
}

KUBECTL_VERSION=$(extract_arg "KUBECTL_VERSION")
HELM_VERSION=$(extract_arg "HELM_VERSION")
TERRAFORM_VERSION=$(extract_arg "TERRAFORM_VERSION")
TASKFILE_VERSION=$(extract_arg "TASKFILE_VERSION")
TRIVY_VERSION=$(extract_arg "TRIVY_VERSION")
TFLINT_VERSION=$(extract_arg "TFLINT_VERSION")
BWS_VERSION=$(extract_arg "BWS_VERSION")

# Ordered list of inventory pins. One entry per line: `<key> <label>`.
INVENTORY_KEYS="kubeadm_version kubeadm
kubectl_version kubectl
kubelet_service_version kubelet systemd unit
containerd_version containerd
runc_version runc
crictl_version crictl
nerdctl_version nerdctl
cni_version CNI plugins
cilium_version Cilium
cilium_cli_version Cilium CLI
pluto_version pluto
minikube_version minikube
k3s_version k3s"

# kubectl is the one tool pinned in both sources. If the operator's client drifts
# from the cluster's, kubectl starts emitting version-skew warnings and nobody
# notices. Assert it rather than publishing two different numbers.
INVENTORY_KUBECTL=$(extract_inventory "kubectl_version")
if [[ "$KUBECTL_VERSION" != "$INVENTORY_KUBECTL" ]]; then
  echo "ERROR: kubectl is pinned twice and the pins disagree." >&2
  echo "  Dockerfile    ARG KUBECTL_VERSION = $KUBECTL_VERSION" >&2
  echo "  inventory.yml kubectl_version     = $INVENTORY_KUBECTL" >&2
  exit 1
fi

# Canonical key -> value map for the inline-span rewriter. Newline-delimited
# rather than a bash 4 associative array, because `task versions:bump` runs on
# macOS where /bin/bash is 3.2.
VERSION_MAP="kubectl_version=$KUBECTL_VERSION
helm_version=$HELM_VERSION
terraform_version=$TERRAFORM_VERSION
taskfile_version=$TASKFILE_VERSION
trivy_version=$TRIVY_VERSION
tflint_version=$TFLINT_VERSION
bws_version=$BWS_VERSION"

while read -r key _label; do
  [[ -n "$key" ]] || continue
  VERSION_MAP+="
${key}=$(extract_inventory "$key")"
done <<< "$INVENTORY_KEYS"

# ---------------------------------------------------------------------------
# Sentinel machinery
# ---------------------------------------------------------------------------

# Replace everything between the start and end markers (inclusive of both) in $1
# with the contents of $4, which carries its own marker lines. `index($0, m) == 1`
# anchors the marker to column 1 and matches it literally, so a marker containing
# `:` or `-` needs no regex escaping - that is what lets multiple ID'd blocks in
# one file target correctly.
replace_block() {
  local file=$1 start=$2 end=$3 payload=$4
  local n_start n_end
  # Exactly one marker pair, or the awk below silently truncates the file (no END)
  # or copies it verbatim and reports "in sync" forever (no pair).
  n_start=$(grep -c -- "^$start" "$file" || true)
  n_end=$(grep -c -- "^$end" "$file" || true)
  if [[ "$n_start" != 1 || "$n_end" != 1 ]]; then
    echo "ERROR: ${file#"$REPO_ROOT"/} must contain exactly one '$start' and one '$end'" >&2
    echo "  found: start=$n_start end=$n_end" >&2
    exit 1
  fi
  # Ordered, too: END above START discards the rest of the file.
  if [[ "$(grep -n -- "^$start" "$file" | cut -d: -f1)" -gt "$(grep -n -- "^$end" "$file" | cut -d: -f1)" ]]; then
    echo "ERROR: ${file#"$REPO_ROOT"/} has '$end' before '$start'" >&2
    exit 1
  fi
  awk -v payload="$payload" -v s="$start" -v e="$end" '
    index($0, s) == 1 {
      while ((getline line < payload) > 0) print line
      close(payload)
      skip = 1
      next
    }
    index($0, e) == 1 { skip = 0; next }
    !skip { print }
  ' "$file"
}

# Rewrite every `<!--v:KEY-->value<!--/v-->` span to the canonical value.
# `[^<]*` is effectively non-greedy for this shape, since a version never
# contains `<`. Unmarked versions elsewhere in the file are never seen.
rewrite_spans() {
  local file=$1 label=$2 key value used
  while IFS='=' read -r key value; do
    [[ -n "$key" ]] || continue
    sed -i.bak -E "s|<!--v:${key}-->[^<]*<!--/v-->|<!--v:${key}-->${value}<!--/v-->|g" "$file"
    rm -f "$file.bak"
  done <<< "$VERSION_MAP"

  # Substitution is driven by the key list, so an unknown key would be skipped in
  # silence and the gate would still report "in sync". Reject it instead.
  while IFS= read -r used; do
    [[ -n "$used" ]] || continue
    if ! grep -q "^${used}=" <<< "$VERSION_MAP"; then
      echo "ERROR: unknown version span key '<!--v:${used}-->' in ${label}" >&2
      exit 1
    fi
  # `[^>]*` rather than an allow-list, or the typo this check exists to catch
  # would not match at all.
  done < <(grep -oE '<!--v:[^>]*-->' "$file" | sed -E 's|<!--v:(.*)-->|\1|' | sort -u)
}

DRIFT=0

# Diff the regenerated copy against the real file; report, then apply or flag.
settle() {
  local target=$1 candidate=$2
  if diff -q "$target" "$candidate" > /dev/null 2>&1; then
    return 0
  fi
  echo "Drift in ${target#"$REPO_ROOT"/}:"
  diff "$target" "$candidate" || true
  if [[ "$CHECK_ONLY" == "true" ]]; then
    DRIFT=1
    return 0
  fi
  cp "$candidate" "$target"
  echo "  updated ${target#"$REPO_ROOT"/}"
}

# ---------------------------------------------------------------------------
# README.md - legacy block, marker text unchanged, plus the two badges
# ---------------------------------------------------------------------------

cat > "$TMP_DIR/readme-table" << EOF
<!-- VERSIONS_START - Do not remove this comment, used by sync-versions workflow -->
| Tool | Version |
|------|---------|
| kubectl | $KUBECTL_VERSION |
| helm | $HELM_VERSION |
| terraform | $TERRAFORM_VERSION |
| taskfile | $TASKFILE_VERSION |
| trivy | $TRIVY_VERSION |
<!-- VERSIONS_END - Do not remove this comment -->
EOF

replace_block "$README" "<!-- VERSIONS_START" "<!-- VERSIONS_END" \
  "$TMP_DIR/readme-table" > "$TMP_DIR/README.md"

sed -i.bak "s/terraform-[0-9.]*-blue/terraform-${TERRAFORM_VERSION}-blue/g" "$TMP_DIR/README.md"
sed -i.bak "s/kubernetes-[0-9.]*-blue/kubernetes-${KUBECTL_VERSION}-blue/g" "$TMP_DIR/README.md"
rm -f "$TMP_DIR/README.md.bak"

settle "$README" "$TMP_DIR/README.md"

# ---------------------------------------------------------------------------
# docs/reference/versions.md - two ID'd blocks
# ---------------------------------------------------------------------------

if [[ -f "$VERSIONS_DOC" ]]; then
  {
    echo "<!-- VERSIONS_START:container-tools - generated by scripts/sync-versions.sh -->"
    echo "| Tool | Version |"
    echo "|------|---------|"
    echo "| kubectl | $KUBECTL_VERSION |"
    echo "| helm | $HELM_VERSION |"
    echo "| terraform | $TERRAFORM_VERSION |"
    echo "| taskfile | $TASKFILE_VERSION |"
    echo "| trivy | $TRIVY_VERSION |"
    echo "| tflint | $TFLINT_VERSION |"
    echo "| bws | $BWS_VERSION |"
    echo "<!-- VERSIONS_END:container-tools -->"
  } > "$TMP_DIR/tools-table"

  {
    echo "<!-- VERSIONS_START:cluster-components - generated by scripts/sync-versions.sh -->"
    echo "| Component | Version | Upstream releases |"
    echo "|-----------|---------|-------------------|"
    while read -r key label; do
      [[ -n "$key" ]] || continue
      url=$(extract_inventory_url "$key")
      if [[ -n "$url" ]]; then
        echo "| $label | $(extract_inventory "$key") | <$url> |"
      else
        echo "| $label | $(extract_inventory "$key") | |"
      fi
    done <<< "$INVENTORY_KEYS"
    echo "<!-- VERSIONS_END:cluster-components -->"
  } > "$TMP_DIR/components-table"

  replace_block "$VERSIONS_DOC" \
    "<!-- VERSIONS_START:container-tools" "<!-- VERSIONS_END:container-tools" \
    "$TMP_DIR/tools-table" > "$TMP_DIR/versions-pass1.md"
  replace_block "$TMP_DIR/versions-pass1.md" \
    "<!-- VERSIONS_START:cluster-components" "<!-- VERSIONS_END:cluster-components" \
    "$TMP_DIR/components-table" > "$TMP_DIR/versions.md"

  settle "$VERSIONS_DOC" "$TMP_DIR/versions.md"
fi

# ---------------------------------------------------------------------------
# Inline spans across every page under docs/
# ---------------------------------------------------------------------------

while IFS= read -r page; do
  grep -q '<!--v:' "$page" || continue
  cp "$page" "$TMP_DIR/span-candidate.md"
  rewrite_spans "$TMP_DIR/span-candidate.md" "${page#"$REPO_ROOT"/}"
  settle "$page" "$TMP_DIR/span-candidate.md"
done < <(find "$REPO_ROOT/docs" -name '*.md' -type f | sort)

if [[ "$DRIFT" -eq 1 ]]; then
  echo "Check mode: versions are out of sync. Run ./scripts/sync-versions.sh to fix."
  exit 1
fi

echo "Versions are in sync."
