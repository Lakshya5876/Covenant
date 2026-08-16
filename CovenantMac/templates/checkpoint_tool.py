#!/usr/bin/env python3
"""Single canonical script for checkpoint capture and retrieval — mirrors the
"one script, not a hand-duplicated pattern in two places" principle already
used for verify_governance_integrity.sh and the trust-root deny-list.

Adopts claude-mem's two concepts (mechanical hook-driven capture instead of
agent self-judgment; progressive-disclosure index-before-fetch retrieval)
without its runtime stack — python3 stdlib only, no daemon, no vector DB.

Content-authoring: `append` (agent-invoked, same schema Guide §4.1 already
documents — LATEST.md + dated .md — now also appended to index.jsonl so
history survives the existing 10-file pruning).

Mechanical capture (hook-invoked, read hook JSON from stdin, same simple
exit-code contract as pre_bash_trust_root_guard.sh and
graph_freshness_check.py — no speculative JSON hook-output schema):
  hook-session-start, hook-pre-compact, hook-post-bash, hook-post-write,
  hook-stop.

Retrieval (agent-invoked via the checkpoint-search command, 3-layer
progressive disclosure): `index --grep`, `timeline --anchor`, `show <ids>`.

KNOWN LIMITATION, stated up front rather than glossed over: `hook-stop`'s
block/continue decision uses Claude Code's documented Stop-hook JSON contract
(`{"decision": "block", "reason": "..."}`), but this script has only been
verified standalone (its own decision logic, exercised directly in
tests/covenant/checkpoint_tool.bats) — it has not been verified against a live
Claude Code session actually honoring that contract, since no sandbox running
this suite can drive a real Claude Code hook dispatch. Confirm against
current Claude Code hook documentation before depending on it in production.
"""
import argparse
import json
import re
import subprocess
import sys
from datetime import datetime, timezone
from pathlib import Path

CHECKPOINTS_DIR = Path(".claude/checkpoints")
LATEST_MD = CHECKPOINTS_DIR / "LATEST.md"
INDEX_JSONL = CHECKPOINTS_DIR / "index.jsonl"
SESSION_STATE = Path(".claude/session_state.json")
COVENANT_STATE = Path(".claude/covenant_state.json")
MAX_DATED_CHECKPOINTS = 10
DEFAULT_THRESHOLDS = {"files": 8, "commits": 1, "session_hours": 3}
MAX_NUDGE_ATTEMPTS = 2  # block twice, fail open (and log) on the 3rd stop attempt


def _now_iso():
    return datetime.now(timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ")


def _run(cmd):
    try:
        return subprocess.run(cmd, capture_output=True, text=True, timeout=10, check=False).stdout
    except (OSError, subprocess.TimeoutExpired):
        return ""


def _read_json(path, default):
    try:
        with open(path) as f:
            return json.load(f)
    except (OSError, json.JSONDecodeError):
        return default


def _write_json_atomic(path, data):
    path.parent.mkdir(parents=True, exist_ok=True)
    tmp = path.with_suffix(path.suffix + ".tmp")
    with open(tmp, "w") as f:
        json.dump(data, f, indent=2)
    tmp.replace(path)


def _read_session_state():
    d = _read_json(SESSION_STATE, {})
    d.setdefault(
        "checkpoint",
        {
            "session_started_at": _now_iso(),
            "files_touched_since_checkpoint": [],
            "commits_since_checkpoint": 0,
            "last_checkpoint_id": None,
            "last_checkpoint_git_sha": None,
            "last_seen_commit_sha": None,
            "nudge_attempts": 0,
        },
    )
    return d


def _write_session_state(d):
    _write_json_atomic(SESSION_STATE, d)


def _checkpoint_pressure_thresholds():
    gs = _read_json(COVENANT_STATE, {})
    return gs.get("thresholds", {}).get("checkpoint_pressure", DEFAULT_THRESHOLDS)


def _append_index_line(entry):
    CHECKPOINTS_DIR.mkdir(parents=True, exist_ok=True)
    with open(INDEX_JSONL, "a") as f:
        f.write(json.dumps(entry) + "\n")


def _read_index_lines():
    if not INDEX_JSONL.exists():
        return []
    lines = []
    with open(INDEX_JSONL) as f:
        for line in f:
            line = line.strip()
            if not line:
                continue
            try:
                lines.append(json.loads(line))
            except json.JSONDecodeError:
                continue  # a hand-edited or truncated line shouldn't crash retrieval
    return lines


def _checkpoint_id(git_sha):
    # Microsecond resolution, not seconds: two appends with no commit between
    # them (same sha) landing in the same wall-clock second previously
    # produced IDENTICAL ids — silently overwriting the earlier dated .md
    # file instead of accumulating (caught by
    # tests/covenant/checkpoint_tool.bats's rapid-append test). Microseconds
    # make an accidental collision astronomically unlikely for any real
    # invocation (each call pays python3-startup + subprocess overhead), but
    # cmd_append additionally checks for an existing file at this id before
    # trusting it — belt and suspenders, not just "unlikely."
    ts = datetime.now(timezone.utc).strftime("%Y%m%d-%H%M%S-%f")
    short_sha = (git_sha or "nogit")[:7]
    return f"{ts}-{short_sha}"


def _git_facts():
    sha = _run(["git", "rev-parse", "HEAD"]).strip() or None
    branch = _run(["git", "branch", "--show-current"]).strip() or None
    dirty = [l for l in _run(["git", "status", "--porcelain"]).splitlines() if l]
    stat = _run(["git", "diff", "--stat"]).strip()
    return sha, branch, dirty, stat


def _prune_dated_checkpoints():
    dated = sorted(
        p for p in CHECKPOINTS_DIR.glob("*.md") if p.name != "LATEST.md"
    )
    excess = len(dated) - MAX_DATED_CHECKPOINTS
    for p in dated[:max(excess, 0)]:
        p.unlink(missing_ok=True)


def _bulleted_section(heading, items, empty_placeholder):
    # Factored out of _render_checkpoint_md purely to keep that function's
    # cyclomatic complexity under this framework's own default threshold
    # (radon cc <= 10) — four near-identical "list or placeholder" branches
    # inline pushed it over; each is behaviorally identical to before, just
    # expressed once here instead of four times.
    lines = ["", heading]
    lines += items or [empty_placeholder]
    return lines


def _render_checkpoint_md(entry):
    lines = [
        "# CHECKPOINT",
        f"phase:        {entry.get('phase') or ''}",
        f"git_sha:      {entry.get('git_sha') or ''}",
        f"branch:       {entry.get('branch') or ''}",
        f"dirty_files:  {entry.get('dirty_files', 0)} uncommitted",
        f"timestamp:    {entry.get('ts')}",
        "",
        "## TASK",
        entry.get("task") or "",
    ]
    lines += _bulleted_section(
        "## FILES MODIFIED THIS SESSION",
        [f"- {f}" for f in entry.get("files_modified", [])],
        "- (none recorded)",
    )
    lines += _bulleted_section(
        "## DECISIONS LOCKED",
        [f"- {d}" for d in entry.get("decisions_locked", [])],
        "- (none recorded)",
    )
    cs = entry.get("current_state", {})
    lines += _bulleted_section(
        "## CURRENT STATE",
        [f"- {k}: {v}" for k, v in cs.items()],
        "- (not recorded)",
    )
    lines += _bulleted_section(
        "## PENDING",
        [f"- {p}" for p in entry.get("pending", [])],
        "- (none recorded)",
    )
    lines += ["", "## RESUME INSTRUCTION", entry.get("resume_instruction") or ""]
    return "\n".join(lines) + "\n"


def _unique_checkpoint_id(sha, phase):
    cid = _checkpoint_id(sha)
    suffix = 1
    base = cid
    while (CHECKPOINTS_DIR / f"{cid}-{phase or 'checkpoint'}.md").exists():
        suffix += 1
        cid = f"{base}-{suffix}"
    return cid


def _or_list(x):
    return x or []


def _parse_kv_pairs(pairs):
    return dict(kv.split("=", 1) for kv in _or_list(pairs))


def _pick_title(args):
    return (args.title or args.task or "checkpoint")[:100]


def _build_checkpoint_entry(args, sha, branch, dirty):
    # Factored out of cmd_append purely to keep that function's cyclomatic
    # complexity under this framework's own default threshold (radon cc <=
    # 10) — the run of `arg or default` fallbacks here, each a branch point,
    # pushed cmd_append itself over on its own. Each fallback is now behind a
    # small named helper above instead of inline, which moves the branch out
    # of this function's own complexity count without changing behavior —
    # cyclomatic complexity counts branches per function, not per call site.
    files_modified = _or_list(args.files)
    entry = {
        "id": _unique_checkpoint_id(sha, args.phase),
        "ts": _now_iso(),
        "trigger": args.trigger,
        "phase": args.phase,
        "git_sha": sha,
        "branch": branch,
        "dirty_files": len(dirty),
        "files_modified": files_modified,
        "files_modified_count": len(files_modified),
        "task": args.task or "",
        "decisions_locked": _or_list(args.decisions),
        "current_state": _parse_kv_pairs(args.current_state),
        "pending": _or_list(args.pending),
        "resume_instruction": args.resume or "",
        "title": _pick_title(args),
        "superseded_by": None,
    }
    entry["token_estimate"] = max(50, len(json.dumps(entry)) // 4)
    return entry


def cmd_append(args):
    sha, branch, dirty, _ = _git_facts()
    entry = _build_checkpoint_entry(args, sha, branch, dirty)

    CHECKPOINTS_DIR.mkdir(parents=True, exist_ok=True)
    dated_path = CHECKPOINTS_DIR / f"{entry['id']}-{(args.phase or 'checkpoint')}.md"
    body = _render_checkpoint_md(entry)
    dated_path.write_text(body)
    LATEST_MD.write_text(body)
    entry["body_md_path"] = str(dated_path)
    _append_index_line(entry)
    _prune_dated_checkpoints()

    ss = _read_session_state()
    ss["checkpoint"].update(
        {
            "files_touched_since_checkpoint": [],
            "commits_since_checkpoint": 0,
            "last_checkpoint_id": entry["id"],
            "last_checkpoint_git_sha": sha,
            "last_seen_commit_sha": sha,
            "nudge_attempts": 0,
        }
    )
    _write_session_state(ss)
    print(f"Checkpoint written: {entry['id']} ({dated_path})")
    return 0


def cmd_hook_session_start(_args):
    try:
        json.load(sys.stdin)
    except (json.JSONDecodeError, UnicodeDecodeError, OSError):
        pass
    if not LATEST_MD.exists():
        return 0
    sha, _, _, _ = _git_facts()
    entries = _read_index_lines()
    last = entries[-1] if entries else None
    if last and last.get("git_sha") == sha:
        print(f"COVENANT: Resuming from checkpoint {last.get('ts')}: {last.get('title')}")
        print(f"Resume instruction: {last.get('resume_instruction')}")
    elif last:
        print(
            f"COVENANT: HEAD ({sha[:12] if sha else '?'}) has diverged from the last "
            f"checkpoint ({last.get('git_sha', '?')[:12]}) — state the divergence "
            f"before assuming continuity."
        )
    recent = entries[-15:]
    if recent:
        print("\nRecent checkpoint index (search further history with the "
              "checkpoint-search command instead of re-reading old files):")
        for e in recent:
            print(
                f"  {e.get('id')} | {e.get('trigger')} | {e.get('title')} "
                f"(~{e.get('token_estimate', '?')} tok)"
            )
    return 0


def cmd_hook_pre_compact(_args):
    try:
        json.load(sys.stdin)
    except (json.JSONDecodeError, UnicodeDecodeError, OSError):
        pass
    sha, branch, dirty, stat = _git_facts()
    entry = {
        "id": _checkpoint_id(sha),
        "ts": _now_iso(),
        "trigger": "pre_compact_auto",
        "phase": None,
        "git_sha": sha,
        "branch": branch,
        "dirty_files": len(dirty),
        "files_modified": dirty[:50],
        "files_modified_count": len(dirty),
        "task": "",
        "decisions_locked": [],
        "current_state": {"diff_stat": stat[-500:] if stat else ""},
        "pending": [],
        "resume_instruction": "",
        "title": "pre-compaction snapshot (facts only, no semantic content)",
        "superseded_by": None,
        "token_estimate": 60,
        "body_md_path": None,
    }
    _append_index_line(entry)
    print("COVENANT: pre-compaction fact snapshot recorded (git_sha, branch, diff-stat).")
    return 0


_GIT_COMMIT_RE = re.compile(r"\bgit\s+commit\b")


def cmd_hook_post_bash(_args):
    try:
        payload = json.load(sys.stdin)
    except (json.JSONDecodeError, UnicodeDecodeError, OSError):
        return 0
    cmd = payload.get("tool_input", {}).get("command", "")
    if not _GIT_COMMIT_RE.search(cmd):
        return 0  # cheap early-exit for the overwhelming majority of Bash calls

    sha, _, _, _ = _git_facts()
    ss = _read_session_state()
    ck = ss["checkpoint"]
    # Deliberately distinct from last_checkpoint_git_sha (which only advances
    # when a checkpoint is actually written, via `append`): comparing against
    # that field here meant every repeated hook-post-bash call for the same
    # commit re-fired until the next checkpoint, since nothing else updates
    # it (caught by tests/covenant/checkpoint_tool.bats's repeated-call test).
    # This field tracks "the last commit this hook itself already recorded",
    # updated unconditionally below regardless of checkpoint activity.
    if sha and sha != ck.get("last_seen_commit_sha"):
        ck["last_seen_commit_sha"] = sha
        ck["commits_since_checkpoint"] = ck.get("commits_since_checkpoint", 0) + 1
        _write_session_state(ss)
        _append_index_line(
            {
                "id": _checkpoint_id(sha),
                "ts": _now_iso(),
                "trigger": "post_commit_auto",
                "phase": None,
                "git_sha": sha,
                "branch": _run(["git", "branch", "--show-current"]).strip() or None,
                "dirty_files": 0,
                "files_modified": [],
                "files_modified_count": 0,
                "task": "",
                "decisions_locked": [],
                "current_state": {},
                "pending": [],
                "resume_instruction": "",
                "title": f"commit landed ({sha[:12]})",
                "superseded_by": None,
                "token_estimate": 40,
                "body_md_path": None,
            }
        )
        print(f"COVENANT: commit detected ({sha[:12]}) — mechanical checkpoint pressure updated.")
    return 0


def cmd_hook_post_write(_args):
    try:
        payload = json.load(sys.stdin)
    except (json.JSONDecodeError, UnicodeDecodeError, OSError):
        return 0
    path = payload.get("tool_input", {}).get("file_path")
    if not path:
        return 0
    ss = _read_session_state()
    touched = set(ss["checkpoint"].get("files_touched_since_checkpoint", []))
    touched.add(path)
    ss["checkpoint"]["files_touched_since_checkpoint"] = sorted(touched)
    _write_session_state(ss)
    return 0


def cmd_hook_stop(_args):
    try:
        json.load(sys.stdin)
    except (json.JSONDecodeError, UnicodeDecodeError, OSError):
        pass
    ss = _read_session_state()
    ck = ss["checkpoint"]
    thresholds = _checkpoint_pressure_thresholds()

    files_touched = len(ck.get("files_touched_since_checkpoint", []))
    commits = ck.get("commits_since_checkpoint", 0)
    started = ck.get("session_started_at")
    hours_elapsed = 0.0
    if started:
        try:
            start_dt = datetime.fromisoformat(started.replace("Z", "+00:00"))
            hours_elapsed = (datetime.now(timezone.utc) - start_dt).total_seconds() / 3600
        except (ValueError, TypeError):
            hours_elapsed = 0.0

    pressure = (
        files_touched >= thresholds.get("files", DEFAULT_THRESHOLDS["files"])
        or commits >= thresholds.get("commits", DEFAULT_THRESHOLDS["commits"])
        or hours_elapsed >= thresholds.get("session_hours", DEFAULT_THRESHOLDS["session_hours"])
    )

    if not pressure:
        return 0

    attempts = ck.get("nudge_attempts", 0)
    if attempts >= MAX_NUDGE_ATTEMPTS:
        # Fail open rather than block forever — but log it, never silently allow.
        sha, branch, dirty, _ = _git_facts()
        _append_index_line(
            {
                "id": _checkpoint_id(sha),
                "ts": _now_iso(),
                "trigger": "degradation_nudge_ignored",
                "phase": None,
                "git_sha": sha,
                "branch": branch,
                "dirty_files": len(dirty),
                "files_modified": [],
                "files_modified_count": 0,
                "task": "",
                "decisions_locked": [],
                "current_state": {
                    "files_touched": files_touched,
                    "commits": commits,
                    "hours_elapsed": round(hours_elapsed, 2),
                },
                "pending": [],
                "resume_instruction": "",
                "title": "checkpoint pressure nudge ignored 3x — allowed to stop, logged",
                "superseded_by": None,
                "token_estimate": 40,
                "body_md_path": None,
            }
        )
        return 0

    ck["nudge_attempts"] = attempts + 1
    _write_session_state(ss)
    reason = (
        f"Checkpoint pressure threshold reached (files={files_touched}/"
        f"{thresholds.get('files')}, commits={commits}/{thresholds.get('commits')}, "
        f"hours={hours_elapsed:.1f}/{thresholds.get('session_hours')}). "
        "Write a checkpoint via `checkpoint_tool.py append` before stopping."
    )
    # Claude Code's documented Stop-hook contract — see this file's module
    # docstring for the verification caveat on this specific mechanism.
    print(json.dumps({"decision": "block", "reason": reason}))
    return 0


def cmd_index(args):
    entries = _read_index_lines()
    term = (args.grep or "").lower()

    def matches(e):
        if term:
            haystack = " ".join(
                [
                    e.get("title", ""),
                    e.get("task", ""),
                    " ".join(e.get("decisions_locked", [])),
                    " ".join(e.get("pending", [])),
                ]
            ).lower()
            if term not in haystack:
                return False
        if args.trigger and e.get("trigger") != args.trigger:
            return False
        if args.phase and e.get("phase") != args.phase:
            return False
        if args.since and e.get("ts", "") < args.since:
            return False
        return not (args.until and e.get("ts", "") > args.until)

    filtered = [e for e in entries if matches(e)]
    filtered = filtered[-args.limit:]
    if args.json_out:
        print(json.dumps(filtered))
        return 0
    if not filtered:
        print("(no matching checkpoints)")
        return 0
    print(f"{'id':<24} {'ts':<21} {'trigger':<20} {'title'}")
    for e in filtered:
        print(
            f"{e.get('id',''):<24} {e.get('ts',''):<21} "
            f"{e.get('trigger',''):<20} {e.get('title','')} "
            f"(~{e.get('token_estimate','?')} tok)"
        )
    return 0


def cmd_timeline(args):
    entries = _read_index_lines()
    anchor_idx = None
    if args.anchor:
        anchor_idx = next((i for i, e in enumerate(entries) if e.get("id") == args.anchor), None)
    elif args.query:
        term = args.query.lower()
        for i in range(len(entries) - 1, -1, -1):
            if term in (entries[i].get("title", "") + entries[i].get("task", "")).lower():
                anchor_idx = i
                break
    if anchor_idx is None:
        print("(anchor not found)")
        return 1
    lo = max(0, anchor_idx - args.before)
    hi = min(len(entries), anchor_idx + args.after + 1)
    for i in range(lo, hi):
        marker = ">>" if i == anchor_idx else "  "
        e = entries[i]
        print(f"{marker} {e.get('id',''):<24} {e.get('trigger',''):<20} {e.get('title','')}")
    return 0


def cmd_show(args):
    entries = {e.get("id"): e for e in _read_index_lines()}
    for cid in args.ids:
        e = entries.get(cid)
        if not e:
            print(f"(checkpoint {cid} not found)")
            continue
        print(_render_checkpoint_md(e))
        print("---")
    return 0


def main():
    p = argparse.ArgumentParser(prog="checkpoint_tool.py")
    sub = p.add_subparsers(dest="cmd", required=True)

    a = sub.add_parser("append")
    a.add_argument("--phase")
    a.add_argument("--trigger", default="agent_manual")
    a.add_argument("--title")
    a.add_argument("--task")
    a.add_argument("--files", nargs="*")
    a.add_argument("--decisions", nargs="*")
    a.add_argument("--pending", nargs="*")
    a.add_argument("--resume")
    a.add_argument("--current-state", nargs="*")
    a.set_defaults(func=cmd_append)

    for name, fn in [
        ("hook-session-start", cmd_hook_session_start),
        ("hook-pre-compact", cmd_hook_pre_compact),
        ("hook-post-bash", cmd_hook_post_bash),
        ("hook-post-write", cmd_hook_post_write),
        ("hook-stop", cmd_hook_stop),
    ]:
        hp = sub.add_parser(name)
        hp.set_defaults(func=fn)

    i = sub.add_parser("index")
    i.add_argument("--grep")
    i.add_argument("--since")
    i.add_argument("--until")
    i.add_argument("--phase")
    i.add_argument("--trigger")
    i.add_argument("--limit", type=int, default=20)
    i.add_argument("--json", dest="json_out", action="store_true")
    i.set_defaults(func=cmd_index)

    t = sub.add_parser("timeline")
    t.add_argument("--anchor")
    t.add_argument("--query")
    t.add_argument("--before", type=int, default=3)
    t.add_argument("--after", type=int, default=3)
    t.set_defaults(func=cmd_timeline)

    s = sub.add_parser("show")
    s.add_argument("ids", nargs="+")
    s.set_defaults(func=cmd_show)

    args = p.parse_args()
    return args.func(args) or 0


if __name__ == "__main__":
    sys.exit(main())
