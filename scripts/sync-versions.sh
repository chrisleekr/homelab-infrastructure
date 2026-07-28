#!/bin/bash
# Sync tool versions from Dockerfile to README.md
# Usage: ./scripts/sync-versions.sh [--check]
#   --check: Only check if versions are in sync, exit 1 if not

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

DOCKERFILE="$REPO_ROOT/Dockerfile"
README="$REPO_ROOT/README.md"

# Parse arguments
CHECK_ONLY=false
if [[ "${1:-}" == "--check" ]]; then
  CHECK_ONLY=true
fi

# Extract versions from Dockerfile
extract_version() {
  local var_name=$1
  grep -E "^ARG ${var_name}=" "$DOCKERFILE" | cut -d'=' -f2
}

KUBECTL_VERSION=$(extract_version "KUBECTL_VERSION")
HELM_VERSION=$(extract_version "HELM_VERSION")
TERRAFORM_VERSION=$(extract_version "TERRAFORM_VERSION")
TASKFILE_VERSION=$(extract_version "TASKFILE_VERSION")
TRIVY_VERSION=$(extract_version "TRIVY_VERSION")

echo "Extracted versions from Dockerfile:"
echo "  kubectl: $KUBECTL_VERSION"
echo "  helm: $HELM_VERSION"
echo "  terraform: $TERRAFORM_VERSION"
echo "  taskfile: $TASKFILE_VERSION"
echo "  trivy: $TRIVY_VERSION"

# Create temp files for processing
TMP_FILE=$(mktemp)
VERSION_TABLE_FILE=$(mktemp)
trap 'rm -f "$TMP_FILE" "$VERSION_TABLE_FILE"' EXIT

# Write version table to temp file (avoids awk multiline string issues)
cat > "$VERSION_TABLE_FILE" << EOF
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

# Use awk to replace content between markers (inclusive of both markers)
# Reads version table from file to avoid multiline string issues
awk -v table_file="$VERSION_TABLE_FILE" '
  /<!-- VERSIONS_START/ {
    while ((getline line < table_file) > 0) print line
    close(table_file)
    skip = 1
    next
  }
  /<!-- VERSIONS_END/ { skip = 0; next }
  !skip { print }
' "$README" > "$TMP_FILE"

# Update badges
sed -i.bak "s/terraform-[0-9.]*-blue/terraform-${TERRAFORM_VERSION}-blue/g" "$TMP_FILE"
sed -i.bak "s/kubernetes-[0-9.]*-blue/kubernetes-${KUBECTL_VERSION}-blue/g" "$TMP_FILE"
rm -f "$TMP_FILE.bak"

# Check for changes
if diff -q "$README" "$TMP_FILE" > /dev/null 2>&1; then
  echo "No version changes detected"
  exit 0
fi

echo "Version changes detected:"
diff "$README" "$TMP_FILE" || true

if [[ "$CHECK_ONLY" == "true" ]]; then
  echo "Check mode: versions are out of sync"
  exit 1
fi

# Apply changes
mv "$TMP_FILE" "$README"
echo "README.md updated successfully"
