#!/usr/bin/env python3
"""Static ordering guard for the kubeadm rolling upgrade (issue #19).

A half-applied upgrade is silent: worker binaries land, nothing drains, kubelet keeps
running the old build. Ordering is therefore asserted mechanically instead of by review.

Parses the stage1 Ansible tree with PyYAML only. No cluster, no network, no ansible
runtime. A missing file, missing marker or unparseable YAML is a FAIL, never a skip:
a skip would let this harness go green while proving nothing.
"""

import re
import sys
from pathlib import Path

try:
    import yaml
except ImportError:  # pragma: no cover - environment problem, not a code path
    sys.exit("PyYAML not importable. Run with the interpreter that has ansible installed.")

ROOT = Path(__file__).resolve().parents[2]
STAGE1 = ROOT / "stage1"
ROLES = STAGE1 / "roles"
SITE = STAGE1 / "site.yml"
SERVER_MAIN = ROLES / "kubeadm_server" / "tasks" / "main.yml"
SERVER_CONTROL_PLANE = ROLES / "kubeadm_server" / "tasks" / "upgrade-control-plane.yml"
SERVER_CILIUM = ROLES / "kubeadm_server" / "tasks" / "upgrade-cilium.yml"
NODE_MAIN = ROLES / "kubeadm_node" / "tasks" / "main.yml"
AGENT_UPGRADE = ROLES / "kubeadm_agent" / "tasks" / "upgrade-node.yml"

# Worker sequence the issue mandates. Binaries land first, kubeadm rewrites the node
# config, only then is the node emptied and the runtime bounced.
WORKER_STEPS = [
    "apply_kubeadm_binary",
    "upgrade_node",
    "drain",
    "apply_runtime_kubelet",
    "wait_ready",
]
STEP_VAR = "kubeadm_upgrade_step"
NODE_TASKS = ROLES / "kubeadm_node" / "tasks"
DRAIN_FILE = "node-drain.yml"
UNCORDON_FILE = "node-uncordon.yml"
WAIT_READY_FILE = "node-wait-ready.yml"

BLOCK_KEYS = ("block", "rescue", "always")
TASK_INCLUDES = ("include_tasks", "import_tasks")
ROLE_INCLUDES = ("include_role", "import_role")

# Only an actual drift check gates a drain. kubeadm_upgrade_enabled defaults to true and is
# a kill switch, not a gate, so accepting it would let an ungated drain read as gated.
# A negated form is the inversion of the intended gate, so it must not count either.
GATE_UPGRADE = re.compile(r"(?<!not )\bkubeadm_node_upgrade_pending\b")
GATE_BOOTSTRAP = re.compile(r"\bnot\s+kubeadm_node_bootstrapped\b")


class HarnessError(Exception):
    """Anything that stops an assertion from being evaluated. Always reported as FAIL."""


def rel(path):
    return str(Path(path).relative_to(ROOT))


# --- loading -----------------------------------------------------------------------

_yaml_cache = {}


def load_yaml(path):
    path = Path(path)
    if path not in _yaml_cache:
        if not path.is_file():
            raise HarnessError(f"missing file: {rel(path)}")
        try:
            _yaml_cache[path] = yaml.safe_load(path.read_text(encoding="utf-8"))
        except yaml.YAMLError as exc:
            raise HarnessError(f"unparseable YAML in {rel(path)}: {exc}") from exc
    return _yaml_cache[path]


def load_tasks(path):
    data = load_yaml(path)
    if not isinstance(data, list):
        raise HarnessError(f"{rel(path)} is not a task list")
    return data


def read_text(path):
    path = Path(path)
    if not path.is_file():
        raise HarnessError(f"missing file: {rel(path)}")
    return path.read_text(encoding="utf-8")


def strip_comments(text):
    """Drop whole-line YAML comments so content checks scan code, not prose about it.

    Whole-line only: an inline split on "#" would truncate values that legitimately
    contain one, such as a URL fragment.
    """
    return "\n".join(line for line in text.splitlines() if not line.lstrip().startswith("#"))


def yaml_files():
    return sorted(p for p in STAGE1.rglob("*.y*ml") if p.is_file())


# --- task traversal ----------------------------------------------------------------


def walk(tasks, ancestors=()):
    """Yield (task, ancestors) depth-first. Ancestors are (owning_task, section) pairs."""
    for task in tasks or []:
        if not isinstance(task, dict):
            continue
        yield task, ancestors
        for key in BLOCK_KEYS:
            if isinstance(task.get(key), list):
                yield from walk(task[key], ancestors + ((task, key),))


def action_value(task, suffixes):
    """Argument of the first matching module key, accepting FQCN or short form."""
    for key, value in task.items():
        if key.split(".")[-1] in suffixes:
            return value
    return None


def role_entry_files(role_name, tasks_from="main"):
    """Role entry points. Meta dependencies run before the role's own tasks."""
    role_dir = ROLES / role_name
    files = []
    meta = role_dir / "meta" / "main.yml"
    if tasks_from == "main" and meta.is_file():
        for dep in (load_yaml(meta) or {}).get("dependencies") or []:
            name = (dep.get("role") or dep.get("name")) if isinstance(dep, dict) else dep
            if name:
                files.extend(role_entry_files(name))
    stem = tasks_from if tasks_from.endswith((".yml", ".yaml")) else f"{tasks_from}.yml"
    files.append(role_dir / "tasks" / stem)
    return files


def include_targets(task, base_dir):
    """Files a task pulls in. Empty when the task is not an include."""
    value = action_value(task, TASK_INCLUDES)
    if value is not None:
        spec = {"file": value} if isinstance(value, str) else (value or {})
        name = spec.get("file") or spec.get("_raw_params")
        return [base_dir / name] if name else []

    value = action_value(task, ROLE_INCLUDES)
    if value is not None:
        spec = {"name": value} if isinstance(value, str) else (value or {})
        name = spec.get("name")
        return role_entry_files(name, spec.get("tasks_from", "main")) if name else []
    return []


def gate_text(task, ancestors):
    """Every `when:` guarding a task, its own plus each enclosing block's."""
    parts = []
    for owner, _ in list(ancestors) + [(task, None)]:
        when = owner.get("when")
        if isinstance(when, list):
            parts.extend(str(item) for item in when)
        elif when is not None:
            parts.append(str(when))
    return " ".join(parts)


def edges(path):
    """(task, gate, child_path) for every include reachable from one task file."""
    return [
        (task, gate_text(task, ancestors), child)
        for task, ancestors in walk(load_tasks(path))
        for child in include_targets(task, Path(path).parent)
    ]


def play_edges():
    """Includes reachable directly from site.yml plays, via `roles:` or a `tasks:` block."""
    plays = load_yaml(SITE)
    if not isinstance(plays, list):
        raise HarnessError(f"{rel(SITE)} is not a play list")
    out = []
    for play in plays:
        if not isinstance(play, dict):
            continue
        for entry in play.get("roles") or []:
            spec = {"role": entry} if isinstance(entry, str) else (entry or {})
            name = spec.get("role") or spec.get("name")
            if name:
                for child in role_entry_files(name, spec.get("tasks_from", "main")):
                    out.append(({}, str(spec.get("when", "")), child))
        for section in ("pre_tasks", "tasks", "post_tasks"):
            for task, ancestors in walk(play.get(section)):
                for child in include_targets(task, STAGE1):
                    out.append((task, gate_text(task, ancestors), child))
    return out


def server_play_roots():
    """Every task file the `hosts: server` play can reach, meta dependencies included.

    Rooting reachability at kubeadm_server/tasks/main.yml alone misses the path the control
    plane actually takes into kubeadm_node, which is a meta dependency of kubeadm_server and
    therefore never an include edge of that file.
    """
    plays = load_yaml(SITE)
    if not isinstance(plays, list):
        raise HarnessError(f"{rel(SITE)} is not a play list")
    roots = []
    for play in plays:
        if not isinstance(play, dict) or play.get("hosts") != "server":
            continue
        for entry in play.get("roles") or []:
            spec = {"role": entry} if isinstance(entry, str) else (entry or {})
            name = spec.get("role") or spec.get("name")
            if name:
                roots.extend(role_entry_files(name, spec.get("tasks_from", "main")))
        for section in ("pre_tasks", "tasks", "post_tasks"):
            for task, _ in walk(play.get(section)):
                roots.extend(include_targets(task, STAGE1))
    if not roots:
        raise HarnessError(f"{rel(SITE)}: no includes found under any `hosts: server` play")
    return roots


def reachable_from(*paths):
    """Transitive include closure.

    A broken edge is a FAIL, not a dead end: silently pruning the subtree behind a renamed
    file would make every reachability check pass by seeing nothing.
    """
    seen, errors, queue = set(), [], [Path(p) for p in paths]
    while queue:
        current = queue.pop()
        if current in seen:
            continue
        seen.add(current)
        try:
            queue.extend(child for _, _, child in edges(current))
        except HarnessError as exc:
            errors.append(str(exc))
    if errors:
        raise HarnessError("; ".join(sorted(set(errors))))
    return seen


def includes_of(path):
    """Ordered (index, child_path) of every include in one task file."""
    return list(enumerate(child for _, _, child in edges(path)))


def resolve_marker(step, path):
    """Locate a marked task plus the content it stands for.

    A marker alone proves nothing, so callers assert against what it resolves to: the
    included file when the task is an include, otherwise the task itself.
    """
    for task, ancestors in walk(load_tasks(path)):
        if (task.get("vars") or {}).get(STEP_VAR) != step:
            continue
        targets = include_targets(task, Path(path).parent)
        if targets:
            text = "".join(read_text(t) for t in targets)
            tasks = [t for target in targets for t in load_tasks(target)]
        else:
            text = yaml.safe_dump(task)
            tasks = [task]
        return task, ancestors, text, tasks
    raise HarnessError(f"no task in {rel(path)} carries vars.{STEP_VAR}: {step}")


# --- assertions --------------------------------------------------------------------
# Each returns (ok, detail). Tags live in CHECKS so an exception still names its criterion.


def worker_step_order():
    steps = [
        (task.get("vars") or {}).get(STEP_VAR)
        for task, _ in walk(load_tasks(AGENT_UPGRADE))
        if (task.get("vars") or {}).get(STEP_VAR)
    ]
    if steps == WORKER_STEPS:
        return True, " -> ".join(steps)
    return False, f"{rel(AGENT_UPGRADE)} step order is {steps or 'empty'}, expected {WORKER_STEPS}"


def _marker_content(step, predicate, expectation):
    # Comments stripped at the choke point, so no text predicate can be satisfied by prose
    # describing the thing instead of the thing itself.
    _, _, text, tasks = resolve_marker(step, AGENT_UPGRADE)
    if predicate(strip_comments(text), tasks):
        return True, ""
    return False, f"content behind marker '{step}' is missing {expectation}"


def drain_content():
    return _marker_content(
        "drain",
        lambda text, _: "kubectl drain" in text and "--ignore-daemonsets" in text,
        "`kubectl drain` with --ignore-daemonsets",
    )


def upgrade_node_content():
    return _marker_content(
        "upgrade_node",
        lambda text, _: "kubeadm upgrade node" in text,
        "`kubeadm upgrade node`",
    )


def kubelet_restart_content():
    def restarts_kubelet(_, tasks):
        for task, _ancestors in walk(tasks):
            args = action_value(task, ("systemd", "systemd_service"))
            if not isinstance(args, dict):
                continue
            if (
                "kubelet" in str(args.get("name", ""))
                and args.get("daemon_reload") is True
                and args.get("state") == "restarted"
            ):
                return True
        return False

    return _marker_content(
        "apply_runtime_kubelet",
        restarts_kubelet,
        "an ansible.builtin.systemd kubelet task with daemon_reload: true and state: restarted",
    )


def wait_ready_content():
    """Structural, not a substring: the version must gate the retry loop.

    Ready alone is true throughout the upgrade, because the old kubelet holds its lease
    until systemd stops it. Only an `until:` that reads nodeInfo.kubeletVersion distinguishes
    "back up" from "back up on the new build".
    """

    def version_gates_the_wait(_, tasks):
        return any(
            "nodeInfo.kubeletVersion" in str(task.get("until", ""))
            for task, _ancestors in walk(tasks)
        )

    return _marker_content(
        "wait_ready",
        version_gates_the_wait,
        "an `until:` that polls on nodeInfo.kubeletVersion",
    )


def uncordon_in_always():
    """Uncordon is unconditional cleanup, so it belongs to the drain block's always."""
    _, ancestors, _, _ = resolve_marker("drain", AGENT_UPGRADE)
    for owner, section in reversed(ancestors):
        if section != "block":
            continue
        for task, _ in walk(owner.get("always")):
            if any("uncordon" in t.name for t in include_targets(task, AGENT_UPGRADE.parent)):
                return True, ""
    return False, (
        f"{rel(AGENT_UPGRADE)}: no uncordon include under the always: of the block "
        f"wrapping the drain step"
    )


def play_ordering():
    plays = load_yaml(SITE)
    if not isinstance(plays, list):
        raise HarnessError(f"{rel(SITE)} is not a play list")
    found = {}
    for position, play in enumerate(plays):
        hosts = play.get("hosts") if isinstance(play, dict) else None
        if hosts in ("server", "agent") and hosts not in found:
            found[hosts] = (position, play)

    problems = [f"no play with hosts: {h}" for h in ("server", "agent") if h not in found]
    if not problems:
        server_at, server_play = found["server"]
        agent_at, agent_play = found["agent"]
        if server_at >= agent_at:
            problems.append(f"server play at index {server_at} must precede agent at {agent_at}")
        if agent_play.get("serial") != 1:
            problems.append(f"agent play serial is {agent_play.get('serial')!r}, expected 1")
        for hosts, play in (("server", server_play), ("agent", agent_play)):
            if play.get("any_errors_fatal") is not True:
                problems.append(f"{hosts} play is missing any_errors_fatal: true")
    return not problems, f"{rel(SITE)}: {'; '.join(problems)}" if problems else ""


def drain_confined_to_workers():
    """Drain verbs stay in dedicated files, and none of them run on the control plane."""
    verbs = ("kubectl drain", "kubectl cordon", "kubectl uncordon")
    dedicated = {DRAIN_FILE, UNCORDON_FILE}
    strays, hosting = [], set()
    for path in yaml_files():
        # Comments stripped: a file may name the verb while warning against it.
        if not any(verb in strip_comments(path.read_text(encoding="utf-8")) for verb in verbs):
            continue
        hosting.add(path.name)
        if path.name not in dedicated:
            strays.append(rel(path))

    problems = [f"no {name} containing a kubectl drain/cordon command" for name in sorted(dedicated - hosting)]
    if strays:
        problems.append(f"drain/cordon verbs leaked into {strays}")
    # Seeded from the whole `hosts: server` play, not just kubeadm_server/tasks/main.yml.
    # The control plane reaches kubeadm_node through a meta dependency, so a drain added
    # there would run on every control-plane pass while a main.yml-only walk saw nothing.
    leaked = sorted(rel(p) for p in reachable_from(*server_play_roots()) if p.name in dedicated)
    if leaked:
        problems.append(f"reachable from the `hosts: server` play: {leaked}")
    return not problems, "; ".join(problems)


def upgrade_plan_consumed():
    """`kubeadm upgrade plan` output must gate something, not just decorate the log."""
    flat = [task for task, _ in walk(load_tasks(SERVER_CONTROL_PLANE))]
    register = plan_at = None
    for position, task in enumerate(flat):
        command = action_value(task, ("command", "shell"))
        if isinstance(command, str) and "kubeadm upgrade plan" in command:
            register, plan_at = task.get("register"), position
            break
    if not register:
        return False, f"{rel(SERVER_CONTROL_PLANE)}: no registered `kubeadm upgrade plan` task"

    for task in flat[plan_at + 1 :]:
        if register in str(task.get("when", "")):
            return True, f"{register} gates a later when:"
        assertion = action_value(task, ("assert",))
        if isinstance(assertion, dict) and register in str(assertion.get("that", "")):
            return True, f"{register} drives a later assert:"
    return False, (
        f"{rel(SERVER_CONTROL_PLANE)}: {register} is only displayed, never consumed by a "
        f"later when: or assert:"
    )


# There was an `upgrade_assert_regex` check here, asserting exactly one backslash before
# `[upgrade` in the success assert. It was removed because its premise was wrong: Jinja lexes
# string literals with unicode-escape, so '\[upgrade\]' and '\\[upgrade\\]' compile to the
# same regex and both match. The check enforced a cosmetic preference and would have led
# someone to "fix" working regexes elsewhere. The real hazard, that the banner text changes
# between kubeadm minors, is documented at the assert itself and cannot be checked statically.


def preflight_before_apply():
    entries = includes_of(SERVER_MAIN)
    preflight = [i for i, child in entries if child.name.startswith("preflight-")]
    mutating = [i for i, child in entries if child.name.startswith(("upgrade-", "apply-"))]
    if not preflight:
        return False, f"{rel(SERVER_MAIN)}: no preflight-*.yml include"
    if not mutating:
        return False, f"{rel(SERVER_MAIN)}: no upgrade/apply include"
    if max(preflight) < min(mutating):
        return True, ""
    return False, (
        f"{rel(SERVER_MAIN)}: preflight at {preflight} must all precede upgrade/apply at {mutating}"
    )


def pluto_version_pinned():
    """A floating `latest` makes the deprecated-API preflight unreproducible.

    Scoped to the release-download URL inside a role task. Matching any line
    mentioning pluto would pass on the inventory's doc-link comment, which
    proves nothing about what actually gets fetched.
    """
    for path in yaml_files():
        if "/roles/" not in path.as_posix():
            continue
        for line in strip_comments(path.read_text(encoding="utf-8")).splitlines():
            if "releases/download" not in line or "pluto" not in line.lower():
                continue
            if "latest" in line:
                return False, f"{rel(path)}: pluto URL uses 'latest': {line.strip()}"
            if "pluto_version" not in line:
                return False, f"{rel(path)}: pluto URL does not interpolate pluto_version: {line.strip()}"
            return True, rel(path)
    return False, "no pluto release-download URL found in any stage1 role task"


def cilium_upgrade_flags():
    # Comments are stripped first: naming cilium_cli_version in a comment that warns against
    # using it is correct, and must not read as a gate on it.
    text = strip_comments(read_text(SERVER_CILIUM))
    problems = []
    if "--version" not in text:
        problems.append("no --version passed to cilium upgrade")
    if "--dry-run" not in text:
        problems.append("no --dry-run preflight")
    if "cilium_cli_version" in text:
        problems.append("gates on cilium_cli_version, which is the CLI build, not the Cilium release")
    return not problems, f"{rel(SERVER_CILIUM)}: {'; '.join(problems)}" if problems else ""


def cilium_before_control_plane():
    """The CNI must already speak the new API surface before the control plane moves."""
    positions = {child.name: i for i, child in includes_of(SERVER_MAIN)}
    cilium = positions.get(SERVER_CILIUM.name)
    control = positions.get(SERVER_CONTROL_PLANE.name)
    if cilium is None or control is None:
        return False, f"{rel(SERVER_MAIN)}: missing {SERVER_CILIUM.name} or {SERVER_CONTROL_PLANE.name} include"
    return cilium < control, (
        ""
        if cilium < control
        else f"{rel(SERVER_MAIN)}: {SERVER_CILIUM.name} at index {cilium} must precede "
        f"{SERVER_CONTROL_PLANE.name} at index {control}"
    )


def binary_apply_gated():
    """Force-overwriting binaries on a joined node with no gate is the original bug.

    Covers the kubelet/runtime apply as well as the kubeadm one: replacing the kubelet under
    running pods is the more destructive half. GATE_BOOTSTRAP pins the polarity, because
    `when: kubeadm_node_bootstrapped` is the exact inversion of the intended gate and would
    otherwise satisfy a bare name match.
    """
    guarded = re.compile(r"apply-(kubeadm-binary|node-runtime-and-kubelet)|configure-kubeadm")
    ungated, found = [], []
    for task, ancestors in walk(load_tasks(NODE_MAIN)):
        for child in include_targets(task, NODE_MAIN.parent):
            if not guarded.search(child.name):
                continue
            found.append(child.name)
            if not GATE_BOOTSTRAP.search(gate_text(task, ancestors)):
                ungated.append(child.name)
    if not found:
        return False, f"{rel(NODE_MAIN)}: no kubeadm/kubelet binary apply include found"
    if ungated:
        return False, f"{rel(NODE_MAIN)}: {ungated} run without `when: not kubeadm_node_bootstrapped`"
    return True, ", ".join(sorted(found))


def kubelet_apply_inside_drain_block():
    _, drain_ancestors, _, _ = resolve_marker("drain", AGENT_UPGRADE)
    _, apply_ancestors, _, _ = resolve_marker("apply_runtime_kubelet", AGENT_UPGRADE)
    drain_blocks = {id(owner) for owner, section in drain_ancestors if section == "block"}
    apply_blocks = {id(owner) for owner, section in apply_ancestors if section == "block"}
    shared = drain_blocks & apply_blocks
    return bool(shared), (
        ""
        if shared
        else f"{rel(AGENT_UPGRADE)}: apply_runtime_kubelet sits outside the block that drains the node"
    )


def drain_always_gated():
    """Walk every include path from site.yml. A drain with no upgrade gate is a live outage."""
    ungated, seen, errors = [], set(), []
    stack = [(child, bool(GATE_UPGRADE.search(gate))) for _, gate, child in play_edges()]
    while stack:
        path, gated = stack.pop()
        if (path, gated) in seen:
            continue
        seen.add((path, gated))
        if path.name == DRAIN_FILE:
            if not gated:
                ungated.append(rel(path))
            continue
        try:
            children = edges(path)
        except HarnessError as exc:
            # A broken edge hides whatever is behind it, including a drain.
            errors.append(str(exc))
            continue
        for _, gate, child in children:
            stack.append((child, gated or bool(GATE_UPGRADE.search(gate))))

    if errors:
        return False, f"include graph is incomplete: {sorted(set(errors))}"
    if not any(path.name == DRAIN_FILE for path, _ in seen):
        return False, f"{DRAIN_FILE} is not reachable from {rel(SITE)}"
    return not ungated, (
        f"reachable with no ancestor upgrade-pending gate: {sorted(set(ungated))}" if ungated else ""
    )


def postflight_after_workers():
    """Verification must run after the workers, which means a later play, not a later task.

    The worker roll is its own `hosts: agent` play. A postflight included from the server
    role asserts that every node is on the target version while every worker is still on the
    old kubelet, so it aborts the run before the workers are ever reached.
    """
    plays = load_yaml(SITE)
    if not isinstance(plays, list):
        raise HarnessError(f"{rel(SITE)} is not a play list")

    agent_at, postflight_at = None, []
    for position, play in enumerate(plays):
        if not isinstance(play, dict):
            continue
        if play.get("hosts") == "agent" and agent_at is None:
            agent_at = position
        for section in ("pre_tasks", "tasks", "post_tasks"):
            for task, _ in walk(play.get(section)):
                for child in include_targets(task, STAGE1):
                    if child.name.startswith(("postflight", "verify")):
                        postflight_at.append(position)

    if agent_at is None:
        return False, f"{rel(SITE)}: no `hosts: agent` play"
    if not postflight_at:
        return False, f"{rel(SITE)}: no play includes a postflight/verify task file"
    if min(postflight_at) <= agent_at:
        return False, (
            f"{rel(SITE)}: postflight runs in play {min(postflight_at)}, "
            f"which is not after the agent play at {agent_at}"
        )
    # Also catch it being left behind in the server role, where it would fire too early.
    stale = [c.name for _, c in includes_of(SERVER_MAIN) if c.name.startswith(("postflight", "verify"))]
    if stale:
        return False, f"{rel(SERVER_MAIN)} still includes {stale}; it would run before the agent play"
    return True, f"play {min(postflight_at)} follows the agent play at {agent_at}"


def node_name_not_inventory_hostname():
    """The shared node tasks must address the Kubernetes node, not the inventory alias.

    The control plane's kubeadm config sets no nodeRegistration.name, so kubeadm registers it
    under the machine hostname while Ansible knows it as `server_host`. `kubectl get node
    server_host` is NotFound forever, which strands wait-ready after the upgrade already ran.
    """
    offenders = []
    for name in (DRAIN_FILE, UNCORDON_FILE, WAIT_READY_FILE):
        path = NODE_TASKS / name
        if "inventory_hostname" in strip_comments(read_text(path)):
            offenders.append(rel(path))
    if offenders:
        return False, f"{offenders} interpolate inventory_hostname; use kubeadm_node_name"
    return True, ""


def worker_drain_interlocked():
    """A worker must not drain itself unless the control-plane play signed off.

    Without the cross-host gate a worker would drain against a control plane whose preflight
    never ran, or that failed its own upgrade.
    """
    gate = None
    for task, ancestors in walk(load_tasks(AGENT_UPGRADE)):
        if (task.get("vars") or {}).get(STEP_VAR) == "drain":
            gate = gate_text(task, ancestors)
            break
    if gate is None:
        raise HarnessError(f"no drain-marked task in {rel(AGENT_UPGRADE)}")
    if "kubeadm_server_preflight_passed" not in gate:
        return False, f"{rel(AGENT_UPGRADE)}: drain is not gated on kubeadm_server_preflight_passed"
    if "hostvars" not in gate:
        return False, (
            f"{rel(AGENT_UPGRADE)}: kubeadm_server_preflight_passed must be read from the "
            f"control plane via hostvars, not from the worker's own scope"
        )
    return True, ""


CHECKS = (
    ("C1/C2/C4", worker_step_order),
    ("C1", drain_content),
    ("C2", upgrade_node_content),
    ("C4", kubelet_restart_content),
    ("C4", wait_ready_content),
    ("C3", uncordon_in_always),
    ("C5", play_ordering),
    ("C6", drain_confined_to_workers),
    ("C7", upgrade_plan_consumed),
    ("C8/C9", preflight_before_apply),
    ("C10", pluto_version_pinned),
    ("C11", cilium_upgrade_flags),
    ("C12", cilium_before_control_plane),
    ("C13", binary_apply_gated),
    ("C13", kubelet_apply_inside_drain_block),
    ("C14", drain_always_gated),
    ("C15", postflight_after_workers),
    ("C16", node_name_not_inventory_hostname),
    ("C17", worker_drain_interlocked),
)


def main():
    failed = 0
    for tag, check in CHECKS:
        try:
            ok, detail = check()
        except HarnessError as exc:
            ok, detail = False, str(exc)
        failed += not ok
        line = f"{'PASS' if ok else 'FAIL'} [{tag}] {check.__name__}: {detail}"
        print(line.rstrip(": "))

    total = len(CHECKS)
    print(f"{total - failed}/{total} assertions passed, {failed} failed")
    return 1 if failed else 0


if __name__ == "__main__":
    sys.exit(main())
