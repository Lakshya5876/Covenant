# Basket 2 — Greenfield Onboarding

> [!IMPORTANT]
> **START HERE: after running `install.sh`, open Claude Code and run `/init-governance`.**
> No file to open, no copy-paste — the installer already generated that command from
> `v1_implementation_package_new.md`'s prompt content. Read that file first if you want
> to see what the command will do before running it; running the command itself does
> not require opening it. Only paste its prompt section manually if you're on an older
> install that predates `/init-governance`.
>
> The other file — `v1_claude_code_development_guide_new.md` — is the engineering constitution for **Claude Code to read**, not you.
> You will copy it into your new repository as it is; the agent internalises it automatically. You do not need to read it yourself.

**For teams starting new projects completely from scratch.**

This directory contains the V1 greenfield workflow assets. Use these if you are beginning
a brand-new project with no prior history or debt. The framework acts as a prescriptive
structural blueprint from commit number one — zero tolerance, zero compromise, zero baseline.

There is **no LOC ceiling** for greenfield projects. The enforcement layer is designed for
fresh workspaces and scales with the project as it grows.

## Files in This Directory

| File | Purpose |
|---|---|
| `v1_claude_code_development_guide_new.md` | The greenfield engineering constitution — copy this into your repo root as-is; the init prompt reads it from disk and Claude Code generates `CLAUDE.md` from it |
| `v1_implementation_package_new.md` | The one-time init prompt — install.sh generates `/init-governance` from this automatically; run that command in Claude Code instead of opening this file |

## Installation

The installer always writes into **the repository you are standing in** (it resolves the
target with `git rev-parse --show-toplevel`). Clone the framework once, then run it *from
inside your new project* using the framework's path.

**Step 1 — Clone the framework once (anywhere)**
```bash
git clone <repository_url> ~/tools/Covenant
```
(This clones the whole Covenant monorepo — the macOS/Linux installer lives at
`~/tools/Covenant/CovenantMac/install.sh`; use `CovenantWin\install.ps1` instead on Windows.)

**Step 2 — Initialize a fresh workspace**
```bash
mkdir my-new-project && cd my-new-project
git init
git checkout -b chore/claude-init
git commit --allow-empty -m "chore: repository birth"
```

**Step 3 — Run the installer by its path (from inside your new project)**
```bash
~/tools/Covenant/CovenantMac/install.sh        # choose [g] greenfield when prompted
```
The installer copies the dev guide + init package into your project root, scaffolds
`.claude/`, wires `.githooks/`, and installs the CI parity workflow at
`.github/workflows/covenant.yml`.

**Step 4 — Execute the initialization package**
Open Claude Code (CLI or Desktop app) in your new project and type:
```
/init-governance
```
The installer already wrote this command from the exact same prompt content you'd otherwise
copy-paste — no file to open, no risk of pasting a truncated selection. (If you're on a
pre-`/init-governance` install, or prefer to read the prompt first: in
`v1_implementation_package_new.md`, locate the section marked between `PROMPT START` and
`PROMPT END` and paste **ONLY THAT SECTION** as your first message instead — same content,
same result.)
Claude Code will first run 6 rounds of questions (product/domain, stack, operational
reality, risk posture, debt philosophy, CORE_FILES), then draft a PRD, TRD, DB schema,
user flows, system design, and architecture-decisions doc under `docs/` and ask you to
explicitly approve them — nothing below happens until you do. After approval, it will
automatically:

- Scaffold the four-layer directory structure:
  - `domain/` — pure data contracts and Pydantic models, zero framework dependencies
  - `application/` — business logic orchestration, cache, and service operations
  - `infrastructure/` — all database queries, external API clients, tool execution
  - `presentation/` — HTTP routes, request parsing, response serialisation, auth enforcement
- Wire all git hooks (pre-commit security scan, pre-push fingerprint covenant)
- Install the shell aliases (`cc-feature`, `cc-push`, `cc-checkpoint`)
- Create the `.claude/` governance directory with the covenant script and settings lockdown

After the init commit lands, your project has a fully governed, ideally structured foundation.
Every feature you build from that point forward is enforced against the constitution automatically.

## 🧪 Testing — Opt-In at Commit, Mechanical at Push

Tests are **opt-in at pre-commit** so day-to-day commits stay fast, but **mandatory and
mechanical** at the points that protect the codebase — code cannot leave your machine or
merge untested.

| Stage | Tests run? | How |
|---|---|---|
| `git commit` (normal) | Opt-in | Add `--run-tests=true` to the commit message to run them |
| `git commit` touching a **CORE_FILES** path | **Always (TIER-3)** | Full suite forced automatically — no flag needed |
| `git push` | **Always** | Pre-push runs the full suite (or verifies a passing pre-commit receipt for the exact tree) |
| CI (`.github/workflows/covenant.yml`) | **Always** | Authoritative backstop even if local hooks were stripped |

* **Run tests at commit:** `git commit -m "feat: new user signup endpoint --run-tests=true"`
* **Coverage threshold:** when a coverage command is configured at init, coverage below the
  threshold (default 80%) blocks the commit/push.
* For a greenfield repo there is no debt baseline — lint is zero-tolerance from commit #1.
