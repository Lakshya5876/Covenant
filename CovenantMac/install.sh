#!/usr/bin/env bash
# install.sh — Covenant governance framework installer
# Usage: ./install.sh  (must be run from within the cloned repository)
#
# What this does:
#   1. Detects basket (greenfield vs brownfield) and validates preconditions
#   2. Downloads and copies governance files into the target repo
#   3. Installs git hooks and configures core.hooksPath
#   4. Installs code-review-graph MCP server (pipx — zero user knowledge required)
#   5. Builds the initial multi-domain graph
#   6. Writes .mcp.json (project-scoped, committed — not global settings)
#   7. Scaffolds org-level token policy if absent
#   8. Prints the one remaining human step (run /init-governance)
#
# NOTE ON graphify: safishamsi/graphify was evaluated and rejected — unnaturally
# high star count (68k, likely botted) indicates unverified provenance. Multi-domain
# graph coverage (SQL, infra, CI) is achieved here via code-review-graph extended
# file patterns instead.

set -euo pipefail

# ── Constants ──────────────────────────────────────────────────────────────────
FRAMEWORK_VERSION="v1"
FRAMEWORK_SEMVER="1.0.0"
# "<version-it-became-obsolete-in>:<path-relative-to-repo-root>"
# Append one line here whenever a release removes/renames a file this
# framework owns. _upgrade() (via _offer_deprecated_cleanup) offers to
# remove anything on this list whose version is newer than the repo's
# previously-recorded framework_version. Empty today — no release has
# deprecated anything yet; this is the mechanism for when one does.
DEPRECATED_SINCE=(
    # "1.1.0:.claude/hooks/old_thing.sh"
)
GRAPH_PACKAGE="code-review-graph==2.3.6"
ORG_POLICY_PATH="${HOME}/.claude/org_policy.json"
DEFAULT_WEEKLY_LIMIT=1250000
DEFAULT_DAILY_BUDGET_PCT=20

RED='\033[0;31m'; YELLOW='\033[1;33m'; GREEN='\033[0;32m'; BLUE='\033[0;34m'; RESET='\033[0m'

# ── Helpers (defined before first use) ────────────────────────────────────────
_info()    { echo -e "${BLUE}[install]${RESET} $*"; }
_success() { echo -e "${GREEN}[install]${RESET} ✓ $*"; }
_warn()    { echo -e "${YELLOW}[install]${RESET} ⚠ $*"; }
_error()   { echo -e "${RED}[install]${RESET} ✗ $*" >&2; exit 1; }

_require() {
    command -v "$1" >/dev/null 2>&1 || _error "$1 is required but not installed. $2"
}

# _rm and _confirm are intentionally duplicated from uninstall.sh rather than
# shared — both scripts are meant to be standalone/single-file (same
# rationale already documented for _check_framework_staleness/
# _bounded_git_fetch, which are also duplicated). _confirm's case-pattern
# match (not ${var,,}) is bash-3.2-safe — macOS ships bash 3.2 as /bin/bash
# by default and does not upgrade it; ${var,,} is bash 4+ only and caused a
# real crash for a real user before this was caught.
_rm() {
    local target="$1"
    if [ -e "$target" ] || [ -L "$target" ]; then
        rm -rf "$target"
        _success "Removed: $target"
    fi
}

_confirm() {
    local answer
    read -r -p "$1 [y/N] " answer </dev/tty
    case "$answer" in
        [Yy]|[Yy][Ee][Ss]) return 0 ;;
        *) return 1 ;;
    esac
}

_version_lt() {
    # Usage: _version_lt v1 v2 -> exit 0 if v1 < v2. Pure bash (indexed
    # arrays + C-style for loops are bash-3.2-safe) — deliberately not
    # `sort -V`, which is a GNU coreutils extension not available in
    # macOS's default BSD `sort` (the same class of "assumes a GNU tool"
    # trap that bit ${var,,} and the `timeout` binary earlier).
    local IFS=.
    local -a v1=($1) v2=($2)
    local i a b
    for ((i = 0; i < 3; i++)); do
        a="${v1[i]:-0}"; b="${v2[i]:-0}"
        case "$a" in ''|*[!0-9]*) a=0 ;; esac
        case "$b" in ''|*[!0-9]*) b=0 ;; esac
        [ "$a" -lt "$b" ] && return 0
        [ "$a" -gt "$b" ] && return 1
    done
    return 1
}

_fetch() {
    # Copy a file from the local REPO_DIR to $2
    local src="$1" dst="$2"
    local src_path="${REPO_DIR}/${src}"

    if [ ! -f "$src_path" ]; then
        _error "File not found: ${src_path}"
    fi

    cp "$src_path" "$dst" || _error "Failed to copy ${src} to ${dst}"
}

_write_hooks() {
    # Write covenant.sh, pre-commit, and pre-push into .githooks/ and configure git.
    # Called from the fresh-install flow (STEP 4) and from _upgrade().
    mkdir -p .githooks

    _fetch "templates/covenant.sh" ".githooks/covenant.sh"
    chmod +x .githooks/covenant.sh

    # Single source of truth for the governance-file integrity check, invoked
    # identically by CI (ci-covenant.yml) and the bats test suite. Extracted out
    # of ci-covenant.yml specifically so the two can never drift out of sync with
    # each other again (a prior audit found a hand-duplicated copy had gone
    # stale). Lives under .githooks/ deliberately — it's already covered by
    # the existing trust-root deny-list and Bash guard hook without any
    # further changes to either.
    _fetch "templates/verify_governance_integrity.sh" ".githooks/verify_governance_integrity.sh"
    chmod +x .githooks/verify_governance_integrity.sh

    # Both are fully static (no per-repo interpolation) — extracted to
    # templates/ alongside covenant.sh and verify_governance_integrity.sh so the
    # bats test fixture can deploy the exact real files instead of a
    # hand-maintained mirror, and so they're covered by the same integrity
    # manifest as every other static governance script.
    _fetch "templates/pre-commit" ".githooks/pre-commit"
    chmod +x .githooks/pre-commit

    _fetch "templates/pre-push" ".githooks/pre-push"
    chmod +x .githooks/pre-push

    git config core.hooksPath .githooks
}

_write_trust_root_settings() {
    # Scaffold .claude/settings.json (permissions.deny) + the Bash trust-root
    # guard hook. Both are universal — identical across every consumer repo,
    # no repo-specific discovery needed — so this is mechanized here rather
    # than left to the init prompt to transcribe by hand from the
    # implementation-package guide. Called from the fresh-install flow and
    # from _upgrade() (which backfills it for repos installed before this
    # existed). Repo-specific allow-list entries remain the init prompt's job.
    local dev_guide_dst="$1" init_pkg_dst="$2"
    mkdir -p .claude/hooks

    # Fully static except for two placeholder tokens, substituted below — see
    # templates/pre_bash_trust_root_guard.sh's own header comment for why this
    # is a real template rather than an inline heredoc: it lets the bats
    # suite exercise the ACTUAL matching logic (not a stub) by deploying this
    # exact file with test-specific substitutions.
    _fetch "templates/pre_bash_trust_root_guard.sh" ".claude/hooks/pre_bash_trust_root_guard.sh"
    sed -i.bak \
        -e "s|__DEV_GUIDE_DST__|${dev_guide_dst}|g" \
        -e "s|__INIT_PKG_DST__|${init_pkg_dst}|g" \
        .claude/hooks/pre_bash_trust_root_guard.sh
    rm -f .claude/hooks/pre_bash_trust_root_guard.sh.bak
    chmod +x .claude/hooks/pre_bash_trust_root_guard.sh

    # Graph read-time freshness guard — warns (never blocks) when a
    # code-review-graph query tool is about to answer against a stale index.
    # Fully static, no placeholder substitution needed.
    _fetch "templates/graph_freshness_check.py" ".claude/hooks/graph_freshness_check.py"
    chmod +x .claude/hooks/graph_freshness_check.py

    # Single canonical source for the trust-root deny-list. There used to be
    # a hand-duplicated JSON literal (fresh-write) and Python literal (merge)
    # that had, so far, stayed in sync only by luck — the same drift shape
    # that caused the CI/test duplication fixed in Module A8. Collapsed to one
    # script, one list, two code paths (create vs. merge) selected by
    # os.path.exists, so there is nothing left to keep hand-synced.
    python3 - "$dev_guide_dst" "$init_pkg_dst" << 'PYEOF'
import json, sys, os

dev_guide_dst, init_pkg_dst = sys.argv[1], sys.argv[2]

# Every hook command below is registered as a bare repo-root-relative path
# (e.g. "bash .claude/hooks/..."). Claude Code's Bash tool persists cwd
# across calls within a session, so an agent running `cd backend && ...`
# leaves every SUBSEQUENT hook invocation (this one included) launched with
# cwd=backend/ — at which point "python3 .claude/checkpoint_tool.py ..." or
# "bash .claude/hooks/pre_bash_trust_root_guard.sh" can't find its own file
# and either throws a raw Python traceback or a shell "No such file or
# directory" straight into the transcript instead of doing its job. `git
# rev-parse --show-toplevel` still resolves correctly from any subdirectory
# of the same working tree, so anchoring every hook command to it makes
# hook execution cwd-independent regardless of what the triggering tool call
# changed directory to. Falls back to the current directory (`pwd`) outside
# a git repo so the anchor itself never becomes the failure. Prepended as
# plain text, not baked into a helper var referenced elsewhere, so each
# hook's "command" is trivially greppable for its target script name — the
# dedup checks below match on substring, and the anchor prefix doesn't
# change what substring is present.
_ANCHOR = 'cd "$(git rev-parse --show-toplevel 2>/dev/null || pwd)" && '

REQUIRED_DENY = [
    "Bash(git reset --hard*)", "Bash(git rebase*)", "Bash(git clean*)",
    "Bash(rm -rf*)", "Bash(sudo*)", "Bash(DROP *)", "Bash(TRUNCATE *)",
    "Bash(DELETE FROM *)", "Bash(nc *)", "Bash(ssh *)", "Bash(scp *)",
    "Bash(git push --force*)", "Bash(git push -f*)",
    "Bash(git push --force-with-lease*)", "Bash(git push --mirror*)",
    "Bash(git push --delete*)", "Bash(git commit --no-verify*)",
    "Bash(git commit -n *)", "Bash(git push --no-verify*)",
    "Bash(git -c core.hooksPath*)", "Bash(SKIP_COVENANT=*)",
    "Read(.env)", "Read(**/.env)", "Read(**/.env.*)", "Read(**/*.pem)",
    "Read(**/id_rsa*)", "Read(**/.aws/credentials)",
    "Bash(cat .env*)", "Bash(cat **/.env*)", "Bash(cat **/*.pem*)",
    "Bash(cat **/id_rsa*)", "Bash(cat **/.aws/credentials*)",
    "Write(.githooks/**)", "Edit(.githooks/**)",
    "Write(.claude/hooks/**)", "Edit(.claude/hooks/**)",
    "Write(.claude/covenant_integrity.sha256)", "Edit(.claude/covenant_integrity.sha256)",
    "Write(.claude/covenant_state.json)", "Edit(.claude/covenant_state.json)",
    "Write(.claude/checkpoint_tool.py)", "Edit(.claude/checkpoint_tool.py)",
    "Write(.github/workflows/covenant.yml)", "Edit(.github/workflows/covenant.yml)",
    "Write(.mcp.json)", "Edit(.mcp.json)",
    f"Write({dev_guide_dst})", f"Edit({dev_guide_dst})",
    f"Write({init_pkg_dst})", f"Edit({init_pkg_dst})",
    "Bash(git notes*remove*)", "Bash(git update-ref -d*)",
    "Bash(git config core.hooksPath*)", "Bash(git config --add core.hooksPath*)",
    "Bash(git commit -a*)", "Bash(git commit -am*)", "Bash(git commit --amend*)",
]
# Deliberately excludes Write/Edit(.claude/settings.json), Write/Edit(CLAUDE.md),
# and Write/Edit(.claude/baseline.json): those three don't exist yet at
# install time and the init prompt must be able to create them. They're added
# as the init prompt's own FINAL edit, preserving the original
# write-settings-json-last guarantee exactly (Module A6/A7 CRITICAL EXECUTION
# ORDER). Also deliberately excludes .claude/checkpoints/**, .claude/commands/**,
# and .claude/session_state.json — all legitimately agent-written on an
# ongoing basis (checkpoint protocol, command generation, session tracking),
# not install-time artifacts. checkpoint_tool.py itself IS protected above
# (Write/Edit denied) despite living alongside those agent-writable paths —
# it's the enforcement mechanism, not its data; the same distinction as
# pre_bash_trust_root_guard.sh vs. the checkpoints it helps produce.

BASH_GUARD_HOOK_ENTRY = {
    "matcher": "Bash",
    "hooks": [{"type": "command", "command": _ANCHOR + "bash .claude/hooks/pre_bash_trust_root_guard.sh"}]
}
# Matches every tool the code-review-graph MCP server exposes
# (mcp__<server-name>__<tool-name> is Claude Code's MCP tool-naming
# convention) rather than enumerating the five tool names individually, so a
# future tool the server adds is covered without an install.sh change.
GRAPH_FRESHNESS_HOOK_ENTRY = {
    "matcher": "mcp__code-review-graph__.*",
    "hooks": [{"type": "command", "command": _ANCHOR + "python3 .claude/hooks/graph_freshness_check.py"}]
}

if os.path.exists('.claude/settings.json'):
    with open('.claude/settings.json') as f:
        d = json.load(f)
    perms = d.setdefault('permissions', {})
    perms.setdefault('defaultMode', 'default')
    deny = perms.setdefault('deny', [])
    added = [e for e in REQUIRED_DENY if e not in deny]
    deny.extend(added)

    hooks = d.setdefault('hooks', {})
    pretool = hooks.setdefault('PreToolUse', [])
    has_bash_guard = any(
        h.get('matcher') == 'Bash' and
        any('pre_bash_trust_root_guard.sh' in hh.get('command', '') for hh in h.get('hooks', []))
        for h in pretool
    )
    if not has_bash_guard:
        pretool.append(BASH_GUARD_HOOK_ENTRY)
        added.append("hooks.PreToolUse[Bash guard]")

    has_graph_freshness = any(
        any('graph_freshness_check.py' in hh.get('command', '') for hh in h.get('hooks', []))
        for h in pretool
    )
    if not has_graph_freshness:
        pretool.append(GRAPH_FRESHNESS_HOOK_ENTRY)
        added.append("hooks.PreToolUse[graph freshness guard]")

    with open('.claude/settings.json', 'w') as f:
        json.dump(d, f, indent=2)

    if added:
        print(f"Added {len(added)} missing trust-root protection(s) to existing .claude/settings.json")
    else:
        print("Existing .claude/settings.json already has all trust-root protections")
else:
    d = {
        "permissions": {"defaultMode": "default", "deny": REQUIRED_DENY},
        "hooks": {"PreToolUse": [BASH_GUARD_HOOK_ENTRY, GRAPH_FRESHNESS_HOOK_ENTRY]},
    }
    with open('.claude/settings.json', 'w') as f:
        json.dump(d, f, indent=2)
    print(".claude/settings.json scaffolded (trust-root deny-list + Bash guard hook + graph freshness guard — mechanical, not advisory)")
PYEOF
}

_write_integrity_manifest() {
    # Multi-file CI integrity manifest — covers every static, install.sh-owned
    # governance script, not just covenant.sh. Callers must ensure every listed
    # file already exists on disk first: _write_hooks (covenant.sh,
    # verify_governance_integrity.sh, pre-commit, pre-push),
    # _write_trust_root_settings (pre_bash_trust_root_guard.sh,
    # graph_freshness_check.py), and _write_checkpoint_memory
    # (checkpoint_tool.py) — hence this is its own function, called once
    # after all three, rather than embedded at the end of any one of them.
    # Regenerated on every fresh install AND every --upgrade, so it never
    # drifts from what's actually deployed. Uses sha256sum/shasum's native
    # manifest format (`<hash>  <path>` per line) so verify_governance_integrity.sh
    # can check it with a single `-c` invocation instead of hand-rolled compares.
    if command -v sha256sum >/dev/null 2>&1; then
        sha256sum \
            .githooks/covenant.sh \
            .githooks/verify_governance_integrity.sh \
            .githooks/pre-commit \
            .githooks/pre-push \
            .claude/hooks/pre_bash_trust_root_guard.sh \
            .claude/hooks/graph_freshness_check.py \
            .claude/checkpoint_tool.py \
            > .claude/covenant_integrity.sha256
    elif command -v shasum >/dev/null 2>&1; then
        shasum -a 256 \
            .githooks/covenant.sh \
            .githooks/verify_governance_integrity.sh \
            .githooks/pre-commit \
            .githooks/pre-push \
            .claude/hooks/pre_bash_trust_root_guard.sh \
            .claude/hooks/graph_freshness_check.py \
            .claude/checkpoint_tool.py \
            > .claude/covenant_integrity.sha256
    else
        _error "Could not compute integrity manifest (need sha256sum or shasum)."
    fi
}

_write_gitattributes() {
    # Protects the 7 integrity-pinned governance files from Windows' commonly
    # recommended core.autocrlf=true silently rewriting their bytes on
    # checkout. The manifest hashes raw on-disk bytes (sha256sum/shasum); a
    # normal `git checkout` on a machine with autocrlf enabled converts LF to
    # CRLF with zero content change, which changes the hash and breaks
    # verify_governance_integrity.sh — and for the bash-shebang files, also
    # breaks the script outright ("set: pipefail: invalid option name").
    # Found and fixed for this framework's own repo first; this propagates
    # the same fix to every repo the framework installs into, which needed
    # it independently — a target repo's .gitattributes is separate from
    # this one's. Idempotent: only appends entries not already present, and
    # called from both fresh install and --upgrade so existing installs get
    # backfilled.
    touch .gitattributes
    GITATTRIBUTES_ENTRIES=(
        ".githooks/covenant.sh text eol=lf"
        ".githooks/verify_governance_integrity.sh text eol=lf"
        ".githooks/pre-commit text eol=lf"
        ".githooks/pre-push text eol=lf"
        ".claude/hooks/pre_bash_trust_root_guard.sh text eol=lf"
        ".claude/hooks/graph_freshness_check.py text eol=lf"
        ".claude/checkpoint_tool.py text eol=lf"
    )
    for entry in "${GITATTRIBUTES_ENTRIES[@]}"; do
        if ! grep -qF "$entry" .gitattributes 2>/dev/null; then
            echo "$entry" >> .gitattributes
        fi
    done
}

_write_init_command() {
    # One-command init: extract the PROMPT START/END block from the init
    # package (the exact content a human would otherwise open the file and
    # copy-paste) and write it as a real slash command, so the remaining
    # manual step becomes "type /init-governance" instead of "open a file,
    # select all, copy, paste into a fresh conversation, hope nothing got
    # truncated." Uses the mechanism already proven working in downstream
    # installs (/audit, /review, /feature, etc. are plain .claude/commands/*.md
    # files with no frontmatter — the first line becomes the picker
    # description). Basket-agnostic: operates on whichever init package was
    # already fetched locally, greenfield or brownfield.
    local init_pkg_dst="$1"
    python3 - "$init_pkg_dst" << 'PYEOF'
import sys
init_pkg_dst = sys.argv[1]
with open(init_pkg_dst) as f:
    lines = f.readlines()
start = next(i for i, l in enumerate(lines) if 'PROMPT START' in l) + 1
end = next(i for i, l in enumerate(lines) if 'PROMPT END' in l)
prompt_body = ''.join(lines[start:end]).strip()
description = (
    "One-time governance bootstrap (run once, immediately after install.sh) — "
    "interrogates you about your stack and architecture, then writes CLAUDE.md, "
    f"layer scaffolding, and enforcement hooks. Source of truth: {init_pkg_dst}."
)
with open('.claude/commands/init-governance.md', 'w') as f:
    f.write(description + "\n\n" + prompt_body + "\n")
PYEOF
}

_write_checkpoint_memory() {
    # Mechanical checkpoint capture + progressive-disclosure retrieval —
    # adopts claude-mem's two concepts (hook-driven capture instead of agent
    # self-judgment; index-before-fetch retrieval) without its runtime stack.
    # See templates/checkpoint_tool.py's own module docstring for full design
    # notes and the one disclosed limitation (Stop-hook contract verified
    # standalone, not against a live Claude Code session).
    mkdir -p .claude/checkpoints .claude/commands
    _fetch "templates/checkpoint_tool.py" ".claude/checkpoint_tool.py"
    chmod +x .claude/checkpoint_tool.py
    [ -f ".claude/checkpoints/index.jsonl" ] || touch ".claude/checkpoints/index.jsonl"
    _fetch "templates/checkpoint_search_command.md" ".claude/commands/checkpoint-search.md"

    # Own merge pass, independent of _write_trust_root_settings's — both do
    # read-current-then-write-back, so running sequentially (not
    # concurrently) in the same install is safe; keeping them separate
    # functions avoids one already-large merge block growing unreadable.
    python3 << 'PYEOF'
import json, os

# See _write_trust_root_settings's _ANCHOR for the full rationale: every hook
# command here is a bare repo-root-relative path, and Claude Code's Bash
# tool persists cwd across calls — a `cd backend && ...` call leaves this
# exact hook launched from backend/ on every subsequent invocation, unable
# to find .claude/checkpoint_tool.py. `git rev-parse --show-toplevel` still
# resolves from any subdirectory of the same working tree.
_ANCHOR = 'cd "$(git rev-parse --show-toplevel 2>/dev/null || pwd)" && '

CHECKPOINT_HOOKS = {
    "SessionStart": {
        "matcher": "startup|resume|clear|compact",
        "hooks": [{"type": "command", "command": _ANCHOR + "python3 .claude/checkpoint_tool.py hook-session-start"}],
    },
    "PreCompact": {
        "matcher": "*",
        "hooks": [{"type": "command", "command": _ANCHOR + "python3 .claude/checkpoint_tool.py hook-pre-compact"}],
    },
    "Stop": {
        "hooks": [{"type": "command", "command": _ANCHOR + "python3 .claude/checkpoint_tool.py hook-stop"}],
    },
}
POST_TOOL_HOOKS = [
    {"matcher": "Bash", "hooks": [{"type": "command", "command": _ANCHOR + "python3 .claude/checkpoint_tool.py hook-post-bash"}]},
    {"matcher": "Write|Edit|MultiEdit", "hooks": [{"type": "command", "command": _ANCHOR + "python3 .claude/checkpoint_tool.py hook-post-write"}]},
]

if not os.path.exists('.claude/settings.json'):
    # _write_trust_root_settings always runs before this in both the fresh-
    # install and --upgrade flows, so settings.json should already exist —
    # this branch only guards against being called out of order.
    print("checkpoint memory: .claude/settings.json missing — run _write_trust_root_settings first")
else:
    with open('.claude/settings.json') as f:
        d = json.load(f)
    hooks = d.setdefault('hooks', {})
    added = []

    for event, entry in CHECKPOINT_HOOKS.items():
        bucket = hooks.setdefault(event, [])
        already = any(
            any('checkpoint_tool.py' in hh.get('command', '') for hh in h.get('hooks', []))
            for h in bucket
        )
        if not already:
            bucket.append(entry)
            added.append(f"hooks.{event}[checkpoint memory]")

    posttool = hooks.setdefault('PostToolUse', [])
    for entry in POST_TOOL_HOOKS:
        wanted_cmd = entry['hooks'][0]['command']
        already = any(
            any(hh.get('command') == wanted_cmd for hh in h.get('hooks', []))
            for h in posttool
        )
        if not already:
            posttool.append(entry)
            added.append(f"hooks.PostToolUse[{entry['matcher']}]")

    with open('.claude/settings.json', 'w') as f:
        json.dump(d, f, indent=2)

    if added:
        print(f"checkpoint memory: added {len(added)} hook registration(s) to .claude/settings.json")
    else:
        print("checkpoint memory: hooks already registered in .claude/settings.json")
PYEOF
}

_bounded_git_fetch() {
    # Usage: _bounded_git_fetch <repo_dir> — a real, hard wall-clock bound on
    # `git fetch`, with no external `timeout` binary (unavailable by default
    # on macOS). git's own http.lowSpeedLimit/http.lowSpeedTime only bound
    # the TRANSFER phase — they do nothing for a slow/hanging DNS lookup or
    # TCP connect, which is exactly the case that hung for multiple minutes
    # in testing (no network reachable to the remote at all). Backgrounds
    # the fetch and polls for up to 5 real wall-clock seconds regardless of
    # which phase it's stuck in, then kills it. Best-effort: returns
    # non-zero on timeout or fetch failure, never raises.
    local repo_dir="$1"
    GIT_TERMINAL_PROMPT=0 git -c http.lowSpeedLimit=1000 -c http.lowSpeedTime=5 -C "$repo_dir" fetch --quiet 2>/dev/null &
    local fetch_pid=$!
    local waited=0
    while kill -0 "$fetch_pid" 2>/dev/null && [ "$waited" -lt 5 ]; do
        sleep 1
        waited=$((waited + 1))
    done
    if kill -0 "$fetch_pid" 2>/dev/null; then
        kill -9 "$fetch_pid" 2>/dev/null
        wait "$fetch_pid" 2>/dev/null
        return 1
    fi
    wait "$fetch_pid" 2>/dev/null
}

_check_framework_staleness() {
    # This framework is meant to be cloned ONCE to a persistent local path
    # (e.g. ~/Covenant) and reused across many target repos — nothing
    # here auto-updates it. A real user ran an old local clone and got a
    # confusing "why doesn't /init-governance exist" report, because their
    # copy predated that feature entirely; install.sh had no way to tell
    # them their clone was behind. Best-effort only: never blocks install,
    # never requires network (silently skips if the fetch fails), and never
    # touches the working tree (fetch only, no pull).
    #
    # COVENANT_SKIP_STALENESS_CHECK=1 skips this entirely — for CI,
    # tests, or offline/sandboxed environments where even a bounded network
    # attempt is undesirable. _bounded_git_fetch caps the wall-clock cost at
    # ~5s for a DNS/connect-phase hang, but real-world conditions (a
    # credential helper prompting the OS keychain, an HTTPS auth handshake
    # that's slow rather than hung, etc.) can still cost real time that a
    # test suite or CI run shouldn't have to pay on every single invocation.
    [ "${COVENANT_SKIP_STALENESS_CHECK:-0}" = "1" ] && return 0
    local repo_dir="$1"
    git -C "$repo_dir" rev-parse --git-dir >/dev/null 2>&1 || return 0
    local upstream
    upstream=$(git -C "$repo_dir" rev-parse --abbrev-ref --symbolic-full-name '@{u}' 2>/dev/null || echo "")
    [ -n "$upstream" ] || return 0
    _bounded_git_fetch "$repo_dir" || return 0
    local behind
    behind=$(git -C "$repo_dir" rev-list --count "HEAD..${upstream}" 2>/dev/null || echo "0")
    case "$behind" in ''|*[!0-9]*) return 0 ;; esac
    [ "$behind" -gt 0 ] || return 0
    echo ""
    echo "⚠ Your local Covenant clone (${repo_dir}) is ${behind} commit(s)"
    echo "  behind ${upstream} — you may be missing recent fixes or features."
    echo "  Recommended: git -C '${repo_dir}' pull, then re-run this installer."
    echo ""
}

_offer_deprecated_cleanup() {
    # Usage: _offer_deprecated_cleanup <old_framework_version>
    # Walks DEPRECATED_SINCE, offers to remove anything declared obsolete in
    # a version newer than the repo's previous one AND still present on
    # disk. Silent (no prompt at all) when there's nothing to do — preserves
    # --upgrade's non-interactive default for the common case where nothing
    # has ever been deprecated.
    #
    # The length-check guard below is required, not defensive-programming
    # excess: under `set -u` (active throughout install.sh), expanding
    # "${arr[@]}" on a genuinely EMPTY array raises "unbound variable" in
    # this shell — even though the array itself is declared — while
    # "${#arr[@]}" (length) does not. DEPRECATED_SINCE is empty by default
    # (nothing has been deprecated yet), so skipping this check would break
    # every upgrade until the first entry is ever added.
    local old_version="$1"
    [ ${#DEPRECATED_SINCE[@]} -eq 0 ] && return 0
    local -a found=()
    local entry ver path
    for entry in "${DEPRECATED_SINCE[@]}"; do
        ver="${entry%%:*}"
        path="${entry#*:}"
        if _version_lt "$old_version" "$ver" && [ -e "$path" ]; then
            found+=("$path")
        fi
    done
    [ ${#found[@]} -eq 0 ] && return 0
    echo ""
    echo "The following files are obsolete as of this upgrade and can be removed:"
    local f
    for f in "${found[@]}"; do echo "  • $f"; done
    echo ""
    if _confirm "Remove these obsolete files?"; then
        for f in "${found[@]}"; do _rm "$f"; done
    else
        _warn "Kept obsolete files — remove manually if desired."
    fi
}

_write_reconcile_command() {
    # Usage: _write_reconcile_command <dev_guide_dst> <diff_file>
    # Same shape as _write_init_command: generates a real slash command
    # rather than expecting a human to manually diff and merge. Unlike
    # /init-governance, this one's job is explicitly NOT to regenerate a
    # file wholesale — CLAUDE.md is human-customized by now, so the command
    # instructs propose-and-approve edits only, mirroring the same
    # never-silently-write discipline /init-governance's own Phase A.5
    # approval gate already established.
    local dev_guide_dst="$1" diff_file="$2"
    local diff_content=""
    [ -f "$diff_file" ] && diff_content=$(cat "$diff_file")
    python3 - "$dev_guide_dst" "$diff_content" << 'PYEOF'
import sys
dev_guide_dst = sys.argv[1]
diff_content = sys.argv[2]
description = (
    "Reconcile CLAUDE.md with a changed engineering-standard source "
    f"({dev_guide_dst}) — run after install.sh --upgrade reports the dev "
    "guide's content changed."
)
instructions = f"""The engineering constitution's source ({dev_guide_dst}) changed content
during the last upgrade. CLAUDE.md was NOT touched automatically — it may contain
significant human-authored decisions by now, and a blind regeneration would lose them.

Read the diff below. For each substantive change (not formatting/wording-only
changes), propose a specific, individually-justified edit to CLAUDE.md: quote the
current text, propose the replacement, and give a one-line reason tied to what
actually changed in the source. Group proposals so each can be approved or
rejected independently — never present this as one big diff to rubber-stamp.

Do NOT edit CLAUDE.md until at least one proposed edit is explicitly approved.
Do NOT regenerate CLAUDE.md wholesale under any circumstance — every edit must be
traceable to a specific change in the diff below, not a fresh read of the whole
updated guide.

--- DIFF: {dev_guide_dst} (old vs. new) ---
{diff_content}
--- END DIFF ---
"""
with open('.claude/commands/reconcile-governance.md', 'w') as f:
    f.write(description + "\n\n" + instructions)
PYEOF
}

_upgrade() {
    cd "$REPO_ROOT"

    [ -f ".claude/covenant_state.json" ] || _error "--upgrade requires an existing governed repo (.claude/covenant_state.json not found)."

    # Read BEFORE the version-bump step overwrites it — needed to know which
    # deprecated-since entries are actually new to this repo (section below).
    OLD_FRAMEWORK_VERSION=$(python3 -c "
import json
try:
    with open('.claude/covenant_state.json') as f:
        v = json.load(f).get('framework_version')
    print(v if v else '')
except Exception:
    print('')
" 2>/dev/null)
    [ -n "$OLD_FRAMEWORK_VERSION" ] || OLD_FRAMEWORK_VERSION="0.0.0"

    echo ""
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo " Covenant Governance Framework — Upgrade to ${FRAMEWORK_SEMVER}"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo ""

    _info "Re-copying covenant.sh and hooks..."
    _write_hooks
    _success "Hooks updated."

    # Backfill the trust-root settings.json scaffold for repos installed before
    # it existed. Detect basket from whichever dev-guide filename is present —
    # DEV_GUIDE_DST/INIT_PKG_DST aren't set in this flow the way they are in
    # fresh install, since --upgrade never re-runs basket detection.
    #
    # CRITICAL: the two _fetch calls at the top of each branch are the fix for
    # a real bug — _upgrade() previously never refreshed the dev-guide or
    # init-package files at all, so _write_init_command below was regenerating
    # /init-governance from whatever content was fetched at the ORIGINAL
    # install time. An upgrade did not actually update the one-command-init
    # prompt. OLD_DEV_GUIDE_CONTENT is captured before the overwrite so the
    # reconciliation check after this block can tell whether the dev guide's
    # actual content changed, not just its version number.
    if [ -f "v1_claude_code_development_guide_new.md" ]; then
        OLD_DEV_GUIDE_CONTENT=$(cat "v1_claude_code_development_guide_new.md" 2>/dev/null || echo "")
        _fetch "../v1_release/basket-2-greenfield/v1_claude_code_development_guide_new.md" "v1_claude_code_development_guide_new.md"
        _fetch "../v1_release/basket-2-greenfield/v1_implementation_package_new.md" "v1_implementation_package_new.md"
        DEV_GUIDE_DST="v1_claude_code_development_guide_new.md"
        _write_trust_root_settings "v1_claude_code_development_guide_new.md" "v1_implementation_package_new.md"
        mkdir -p .claude/commands
        _write_init_command "v1_implementation_package_new.md"
        _write_checkpoint_memory
    elif [ -f "v1_claude_code_development_guide_existing.md" ]; then
        OLD_DEV_GUIDE_CONTENT=$(cat "v1_claude_code_development_guide_existing.md" 2>/dev/null || echo "")
        _fetch "../v1_release/basket-1-brownfield/v1_claude_code_development_guide_existing.md" "v1_claude_code_development_guide_existing.md"
        _fetch "../v1_release/basket-1-brownfield/v1_implementation_package_existing.md" "v1_implementation_package_existing.md"
        DEV_GUIDE_DST="v1_claude_code_development_guide_existing.md"
        _write_trust_root_settings "v1_claude_code_development_guide_existing.md" "v1_implementation_package_existing.md"
        mkdir -p .claude/commands
        _write_init_command "v1_implementation_package_existing.md"
        _write_checkpoint_memory
    else
        _warn "Could not detect basket (no dev guide found) — skipping trust-root settings.json backfill. Run install.sh's fresh-install flow if this repo predates the dev guide copy step."
    fi
    _success "Trust-root settings.json checked/backfilled."
    _success ".claude/commands/init-governance.md checked/backfilled."
    _success "Checkpoint memory checked/backfilled."

    # Constitution reconciliation: if the dev guide's actual CONTENT changed
    # (not just a version bump that didn't touch it), generate
    # /reconcile-governance so a human decides what, if anything, to change in
    # CLAUDE.md — never a silent regeneration. Only runs when there's a real
    # diff and a detected basket; skips entirely otherwise (no busywork).
    if [ -n "${DEV_GUIDE_DST:-}" ] && [ -n "${OLD_DEV_GUIDE_CONTENT:-}" ] && [ "$OLD_DEV_GUIDE_CONTENT" != "$(cat "$DEV_GUIDE_DST" 2>/dev/null)" ]; then
        mkdir -p .claude/commands
        diff -u <(printf '%s' "$OLD_DEV_GUIDE_CONTENT") "$DEV_GUIDE_DST" > .claude/commands/.reconcile-diff.txt 2>/dev/null || true
        _write_reconcile_command "$DEV_GUIDE_DST" ".claude/commands/.reconcile-diff.txt"
        rm -f .claude/commands/.reconcile-diff.txt
        _success "/reconcile-governance generated — the dev guide's content changed; review before CLAUDE.md drifts further."
    fi

    # Deprecation cleanup: offer to remove any framework-owned file that
    # became obsolete in a version newer than this repo's previous one. Only
    # prints/prompts when there's actually something to remove.
    _offer_deprecated_cleanup "$OLD_FRAMEWORK_VERSION"

    # Re-pin the integrity manifest — must run after every governance script
    # above exists, and unconditionally (not inside the if/elif above), since
    # _write_hooks (called unconditionally at the top of _upgrade) always
    # updates covenant.sh/verify_governance_integrity.sh/pre-commit/pre-push
    # regardless of whether basket detection succeeded.
    _write_integrity_manifest
    _success "Integrity manifest re-pinned (.claude/covenant_integrity.sha256)."
    _write_gitattributes
    _success "Governance files pinned to LF in .gitattributes (backfilled for existing installs)."

    # CI workflow is force-overwritten on upgrade (unlike fresh install which skips if exists)
    mkdir -p .github/workflows
    _fetch "templates/ci-covenant.yml" ".github/workflows/covenant.yml"
    _success "CI governance workflow updated (.github/workflows/covenant.yml)"

    # Bump version in covenant_state.json, preserve all user-owned fields
    python3 - << PYEOF
import json
from datetime import datetime, timezone
with open('.claude/covenant_state.json') as f:
    d = json.load(f)
d['framework_version'] = '${FRAMEWORK_SEMVER}'
d['framework_last_upgrade'] = datetime.now(timezone.utc).strftime('%Y-%m-%dT%H:%M:%SZ')
with open('.claude/covenant_state.json', 'w') as f:
    json.dump(d, f, indent=2)
PYEOF
    _success "covenant_state.json: framework_version → ${FRAMEWORK_SEMVER}"

    echo ""
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo -e "${GREEN} Upgrade complete${RESET}"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo ""
    echo "What was updated:"
    echo "  ✓ .githooks/covenant.sh"
    echo "  ✓ .githooks/verify_governance_integrity.sh"
    echo "  ✓ .githooks/pre-commit"
    echo "  ✓ .githooks/pre-push"
    echo "  ✓ .claude/covenant_integrity.sha256 (re-pinned — multi-file manifest covering covenant.sh,"
    echo "    verify_governance_integrity.sh, pre-commit, pre-push, the Bash-guard hook, the"
    echo "    graph freshness guard, and the checkpoint memory tool)"
    echo "  ✓ .claude/settings.json (trust-root deny-list + Bash guard hook — backfilled if missing)"
    echo "  ✓ .claude/hooks/pre_bash_trust_root_guard.sh"
    echo "  ✓ .github/workflows/covenant.yml"
    echo "  ✓ .claude/covenant_state.json: framework_version → ${FRAMEWORK_SEMVER}"
    echo ""
    echo "What was preserved:"
    echo "  • .claude/baseline.json (debt ratchet — untouched)"
    echo "  • CLAUDE.md (repo constitution — untouched)"
    echo "  • .mcp.json (graph config — untouched)"
    echo "  • covenant_state.json: receipts, token data, thresholds, core_files"
    echo "  • Any repo-specific permissions.allow entries already in settings.json"
    echo ""
    echo "This upgrade re-pinned .claude/covenant_integrity.sha256 — CI will fail until"
    echo "the new manifest is committed alongside every file it covers. Get this"
    echo "reviewed like any other change to the enforcement boundary, not rubber-stamped."
    echo ""
    echo "Commit the upgrade to activate it for the whole team:"
    echo "  git add .githooks/ .claude/covenant_integrity.sha256 .claude/settings.json .claude/hooks/ .claude/checkpoint_tool.py .claude/commands/ .github/workflows/covenant.yml .claude/covenant_state.json .gitattributes"
    echo "  git commit -m 'chore: upgrade governance framework to ${FRAMEWORK_SEMVER}'"
    echo ""
}

# Locate the Covenant framework directory (helpers exist now, so _error works)
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
if [ ! -f "${SCRIPT_DIR}/../v1_release/basket-1-brownfield/v1_implementation_package_existing.md" ]; then
    _error "Framework files not found. Ensure you cloned Covenant. Usage: cd <your-target-repo> && /path/to/Covenant/CovenantMac/install.sh"
fi
REPO_DIR="${SCRIPT_DIR}"

# ── Argument parsing ──────────────────────────────────────────────────────────
UPGRADE_MODE=false
for _arg in "$@"; do
    case "$_arg" in
        --upgrade) UPGRADE_MODE=true ;;
        *) _error "Unknown argument: ${_arg}. Usage: ./install.sh [--upgrade]" ;;
    esac
done

# ── STEP 0: Preflight checks ──────────────────────────────────────────────────
echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo " Covenant Governance Framework — ${FRAMEWORK_VERSION} Installer"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

# _require git/python3 MUST run before _check_framework_staleness — that
# function shells out to git internally, so a machine truly missing git
# would hit a raw "command not found" from the shell before ever reaching
# _require's clean, actionable error message.
_require git "Install git from https://git-scm.com/"
_require python3 "Install Python 3.8+ from https://python.org/"

_check_framework_staleness "$REPO_DIR"

# Must be inside a git repo
git rev-parse --git-dir >/dev/null 2>&1 || _error "Not inside a git repository. Run 'git init' first."

REPO_ROOT=$(git rev-parse --show-toplevel)

# Guard: refuse to govern the Covenant repo itself
if [ "$REPO_ROOT" = "$SCRIPT_DIR" ]; then
    _error "You are inside the Covenant framework repo — not your target repo.
       cd into the repo you want to govern, then run:
         ${SCRIPT_DIR}/install.sh
       (i.e. the copy of install.sh under Covenant/CovenantMac/, not the Covenant/ root)"
fi

_info "Repository root: ${REPO_ROOT}"

# Upgrade short-circuit — skip basket selection and all scaffolding
if $UPGRADE_MODE; then _upgrade; exit 0; fi

# Claude Code CLI check — advisory only, not a hard block
if ! command -v claude >/dev/null 2>&1; then
    _warn "Claude Code CLI not found. Install from https://claude.ai/download — required for the final init step."
fi

# ── STEP 1: Basket selection ──────────────────────────────────────────────────
echo ""
echo "Which type of repository is this?"
echo "  [g] Greenfield — new project, no prior history"
echo "  [b] Brownfield — existing repository with code"
echo ""
read -r -p "Enter g or b: " BASKET_INPUT </dev/tty

case "$BASKET_INPUT" in
    g|G|green|greenfield) BASKET="greenfield" ;;
    b|B|brown|brownfield) BASKET="brownfield" ;;
    *) _error "Invalid input '${BASKET_INPUT}'. Enter 'g' or 'b'." ;;
esac
_info "Basket: ${BASKET}"

# LOC advisory for brownfield
if [ "$BASKET" = "brownfield" ]; then
    echo ""
    _info "Checking repository size..."
    LOC=$(find . -not -path './.git/*' -type f | xargs wc -l 2>/dev/null | tail -1 | awk '{print $1}' || echo "0")
    _info "Approximate LOC: ${LOC}"
    if [ "${LOC:-0}" -gt 1000000 ]; then
        _error "Repository exceeds 1,000,000 LOC (${LOC} lines). V1 framework is certified for ≤1M LOC only."
    fi
fi

# ── STEP 2: Copy governance files ────────────────────────────────────────────
echo ""
_info "Copying governance files..."

cd "$REPO_ROOT"

# Dev guide (copied as-is with v1_ prefix — init prompt reads it, generates CLAUDE.md from it)
if [ "$BASKET" = "greenfield" ]; then
    DEV_GUIDE_SRC="../v1_release/basket-2-greenfield/v1_claude_code_development_guide_new.md"
    DEV_GUIDE_DST="v1_claude_code_development_guide_new.md"
    INIT_PKG_SRC="../v1_release/basket-2-greenfield/v1_implementation_package_new.md"
    INIT_PKG_DST="v1_implementation_package_new.md"
else
    DEV_GUIDE_SRC="../v1_release/basket-1-brownfield/v1_claude_code_development_guide_existing.md"
    DEV_GUIDE_DST="v1_claude_code_development_guide_existing.md"
    INIT_PKG_SRC="../v1_release/basket-1-brownfield/v1_implementation_package_existing.md"
    INIT_PKG_DST="v1_implementation_package_existing.md"
fi

_fetch "$DEV_GUIDE_SRC" "$DEV_GUIDE_DST"
_fetch "$INIT_PKG_SRC" "$INIT_PKG_DST"
_success "Dev guide copied: ${DEV_GUIDE_DST}"
_success "Init package copied: ${INIT_PKG_DST}"

# ── STEP 3: Scaffold .claude/ directory ───────────────────────────────────────
_info "Scaffolding .claude/ directory..."
mkdir -p .claude/commands .claude/checkpoints

_write_init_command "$INIT_PKG_DST"
_success ".claude/commands/init-governance.md created (run /init-governance instead of copy-pasting ${INIT_PKG_DST})"

# covenant_state.json from template
_fetch "templates/covenant_state.json" ".claude/covenant_state.json"
# Stamp today's date into token.token_last_reset
python3 -c "
import json
from datetime import date
with open('.claude/covenant_state.json') as f:
    d = json.load(f)
d.setdefault('token', {})['token_last_reset'] = str(date.today())
d['framework_version'] = '${FRAMEWORK_SEMVER}'
with open('.claude/covenant_state.json', 'w') as f:
    json.dump(d, f, indent=2)
"
_success "covenant_state.json created"


# session_state.json (gitignored — ephemeral)
echo '{"mode": null, "complexity_tier": null, "budget_pct_at_selection": null, "timestamp": null}' > .claude/session_state.json
_success "session_state.json created (gitignored)"

# baseline.json — brownfield only. Seeded UNPOPULATED here; the init prompt
# (Phase C/D) fills lint_findings once LINT_CMD is known, then sets populated=true.
# covenant.sh treats an unpopulated baseline as zero-tolerance until it is filled.
if [ "$BASKET" = "brownfield" ] && [ ! -f ".claude/baseline.json" ]; then
    HEAD_SHA_NOW=$(git rev-parse HEAD 2>/dev/null || echo "INIT")
    cat > .claude/baseline.json << BASELINE
{
  "_comment": "Identity-based debt baseline. covenant.sh grandfathers these findings and blocks any NEW identity. Identity = '<normalized_path>|<rule_code>'. Committed team state — edited only via human-authored PR.",
  "ratchet_mode": "identity",
  "populated": false,
  "generated_at": null,
  "generated_from_sha": "${HEAD_SHA_NOW}",
  "lint_findings": [],
  "summary": { "lint_count": 0 }
}
BASELINE
    _success "baseline.json seeded (unpopulated — init prompt fills it)"
fi

# ── STEP 4: Install git hooks ──────────────────────────────────────────────────
_info "Installing git hooks..."
_write_hooks
_success "Git hooks installed (.githooks/)"

# ── STEP 4a: Trust-root settings.json (deny-list + Bash guard hook) ──────────
_info "Scaffolding trust-root protections (.claude/settings.json)..."
_write_trust_root_settings "$DEV_GUIDE_DST" "$INIT_PKG_DST"
_success "Trust-root protections in place (mechanical, not left to the init prompt)."

# ── STEP 4b: Mechanical checkpoint memory (must run after settings.json exists) ──
_info "Scaffolding mechanical checkpoint memory..."
_write_checkpoint_memory
_success "Checkpoint memory installed (.claude/checkpoint_tool.py, /checkpoint-search command, hooks registered)"

# ── STEP 4c: Integrity manifest (must run after every governance script above exists) ──
_write_integrity_manifest
_success "Integrity manifest computed (.claude/covenant_integrity.sha256)"
_write_gitattributes
_success "Governance files pinned to LF in .gitattributes (protects the manifest from autocrlf drift)"

# CI parity workflow — the authoritative backstop if local hooks are stripped.
mkdir -p .github/workflows
if [ ! -f ".github/workflows/covenant.yml" ]; then
    _fetch "templates/ci-covenant.yml" ".github/workflows/covenant.yml"
    _success "CI governance workflow installed (.github/workflows/covenant.yml)"
else
    _warn ".github/workflows/covenant.yml already exists — left unchanged. Compare against templates/ci-covenant.yml manually."
fi

# ── STEP 4d: CODEOWNERS starter file ─────────────────────────────────────────
# docs/SECURITY_POSTURE.md and the implementation package are explicit that
# closing the "CI verifies internal self-consistency, not an externally-
# trusted reference" gap requires a human-controlled GitHub setting
# (CODEOWNERS + a branch-protection rule requiring Code Owner review) that
# install.sh cannot activate on its own — GitHub's branch-protection API call
# needs repo-admin credentials this script never has. That's still true; this
# does NOT flip branch protection on. What was missing is scaffolding: the
# mission brief and the implementation package both expect
# .github/CODEOWNERS to exist, but install.sh never wrote one, leaving a
# human to hand-transcribe the exact path list from the guide instead of
# just filling in a team name. Never overwrites an existing CODEOWNERS —
# a human may already have real content there.
if [ ! -f ".github/CODEOWNERS" ]; then
    cat > .github/CODEOWNERS << 'CODEOWNERS_EOF'
# Governance trust-root — requires Code Owner review before merge.
# Scaffolded by install.sh; replace @your-org/platform-team with a real
# team/user, then enable "Require review from Code Owners" on this repo's
# default-branch protection rule (Settings -> Branches). CODEOWNERS alone is
# advisory — GitHub does not enforce it without that branch protection rule.
/.githooks/                         @your-org/platform-team
/.claude/covenant_integrity.sha256      @your-org/platform-team
/.claude/hooks/                     @your-org/platform-team
/.claude/settings.json              @your-org/platform-team
/.github/workflows/covenant.yml         @your-org/platform-team
/CLAUDE.md                          @your-org/platform-team
CODEOWNERS_EOF
    _success ".github/CODEOWNERS scaffolded (placeholder team — edit it, then enable branch protection; see docs/SECURITY_POSTURE.md)"
else
    _warn ".github/CODEOWNERS already exists — left unchanged. Verify it covers .githooks/, .claude/hooks/, .claude/covenant_integrity.sha256, .claude/settings.json, .github/workflows/covenant.yml, and CLAUDE.md."
fi

# Bypass note refspecs (so bypass audit trail leaves the machine)
git config --add remote.origin.push  'refs/notes/bypasses:refs/notes/bypasses' 2>/dev/null || true
git config --add remote.origin.fetch '+refs/notes/bypasses:refs/notes/bypasses' 2>/dev/null || true
_success "Bypass note refspecs configured"

# ── STEP 5: Org-level token policy ───────────────────────────────────────────
_info "Checking org-level token policy..."
mkdir -p "${HOME}/.claude"

if [ ! -f "$ORG_POLICY_PATH" ]; then
    cat > "$ORG_POLICY_PATH" << ORGPOLICY
{
  "_comment": "Org-wide Claude Code token budget. Daily limit = WEEKLY_LIMIT x DAILY_BUDGET_PCT / 100.",
  "_edit_policy": "Changes require a human PR — never agent-modified.",
  "WEEKLY_LIMIT": ${DEFAULT_WEEKLY_LIMIT},
  "DAILY_BUDGET_PCT": ${DEFAULT_DAILY_BUDGET_PCT},
  "HARD_BLOCK_AT_100_PCT": true,
  "WARN_AT_PCT": 80
}
ORGPOLICY
    DAILY_LIMIT=$(( DEFAULT_WEEKLY_LIMIT * DEFAULT_DAILY_BUDGET_PCT / 100 ))
    _success "Org policy created: ${ORG_POLICY_PATH} (WEEKLY_LIMIT=${DEFAULT_WEEKLY_LIMIT}, daily cap=${DAILY_LIMIT})"
else
    CURRENT_WEEKLY=$(python3 -c "import json; d=json.load(open('${ORG_POLICY_PATH}')); print(d.get('WEEKLY_LIMIT', d.get('TOKEN_BUDGET','not set')))" 2>/dev/null || echo "unreadable")
    _info "Org policy already exists: WEEKLY_LIMIT=${CURRENT_WEEKLY}"
fi

# ── STEP 6: MCP graph server installation ────────────────────────────────────
echo ""
_info "Installing code-review-graph MCP server (zero-knowledge — this is automatic)..."

# Ensure pipx is available. This whole server is an enhancement layer (it
# *informs* the agent; it never gates a commit), so a failure here degrades
# to "graph mode inactive," exactly like a failed
# ${GRAPH_PACKAGE} install two steps below — it must never hard-abort the
# entire install and leave every trust-root/hooks/CI file already written by
# the steps above in a half-installed limbo. Previously this used _error
# (hard exit 1) for both the "pip3 install --user pipx failed" and "pip3 not
# found" cases — a real bug: `pip3 install --user` fails inside any activated
# venv ("User site-packages are not visible in this virtualenv"), which is
# not a contrived case (the project's own demo.sh activates one, see
# demo.sh's Step 0), and a machine with python3 but no separate `pip3` binary
# (common on minimal/managed installs) hit the second _error just as hard.
GRAPH_INSTALLED=true
if ! command -v pipx >/dev/null 2>&1; then
    _info "pipx not found — installing..."
    if command -v pip3 >/dev/null 2>&1; then
        if pip3 install --user pipx --quiet 2>&1 | tail -3; then
            export PATH="${HOME}/.local/bin:${PATH}"
        else
            _warn "Failed to install pipx (pip3 install --user pipx). Graph mode will be inactive. Install manually later: pip3 install --user pipx"
            GRAPH_INSTALLED=false
        fi
    else
        _warn "pip3 not found. Graph mode will be inactive. Install Python 3 with pip (https://python.org/) and re-run, or install pipx manually."
        GRAPH_INSTALLED=false
    fi
fi

# Install the graph package (pinned exact version — security requirement)
if $GRAPH_INSTALLED && ! command -v pipx >/dev/null 2>&1; then
    _warn "pipx still not on PATH after install — graph mode will be inactive."
    GRAPH_INSTALLED=false
fi
if $GRAPH_INSTALLED; then
    _info "Installing ${GRAPH_PACKAGE}..."
    pipx install "${GRAPH_PACKAGE}" --force --quiet 2>&1 | tail -3 || {
        _warn "code-review-graph install failed. Graph mode will be inactive. Continuing..."
        GRAPH_INSTALLED=false
    }
fi
GRAPH_BUILD_OK=false

if $GRAPH_INSTALLED; then
    # Detect bin path
    GRAPH_BIN=$(pipx environment --value PIPX_BIN_DIR 2>/dev/null || echo "${HOME}/.local/bin")
    GRAPH_BIN_PATH="${GRAPH_BIN}/code-review-graph"

    if [ ! -f "$GRAPH_BIN_PATH" ]; then
        _warn "code-review-graph binary not found at ${GRAPH_BIN_PATH}. Trying PATH..."
        GRAPH_BIN_PATH=$(command -v code-review-graph 2>/dev/null || echo "")
    fi

    if [ -n "$GRAPH_BIN_PATH" ] && [ -f "$GRAPH_BIN_PATH" ]; then
        _success "code-review-graph installed: ${GRAPH_BIN_PATH}"
        GRAPH_BUILD_OK=false

        # Build the initial graph with multi-domain config
        _info "Building initial code graph (multi-domain: code + SQL + infra + CI)..."
        _info "This may take 2–5 minutes on large repositories (>100k LOC). Progress updates below."
        cd "$REPO_ROOT"

        GRAPH_INCLUDE_ARGS=(
            --include "*.py,*.ts,*.tsx,*.js,*.go,*.rs,*.java"
            --include "*.sql,migrations/**"
            --include "Dockerfile*,docker-compose*.yml,*.tf,*.hcl"
            --include ".github/workflows/*.yml,.circleci/config.yml"
            --include "nginx.conf,*.conf,.env.example"
            --exclude ".git/,node_modules/,.venv/,dist/,build/,__pycache__/"
        )

        # Background the build with a progress monitor (10-minute timeout for 1M LOC repos)
        if command -v timeout >/dev/null 2>&1; then
            if timeout 600 "${GRAPH_BIN_PATH}" build \
                "${GRAPH_INCLUDE_ARGS[@]}" \
                2>&1 | while IFS= read -r line; do
                    # Emit progress every 5 lines of output
                    _info "Graph: $line"
                done; then
                GRAPH_BUILD_OK=true
            else
                EXIT_CODE=$?
                if [ $EXIT_CODE -eq 124 ]; then
                    _warn "Graph build exceeded 10-minute timeout. This repository may exceed 1M LOC. Continuing without graph."
                else
                    # The --include/--exclude flags above are this framework's
                    # own multi-domain convention, not a guaranteed-stable
                    # code-review-graph CLI contract — a flag rename/removal
                    # in a newer package release previously crashed the build
                    # outright ("unrecognized arguments") and left graph mode
                    # permanently, silently inactive with no retry attempted
                    # and a final summary that still claimed success (it only
                    # checked whether the PACKAGE installed, never whether the
                    # BUILD actually completed). Retry with a bare `build`
                    # before giving up, so a CLI drift degrades to reduced
                    # domain coverage instead of zero graph at all.
                    _warn "Graph build with multi-domain filters failed (exit ${EXIT_CODE}) — retrying with default scope (no --include/--exclude) in case this code-review-graph version's CLI flags have changed..."
                    if timeout 600 "${GRAPH_BIN_PATH}" build 2>&1 | tail -20; then
                        GRAPH_BUILD_OK=true
                        _warn "Graph built with default scope only — SQL/infra/CI domain coverage may be reduced until the flag mismatch is resolved (check: ${GRAPH_BIN_PATH} build --help)."
                    else
                        _warn "Graph build failed even with default scope (exit $?). Graph mode inactive until resolved."
                    fi
                fi
            fi
        else
            # Fallback for systems without timeout command
            if "${GRAPH_BIN_PATH}" build "${GRAPH_INCLUDE_ARGS[@]}" 2>&1 | tail -10; then
                GRAPH_BUILD_OK=true
            else
                _warn "Graph build with multi-domain filters failed — retrying with default scope (no --include/--exclude) in case this code-review-graph version's CLI flags have changed..."
                if "${GRAPH_BIN_PATH}" build 2>&1 | tail -20; then
                    GRAPH_BUILD_OK=true
                    _warn "Graph built with default scope only — SQL/infra/CI domain coverage may be reduced until the flag mismatch is resolved (check: ${GRAPH_BIN_PATH} build --help)."
                else
                    _warn "Graph build failed even with default scope — graph mode inactive until resolved."
                fi
            fi
        fi

        # Write .mcp.json — project-scoped, committed (NOT ~/.claude/settings.json)
        # Rationale: .mcp.json travels with the repo so every team member gets graph
        # mode automatically on clone, without per-developer setup.
        cat > .mcp.json << MCPJSON
{
  "_comment": "Project-scoped MCP server config — committed so all team members get graph mode on clone.",
  "_do_not_move_to_settings": "This file must remain in the project root, not in ~/.claude/settings.json.",
  "mcpServers": {
    "code-review-graph": {
      "command": "${GRAPH_BIN_PATH}",
      "args": ["serve"],
      "env": {
        "PROJECT_ROOT": "."
      }
    }
  }
}
MCPJSON
        _success ".mcp.json written (project root, committed)"

        # Verify graph is live
        _info "Verifying graph server..."
        GRAPH_STATUS=$("${GRAPH_BIN_PATH}" status 2>&1 || echo "unavailable")
        if echo "$GRAPH_STATUS" | grep -qi "healthy\|running\|ok\|nodes"; then
            _success "Graph server healthy: ${GRAPH_STATUS}"
            # Update covenant_state.json with graph metadata
            python3 -c "
import json, re
from datetime import datetime, timezone
with open('.claude/covenant_state.json') as f:
    d = json.load(f)
node_match = re.search(r'(\d+)\s*nodes?', '${GRAPH_STATUS}', re.IGNORECASE)
d.setdefault('mcp_graph', {})['last_build_timestamp'] = datetime.now(timezone.utc).strftime('%Y-%m-%dT%H:%M:%SZ')
d['mcp_graph']['node_count'] = int(node_match.group(1)) if node_match else 0
with open('.claude/covenant_state.json', 'w') as f:
    json.dump(d, f, indent=2)
" 2>/dev/null || true
        else
            _warn "Graph server not responding. Graph mode inactive until 'code-review-graph build' is run."
        fi
    else
        _warn "Could not locate code-review-graph binary. Graph mode inactive."
    fi
fi

# ── STEP 7: .gitignore additions ─────────────────────────────────────────────
_info "Updating .gitignore..."
GITIGNORE_ENTRIES=(
    ".claude/session_state.json"
    ".claude/session_spend.tmp"
    ".claude/git_cache.json"
    ".claude/checkpoints/"
    ".env"
    ".env.*"
)
for entry in "${GITIGNORE_ENTRIES[@]}"; do
    if ! grep -qF "$entry" .gitignore 2>/dev/null; then
        echo "$entry" >> .gitignore
    fi
done
# .mcp.json is NOT gitignored — it must be committed for team-wide graph activation
_success ".gitignore updated"

# ── STEP 8: Summary and handoff ───────────────────────────────────────────────
echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo -e "${GREEN} Installation complete${RESET}"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
echo "What was installed:"
echo "  ✓ Dev guide:      ${DEV_GUIDE_DST}"
echo "  ✓ Init package:   ${INIT_PKG_DST}"
echo "  ✓ Covenant ledger:    .claude/covenant_state.json"
echo "  ✓ Git hooks:      .githooks/ (pre-commit, pre-push, covenant.sh, verify_governance_integrity.sh)"
echo "  ✓ Integrity pin:  .claude/covenant_integrity.sha256 (multi-file manifest — CI verifies all 7 governance scripts against this)"
echo "  ✓ Line endings:   .gitattributes (pins the 7 governance files to LF — protects the manifest from autocrlf drift)"
echo "  ✓ Trust-root deny: .claude/settings.json (permissions.deny + Bash guard hook — mechanical)"
echo "  ✓ Init command:   .claude/commands/init-governance.md (run /init-governance next, instead of copy-pasting ${INIT_PKG_DST})"
echo "  ✓ Checkpoint memory: .claude/checkpoint_tool.py + .claude/commands/checkpoint-search.md (mechanical capture + progressive-disclosure search)"
echo "  ✓ CI workflow:    .github/workflows/covenant.yml (CI parity backstop)"
echo "  ✓ CODEOWNERS:     .github/CODEOWNERS (placeholder team — edit + enable branch protection, see below)"
if [ "$BASKET" = "brownfield" ]; then
echo "  ✓ Debt baseline:  .claude/baseline.json (unpopulated — init prompt fills it)"
fi
echo "  ✓ Org policy:     ${ORG_POLICY_PATH} (WEEKLY_LIMIT=${DEFAULT_WEEKLY_LIMIT}, daily=$(( DEFAULT_WEEKLY_LIMIT * DEFAULT_DAILY_BUDGET_PCT / 100 )) tokens)"
if $GRAPH_INSTALLED 2>/dev/null && ${GRAPH_BUILD_OK:-false}; then
echo "  ✓ Graph server:   code-review-graph ${GRAPH_PACKAGE##*==} (${GRAPH_BIN_PATH})"
echo "  ✓ MCP config:     .mcp.json (committed — team-wide graph activation)"
elif $GRAPH_INSTALLED 2>/dev/null; then
# Package installed but the initial build never completed (see warnings
# above) — distinct from "skipped" so this isn't misread as full success.
# .mcp.json is still written/committed either way: the server can build its
# index lazily later, but graph-backed review tools have nothing to query
# until 'code-review-graph build' succeeds.
echo "  ⚠ Graph server:   installed but index build FAILED — graph mode inactive (run manually: ${GRAPH_BIN_PATH:-code-review-graph} build)"
else
echo "  ⚠ Graph server:   skipped (install manually: pipx install ${GRAPH_PACKAGE})"
fi
echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo -e "${BLUE} REMAINING STEPS — required to complete setup:${RESET}"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
echo "  1. Open Claude Code in this directory:"
echo "     claude"
echo ""
echo "  2. Run the init command:"
echo "     /init-governance"
echo "     No file to open, no copy-paste — this command already contains the"
echo "     exact content that used to live in ${INIT_PKG_DST}. Claude Code will:"
echo "     • Interrogate you (product/stack/risk/debt — several rounds, not one)"
echo "     • Draft PRD/TRD/DB-schema/user-flows/system-design docs under docs/"
echo "       and wait for your explicit approval before writing anything else"
echo "     • Generate CLAUDE.md (repo-specific constitution)"
echo "     • Generate stack-specific covenant.sh commands"
echo "     • Complete the governance scaffold"
echo ""
echo "  3. ${INIT_PKG_DST} is kept locally too, purely for reference if you'd"
echo "     rather read the prompt before running it — running /init-governance"
echo "     does not require opening it."
echo ""
echo -e "  4. ${YELLOW}Required — do this in GitHub's repo settings, not here:${RESET}"
echo "     a. Edit .github/CODEOWNERS: replace @your-org/platform-team with a"
echo "        real team/user."
echo "     b. Settings -> Branches -> protection rule for your default branch:"
echo "        enable 'Require a pull request before merging' AND 'Require"
echo "        review from Code Owners'."
echo "     Until step (b) is done, every control this framework installs is"
echo "     LOCAL-ONLY: git hooks live in the working tree, so a branch with no"
echo "     hooks checked out (a fresh clone before the governance commit lands,"
echo "     or a protected branch nothing has merged governance into yet) is"
echo "     completely unguarded, and CI verifies internal self-consistency"
echo "     only — it cannot stop a PR that edits covenant.sh and its own integrity"
echo "     pin together. See docs/SECURITY_POSTURE.md for the full threat model."
echo ""
echo "  After the init commit AND step 4, your repo is fully governed."
echo ""
