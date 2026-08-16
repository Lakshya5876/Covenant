# Basket 1 — Brownfield Onboarding

> [!IMPORTANT]
> **START HERE: after running `install.sh`, open Claude Code and run `/init-governance`.**
> No file to open, no copy-paste — the installer already generated that command from
> `v1_implementation_package_existing.md`'s prompt content. Read that file first for the
> pre-flight checklist and LOC ceiling check, and to see what the command will do before
> running it; running the command itself does not require opening it. Only paste its
> prompt section manually if you're on an older install that predates `/init-governance`.
>
> The other file — `v1_claude_code_development_guide_existing.md` — is the engineering constitution for **Claude Code to read**, not you.
> You will copy it into your target repository as it is; the agent internalises it automatically. You do not need to read it yourself.

**For teams with existing, active codebases.**

This directory contains the V1 brownfield workflow assets. Use these if your repository
already has code, history, and pre-existing technical debt. The framework meets you where
you are — it freezes existing debt in a baseline ledger and enforces that debt can only
decrease from that point forward, never increase.

## V1 LOC Ceiling — Run This First

This package carries a hard ceiling of **≤ 1,000,000 Lines of Code**. Before doing anything
else, verify your repository is within bounds.

Run this command at your project root:

```bash
find . -type f \
  -not -path "*/.git/*" \
  -not -path "*/node_modules/*" \
  -not -path "*/.venv/*" \
  -not -path "*/__pycache__/*" \
  -not -path "*/vendor/*" \
  -not -path "*/dist/*" \
  -not -path "*/build/*" \
  -not -path "*/.next/*" \
  | xargs wc -l 2>/dev/null | tail -1
```

If the `total` on the last line is **> 1,000,000**, stop here. This package is not compatible
with your repository in V1. Contact the platform team for monorepo governance assistance.

## Files in This Directory

| File | Purpose |
|---|---|
| `v1_claude_code_development_guide_existing.md` | The engineering constitution — copy this into your repo root as-is; the init prompt reads it from disk and Claude Code generates `CLAUDE.md` from it |
| `v1_implementation_package_existing.md` | The one-time init prompt — install.sh generates `/init-governance` from this automatically; run that command in Claude Code instead of opening this file |

## Installation

The installer always writes into **the repository you are standing in** (it resolves the
target with `git rev-parse --show-toplevel`). So you clone the framework once, then run it
*from inside your target repo* using the framework's path. Do **not** run it from inside the
`Covenant` clone — that would govern the framework itself.

**Step 1 — Clone the framework once (anywhere)**
```bash
git clone <repository_url> ~/tools/Covenant
```
(This clones the whole Covenant monorepo — the macOS/Linux installer lives at
`~/tools/Covenant/CovenantMac/install.sh`; use `CovenantWin\install.ps1` instead on Windows.)

**Step 2 — Enter your target repository and verify the LOC ceiling**
```bash
cd /path/to/your-target-repo
find . -type f \
  -not -path "*/.git/*" \
  -not -path "*/node_modules/*" \
  -not -path "*/.venv/*" \
  -not -path "*/__pycache__/*" \
  -not -path "*/vendor/*" \
  -not -path "*/dist/*" \
  -not -path "*/build/*" \
  -not -path "*/.next/*" \
  | xargs wc -l 2>/dev/null | tail -1
```
Confirm the `total` is under 1,000,000 LOC. If it is, continue.

**Step 3 — Create a setup branch and run the installer by its path**
```bash
git checkout -b chore/claude-init
~/tools/Covenant/CovenantMac/install.sh        # choose [b] brownfield when prompted
```
The installer copies the dev guide + init package into your repo root, scaffolds `.claude/`
(including an unpopulated `baseline.json`), wires `.githooks/`, and installs the CI parity
workflow at `.github/workflows/covenant.yml`.

**Step 4 — Execute the initialization package**
Open Claude Code (CLI or Desktop app) in your target repository and type:
```
/init-governance
```
The installer already wrote this command from the exact same prompt content you'd otherwise
copy-paste — no file to open, no risk of pasting a truncated selection. (If you're on a
pre-`/init-governance` install, or prefer to read the prompt first: in
`v1_implementation_package_existing.md`, locate the section marked between `PROMPT START`
and `PROMPT END` and paste **ONLY THAT SECTION** as your first message instead — same
content, same result. Do not paste the entire document.) Claude Code runs automated reconnaissance,
maps your architecture, populates the debt baseline, and generates `CLAUDE.md` — one time,
fully automated.

After the init commit lands, your repository is a governed, hook-enforced agentic engineering
environment. Every subsequent session operates under the constitution and enforcement layer
established during init.

## 🧪 Testing — Opt-In at Commit, Mechanical at Push

Tests are **opt-in at pre-commit** so day-to-day commits stay fast, but **mandatory and
mechanical** at the points that actually protect the codebase — code cannot leave your
machine or merge untested.

| Stage | Tests run? | How |
|---|---|---|
| `git commit` (normal) | Opt-in | Add `--run-tests=true` to the commit message to run them |
| `git commit` touching a **CORE_FILES** path | **Always (TIER-3)** | Full suite forced automatically — no flag needed |
| `git push` | **Always** | Pre-push runs the full suite (or verifies a passing pre-commit receipt for the exact tree) |
| CI (`.github/workflows/covenant.yml`) | **Always** | Authoritative backstop even if local hooks were stripped |

* **Run tests at commit:** `git commit -m "fix: corrected auth flow --run-tests=true"`
* **Coverage threshold:** when a coverage command is configured at init, coverage below the
  threshold (default 80%) blocks the commit/push.
* You cannot push untested code — the pre-push hook has no opt-out short of the audited,
  24-hour `SKIP_COVENANT` bypass.
