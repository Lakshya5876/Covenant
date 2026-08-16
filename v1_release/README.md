# V1 Release — Enterprise AI Development Governance Framework

## Prerequisites

- **OS:** macOS or Linux — use the `CovenantMac` installer (`install.sh`). On Windows, use the
  `CovenantWin` installer instead (`install.ps1`, native PowerShell/Python, no WSL2 required) —
  see `../CovenantWin/README.md`.
- **On `PATH`:** `git`, `bash` 3.2+, `python3`.
- **Installed separately:** the [Claude Code CLI](https://claude.ai/download) — required to run the one-time `/init-governance` step; `install.sh` only warns if it's missing, it doesn't block on it.

## What This Framework Does

This framework is a **plug-and-play mechanical cage** that embeds un-bypassable enterprise
governance directly inside an ultra-smooth developer workflow. It does not slow engineers down —
it automates quality, security, and architecture compliance so that senior-grade output becomes
the floor, not the ceiling.

When a developer uses this framework, every commit, push, and PR automatically passes through:
- Scoped security scanning (hunk-intersection, not full-file noise)
- Layer architecture enforcement (no business logic in routes, no SQL in services)
- An identity-based technical debt ratchet (existing debt is frozen; it cannot grow)
- A cryptographic fingerprint covenant (working-tree state is matched at pre-push)
- A checkpoint system that preserves decision context across sessions

## Two-Basket Deployment Strategy

The framework ships in two variants — one for each type of codebase your org will encounter.

| Basket | Directory | Target | Approach |
|---|---|---|---|
| Basket 1 — Brownfield | `basket-1-brownfield/` | Existing, active repositories with pre-existing debt | Maps the repo at init, freezes debt in a baseline ledger, enforces that debt can only decrease — never increase. Every bypass is recorded with an identity receipt and a 24-hour server-replicated deadline via Git Notes. |
| Basket 2 — Greenfield | `basket-2-greenfield/` | Brand-new projects starting from commit zero | Prescriptive structural blueprint. No baseline — zero tolerance from day one. The four-layer scaffold (domain, application, infrastructure, presentation) is enforced from the first commit. |

## Contents

> **Reading order:** each basket contains two files. Always open the **Implementation Package first** — it is your human onboarding guide and contains the step-by-step instructions and the Claude Code prompt. The **Development Guide** is the engineering constitution that Claude Code reads automatically; copy it into your repo as it is and let the agent do the rest.

| Path | File | Read by | Purpose |
|---|---|---|---|
| `basket-1-brownfield/` | `v1_implementation_package_existing.md` | **You (human)** — read this first | Pre-flight checklist, LOC ceiling check, one-time init prompt |
| `basket-1-brownfield/` | `v1_claude_code_development_guide_existing.md` | **Claude Code** — becomes `CLAUDE.md` | Full brownfield engineering constitution — layer rules, naming contracts, security invariants, enforcement mechanics |
| `basket-2-greenfield/` | `v1_implementation_package_new.md` | **You (human)** — read this first | Pre-flight checklist, one-time init prompt |
| `basket-2-greenfield/` | `v1_claude_code_development_guide_new.md` | **Claude Code** — becomes `CLAUDE.md` | Full greenfield engineering constitution — prescriptive from commit one |

## Core Safety Pillars

### 24-Hour Bypass Debt Clock via Server-Replicated Git Notes
Every time a developer bypasses a covenant (skips a failing test, overrides the ratchet), the
bypass is recorded as a Git Note attached to the commit. Git Notes are pushed to the remote
via a dedicated refspec (`refs/notes/bypasses`), making the audit trail server-replicated
and visible to CI. Each bypass carries an identity receipt (author, timestamp, justification)
and a 24-hour resolution deadline. CI fails the next pipeline if the bypass is not resolved
within the window.

### Trust-Root Lockdown
Claude Code is denied Write and Edit access to its own constraint files: `.githooks/**`,
`.claude/hooks/**`, `.claude/covenant_integrity.sha256`, `.claude/covenant_state.json`,
`.claude/checkpoint_tool.py`, `.mcp.json`, and `.github/workflows/covenant.yml`, from the
moment the installer runs. `.claude/settings.json`, `CLAUDE.md`, and `.claude/baseline.json`
don't exist yet at install time, so they can't be locked down before they're created —
`/init-governance` adds Write/Edit deny rules for all three as its own final step, immediately
after generating them, closing that window rather than leaving it open indefinitely. Either
way, once governance is established, the agent cannot modify the rules it operates under
without a human developer action.

### Identity-Based Debt Ratchet
Technical debt is tracked by finding identity — not by count. The ratchet stores a normalized
token hash per finding so that whitespace and formatting changes do not re-trigger the debt
clock. Debt can only decrease over time; any new finding not present at baseline is a
hard-blocking violation.

### Cryptographic Fingerprint Covenant
A working-tree fingerprint (tree hash + staged diff + unstaged diff + untracked file hashes)
is computed at session start and matched at pre-push. If the fingerprint does not match, the
push is blocked until the session ledger is reconciled.

## 🧪 Testing — Opt-In at Commit, Mechanical at Push

Tests are **opt-in at pre-commit** to keep day-to-day commits fast, but **mandatory and
mechanical** where it matters — code cannot leave a machine or merge untested.

| Stage | Tests run? |
|---|---|
| `git commit` (normal) | Opt-in — add `--run-tests=true` to the commit message |
| `git commit` touching a **CORE_FILES** path | Always (full suite, forced — TIER-3) |
| `git push` | Always (full suite, or a verified pre-commit receipt for the exact tree) |
| CI (`.github/workflows/covenant.yml`) | Always (authoritative backstop if local hooks are stripped) |

A coverage threshold (default 80%, configured at init) blocks when unmet. The pre-push hook has
no opt-out short of the audited, 24-hour `SKIP_COVENANT` bypass.

## V1 Constraints

- Brownfield basket: **≤ 1,000,000 LOC (1M LOC Certified)** per repository (see basket-1-brownfield README for the mandatory pre-check command)
- Greenfield basket: no LOC ceiling — designed for fresh projects
- V2 Enterprise Monorepo release will add hierarchical CLAUDE.md support
