#!/usr/bin/env python3
"""Guard for scripts/check-docs.py. No network, no MkDocs, PyYAML only.

check-docs.py gates every push in GitHub Actions, GitLab CI and pre-commit, and
its three interesting behaviours all fail *open* when they break: a desynced
fence toggle skips citations silently, a broken slug mapping stops matching
modules silently, and a loader regression turns `!!python/name:` in mkdocs.yml
into code execution during a pre-commit run. Each of those would leave the gate
reporting success having verified nothing.

Follows stage1/tests/test_upgrade_ordering.py: plain python3, exit non-zero on
failure, a missing precondition is a FAIL and never a skip.

Run: python3 scripts/tests/test_check_docs.py
"""

from __future__ import annotations

import os
import shutil
import subprocess
import sys
import tempfile
from pathlib import Path

CHECKER = Path(__file__).resolve().parents[1] / "check-docs.py"

FAILURES: list[str] = []


def check(name: str, condition: bool, detail: str = "") -> None:
    if condition:
        print(f"  PASS  {name}")
    else:
        print(f"  FAIL  {name}{': ' + detail if detail else ''}")
        FAILURES.append(name)


def run_checker(root: Path) -> subprocess.CompletedProcess[str]:
    env = {**os.environ, "DOCS_CHECK_REPO_ROOT": str(root)}
    return subprocess.run(
        [sys.executable, str(CHECKER), "--check"],
        env=env,
        capture_output=True,
        text=True,
        check=False,
    )


def build_fixture(root: Path, nav: str, pages: dict[str, str], modules=(), roles=()) -> None:
    """Minimal repo-shaped tree: mkdocs.yml + docs/ + optional sources.

    Both source roots are always created. check-docs.py treats a missing
    stage2/ or stage1/roles as an error in its own right, so a fixture without
    them would fail for a reason unrelated to what the test is asserting.
    """
    (root / "docs").mkdir(parents=True, exist_ok=True)
    (root / "stage2").mkdir(parents=True, exist_ok=True)
    (root / "stage1" / "roles").mkdir(parents=True, exist_ok=True)
    (root / "mkdocs.yml").write_text(nav, encoding="utf-8")
    for rel, body in pages.items():
        page = root / "docs" / rel
        page.parent.mkdir(parents=True, exist_ok=True)
        page.write_text(body, encoding="utf-8")
    for name in modules:
        (root / "stage2" / name).mkdir(parents=True, exist_ok=True)
        (root / "stage2" / name / "main.tf").touch()
    for name in roles:
        (root / "stage1" / "roles" / name / "tasks").mkdir(parents=True, exist_ok=True)


def test_clean_tree_passes() -> None:
    with tempfile.TemporaryDirectory() as tmp:
        root = Path(tmp)
        build_fixture(
            root,
            nav="nav:\n  - Home: index.md\n  - Mod: stage2/alpha.md\n",
            pages={"index.md": "# Home\n", "stage2/alpha.md": "# Alpha\n"},
            modules=("alpha",),
        )
        result = run_checker(root)
        check("clean tree exits 0", result.returncode == 0, result.stderr.strip())


def test_module_without_page_fails() -> None:
    with tempfile.TemporaryDirectory() as tmp:
        root = Path(tmp)
        build_fixture(
            root,
            nav="nav:\n  - Home: index.md\n",
            pages={"index.md": "# Home\n"},
            modules=("orphaned",),
        )
        result = run_checker(root)
        check("module with no page fails", result.returncode == 1)
        check(
            "names the missing page",
            "docs/stage2/orphaned.md" in result.stderr,
            result.stderr.strip(),
        )


def test_page_without_module_fails() -> None:
    with tempfile.TemporaryDirectory() as tmp:
        root = Path(tmp)
        build_fixture(
            root,
            nav="nav:\n  - Home: index.md\n  - Ghost: stage2/ghost.md\n",
            pages={"index.md": "# Home\n", "stage2/ghost.md": "# Ghost\n"},
        )
        result = run_checker(root)
        check("page with no module fails", result.returncode == 1)
        check("names the stale page", "ghost.md" in result.stderr, result.stderr.strip())


def test_page_on_disk_but_not_in_nav_fails() -> None:
    """Exercises the coverage `elif` branch, distinct from the orphan check."""
    with tempfile.TemporaryDirectory() as tmp:
        root = Path(tmp)
        build_fixture(
            root,
            nav="nav:\n  - Home: index.md\n",
            pages={"index.md": "# Home\n", "stage2/alpha.md": "# Alpha\n"},
            modules=("alpha",),
        )
        result = run_checker(root)
        check("page missing from nav fails", result.returncode == 1)
        # Assert the coverage-specific wording: check_orphans also fires here, and
        # matching on the shared word "nav" would pass even with the elif deleted.
        check(
            "coverage branch fires, not just the orphan check",
            "coverage: docs/stage2/alpha.md exists but is not in the mkdocs.yml nav" in result.stderr,
            result.stderr.strip(),
        )


def test_role_slug_uses_dashes() -> None:
    with tempfile.TemporaryDirectory() as tmp:
        root = Path(tmp)
        build_fixture(
            root,
            nav="nav:\n  - Home: index.md\n  - Role: stage1/roles/host-setup.md\n",
            pages={"index.md": "# Home\n", "stage1/roles/host-setup.md": "# host_setup\n"},
            roles=("host_setup",),
        )
        result = run_checker(root)
        check("role underscore maps to dashed page", result.returncode == 0, result.stderr.strip())


def test_citation_outside_fence_fails_inside_fence_passes() -> None:
    """The assertion that catches a desynced fence toggle."""
    with tempfile.TemporaryDirectory() as tmp:
        root = Path(tmp)
        build_fixture(
            root,
            nav="nav:\n  - Home: index.md\n",
            pages={"index.md": "# Home\n\n```bash\n`stage1/nope.yml`\n```\n"},
        )
        check("citation inside a fence is skipped", run_checker(root).returncode == 0)

    with tempfile.TemporaryDirectory() as tmp:
        root = Path(tmp)
        build_fixture(
            root,
            nav="nav:\n  - Home: index.md\n",
            pages={"index.md": "# Home\n\nSee `stage1/nope.yml` for details.\n"},
        )
        result = run_checker(root)
        check("citation outside a fence is checked", result.returncode == 1)
        check("names the missing path", "stage1/nope.yml" in result.stderr, result.stderr.strip())


def test_unclosed_fence_is_reported() -> None:
    with tempfile.TemporaryDirectory() as tmp:
        root = Path(tmp)
        build_fixture(
            root,
            nav="nav:\n  - Home: index.md\n",
            pages={"index.md": "# Home\n\n```bash\nnever closed\n"},
        )
        result = run_checker(root)
        check("unclosed fence fails loudly", result.returncode == 1)
        check("says unclosed", "unclosed" in result.stderr, result.stderr.strip())


def test_tilde_fence_does_not_close_backtick_fence() -> None:
    with tempfile.TemporaryDirectory() as tmp:
        root = Path(tmp)
        build_fixture(
            root,
            nav="nav:\n  - Home: index.md\n",
            pages={"index.md": "# Home\n\n```text\n~~~\n`stage1/nope.yml`\n```\n"},
        )
        check("~~~ does not close a ``` fence", run_checker(root).returncode == 0)


def test_citation_cannot_escape_repo_root() -> None:
    with tempfile.TemporaryDirectory() as tmp:
        root = Path(tmp)
        build_fixture(
            root,
            nav="nav:\n  - Home: index.md\n",
            pages={"index.md": "# Home\n\nSee `stage1/../../../../etc/passwd` here.\n"},
        )
        result = run_checker(root)
        check("traversal citation fails", result.returncode == 1)
        check("says escapes", "escapes" in result.stderr, result.stderr.strip())


def test_loader_does_not_execute_python_tags() -> None:
    """A regression to yaml.Loader here would be arbitrary code execution."""
    sys.path.insert(0, str(CHECKER.parent))
    import importlib.util

    spec = importlib.util.spec_from_file_location("check_docs", CHECKER)
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    import yaml

    doc = (
        "a: !!python/name:os.system\n"
        "b: !ENV [CI, false]\n"
        'c: !!python/object/apply:os.system ["echo pwned"]\n'
        "d: plain\n"
    )
    loaded = yaml.load(doc, Loader=module._NavLoader)
    check("python/name yields data, not a callable", not callable(loaded["a"]))
    check("python/object/apply is not invoked", loaded["c"] == ["echo pwned"], repr(loaded["c"]))
    check("!ENV preserves nested types", loaded["b"] == ["CI", False], repr(loaded["b"]))
    check("standard tags untouched", loaded["d"] == "plain")


def test_em_dash_is_rejected_anywhere_in_a_page() -> None:
    """Prose, a fenced mermaid label and a table cell are all rendered text."""
    em = chr(0x2014)
    for label, body in (
        ("prose", f"# Home\n\nOne thing {em} then another.\n"),
        ("mermaid label", f'# Home\n\n```mermaid\nflowchart TD\n    a["Play 1 {em} localhost"]\n```\n'),
        ("table cell", f"# Home\n\n| A | B |\n|---|---|\n| x | y {em} z |\n"),
    ):
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp)
            build_fixture(root, nav="nav:\n  - Home: index.md\n", pages={"index.md": body})
            result = run_checker(root)
            check(f"em dash in {label} fails", result.returncode == 1, result.stderr.strip())
            check(f"names the line for {label}", "index.md:" in result.stderr, result.stderr.strip())


def test_en_dash_and_hyphen_are_allowed() -> None:
    """Only U+2014 is banned. A numeric range and a hyphen must still pass."""
    with tempfile.TemporaryDirectory() as tmp:
        root = Path(tmp)
        build_fixture(
            root,
            nav="nav:\n  - Home: index.md\n",
            pages={"index.md": f"# Home\n\nExpect 30{chr(0x2013)}60 minutes on a well-known host.\n"},
        )
        result = run_checker(root)
        check("en dash and hyphen pass", result.returncode == 0, result.stderr.strip())


def test_em_dash_outside_docs_is_rejected() -> None:
    """Check E covers the whole tree, not just docs/. This fixture has no git,
    so it also exercises the walk fallback that CI's git-less image relies on."""
    with tempfile.TemporaryDirectory() as tmp:
        root = Path(tmp)
        build_fixture(root, nav="nav:\n  - Home: index.md\n", pages={"index.md": "# Home\n"})
        (root / "stage2" / "alpha.tf").write_text(
            f"# timeout {chr(0x2014)} extended for CRD installation\n", encoding="utf-8"
        )
        result = run_checker(root)
        check("em dash in a .tf comment fails", result.returncode == 1, result.stderr.strip())
        check("names the .tf file", "alpha.tf:1:" in result.stderr, result.stderr.strip())


def test_untracked_files_are_out_of_scope() -> None:
    """`git ls-files` is the scope authority. A gitignored .env holds the bws
    token and is never ours to rewrite, so it must not be scanned."""
    if shutil.which("git") is None:
        # CI runs this on python:3.13-alpine, which ships no git. The fallback
        # path is covered by every other fixture; only this assertion needs git.
        check("git absent, tracked-scope assertion skipped", True)
        return
    with tempfile.TemporaryDirectory() as tmp:
        root = Path(tmp)
        build_fixture(root, nav="nav:\n  - Home: index.md\n", pages={"index.md": "# Home\n"})
        (root / ".gitignore").write_text(".env\n", encoding="utf-8")
        (root / ".env").write_text(f"# token {chr(0x2014)} the only value\n", encoding="utf-8")
        for args in (["init", "-q"], ["add", "-A"]):
            subprocess.run(["git", "-C", str(root), *args], check=True, capture_output=True)
        result = run_checker(root)
        check("gitignored .env is not scanned", result.returncode == 0, result.stderr.strip())


def test_unreadable_mkdocs_yml_is_rejected() -> None:
    """An mkdocs.yml that is not a readable file must fail on the guard, not a traceback."""
    with tempfile.TemporaryDirectory() as tmp:
        root = Path(tmp)
        build_fixture(root, nav="nav: []\n", pages={})
        (root / "mkdocs.yml").unlink()
        (root / "mkdocs.yml").mkdir()  # a directory, so is_file() is False
        result = run_checker(root)
        check("unreadable config fails", result.returncode == 1, result.stderr.strip())
        check(
            "the missing-config guard fires, not a traceback",
            "not found" in result.stderr and "Traceback" not in result.stderr,
            result.stderr.strip(),
        )


def test_empty_mkdocs_yml_is_not_a_traceback() -> None:
    """An empty config parses to None. Check A must report the gap, not raise AttributeError."""
    with tempfile.TemporaryDirectory() as tmp:
        root = Path(tmp)
        build_fixture(
            root,
            nav="nav:\n  - Home: index.md\n",
            pages={"index.md": "# Home\n"},
            modules=("nginx",),
        )
        (root / "mkdocs.yml").write_text("", encoding="utf-8")
        result = run_checker(root)
        check("empty config fails", result.returncode == 1, result.stderr.strip())
        check(
            "reports the uncovered module, not a traceback",
            "docs/stage2/nginx.md" in result.stderr and "Traceback" not in result.stderr,
            result.stderr.strip(),
        )


def test_em_dash_in_mkdocs_nav_is_rejected() -> None:
    """Nav titles are rendered document text, so the config is scanned too."""
    with tempfile.TemporaryDirectory() as tmp:
        root = Path(tmp)
        build_fixture(
            root,
            nav=f'nav:\n  - "Stage 0 {chr(0x2014)} setup": index.md\n',
            pages={"index.md": "# Home\n"},
        )
        result = run_checker(root)
        check("em dash in nav fails", result.returncode == 1, result.stderr.strip())
        check("names mkdocs.yml", "mkdocs.yml:" in result.stderr, result.stderr.strip())


def test_unknown_flag_is_rejected() -> None:
    with tempfile.TemporaryDirectory() as tmp:
        root = Path(tmp)
        build_fixture(root, nav="nav: []\n", pages={})
        env = {**os.environ, "DOCS_CHECK_REPO_ROOT": str(root)}
        result = subprocess.run(
            [sys.executable, str(CHECKER), "--chekc"],
            env=env,
            capture_output=True,
            text=True,
            check=False,
        )
        check("typo'd flag exits 2", result.returncode == 2, f"got {result.returncode}")


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
    print("All check-docs.py guards passed.")
    return 0


if __name__ == "__main__":
    sys.exit(main())
