#!/usr/bin/env python3
"""Documentation drift gate.

Five static checks over the docs tree. None of them needs MkDocs installed, so the
only dependency is PyYAML.

  A. Coverage    every stage2 module and stage1 role has a doc page AND a nav entry,
                 and every such page maps back to a real module or role.
  B. Citations   every repo path cited in inline code under docs/ actually exists.
  D. Orphans     every .md under docs/ appears in the mkdocs.yml nav.
  E. Typography  no em dash in any tracked text file.
  F. Wrapping    no hard-wrapped paragraph in any tracked Markdown file.

Check C, version pins, lives in scripts/sync-versions.sh because it is line-oriented
text substitution over sentinel blocks, which that script already does.

`mkdocs build --strict` is the other half of check D: it catches broken links between
pages, which is not attempted here.

Usage: ./scripts/check-docs.py [--check]
  --check: accepted for symmetry with sync-versions.sh. This script never writes,
           so it is a no-op flag.
"""

from __future__ import annotations

import argparse
import os
import re
import subprocess
import sys
from pathlib import Path

import yaml

REPO_ROOT = Path(os.environ.get("DOCS_CHECK_REPO_ROOT", Path(__file__).resolve().parent.parent))
DOCS_DIR = REPO_ROOT / "docs"
MKDOCS_YML = REPO_ROOT / "mkdocs.yml"

# ---------------------------------------------------------------------------
# Layout contract. THIS IS THE ONE PLACE that knows where a module or role doc
# page lives. Relocating docs/stage2/<mod>.md to docs/stage2/<mod>/index.md is a
# one-line change here and nothing else.
# ---------------------------------------------------------------------------
COVERAGE_RULES = (
    {
        "label": "stage2 module",
        "source_dir": "stage2",
        # stage2/host-keys holds generated key material, not Terraform. Requiring a
        # .tf file is what distinguishes a module from a data directory.
        "is_source": lambda d: any(d.glob("*.tf")),
        "doc_dir": "stage2",
        "slug": lambda name: name,
        # Section-level pages that describe the group rather than one module. Keep
        # this to pages about the section itself; anything module-shaped belongs in
        # the generated set instead.
        "section_pages": frozenset({"index", "dependency-graph"}),
    },
    {
        "label": "stage1 role",
        "source_dir": "stage1/roles",
        "is_source": lambda d: (d / "tasks").is_dir(),
        "doc_dir": "stage1/roles",
        "slug": lambda name: name.replace("_", "-"),
        "section_pages": frozenset({"index"}),
    },
)

# Root-level Markdown that ships outside docs/ but cites repo paths all the same.
ROOT_DOCS = ("README.md", "CONTRIBUTING.md", "SECURITY.md", "AGENTS.md")

# A backticked token counts as a repo-path citation only if it starts with one of
# these prefixes or exactly equals one of these names. Everything else in inline
# code - a CLI flag, an Ansible variable, a Helm value key - is ignored.
#
# `container/` and `site/` are deliberately absent: both are gitignored, so they
# exist on a working machine and not in a fresh CI clone.
CITATION_PREFIXES = ("stage1/", "stage2/", "scripts/", "docs/", ".github/")
CITATION_FILES = frozenset(
    {
        "Dockerfile",
        "Taskfile.yml",
        "mkdocs.yml",
        ".gitlab-ci.yml",
        ".pre-commit-config.yaml",
        ".env.example",
        ".gitignore",
        "README.md",
        "CONTRIBUTING.md",
        "SECURITY.md",
        "AGENTS.md",
        "LICENSE",
    }
)

# A citation containing one of these is a template or an example, not a claim about
# a concrete file, so it is skipped without complaint.
PLACEHOLDER_MARKERS = ("<", ">", "{{", "*", "...", "$")

# CommonMark code spans open and close with backtick runs of equal length, so a
# double-backtick span may contain single backticks. Group 2 is the content.
INLINE_CODE = re.compile(r"(?<!`)(`+)(?!`)(.+?)(?<!`)\1(?!`)")
# A fence is closed only by the same character, at least as long. Capturing both
# is what stops a ~~~ inside a ``` block, or an inner 3-tick fence inside a
# 4-tick one, from toggling the state off early.
FENCE = re.compile(r"^\s*(`{3,}|~{3,})")

# Spelled as an escape: the literal is indistinguishable from an en dash or a
# hyphen at a glance, and this is the one place the distinction has to be exact.
# U+2013 en dash is deliberately allowed; it is correct in numeric ranges.
EM_DASH = chr(0x2014)

# Check E walks the whole tree, so it needs to know what is not source.
# Matched against any path segment: generated or vendored wherever they appear.
SKIP_DIR_NAMES = frozenset({".git", ".terraform", "__pycache__", "node_modules", ".ruff_cache"})
# Matched against the first segment only. `container/` at the root is the
# gitignored bind-mount target; `scripts/container/` is real source and must not
# be caught by a name-based rule.
SKIP_ROOT_DIRS = frozenset({"site", "container", ".cache", ".venv-docs", ".venv"})


# ---------------------------------------------------------------------------
# mkdocs.yml parsing
# ---------------------------------------------------------------------------
class _NavLoader(yaml.SafeLoader):
    """SafeLoader that tolerates mkdocs' custom tags instead of executing them.

    mkdocs.yml carries `!!python/name:pymdownx.superfences.fence_code_format` and,
    once the social plugin is enabled, `!ENV [CI, false]`. yaml.safe_load raises
    ConstructorError on both.

    Switching to yaml.Loader or UnsafeLoader would make `!!python/name:<path>`
    import and execute whatever the config names, which is exactly what SafeLoader
    exists to prevent. Instead register a catch-all *multi*-constructor.

    That is safe because PyYAML's BaseConstructor.construct_object looks up
    node.tag in yaml_constructors (exact match) FIRST and only falls through to
    yaml_multi_constructors (prefix match) on a miss. SafeConstructor registers
    every standard tag exactly and registers zero multi-constructors, so a
    catch-all on prefix "" sees only the tags SafeLoader would have rejected.
    """


def _ignore_unknown_tag(loader: yaml.SafeLoader, tag_suffix: str, node: yaml.Node):
    del tag_suffix
    if isinstance(node, yaml.ScalarNode):
        return loader.construct_scalar(node)
    if isinstance(node, yaml.SequenceNode):
        # deep=True so nested scalars keep their real types: !ENV [CI, false]
        # must yield ["CI", False], not ["CI", "false"].
        return loader.construct_sequence(node, deep=True)
    return loader.construct_mapping(node, deep=True)


_NavLoader.add_multi_constructor("", _ignore_unknown_tag)


def load_nav_paths() -> set[str]:
    """Every docs-relative page path reachable from the nav tree."""
    with MKDOCS_YML.open(encoding="utf-8") as handle:
        # _NavLoader is a SafeLoader subclass; see its docstring for why this is
        # not the yaml.load foot-gun it looks like. `or {}`: an empty or
        # comment-only file parses to None, and .get would raise.
        config = yaml.load(handle, Loader=_NavLoader) or {}

    found: set[str] = set()

    def walk(node) -> None:
        if isinstance(node, str):
            if node.endswith(".md"):
                found.add(node)
        elif isinstance(node, list):
            for item in node:
                walk(item)
        elif isinstance(node, dict):
            for value in node.values():
                walk(value)

    walk(config.get("nav") or [])
    return found


# ---------------------------------------------------------------------------
# Check A - coverage
# ---------------------------------------------------------------------------
def check_coverage(nav_paths: set[str], errors: list[str]) -> int:
    checked = 0
    for rule in COVERAGE_RULES:
        source_root = REPO_ROOT / rule["source_dir"]
        if not source_root.is_dir():
            errors.append(f"coverage: {rule['source_dir']} does not exist")
            continue

        expected: dict[str, str] = {}
        for entry in sorted(source_root.iterdir()):
            if not entry.is_dir() or not rule["is_source"](entry):
                continue
            expected[entry.name] = f"{rule['doc_dir']}/{rule['slug'](entry.name)}.md"

        for name, doc_path in expected.items():
            checked += 1
            if not (DOCS_DIR / doc_path).is_file():
                errors.append(
                    f"coverage: {rule['label']} '{name}' has no page at docs/{doc_path}"
                )
            elif doc_path not in nav_paths:
                errors.append(
                    f"coverage: docs/{doc_path} exists but is not in the mkdocs.yml nav"
                )

        # And the reverse: a page whose module or role has been deleted or renamed.
        doc_root = DOCS_DIR / rule["doc_dir"]
        if doc_root.is_dir():
            valid_slugs = {rule["slug"](name) for name in expected}
            for page in sorted(doc_root.glob("*.md")):
                if page.stem in rule["section_pages"] or page.stem in valid_slugs:
                    continue
                errors.append(
                    f"coverage: docs/{rule['doc_dir']}/{page.name} has no matching "
                    f"{rule['label']} under {rule['source_dir']}/"
                )
    return checked


# ---------------------------------------------------------------------------
# Check B - path citations
# ---------------------------------------------------------------------------
def iter_citations(text: str):
    """Yield (lineno, token) for inline-code repo paths, fenced blocks skipped.

    Fenced blocks are full of shell placeholders and example output, so scanning
    them produces noise. The trade-off is that a path cited only inside a fence is
    never verified.

    Yields ``(0, None)`` once if the text ends inside an unclosed fence: silently
    skipping the rest of a page would let the gate report success having checked
    nothing after the first stray fence.
    """
    fence: tuple[str, int] | None = None
    for lineno, line in enumerate(text.splitlines(), start=1):
        match = FENCE.match(line)
        if match:
            char, run = match.group(1)[0], len(match.group(1))
            if fence is None:
                fence = (char, run)
            elif char == fence[0] and run >= fence[1] and not line[match.end() :].strip():
                fence = None
            continue
        if fence is not None:
            continue
        for match in INLINE_CODE.finditer(line):
            token = match.group(2).strip()
            if any(marker in token for marker in PLACEHOLDER_MARKERS):
                continue
            if token in CITATION_FILES or token.startswith(CITATION_PREFIXES):
                yield lineno, token
    if fence is not None:
        yield 0, None


def check_citations(errors: list[str]) -> int:
    checked = 0
    repo_root = REPO_ROOT.resolve()
    pages = sorted(DOCS_DIR.rglob("*.md"))
    pages += [REPO_ROOT / name for name in ROOT_DOCS]

    for page in pages:
        if not page.is_file():
            continue  # a root doc that does not exist is not this gate's problem
        rel = page.relative_to(REPO_ROOT)
        for lineno, token in iter_citations(page.read_text(encoding="utf-8")):
            if token is None:
                errors.append(
                    f"citation: {rel} ends inside an unclosed fence; "
                    "citations after it were not checked"
                )
                continue
            checked += 1
            # Trailing slash means "this directory"; strip it before resolving.
            # Resolve and confine: a `..` segment would otherwise turn the gate
            # into a filesystem existence oracle outside the repo.
            target = (REPO_ROOT / token.rstrip("/")).resolve()
            if not target.is_relative_to(repo_root):
                errors.append(f"citation: {rel}:{lineno} cites `{token}`, which escapes the repo")
            elif not target.exists():
                errors.append(f"citation: {rel}:{lineno} cites `{token}`, which does not exist")
    return checked


# ---------------------------------------------------------------------------
# Check D - orphans. `mkdocs build --strict` is the other half.
# ---------------------------------------------------------------------------
def check_orphans(nav_paths: set[str], errors: list[str]) -> int:
    checked = 0
    for page in sorted(DOCS_DIR.rglob("*.md")):
        rel = page.relative_to(DOCS_DIR).as_posix()
        checked += 1
        if rel not in nav_paths:
            errors.append(f"orphan: docs/{rel} is not in the mkdocs.yml nav")

    for rel in sorted(nav_paths):
        if not (DOCS_DIR / rel).is_file():
            errors.append(f"nav: mkdocs.yml points at docs/{rel}, which does not exist")
    return checked


# ---------------------------------------------------------------------------
# Check E - typography. House style bans the em dash; a comma, colon, full stop
# or parentheses always carries the same sentence.
# ---------------------------------------------------------------------------
def tracked_files() -> list[Path] | None:
    """Repo-relative paths git tracks, or None when git cannot answer."""
    try:
        completed = subprocess.run(
            ["git", "-C", str(REPO_ROOT), "ls-files", "-z"],
            capture_output=True,
            text=True,
            check=True,
            timeout=30,
        )
    except (OSError, subprocess.SubprocessError):
        return None
    # An empty listing is "git could not answer", not "the repo is empty".
    # Returning [] here would make check E scan nothing and report success.
    return [Path(entry) for entry in completed.stdout.split("\0") if entry] or None


def iter_text_files():
    """Every tracked text file, skipping build output and vendored trees.

    `git ls-files` is the authority when it can answer, because "tracked" is the
    scope this check claims and a walk cannot reproduce .gitignore. It gets a
    fallback rather than being required: the CI docs image is python:3.13-alpine,
    which ships no git (GitLab clones with the runner-helper image, not the job
    image), and the fixture harness runs against plain temp directories. Both of
    those hold the tracked set plus build output, which SKIP_* already excludes,
    so the walk is equivalent exactly where it is used.
    """
    rels = tracked_files()
    if rels is None:
        rels = sorted(p.relative_to(REPO_ROOT) for p in REPO_ROOT.rglob("*"))

    for rel in rels:
        path = REPO_ROOT / rel
        # Symlinks resolve to a file already listed. AGENTS.md alone has five
        # (CLAUDE.md, AGENT.md, GEMINI.md, .cursorrules, copilot-instructions.md),
        # so following them would report the same line six times.
        if path.is_symlink() or not path.is_file():
            continue
        if set(rel.parts) & SKIP_DIR_NAMES or rel.parts[0] in SKIP_ROOT_DIRS:
            continue
        try:
            text = path.read_text(encoding="utf-8")
        except (UnicodeDecodeError, OSError):
            continue  # binary, or unreadable; neither can carry prose
        yield rel, text


def check_typography(errors: list[str]) -> int:
    checked = 0
    for rel, text in iter_text_files():
        checked += 1
        # Fenced blocks are scanned too. Mermaid node labels live in fences and
        # are prose to the reader, and no command or sample output in this repo
        # needs the character.
        for lineno, line in enumerate(text.splitlines(), 1):
            column = line.find(EM_DASH)
            if column >= 0:
                errors.append(
                    f"typography: {rel}:{lineno}:{column + 1} has an em dash. "
                    "Use a comma, colon, full stop or parentheses."
                )
    return checked


# ---------------------------------------------------------------------------
# Check F - wrapping. Prose is authored one logical line per paragraph, list item
# and quoted line. Hard wrapping reflows on every edit, so a one-word change
# arrives in review as a rewritten block and `git blame` points at the reflow.
# Wrapping is the editor's job: .editorconfig sets max_line_length = off and
# .markdownlint.json disables MD013 so neither nags you back into it.
# ---------------------------------------------------------------------------
# Anything that opens a construct other than a paragraph. No line folds onto one.
BLOCK_STARTS = tuple(
    re.compile(pattern)
    for pattern in (
        r"#{1,6}(\s|$)",  # ATX heading
        r"(-{3,}|\*{3,}|_{3,})\s*$",  # thematic break, or a setext h2 underline
        r"=+\s*$",  # setext h1 underline
        r"={3,}(\s|$)",  # pymdownx.tabbed tab marker
        r"\|",  # table row
        r"<",  # HTML block or comment
        r"(!!!|\?\?\?)",  # admonition, pymdownx.details
        r"\[[^\]]*\]:\s",  # link reference definition
        r"\{",  # attr_list block
        r":\s",  # definition list body
    )
)
LIST_MARKER = re.compile(r"([-*+]|\d+[.)])(\s+)(?=\S)")
QUOTE_PREFIX = re.compile(r">+\s?")
# Two trailing spaces or a backslash is an explicit line break, not a wrap.
HARD_BREAK = re.compile(r"( {2,}|\\)$")
# A badge row. One image link per line is deliberate and stays that way.
IMAGE_LINK = re.compile(r"\[?!\[[^\]]*\]\([^)]*\)(\]\([^)]*\))?")


def _is_image_row(body: str) -> bool:
    return bool(body) and not IMAGE_LINK.sub("", body).strip()


def iter_wrapped(text: str):
    """Yield the 1-based line number of every line that continues the line above.

    A continuation is a non-blank line that opens nothing of its own and sits at
    the exact column where the preceding line's text starts: same quote prefix,
    same indent. That equality is what keeps an indented code block, a nested
    list and an admonition body out of it, since each starts at a column of its
    own after a blank line.
    """
    lines = text.split("\n")

    start = 0
    if lines and lines[0].strip() == "---":  # YAML front matter is not Markdown
        for end, line in enumerate(lines[1:], start=1):
            if line.strip() in ("---", "..."):
                start = end + 1
                break

    fence: tuple[str, int] | None = None
    block: tuple[str, int] | None = None  # (quote prefix, column of the text)
    previous = ""

    for lineno, line in enumerate(lines[start:], start=start + 1):
        match = FENCE.match(line)
        if match:
            char, run = match.group(1)[0], len(match.group(1))
            if fence is None:
                fence = (char, run)
            elif char == fence[0] and run >= fence[1] and not line[match.end() :].strip():
                fence = None
            block = None
        elif fence is not None:
            pass
        elif not line.strip():
            block = None
        else:
            quote = QUOTE_PREFIX.match(line)
            prefix = quote.group(0) if quote else ""
            rest = line[len(prefix) :]
            indent = len(rest) - len(rest.lstrip(" "))
            body = rest[indent:]
            marker = LIST_MARKER.match(body)

            if not body:  # a bare `>` ends the quoted paragraph
                block = None
            elif marker:
                block = (prefix, indent + marker.end())
            elif any(pattern.match(body) for pattern in BLOCK_STARTS):
                block = None
            elif (
                block == (prefix, indent)
                and not HARD_BREAK.search(previous)
                and not _is_image_row(body)
                and not _is_image_row(previous.strip())
            ):
                yield lineno
            else:
                block = (prefix, indent)
        previous = line


def check_wrapping(errors: list[str]) -> int:
    checked = 0
    for rel, text in iter_text_files():
        if rel.suffix != ".md":
            continue
        checked += 1
        for lineno in iter_wrapped(text):
            errors.append(
                f"wrap: {rel}:{lineno} continues the paragraph above. "
                "Join it onto the previous line; one line per paragraph."
            )
    return checked


def main() -> int:
    parser = argparse.ArgumentParser(description="Documentation drift gate.")
    # No-op: this script never writes. Declared so the call sites read the same
    # as sync-versions.sh, and so a typo'd flag exits 2 instead of passing.
    parser.add_argument("--check", action="store_true", help="no-op; accepted for symmetry")
    parser.parse_args()

    if not MKDOCS_YML.is_file():
        print(f"ERROR: {MKDOCS_YML} not found", file=sys.stderr)
        return 1

    errors: list[str] = []
    nav_paths = load_nav_paths()

    n_coverage = check_coverage(nav_paths, errors)
    n_citations = check_citations(errors)
    n_orphans = check_orphans(nav_paths, errors)
    n_typography = check_typography(errors)
    n_wrapping = check_wrapping(errors)
    # Scanning nothing is the one way checks E and F pass without checking anything.
    if n_typography == 0:
        errors.append("typography: no text files were scanned; the file walk is broken")

    if errors:
        print("Documentation drift detected:\n", file=sys.stderr)
        for error in errors:
            print(f"  {error}", file=sys.stderr)
        print(f"\n{len(errors)} problem(s).", file=sys.stderr)
        return 1

    print(
        f"Docs OK: {n_coverage} modules/roles covered, "
        f"{n_citations} path citations verified, "
        f"{n_orphans} pages in nav, "
        f"{n_typography} files free of em dashes, "
        f"{n_wrapping} Markdown files free of hard wraps."
    )
    return 0


if __name__ == "__main__":
    sys.exit(main())
