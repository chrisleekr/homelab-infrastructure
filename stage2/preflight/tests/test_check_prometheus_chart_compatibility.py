#!/usr/bin/env python3
"""Guard for stage2/preflight/scripts/check-prometheus-chart-compatibility.py. No network.

The checker gates every Stage 2 plan through `data.external`, so both of its failure
directions are expensive. Reading the wrong `version` pin fails *open*: the gate reports
PASS having compared an unrelated chart. Matching a pin the release does not own fails
*closed*: every plan dies with a message about chart compatibility that has nothing to do
with the edit. Neither shows up without a test, because the live pins currently agree.

Follows scripts/tests/test_check_docs.py: plain python3, exit non-zero on failure, a
missing precondition is a FAIL and never a skip.

Run: python3 stage2/preflight/tests/test_check_prometheus_chart_compatibility.py
"""

from __future__ import annotations

import importlib.util
import io
import json
import sys
import tempfile
from contextlib import redirect_stderr, redirect_stdout
from pathlib import Path

CHECKER = (
    Path(__file__).resolve().parents[1]
    / "scripts"
    / "check-prometheus-chart-compatibility.py"
)

FAILURES: list[str] = []


def check(name: str, condition: bool, detail: str = "") -> None:
    if condition:
        print(f"  PASS  {name}")
    else:
        print(f"  FAIL  {name}{': ' + detail if detail else ''}")
        FAILURES.append(name)


def load_checker():
    spec = importlib.util.spec_from_file_location("chart_compat", CHECKER)
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module


def write_tf(body: str) -> Path:
    handle = tempfile.NamedTemporaryFile(
        "w", suffix=".tf", delete=False, encoding="utf-8"
    )
    handle.write(body)
    handle.close()
    return Path(handle.name)


RELEASE = '''terraform {
  required_version = ">= 1.5.0"
}

resource "helm_release" "crds" {
  name    = "prometheus-operator-crds"
  chart   = "prometheus-operator-crds"
  version = "31.0.0"
}

resource "helm_release" "other" {
  name    = "some-other-chart"
  chart   = "some-other-chart"
  version = "9.9.9"
}
'''


class FakeResponse:
    def __init__(self, body: str) -> None:
        self._body = body

    def __enter__(self):
        return self

    def __exit__(self, *_):
        return False

    def read(self) -> bytes:
        return self._body.encode("utf-8")


def test_pin_is_scoped_to_its_own_release():
    module = load_checker()
    path = write_tf(RELEASE)

    check(
        "picks the pin from the matching release, not the first in the file",
        module.read_chart_pin("prometheus-operator-crds", path) == "31.0.0",
    )
    check(
        "picks a later release's pin by chart name",
        module.read_chart_pin("some-other-chart", path) == "9.9.9",
    )
    check(
        "required_version outside any release is ignored",
        module.read_chart_pin("prometheus-operator-crds", path) == "31.0.0",
    )

    path.unlink()


def test_missing_and_ambiguous_pins_fail_closed():
    module = load_checker()

    absent = write_tf(RELEASE)
    try:
        module.read_chart_pin("not-present", absent)
        check("absent chart raises", False, "no RuntimeError")
    except RuntimeError as error:
        check("absent chart raises", "found 0" in str(error), str(error))
    absent.unlink()

    duplicated = write_tf(RELEASE + RELEASE.split("terraform {", 1)[1].split("}", 1)[1])
    try:
        module.read_chart_pin("prometheus-operator-crds", duplicated)
        check("duplicate release raises", False, "no RuntimeError")
    except RuntimeError as error:
        check("duplicate release raises", "found 2" in str(error), str(error))
    duplicated.unlink()

    unpinned = write_tf(
        'resource "helm_release" "crds" {\n  chart = "prometheus-operator-crds"\n}\n'
    )
    try:
        module.read_chart_pin("prometheus-operator-crds", unpinned)
        check("release without a version pin raises", False, "no RuntimeError")
    except RuntimeError as error:
        check("release without a version pin raises", "found 0" in str(error), str(error))
    unpinned.unlink()


def test_pin_must_be_semver():
    module = load_checker()
    traversal = write_tf(
        'resource "helm_release" "crds" {\n'
        '  chart   = "prometheus-operator-crds"\n'
        '  version = "31.0.0/../../../elsewhere"\n'
        "}\n"
    )
    try:
        module.read_chart_pin("prometheus-operator-crds", traversal)
        check("non-semver pin is rejected", False, "no RuntimeError")
    except RuntimeError as error:
        check("non-semver pin is rejected", "found 0" in str(error), str(error))
    traversal.unlink()


def test_app_version_normalisation():
    module = load_checker()

    for raw, expected in (("v0.93.0", "0.93.0"), ("0.93.0", "0.93.0"), ('"v1.2.3"', "1.2.3")):
        module.urlopen = lambda *_, **__: FakeResponse(
            f"apiVersion: v2\nappVersion: {raw}\nname: chart\n"
        )
        check(
            f"appVersion {raw} normalises to {expected}",
            module.read_app_version("chart", "1.0.0") == expected,
        )

    module.urlopen = lambda *_, **__: FakeResponse("apiVersion: v2\nname: chart\n")
    try:
        module.read_app_version("chart", "1.0.0")
        check("missing appVersion raises", False, "no RuntimeError")
    except RuntimeError as error:
        check("missing appVersion raises", "appVersion is missing" in str(error), str(error))


def run_main(module, argv: list[str], stdin: str = "{}"):
    out, err = io.StringIO(), io.StringIO()
    saved_argv, saved_stdin = sys.argv, sys.stdin
    sys.argv = ["check-prometheus-chart-compatibility.py", *argv]
    sys.stdin = io.StringIO(stdin)
    try:
        with redirect_stdout(out), redirect_stderr(err):
            code = module.main()
    finally:
        sys.argv, sys.stdin = saved_argv, saved_stdin
    return code, out.getvalue(), err.getvalue()


def stub_versions(module, crd: str, stack: str) -> None:
    versions = {"prometheus-operator-crds": crd, "kube-prometheus-stack": stack}
    module.read_chart_pin = lambda chart, path: "1.0.0"
    module.read_app_version = lambda chart, chart_version: versions[chart]


def test_main_output_contract():
    module = load_checker()
    stub_versions(module, "0.93.0", "0.93.0")

    code, out, _ = run_main(module, ["--terraform"])
    check("matching versions exit 0", code == 0, f"got {code}")

    try:
        payload = json.loads(out)
    except json.JSONDecodeError as error:
        payload = {}
        check("--terraform prints one JSON object", False, str(error))
    else:
        check("--terraform prints one JSON object", True)

    check(
        "--terraform reports compatible=true",
        payload.get("compatible") == "true",
        repr(payload),
    )
    check(
        "every external result value is a string",
        payload != {} and all(isinstance(value, str) for value in payload.values()),
        repr(payload),
    )

    code, out, _ = run_main(module, [])
    check("plain mode exits 0 and prints no JSON", code == 0 and "{" not in out, out)


def test_main_failure_paths():
    module = load_checker()

    stub_versions(module, "0.93.0", "0.92.0")
    code, _, err = run_main(module, ["--terraform"])
    check("mismatched operator versions exit 1", code == 1, f"got {code}")
    check("mismatch names both versions", "0.93.0" in err and "0.92.0" in err, err)

    stub_versions(module, "0.93.0", "0.93.0")
    code, _, _ = run_main(module, ["--wrong-flag"])
    check("unknown flag exits 2", code == 2, f"got {code}")

    code, _, err = run_main(module, ["--terraform"], stdin="not json")
    check("invalid external provider input exits 1", code == 1, f"got {code}")
    check("invalid input is reported on stderr", "invalid external provider input" in err, err)


def main() -> int:
    if not CHECKER.is_file():
        print(f"FAIL: {CHECKER} not found", file=sys.stderr)
        return 1

    tests = [value for name, value in sorted(globals().items()) if name.startswith("test_")]
    for test in tests:
        print(test.__name__)
        test()

    print()
    if FAILURES:
        print(f"FAILED: {len(FAILURES)} assertion(s): {', '.join(FAILURES)}", file=sys.stderr)
        return 1
    print("All chart compatibility guards passed.")
    return 0


if __name__ == "__main__":
    sys.exit(main())
