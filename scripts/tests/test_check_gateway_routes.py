#!/usr/bin/env python3
"""Guard for scripts/check-gateway-routes.py. No network, no dependencies.

The gate's failure modes are all silent-pass: a broken resource-block splitter stops matching
routes, a broken walk scans nothing, and an over-eager exemption lets an unfiltered route through.
Each would leave the gate reporting success having verified nothing.

Follows scripts/tests/test_check_docs.py: plain python3, exit non-zero on failure, a missing
precondition is a FAIL and never a skip.

Run: python3 scripts/tests/test_check_gateway_routes.py
"""

from __future__ import annotations

import importlib.util
import os
import subprocess
import sys
import tempfile
from pathlib import Path

CHECKER = Path(__file__).resolve().parents[1] / "check-gateway-routes.py"
REPO_ROOT = Path(__file__).resolve().parents[2]

FAILURES: list[str] = []

FILTER_LOCALS = """
locals {
  demo_request_header_filter = {
    type = "RequestHeaderModifier"
    requestHeaderModifier = {
      set = [{
        name  = "X-Real-IP"
        value = "%REQ(X-ENVOY-EXTERNAL-ADDRESS)%"
      }]
      remove = [
        "x-envoy-peer-metadata",
        "x-envoy-peer-metadata-id",
        "x-envoy-decorator-operation",
      ]
    }
  }

  demo_response_header_filter = {
    type = "ResponseHeaderModifier"
    responseHeaderModifier = {
      set = [
        {
          name  = "Strict-Transport-Security"
          value = "max-age=63072000"
        },
        {
          name  = "Referrer-Policy"
          value = "strict-origin-when-cross-origin"
        },
      ]
      remove = ["server"]
    }
  }
}
"""

ROUTE_WITH_FILTERS = """
resource "kubectl_manifest" "route" {
  yaml_body = yamlencode({
    kind = "HTTPRoute"
    spec = {
      rules = [{
        filters = [
          local.demo_request_header_filter,
          local.demo_response_header_filter,
        ]
        backendRefs = [{
          name = "demo"
          port = 80
        }]
      }]
    }
  })
}
"""

ROUTE_WITHOUT_FILTERS = """
resource "kubectl_manifest" "route" {
  yaml_body = yamlencode({
    kind = "HTTPRoute"
    spec = {
      rules = [{
        backendRefs = [{
          name = "demo"
          port = 80
        }]
      }]
    }
  })
}
"""

ROUTE_SECOND_RULE_UNFILTERED = """
resource "kubectl_manifest" "route" {
  yaml_body = yamlencode({
    kind = "HTTPRoute"
    spec = {
      rules = [
        {
          filters = [
            local.demo_request_header_filter,
            local.demo_response_header_filter,
          ]
          backendRefs = [{
            name = "demo"
            port = 80
          }]
        },
        {
          backendRefs = [{
            name = "demo"
            port = 8080
          }]
        },
      ]
    }
  })
}
"""

REDIRECT_ONLY_ROUTE = """
resource "kubectl_manifest" "https_redirect" {
  yaml_body = yamlencode({
    kind = "HTTPRoute"
    spec = {
      rules = [{
        filters = [{
          type = "RequestRedirect"
          requestRedirect = {
            scheme     = "https"
            statusCode = 301
          }
        }]
      }]
    }
  })
}
"""


def check(name: str, condition: bool, detail: str = "") -> None:
    if condition:
        print(f"  PASS  {name}")
    else:
        print(f"  FAIL  {name}{': ' + detail if detail else ''}")
        FAILURES.append(name)


def run_checker(root: Path) -> subprocess.CompletedProcess[str]:
    env = {**os.environ, "GATEWAY_ROUTES_REPO_ROOT": str(root)}
    return subprocess.run(
        [sys.executable, str(CHECKER), "--check"],
        env=env,
        capture_output=True,
        text=True,
        check=False,
    )


def build_fixture(root: Path, body: str) -> None:
    module = root / "stage2" / "demo"
    module.mkdir(parents=True, exist_ok=True)
    (module / "httproute.tf").write_text(body, encoding="utf-8")


def test_compliant_route_passes() -> None:
    with tempfile.TemporaryDirectory() as tmp:
        root = Path(tmp)
        build_fixture(root, FILTER_LOCALS + ROUTE_WITH_FILTERS)
        result = run_checker(root)
        check("compliant route passes", result.returncode == 0, result.stderr.strip())


def test_missing_filters_fails() -> None:
    with tempfile.TemporaryDirectory() as tmp:
        root = Path(tmp)
        build_fixture(root, FILTER_LOCALS + ROUTE_WITHOUT_FILTERS)
        result = run_checker(root)
        check(
            "route with a backend and no filters fails",
            result.returncode == 1 and "request header filter" in result.stderr,
            result.stderr.strip(),
        )


def test_second_rule_unfiltered_fails() -> None:
    """The realistic bug: one rule was added later and nobody copied the filters into it."""
    with tempfile.TemporaryDirectory() as tmp:
        root = Path(tmp)
        build_fixture(root, FILTER_LOCALS + ROUTE_SECOND_RULE_UNFILTERED)
        result = run_checker(root)
        check(
            "route whose second rule lacks filters fails",
            result.returncode == 1 and "2 backendRefs" in result.stderr,
            result.stderr.strip(),
        )


def test_redirect_only_route_is_exempt() -> None:
    with tempfile.TemporaryDirectory() as tmp:
        root = Path(tmp)
        build_fixture(root, REDIRECT_ONLY_ROUTE)
        result = run_checker(root)
        check("redirect-only route is exempt", result.returncode == 0, result.stderr.strip())


# One entry per REQUIRED_CONTENTS label in check-gateway-routes.py, paired with the FILTER_LOCALS
# fragment that satisfies it. The test asserts the label lists match.
CONTENT_CASES = (
    ("X-Real-IP set", 'name  = "X-Real-IP"'),
    ("X-Real-IP from the trusted address", "%REQ(X-ENVOY-EXTERNAL-ADDRESS)%"),
    ("x-envoy-peer-metadata removed", '"x-envoy-peer-metadata",'),
    ("x-envoy-peer-metadata-id removed", '"x-envoy-peer-metadata-id",'),
    ("x-envoy-decorator-operation removed", '"x-envoy-decorator-operation",'),
    ("Strict-Transport-Security set", 'name  = "Strict-Transport-Security"'),
    ("Referrer-Policy set", 'name  = "Referrer-Policy"'),
    ("server header removed", 'remove = ["server"]'),
)


def test_missing_response_filter_fails() -> None:
    """The request and response counts are separate branches; this one must fire on its own."""
    with tempfile.TemporaryDirectory() as tmp:
        root = Path(tmp)
        route = ROUTE_WITH_FILTERS.replace("          local.demo_response_header_filter,\n", "")
        check("fixture drops the response filter", route != ROUTE_WITH_FILTERS)
        build_fixture(root, FILTER_LOCALS + route)
        result = run_checker(root)
        check(
            "route with only the request filter fails on the response filter",
            result.returncode == 1
            and "response header filter" in result.stderr
            and "request header filter" not in result.stderr,
            result.stderr.strip(),
        )


def test_hollowed_out_filter_contents_fail() -> None:
    """Check B: the locals are named right and referenced, but one header mutation is gone."""
    spec = importlib.util.spec_from_file_location("check_gateway_routes", CHECKER)
    checker = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(checker)
    labels = [label for label, _ in checker.REQUIRED_CONTENTS]
    check(
        "CONTENT_CASES covers every REQUIRED_CONTENTS label",
        labels == [label for label, _ in CONTENT_CASES],
        f"checker has {labels}",
    )
    for label, fragment in CONTENT_CASES:
        # Exactly one occurrence, so removing it leaves no other copy for the pattern to match.
        if FILTER_LOCALS.count(fragment) != 1:
            check(f"fixture carries {label}", False, f"{fragment!r} not found exactly once")
            continue
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp)
            build_fixture(root, FILTER_LOCALS.replace(fragment, "") + ROUTE_WITH_FILTERS)
            result = run_checker(root)
            check(
                f"filter locals without {label} fail",
                result.returncode == 1 and f"missing {label}" in result.stderr,
                result.stderr.strip(),
            )


def test_terraform_cache_is_ignored() -> None:
    """Provider and module caches under .terraform/ are not ours to gate."""
    with tempfile.TemporaryDirectory() as tmp:
        root = Path(tmp)
        build_fixture(root, FILTER_LOCALS + ROUTE_WITH_FILTERS)
        cached = root / "stage2" / "demo" / ".terraform" / "modules" / "vendored"
        cached.mkdir(parents=True)
        unfiltered = FILTER_LOCALS + ROUTE_WITHOUT_FILTERS
        (cached / "httproute.tf").write_text(unfiltered, encoding="utf-8")
        result = run_checker(root)
        check(
            "unfiltered route under .terraform/ is ignored",
            result.returncode == 0,
            result.stderr.strip(),
        )


def test_empty_tree_fails() -> None:
    """Scanning nothing must be an error, not a pass."""
    with tempfile.TemporaryDirectory() as tmp:
        root = Path(tmp)
        (root / "stage2").mkdir(parents=True, exist_ok=True)
        result = run_checker(root)
        check(
            "an empty stage2 tree fails",
            result.returncode == 1 and "file walk is broken" in result.stderr,
            result.stderr.strip(),
        )


def test_real_repo_passes() -> None:
    result = run_checker(REPO_ROOT)
    check("the repository itself passes", result.returncode == 0, result.stderr.strip())


def main() -> int:
    print("check-gateway-routes.py gate self-test")
    for test in (
        test_compliant_route_passes,
        test_missing_filters_fails,
        test_second_rule_unfiltered_fails,
        test_redirect_only_route_is_exempt,
        test_missing_response_filter_fails,
        test_hollowed_out_filter_contents_fail,
        test_terraform_cache_is_ignored,
        test_empty_tree_fails,
        test_real_repo_passes,
    ):
        test()
    if FAILURES:
        print(f"\n{len(FAILURES)} failure(s): {', '.join(FAILURES)}", file=sys.stderr)
        return 1
    print("\nAll checks passed.")
    return 0


if __name__ == "__main__":
    sys.exit(main())
