#!/usr/bin/env python3
"""Gateway route header-filter gate.

Every HTTPRoute under stage2/ that forwards to a backend must carry both header filters. A route
that omits them fails SILENTLY and in two security-relevant ways:

  - X-Real-IP arrives from the client untouched, so a caller can forge its own address. Only the
    route overwrites it, from the trusted address meshConfig's numTrustedProxies establishes.
  - The backend's own Server header reaches the client. Mesh proxyHeaders.server.disabled only
    stops Envoy overwriting the header, it does not remove it.

Nothing in Terraform, Istio or the Gateway API objects to either, which is why this is a static
gate rather than a runtime check.

Scope is stage2/ only. The ArgoCD-managed hosts declare the same filters inline in chart values in
the argocd-apps repository, which this gate cannot see; that repo needs its own copy.

Two checks:

  A. Coverage   every HTTPRoute rule carrying backendRefs also references both filter locals.
                A rule with no backendRefs is exempt: a redirect-only route has no backend to
                forge a header for. That is what stage2/istio-gateway/routes.tf is.
  B. Contents   in a file that declares a gated route, the filter locals actually carry the
                header mutations. A local named right but emptied out would pass check A.

Check A counts `local.*_request_header_filter` references against `backendRefs` occurrences inside
each HTTPRoute resource, so a route whose second rule forgot the filters is caught. This requires
the repo idiom of declaring the filters as locals and referencing them; inlining the maps in the
route would fail the gate even if correct.

Usage: ./scripts/check-gateway-routes.py [--check]
  --check: accepted for symmetry with the other gates. This script never writes.
"""

from __future__ import annotations

import argparse
import os
import re
import sys
from pathlib import Path

REPO_ROOT = Path(
    os.environ.get("GATEWAY_ROUTES_REPO_ROOT", Path(__file__).resolve().parent.parent)
)
SOURCE_DIR = "stage2"

RESOURCE_RE = re.compile(r'^resource\s+"[^"]+"\s+"([^"]+)"\s*\{', re.M)
HTTPROUTE_RE = re.compile(r'kind\s*=\s*"HTTPRoute"')
BACKEND_RE = re.compile(r"\bbackendRefs\s*=")
REQUEST_REF_RE = re.compile(r"local\.\w*_request_header_filter\b")
RESPONSE_REF_RE = re.compile(r"local\.\w*_response_header_filter\b")

# The header contract itself. Each entry is (human name, pattern that must appear in the file).
REQUIRED_CONTENTS = (
    ("X-Real-IP set", re.compile(r'name\s*=\s*"X-Real-IP"')),
    ("X-Real-IP from the trusted address", re.compile(r"%REQ\(X-ENVOY-EXTERNAL-ADDRESS\)%")),
    ("x-envoy-peer-metadata removed", re.compile(r'"x-envoy-peer-metadata"')),
    ("x-envoy-peer-metadata-id removed", re.compile(r'"x-envoy-peer-metadata-id"')),
    ("x-envoy-decorator-operation removed", re.compile(r'"x-envoy-decorator-operation"')),
    ("Strict-Transport-Security set", re.compile(r'name\s*=\s*"Strict-Transport-Security"')),
    ("Referrer-Policy set", re.compile(r'name\s*=\s*"Referrer-Policy"')),
    ("server header removed", re.compile(r'remove\s*=\s*\[\s*"server"\s*\]')),
)


def resource_blocks(text: str):
    """Yield (resource name, block text) for each top-level resource block.

    A block runs to the start of the next top-level resource, which is safe because these blocks
    never nest. Locals declared above the first resource stay out of every block, so a filter
    DEFINITION is never miscounted as a reference.
    """
    starts = [(m.start(), m.group(1)) for m in RESOURCE_RE.finditer(text)]
    for i, (start, name) in enumerate(starts):
        end = starts[i + 1][0] if i + 1 < len(starts) else len(text)
        yield name, text[start:end]


def check_file(path: Path, rel: str, errors: list[str]) -> int:
    """Return the number of gated routes checked in this file."""
    text = path.read_text(encoding="utf-8")
    if not HTTPROUTE_RE.search(text):
        return 0

    gated = 0
    for name, block in resource_blocks(text):
        if not HTTPROUTE_RE.search(block):
            continue
        backends = len(BACKEND_RE.findall(block))
        if backends == 0:
            continue
        gated += 1
        requests = len(REQUEST_REF_RE.findall(block))
        responses = len(RESPONSE_REF_RE.findall(block))
        if requests < backends:
            errors.append(
                f"{rel}: resource {name} has {backends} backendRefs but only {requests} "
                f"request header filter reference(s); every rule with a backend needs one"
            )
        if responses < backends:
            errors.append(
                f"{rel}: resource {name} has {backends} backendRefs but only {responses} "
                f"response header filter reference(s); every rule with a backend needs one"
            )

    if gated:
        for label, pattern in REQUIRED_CONTENTS:
            if not pattern.search(text):
                errors.append(f"{rel}: filter locals are missing {label}")
    return gated


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    # No-op: this script never writes. Declared so the call sites read the same as the other
    # gates, and so a typo'd flag exits 2 instead of passing.
    parser.add_argument("--check", action="store_true", help="no-op; accepted for symmetry")
    parser.parse_args()

    source_root = REPO_ROOT / SOURCE_DIR
    if not source_root.is_dir():
        print(f"ERROR: {source_root} not found", file=sys.stderr)
        return 1

    errors: list[str] = []
    files = 0
    gated = 0
    for path in sorted(source_root.rglob("*.tf")):
        if ".terraform" in path.parts:
            continue
        files += 1
        gated += check_file(path, str(path.relative_to(REPO_ROOT)), errors)

    # Walking nothing is the one way this gate passes without checking anything.
    if files == 0:
        errors.append("no .tf files were scanned; the file walk is broken")

    if errors:
        print("Gateway route drift detected:\n", file=sys.stderr)
        for error in errors:
            print(f"  {error}", file=sys.stderr)
        print(f"\n{len(errors)} problem(s).", file=sys.stderr)
        return 1

    print(f"Gateway routes OK: {gated} route(s) with a backend carry both header filters, {files} .tf files scanned.")
    return 0


if __name__ == "__main__":
    sys.exit(main())
