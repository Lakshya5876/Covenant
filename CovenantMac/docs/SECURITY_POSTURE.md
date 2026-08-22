# Security Posture — Claude Code Governance Framework v1

This document describes what the framework touches, what it never reads, and how it satisfies the controls auditors ask about most. It is written for a security reviewer, not a developer.

---

## 1. Data flows

### What the framework reads

| Source | Read by | Purpose |
|--------|---------|---------|
| Staged file contents | `covenant.sh` (via `git diff --cached`) | Lint, type-check, complexity, layer-boundary scan |
| `.claude/covenant_state.json` | `covenant.sh`, `install.sh` | Token budget, coverage thresholds, core_files |
| `.claude/covenant_receipts.json` (gitignored, never committed) | `covenant.sh` | Fingerprint receipts — the pre-push fast-path cache |
| `.claude/baseline.json` | `covenant.sh` | Identity-based lint debt ratchet |
| `refs/notes/bypasses` | `pre-push` hook | Bypass clock enforcement |
| `~/.claude/org_policy.json` | `covenant.sh` | Per-developer token budget ceiling (local file, not centrally enforced — see §6, CC6.6) |
| `.claude/checkpoints/index.jsonl`, `.claude/session_state.json` | `checkpoint_tool.py` (hooks + agent-invoked search) | Checkpoint history for progressive-disclosure retrieval; ephemeral pressure counters |

### What the framework writes

| Destination | Written by | Content |
|-------------|-----------|---------|
| `.claude/covenant_state.json` | `covenant.sh` | Receipt fingerprints, token spend, pass/fail ledger |
| `.claude/session_spend.tmp` | `covenant.sh` | Per-session token accumulator (deleted after each run) |
| `refs/notes/bypasses` | `pre-commit` hook (bypass path only) | Audit record: timestamp + human-typed reason |
| `.claude/git_cache.json` | `covenant.sh` | Short-lived git metadata cache (TTL: 60 s, gitignored) |
| `.claude/checkpoints/index.jsonl`, `.claude/checkpoints/*.md`, `.claude/checkpoints/LATEST.md` | `checkpoint_tool.py` (`append` + hooks) | Checkpoint bodies (task, decisions, pending, resume instruction) plus git facts (sha, branch, dirty-file count). Gitignored by default — per-clone, not team-shared, unless a team deliberately opts in (see §7). Kept indefinitely, size-bounded only by manual pruning — no automatic rotation shipped yet. |
| `.claude/session_state.json` (`checkpoint` sub-object) | `checkpoint_tool.py` hooks | Ephemeral pressure counters (files/commits touched since last checkpoint, session start time, nudge attempts) — gitignored, reset by `append` |
| `.claude/commands/reconcile-governance.md` | `install.sh --upgrade` (only when the dev guide's content actually changed) | A unified diff of the framework's own bundled dev-guide markdown, plus instructions for Claude Code to propose (never silently apply) `CLAUDE.md` edits. Contains no repo-specific or developer data — the diff is between two versions of framework-shipped documentation. |

### What the framework never reads

- Source code outside the current git working tree.
- Credentials, `.env` files, shell history, or SSH keys. The `.gitignore` additions written by `install.sh` explicitly exclude `.env` and `.env.*`.
- Browser data, clipboard contents, or network requests from developer machines.
- Claude Code's own `settings.json` — the framework writes `.mcp.json` (project-scoped MCP config) but never reads `~/.claude/settings.json`.

---

## 2. External network calls

**The framework makes zero external network calls at covenant time.**

- `covenant.sh` is a pure local bash script. It calls only: `git`, `python3`, and the configured lint/type/test commands (all local binaries).
- The MCP graph server (`code-review-graph`) runs locally via `pipx`. It reads the local repository graph; it does not phone home.
- `install.sh` calls `pipx install code-review-graph==2.3.6` once at install time to fetch the pinned package. This is the only outbound call, and it is install-only, not covenant-time.

---

## 3. Claude Code `denyRead` scope

Claude Code's file-access controls are configured in `.claude/settings.json` (per-repo) or `~/.claude/settings.json` (global). The framework does not write these files; they remain under human control.

**Recommended `denyRead` entries for governed repos** (add to `.claude/settings.json`):

```json
{
  "denyRead": [
    ".env",
    ".env.*",
    "**/*.pem",
    "**/*.key",
    "**/*.p12",
    "~/.ssh/**",
    "~/.aws/credentials"
  ]
}
```

These ensure Claude Code cannot read secrets even if instructed to by a malicious prompt.

---

## 4. Bypass audit trail

Every covenant bypass is cryptographically linked to the git history.

**How it works:**

1. Developer runs `SKIP_COVENANT=1 git commit -m "..."` in an interactive terminal.
2. `pre-commit` hook prompts for a typed reason (required; empty string is rejected).
3. Hook writes a git note to `refs/notes/bypasses` on the current HEAD:
   ```
   BYPASS | date=<unix-epoch> | reason=<human-typed text>
   ```
4. `pre-push` hook reads the note and enforces the 24-hour resolution window:
   - Active bypass (< 24 h): warns, allows push, audit trail intact.
   - Expired bypass (≥ 24 h): **blocks push** until the underlying issue is fixed or a new bypass window is opened.
5. Bypass notes travel to the remote via:
   ```
   remote.origin.push  refs/notes/bypasses:refs/notes/bypasses
   remote.origin.fetch +refs/notes/bypasses:refs/notes/bypasses
   ```
   Both refspecs are written by `install.sh`. They cannot be stripped by a force-push (tampering with the bypass refspec is itself a block condition in `pre-push`).

**Non-repudiation:** the note is attached to the git object that was committed, not to a mutable file. `git log --show-notes=bypasses` shows the full trail for any reviewer.

---

## 5. Data retention

| Data | Location | Retention |
|------|----------|-----------|
| Token audit log | `covenant_state.json — token.token_audit_log[]` | Rolling 90-day window; covenant.sh prunes entries older than 90 days on each write |
| Per-session spend | `.claude/session_spend.tmp` | Deleted by covenant.sh at the end of every covenant run (gitignored) |
| Fingerprint receipts | `.claude/covenant_receipts.json` (gitignored) | Pruned to the 50 most recent on write; no PII |
| Bypass notes | `refs/notes/bypasses` | Permanent git history; never auto-purged (audit requirement) |
| Git metadata cache | `.claude/git_cache.json` | TTL 60 s; covenant.sh invalidates stale entries on every run (gitignored) |

---

## 6. SOC 2 control mapping

| SOC 2 Control | Framework mechanism |
|---------------|---------------------|
| CC6.1 — Logical access controls | Every Claude Code action verified by `pre-commit`/`pre-push`; no route around the covenant without an audited bypass |
| CC6.6 — Restrict logical access to system boundaries | **Partial control — see caveat below.** Token budget ceiling read from `~/.claude/org_policy.json`, which is a local, per-developer-machine file, not a centrally distributed or tamper-evident policy. `covenant.sh` enforces whatever value is present on that machine at covenant time; it does not verify the value against an org-issued source of truth, and a developer with shell access can edit their own copy to raise or remove their ceiling. This mechanism deters accidental/unbounded spend (e.g. a runaway agent loop) on a cooperating machine; it is not a control that prevents a developer from unilaterally raising their own limit, and should not be represented to an auditor as centrally enforced without a companion mechanism (e.g. a signed policy file, or a CI/telemetry check that flags local overrides). |
| CC6.8 — Prevent unauthorized changes | Protected branch guard in `pre-push` blocks direct pushes to main/master/develop/production/release/* |
| CC7.2 — Monitor system components | `covenant_state.json` token audit log + bypass notes provide a time-stamped record of every covenant interaction |
| CC8.1 — Change management | Layer boundary scanner (STEP 6.5) blocks architecture violations at commit time, not code review time |
| A1.1 — Availability commitments | Covenant enforces coverage threshold and complexity ceiling to prevent quality regressions that degrade availability |

---

## 7. Threat model — what the framework does not protect against

- **Compromised developer machine:** if an attacker controls the developer's shell, they can modify covenant.sh directly or set `SKIP_COVENANT=1` without the interactive prompt. The CI backstop (`.github/workflows/covenant.yml`) is the authoritative enforcement layer — it runs in a clean, audited environment the developer cannot modify.
- **Malicious CI runner:** if the CI runner itself is compromised, all bets are off. Use GitHub's hardened runner images and pin action versions (`actions/checkout@v4` SHA-pinning recommended).
- **Social engineering to extend bypass:** the 24-hour window is a policy control, not a technical one. A developer with shell access can always open a new bypass window. The audit trail makes this visible to reviewers; it does not prevent it.
- **The CI integrity manifest has no external trust anchor.** `.claude/covenant_integrity.sha256` is a repo-tracked file — it proves internal self-consistency (the checked-out `covenant.sh` matches the checked-out pin), not consistency against an externally-trusted reference. A single PR that edits `.githooks/covenant.sh` *and* regenerates the pin to match, via normal git/filesystem access outside Claude Code's tool-mediated hooks, passes CI. This is **not** closable by anything `install.sh` can configure — it requires a human-controlled GitHub setting: a `CODEOWNERS` entry for `.githooks/`, `.claude/covenant_integrity.sha256`, `.claude/hooks/`, `.claude/settings.json`, and `.github/workflows/covenant.yml`, plus a branch protection rule requiring Code Owner review. The exact `CODEOWNERS` content and branch-protection steps are in each basket's `v1_implementation_package_*.md`, STEP 3/4 — ACTIVATION. Skipping that step leaves this specific gap open regardless of how hardened the rest of the chain is.
- **The secrets scanner is a keyword-plus-format matcher, not an entropy scanner.** STEP 5 catches an English identifier near a value (`password`, `secret`, `api_key`...) or a well-known, high-confidence credential prefix (`AKIA...`, `ghp_...`, `xox[baprs]-...`, `sk_live_...`, `pk_live_...`) or a PEM private-key header regardless of algorithm. It does **not** catch an opaque secret with no recognizable keyword and no recognizable format signature — e.g. a bare token from a vendor not in the prefix list, or a value split across a string-concatenation expression. Closing that requires content-decoding/entropy analysis (what dedicated tools like gitleaks/trufflehog do), which is out of scope for a bounded keyword-plus-format scanner by design. If your threat model includes sophisticated secret obfuscation, run a dedicated secret scanner in CI in addition to this covenant, not instead of it.
- **`_is_claude_agent_process` is a client-side self-identification signal, not a cryptographic one.** It checks `$CLAUDECODE` (inherited across `setsid`/`nohup`/backgrounding, unlike process ancestry) and falls back to walking the process tree for a `claude-code` ancestor. An agent that deliberately strips its own environment (`env -u CLAUDECODE` / `env -i`) before running a command defeats both signals — the same fundamental limit as the Bash-guard hook's lexical command scanning. This mechanism closes realistic accidental cases (an agent backgrounding a commit and severing its own process-tree link before covenant.sh runs); it is not a defense against an agent deliberately trying to evade its own governance checks.
- **The layer-boundary lint supplement (`templates/.pylintrc.layer-boundary`, `templates/eslint-layer-boundary.snippet.cjs`) is AST-based and catches more than the STEP 6.5 grep — it still cannot see through indirection.** Both pylint's native `deprecated-module` check and ESLint's native `no-restricted-imports` operate only on the import statement written in the file being linted; verified empirically that both catch aliased imports (`from fastapi import HTTPException as Err`, `import { Router as R } from "express"`) and submodule imports of a banned package (`fastapi.responses`, `express/lib/router`) that a naive linter config might miss. Neither catches `from myapp.http_shim import raise_http_error` where `http_shim.py` itself imports the banned framework — pinned at `tests/covenant/layer_boundary_block.bats:63` for the grep case and re-verified for the lint case in `tests/covenant/layer_boundary_lint_supplement.bats`. Resolving an imported *name* back to where it's actually defined requires import-graph/AST resolution across files, which is the MCP graph server's job, not a linter config's. The ESLint rule additionally only inspects ES `import` declarations — a stack still on CommonJS `require()` needs a companion rule. If your threat model requires closing the cross-file gap, that needs the graph server's `resolve`-style tooling in addition to this supplement, not instead of it.
- **`_ensure_graph_alive` (the graph-server watchdog) recovers `code-review-graph` from a mid-session crash; it does not prevent the crash or make the graph a trusted source.** It detects a `.claude/graph.pid` pointing at a process that is dead (or, after OS PID reuse, alive but no longer `code-review-graph`) and relaunches the build, capped at 3 restarts per rolling 24h window to avoid silently crash-looping forever. `code-review-graph serve` remains a plain per-session stdio MCP process, not a persistent cross-session daemon — deliberately: `_ensure_graph_freshness`'s existing kill-and-restart lifecycle already treats the index as disposable per commit, and nothing in `.mcp.json` or the install flow indicates the graph is meant to survive across sessions or be shared across worktrees. A repeated crash loop (hitting the cap) means graph-backed review context may be stale or unavailable for the rest of the session; the covenant itself is never blocked by this, by design, so a crashing indexer cannot become a denial-of-service on commits or pushes.
- **`graph_freshness_check.py` (PreToolUse hook on every `mcp__code-review-graph__*` tool) closes the read-time half of the staleness gap the two mechanisms above don't cover: nothing previously checked freshness at the moment a query actually happens, only at commit boundaries.** It compares `covenant_state.json`'s `mcp_graph.last_build_timestamp` against `git log`'s latest commit time and `git status --porcelain` for uncommitted changes to indexed-extension files, warning (never blocking — a stale-but-answered query beats a blocked one) when either drifts. For a real commit-driven drift (not just uncommitted work, which no rebuild could have indexed anyway) it attempts a **synchronous** rebuild before answering, but only below a 50,000-LOC ceiling — above that, it falls back to a warn-only path so an interactive query can never hang on a multi-minute rebuild for a large repo. Verified empirically (not just asserted) against dirty-file, stale-commit, fresh, and code-review-graph-absent scenarios in `tests/covenant/graph_freshness_hook.bats`. Still cannot make an *absent* index trustworthy, and the synchronous-rebuild ceiling is a real, disclosed tradeoff — a repo just above 50,000 LOC gets the same warn-only treatment as a 1M-LOC repo.
- **`checkpoint_tool.py`'s mechanical capture only replaces the objectively countable half of the SD1–SD5 degradation signals; the other half remains agent self-judgment, the same as before this existed.** `hook-stop` mechanically blocks a turn from ending once file/commit/session-duration thresholds are crossed (SD5's countable component, plus the previously-manual "mandatory post-commit checkpoint" rule), and `hook-pre-compact` unconditionally snapshots objective git facts on any compaction — including a user-triggered `/compact`, which the `Stop` hook never sees at all. Neither hook, nor any hook, can detect SD1 (re-reading a file), SD2 (repeating a diagnosed mistake), SD3 (narrating unprompted), or SD4 (hedging on a prior fact): these are signals in the model's own reasoning, invisible to a `command`-type hook that only sees tool-call events. The `checkpoint-search` command is a partial, indirect mitigation (a cheap way to check "have I already done this" before doing it again) — not a detector. `hook-stop`'s block/continue decision additionally relies on Claude Code's documented Stop-hook JSON contract (`{"decision": "block", "reason": "..."}`), verified in `tests/covenant/checkpoint_tool.bats` as the script's own decision logic in isolation — not against a live Claude Code session actually honoring that contract, since no sandbox running this test suite can drive a real Claude Code hook dispatch. `index.jsonl` is gitignored by default (inherits `.claude/checkpoints/`'s existing ignore rule) — cross-session-on-the-same-machine memory works out of the box, cross-developer "did a teammate already solve this" does not, unless a team deliberately opts into committing it (a decision this framework does not make silently on your behalf).
