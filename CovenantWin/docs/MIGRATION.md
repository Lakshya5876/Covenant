# Covenant to CovenantWin: Windows implementation notes

`CovenantMac`'s bash implementation depends on POSIX tools (`bash`, `grep`, `awk`, `sed`,
`sha256sum`, `timeout`, `nohup`, `ps`, `/dev/tty`, Unix signals, and `$HOME`). CovenantWin
replaces the *enforcement engine* with Python `pathlib`, `subprocess` argument lists, and
`hashlib` — a behavioral port, not a shared codebase (see the caveat at the bottom). This
avoids path separator, executable-bit, shell quoting, `/tmp`, and Unix-process assumptions.

Git for Windows still dispatches hooks as POSIX-text hook files, so `pre-commit`/`pre-push`
and the trust-root Bash guard are `CovenantMac`'s *actual* scripts, reused unmodified — deployed
by `covenantwin.py`'s installer, not hand-ported. They call this engine directly
(`python .githooks/covenantwin.py covenant --trigger ...`); there is no PowerShell hop in that path
(an earlier `covenant.ps1` indirection was removed once this was confirmed to work). Paths are
resolved from `git rev-parse --show-toplevel`, so spaces, nested repositories, drive letters,
and UNC paths are supported by the core implementation.

Agent integration is preserved through `.claude/covenant_state.json`, `.claude/hooks/`, and the
generated `.githooks` files.

| CovenantMac (macOS/Linux) | CovenantWin | Reason |
| --- | --- | --- |
| Bash plus GNU/BSD utilities | Python 3 standard library engine | One portable implementation; avoids quoting and utility-version differences. |
| `sha256sum`/`shasum` | `hashlib.sha256` | Same integrity semantics without external binaries. |
| `timeout`, signals, `nohup`, `ps` | `subprocess.run(..., timeout=...)` | Windows process semantics. |
| POSIX pre-commit/pre-push scripts | Same scripts, reused verbatim; `python3` calls inside the trust-root guard are rewritten to `python` at deploy time | `python3` is frequently absent on Windows (or resolves to a non-functional Microsoft Store stub) — and the guard's own error handling means a missing interpreter fails *open*, not closed, so this rewrite is a real security-relevant fix, not cosmetic. |
| `$HOME/.claude` policy path | repository-local state | No assumption about Windows profile naming or redirected home directories. |
| `install.sh`'s embedded Python heredocs (trust-root deny-list, integrity manifest, `/init-governance` extraction) | Native Python functions in `covenantwin.py` | Same logic, no shell-to-Python round-trip needed since the whole installer is already Python. |

## What's genuinely shared vs. ported

- **Shared, byte-identical, deployed from the same source:** `v1_release/` (the dev-guide and
  implementation-package constitution content — zero OS-specific instructions), the
  `pre-commit`/`pre-push` hook scripts (SKIP_COVENANT bypass + git-notes audit trail; force-push/
  protected-branch/24h-clock guards), and the trust-root Bash guard script.
- **Behaviorally ported, not shared source:** the enforcement engine itself (`covenant.sh` vs.
  `covenantwin.py`). This is a real, disclosed maintenance obligation: a change to `covenant.sh`'s
  checks needs a matching change to `covenantwin.py`, verified by that platform's own test suite
  — there is no compiler or shared module to catch a missed one. Two things mitigate this in
  practice: the governance *content* (`v1_release/`, the bypass-audit-trail hook scripts, the
  trust-root Bash guard) is genuinely shared, not duplicated, since none of it is OS-specific;
  and both engines are exercised by the same *class* of end-to-end test (deploy the real
  artifacts into a scratch repo, drive real git commands), so a behavioral drift tends to show up
  as a failing test on whichever side lags, rather than as silent divergence. There is no
  compiler to catch a missed sync, though — it stays a per-change obligation, not a solved
  problem.
- **Ported despite initial appearances to the contrary:** the two agent-only *blocking* checkpoint
  gates — the tier-3 brainstorming block at commit (≥5-file agent change with no
  `.claude/checkpoints/LATEST.md`) and the checkpoint-required gate at push (agent push touching
  source with no checkpoint) — mirror `covenant.sh`'s STEP 4.4/4.6 exactly, keyed on the same
  `$CLAUDECODE` marker. These were originally absent from `covenantwin.py` and had been
  mis-described here as part of the unported "enhancement layer"; they are not — they are real
  gating decisions, ported without needing `checkpoint_tool.py` itself, since the gate is a plain
  file-existence check on `.claude/checkpoints/LATEST.md`, not a dependency on the tool that
  happens to write it on `CovenantMac`.
- **Not yet ported:** checkpoint *memory* — the cross-session retrieval tool
  (`checkpoint_tool.py`'s `append`/`checkpoint-search` progressive-disclosure commands) — and the
  `code-review-graph` MCP integration. Both genuinely are enhancement layers that *inform* the
  agent, never part of a gating decision, so their absence does not weaken enforcement, only
  session-continuity/graph-assisted review UX.
