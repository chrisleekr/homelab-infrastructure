#!/usr/bin/env python3
"""Require both Prometheus charts to package the same Operator version."""

from pathlib import Path
import re
import sys
import json
from urllib.error import URLError
from urllib.request import Request, urlopen

ROOT = Path(__file__).resolve().parents[3]

CHARTS = {
    "prometheus-operator-crds": ROOT / "stage2/kubernetes/prometheus-crd.tf",
    "kube-prometheus-stack": ROOT / "stage2/monitoring/prometheus-stack.tf",
}

# Scoped to the helm_release that installs the chart, not to file position. A bare
# file-wide search reads the wrong pin as soon as a second release lands in the file.
RELEASE_PATTERN = re.compile(
    r'^resource\s+"helm_release"\s+"[^"]+"\s*\{.*?^\}',
    re.MULTILINE | re.DOTALL,
)

# Strict semver keeps the pin free of "/", so it cannot escape its URL path segment.
PIN_PATTERN = re.compile(
    r'^\s*version\s*=\s*"(\d+\.\d+\.\d+(?:[-+][0-9A-Za-z.-]+)?)"\s*(?:#.*)?$',
    re.MULTILINE,
)

APP_VERSION_PATTERN = re.compile(
    r'^appVersion:\s*["\']?([^"\'\s]+)["\']?\s*(?:#.*)?$',
    re.MULTILINE,
)


def read_chart_pin(chart: str, path: Path) -> str:
    chart_line = re.compile(rf'^\s*chart\s*=\s*"{re.escape(chart)}"\s*$', re.MULTILINE)
    blocks = [
        match.group(0)
        for match in RELEASE_PATTERN.finditer(path.read_text(encoding="utf-8"))
        if chart_line.search(match.group(0))
    ]

    if len(blocks) != 1:
        raise RuntimeError(
            f"expected exactly one helm_release for {chart} in {path}, found {len(blocks)}"
        )

    matches = PIN_PATTERN.findall(blocks[0])

    if len(matches) != 1:
        raise RuntimeError(
            f"expected exactly one version pin for {chart} in {path}, found {len(matches)}"
        )

    return matches[0]


def read_app_version(chart: str, chart_version: str) -> str:
    url = (
        "https://raw.githubusercontent.com/"
        "prometheus-community/helm-charts/"
        f"{chart}-{chart_version}/charts/{chart}/Chart.yaml"
    )

    request = Request(
        url,
        headers={"User-Agent": "homelab-infrastructure-version-check"},
    )

    try:
        with urlopen(request, timeout=20) as response:
            chart_yaml = response.read().decode("utf-8")
    except (OSError, URLError, UnicodeError) as error:
        raise RuntimeError(f"could not read {url}: {error}") from error

    match = APP_VERSION_PATTERN.search(chart_yaml)

    if not match:
        raise RuntimeError(f"appVersion is missing from {url}")

    return match.group(1).removeprefix("v")


def main() -> int:
    args = sys.argv[1:]

    if args not in ([], ["--terraform"]):
        print(
            "usage: check-prometheus-chart-compatibility.py [--terraform]",
            file=sys.stderr,
        )
        return 2

    terraform_mode = args == ["--terraform"]

    if terraform_mode:
        try:
            json.load(sys.stdin)
        except json.JSONDecodeError as error:
            print(f"ERROR: invalid external provider input: {error}", file=sys.stderr)
            return 1

    operator_versions: dict[str, str] = {}

    try:
        for chart, path in CHARTS.items():
            chart_version = read_chart_pin(chart, path)
            app_version = read_app_version(chart, chart_version)
            operator_versions[chart] = app_version

            if not terraform_mode:
                print(
                    f"{chart} {chart_version} "
                    f"packages Prometheus Operator {app_version}"
                )
    except RuntimeError as error:
        print(f"ERROR: {error}", file=sys.stderr)
        return 1

    crd_app_version = operator_versions["prometheus-operator-crds"]
    stack_app_version = operator_versions["kube-prometheus-stack"]

    if crd_app_version != stack_app_version:
        print(
            "ERROR: Prometheus Operator versions do not match: "
            f"CRDs={crd_app_version}, stack={stack_app_version}",
            file=sys.stderr,
        )
        return 1

    if terraform_mode:
        print(
            json.dumps(
                {
                    "compatible": "true",
                    "operator_version": stack_app_version,
                }
            )
        )
    else:
        print(
            "Prometheus chart compatibility: PASS "
            f"(Operator {stack_app_version})"
        )

    return 0


if __name__ == "__main__":
    sys.exit(main())
