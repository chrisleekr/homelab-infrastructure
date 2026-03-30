#!/bin/bash
# Bump tool and Alpine package versions in the Dockerfile to their latest releases.
# Usage: ./scripts/bump-versions.sh [--check | --apply]
#   --check (default): Show version comparison, exit 1 if updates available
#   --apply:           Update Dockerfile in place

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
DOCKERFILE="$REPO_ROOT/Dockerfile"

# ── Colours ──────────────────────────────────────────────────────────────────
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
CYAN='\033[0;36m'
BOLD='\033[1m'
NC='\033[0m' # No Colour

# ── Arguments ────────────────────────────────────────────────────────────────
APPLY=false
if [[ "${1:-}" == "--apply" ]]; then
  APPLY=true
elif [[ "${1:-}" != "" && "${1:-}" != "--check" ]]; then
  echo "Usage: $0 [--check | --apply]"
  exit 1
fi

# ── Prerequisites ────────────────────────────────────────────────────────────
for cmd in curl jq awk sed grep; do
  if ! command -v "$cmd" &>/dev/null; then
    echo "Error: $cmd is required but not found" >&2
    exit 1
  fi
done

# ── GitHub API helper ────────────────────────────────────────────────────────
# Supports optional GITHUB_TOKEN env var for higher rate limits.
github_curl() {
  local url="$1"
  if [[ -n "${GITHUB_TOKEN:-}" ]]; then
    curl -fsSL -H "Authorization: token ${GITHUB_TOKEN}" "$url"
  else
    curl -fsSL "$url"
  fi
}

# ── Extract helpers ──────────────────────────────────────────────────────────
extract_arg() {
  local var_name=$1
  grep -E "^ARG ${var_name}=" "$DOCKERFILE" | head -1 | cut -d'=' -f2
}

# ── Temp dir ─────────────────────────────────────────────────────────────────
TMPDIR_WORK="$(mktemp -d)"
trap 'rm -rf "$TMPDIR_WORK"' EXIT

###############################################################################
# PART 1 – Fetch latest tool versions
###############################################################################

echo -e "${BOLD}Fetching latest tool versions…${NC}"

validate_version() {
  local name="$1" version="$2"
  if [[ -z "$version" || "$version" == "null" ]]; then
    echo "Error: Failed to fetch latest version for $name" >&2
    exit 1
  fi
}

# kubectl – https://dl.k8s.io/release/stable.txt
KUBECTL_CURRENT=$(extract_arg "KUBECTL_VERSION")
KUBECTL_LATEST=$(curl -fsSL https://dl.k8s.io/release/stable.txt | sed 's/^v//')
validate_version "kubectl" "$KUBECTL_LATEST"

# Helm – GitHub releases
HELM_CURRENT=$(extract_arg "HELM_VERSION")
HELM_LATEST=$(github_curl "https://api.github.com/repos/helm/helm/releases/latest" \
  | jq -r '.tag_name' | sed 's/^v//')
validate_version "helm" "$HELM_LATEST"

# Terraform – GitHub releases
TERRAFORM_CURRENT=$(extract_arg "TERRAFORM_VERSION")
TERRAFORM_LATEST=$(github_curl "https://api.github.com/repos/hashicorp/terraform/releases/latest" \
  | jq -r '.tag_name' | sed 's/^v//')
validate_version "terraform" "$TERRAFORM_LATEST"

# Taskfile – GitHub releases
TASKFILE_CURRENT=$(extract_arg "TASKFILE_VERSION")
TASKFILE_LATEST=$(github_curl "https://api.github.com/repos/go-task/task/releases/latest" \
  | jq -r '.tag_name' | sed 's/^v//')
validate_version "taskfile" "$TASKFILE_LATEST"

# Trivy – GitHub releases
TRIVY_CURRENT=$(extract_arg "TRIVY_VERSION")
TRIVY_LATEST=$(github_curl "https://api.github.com/repos/aquasecurity/trivy/releases/latest" \
  | jq -r '.tag_name' | sed 's/^v//')
validate_version "trivy" "$TRIVY_LATEST"

###############################################################################
# PART 2 – Fetch latest Alpine package versions
###############################################################################

echo -e "${BOLD}Fetching latest Alpine package versions…${NC}"

# Parse Alpine version from the FROM line (e.g. "alpine:3.21" → "3.21")
ALPINE_VER=$(grep -E '^FROM .* alpine:' "$DOCKERFILE" | head -1 \
  | sed -E 's/.*alpine:([0-9]+\.[0-9]+).*/\1/')
echo "  Alpine base: v${ALPINE_VER}"

# Download and combine APKINDEX from main + community repos
for repo in main community; do
  curl -fsSL "https://dl-cdn.alpinelinux.org/alpine/v${ALPINE_VER}/${repo}/x86_64/APKINDEX.tar.gz" \
    | tar -xzf - -C "$TMPDIR_WORK" APKINDEX 2>/dev/null || true
  cat "$TMPDIR_WORK/APKINDEX" >> "$TMPDIR_WORK/APKINDEX_COMBINED" 2>/dev/null || true
done

# Lookup latest version of a package from the combined APKINDEX.
# APKINDEX format: blocks separated by blank lines; P: = package name, V: = version.
apk_latest_version() {
  local pkg="$1"
  awk -v pkg="$pkg" '
    /^P:/ { name = substr($0, 3) }
    /^V:/ { ver  = substr($0, 3) }
    /^$/ {
      if (name == pkg && ver != "") print ver
      name = ""; ver = ""
    }
    END {
      if (name == pkg && ver != "") print ver
    }
  ' "$TMPDIR_WORK/APKINDEX_COMBINED" | sort -V | tail -1
}

# Extract all pinned Alpine packages from the Dockerfile (name=version pattern).
# Uses parallel indexed arrays for bash 3.2 compatibility (no associative arrays).
APK_PKGS=()
APK_CURRENT=()
APK_LATEST=()

while IFS= read -r entry; do
  pkg="${entry%%=*}"
  ver="${entry#*=}"
  APK_PKGS+=("$pkg")
  APK_CURRENT+=("$ver")
done < <(grep -oE '[a-z][a-z0-9_+.-]*=[0-9][^ \\]*' "$DOCKERFILE" | sort -u)

for pkg in "${APK_PKGS[@]}"; do
  latest=$(apk_latest_version "$pkg")
  APK_LATEST+=("${latest:-UNKNOWN}")
done

###############################################################################
# PART 3 – Report
###############################################################################

HAS_UPDATES=false

print_row() {
  local name="$1" current="$2" latest="$3"
  if [[ "$latest" == "UNKNOWN" ]]; then
    # shellcheck disable=SC2059
    printf "  ${YELLOW}%-25s %s → %s${NC}\n" "$name" "$current" "UNKNOWN (check manually)"
    HAS_UPDATES=true
  elif [[ "$current" == "$latest" ]]; then
    # shellcheck disable=SC2059
    printf "  ${GREEN}%-25s %s ✓${NC}\n" "$name" "$current"
  else
    # shellcheck disable=SC2059
    printf "  ${RED}%-25s %s → %s${NC}\n" "$name" "$current" "$latest"
    HAS_UPDATES=true
  fi
}

echo ""
echo -e "${BOLD}${CYAN}── Tool Binaries ──${NC}"
print_row "kubectl"   "$KUBECTL_CURRENT"   "$KUBECTL_LATEST"
print_row "helm"      "$HELM_CURRENT"      "$HELM_LATEST"
print_row "terraform" "$TERRAFORM_CURRENT" "$TERRAFORM_LATEST"
print_row "taskfile"  "$TASKFILE_CURRENT"  "$TASKFILE_LATEST"
print_row "trivy"     "$TRIVY_CURRENT"     "$TRIVY_LATEST"

echo ""
echo -e "${BOLD}${CYAN}── Alpine Packages (v${ALPINE_VER}) ──${NC}"
idx=0
for pkg in "${APK_PKGS[@]}"; do
  print_row "$pkg" "${APK_CURRENT[$idx]}" "${APK_LATEST[$idx]}"
  idx=$((idx + 1))
done

echo ""

###############################################################################
# PART 4 – Apply (optional)
###############################################################################

if [[ "$HAS_UPDATES" == "false" ]]; then
  echo -e "${GREEN}All versions are up to date.${NC}"
  exit 0
fi

if [[ "$APPLY" == "false" ]]; then
  echo -e "${YELLOW}Updates available. Run with --apply to update the Dockerfile.${NC}"
  exit 1
fi

echo -e "${BOLD}Applying updates to Dockerfile…${NC}"

# Tool ARGs — iterate with positional args to avoid associative arrays
apply_tool_update() {
  local var="$1" current="$2" latest="$3"
  if [[ "$current" != "$latest" ]]; then
    sed -i.bak "s/^ARG ${var}=.*/ARG ${var}=${latest}/" "$DOCKERFILE"
    echo "  Updated $var: $current → $latest"
  fi
}

apply_tool_update "KUBECTL_VERSION"   "$KUBECTL_CURRENT"   "$KUBECTL_LATEST"
apply_tool_update "HELM_VERSION"      "$HELM_CURRENT"      "$HELM_LATEST"
apply_tool_update "TERRAFORM_VERSION" "$TERRAFORM_CURRENT" "$TERRAFORM_LATEST"
apply_tool_update "TASKFILE_VERSION"  "$TASKFILE_CURRENT"  "$TASKFILE_LATEST"
apply_tool_update "TRIVY_VERSION"     "$TRIVY_CURRENT"     "$TRIVY_LATEST"

# Alpine packages (global replace to handle duplicates like py3-pip)
idx=0
for pkg in "${APK_PKGS[@]}"; do
  current="${APK_CURRENT[$idx]}"
  latest="${APK_LATEST[$idx]}"
  if [[ "$current" != "$latest" && "$latest" != "UNKNOWN" ]]; then
    # Escape + in package names for sed (e.g. g++)
    escaped_pkg=$(printf '%s' "$pkg" | sed 's/[+]/\\+/g')
    sed -i.bak "s/${escaped_pkg}=${current}/${escaped_pkg}=${latest}/g" "$DOCKERFILE"
    echo "  Updated ${pkg}: ${current} → ${latest}"
  fi
  idx=$((idx + 1))
done

# Cleanup sed backup files
rm -f "${DOCKERFILE}.bak"

echo ""
echo -e "${GREEN}Dockerfile updated.${NC}"
echo -e "${YELLOW}Remember to run: ./scripts/sync-versions.sh${NC}"
