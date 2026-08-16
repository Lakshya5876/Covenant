# CLAUDE CODE — THE ENTERPRISE EXECUTION STANDARD
## Edition: EXISTING REPOSITORIES (Brownfield)

**Classification:** Internal Engineering Standard
**Audience:** All Engineering Personnel — Junior through Principal
**Applies to:** Any repository with existing code, history, and accumulated debt
**Companion document:** Implementation Package (Existing Repos) — contains the one-time init prompt

> Every section is immediately actionable. The difference between an engineer who uses
> Claude Code and one who is unbeatable with it is not talent — it is methodology.
> This document is that methodology, adapted for the reality of existing codebases:
> legacy debt, enormous file counts, pre-existing test suites, and architecture that
> grew organically rather than by design.

| Section | Title | Core Skill Delivered |
|---|---|---|
| 1 | The Paradigm Shift | Execution contracts vs. conversational chatting |
| 2 | Enterprise Configuration | CLAUDE.md (descriptive), settings.json, skill commands |
| 3 | The Agentic Pipeline | Scanning tiers, stubs-first, self-correction |
| 4 | The Stateful Layer | Checkpoints, covenant-state ledger, baseline ratchet |
| 5 | Code Quality Guardrails | Atomic commits, incremental covenants, hard stops |
| 6 | Testing at Scale | 3-tier test selection for large suites |
| 7 | Session & Context Management | Budgets, compact vs. restart, XL decomposition |
| 8 | Worktree Isolation | Parallel agentic sessions without contamination |
| 9 | Performance Rubric | Beginner → Expert self-assessment |
| 10 | Quick Reference | Field card |
| A | Onboarding Path | 30-day transition schedule |

---

# SECTION 0 — GETTING STARTED

## What Is This?

Claude Code is an autonomous execution engine for software development. Unlike conversational AI assistants, it operates under a strict contract system: you specify *what must be true when done* (the objective), not *what steps to take*. The engine then reads your codebase, designs the implementation, applies changes, runs tests, and delivers results — all in one self-correcting loop.

This framework sits on top of Claude Code and standardises that execution. It provides:

- A **constitution** (CLAUDE.md) that codifies your architecture, naming contracts, and security rules once — then enforces them automatically on every task
- A **stateful covenant system** that tracks quality ratchets and prevents regressions
- A **skill command pipeline** (/feature, /audit, /review, /prep) that automate the entire development workflow
- A **worktree isolation layer** so multiple engineers can run parallel agentic sessions without stepping on each other

**Expected reading time for this section: 8 minutes.**  
**Setup time: 5 minutes.**  
**Your first feature: 10 minutes (including git push confirmation).**

---

## Installation at a Glance

```bash
# 1. Clone/enter your repository
cd your-repository

# 2. Run the init script (copies .claude/ and .githooks/ into place)
curl -s https://your-company/installer/claude-code-init.sh | bash

# 3. Verify the installation
git config core.hooksPath .githooks
ls -la .claude/settings.json .claude/commands/ CLAUDE.md

# 4. Activate hooks in this clone
cc-init-hooks  # alias for: git config core.hooksPath .githooks
```

**What got installed:**

| Directory | Purpose | Committed? |
|---|---|---|
| `.claude/settings.json` | Permission boundaries (what tools require confirmation) | ✓ Yes |
| `.claude/baseline.json` (brownfield only) | Frozen debt identities — the ratchet (see §4.3) | ✓ Yes |
| `.claude/covenant_state.json` | Covenant receipt ledger — tracks each commit's quality score | ✗ .gitignored |
| `.claude/checkpoints/` | Session snapshots (memory, context usage) | ✗ .gitignored |
| `.claude/commands/` | Skill command modules (/feature, /audit, /review, /prep) | ✓ Yes |
| `.githooks/pre-commit` | THE COVENANT — runs /audit and /review on every commit | ✓ Yes |
| `.githooks/pre-push` | Push covenant — validates receipt, enforces bypass deadline | ✓ Yes |
| `CLAUDE.md` | Constitution — architecture + naming + security rules | ✓ Yes |
| `quarantine.txt` | Flaky test quarantine (team-wide) | ✓ Yes |

Add to `.gitignore`:
```
.claude/covenant_state.json
.claude/checkpoints/
```

---

## Glossary: 20 Key Terms

<details>
<summary><strong>Click to expand — 20 definitions you'll see everywhere</strong></summary>

1. **Covenant** — Automated enforcement rule that runs on `git commit` and `git push`. Prevents regression, security violations, and architectural drift before code ever leaves your machine.

2. **Ledger** — The `.claude/covenant_state.json` file tracking every commit's quality score. If a commit fails /audit with a HIGH severity finding, the ledger records it; that receipt is validated before push.

3. **Fingerprint** — A hash of a file's content at a specific git commit. Used by the baseline ratchet to detect when a file was touched (and thus subject to full constitution enforcement).

4. **Token** — A unit of input to the LLM. 1,000 tokens ≈ 750 words. Used to calculate budget and context overhead. See §7 for token accounting.

5. **Token Budget** — The context window reserved for a single agentic task. Greenfield: 80k. Brownfield: 60k. Determines how many files can be read before context is exhausted.

6. **Hard Block** — A rule in CLAUDE.md (Section 6) that always requires explicit human approval before Claude Code proceeds. Examples: new runtime dependency, auth/authz change, schema migration.

7. **Graph** — The dependency graph of your codebase. `/audit` uses this to determine scope spillover when a file you edited is imported elsewhere (§3.2).

8. **MCP** — Model Context Protocol. The standardized interface Claude Code uses to invoke tools (read, edit, execute bash, git, etc.) safely.

9. **Blast Radius** — The set of all files affected by a change, including transitive imports. If you edit `auth.py` and 8 other files import it, the blast radius is 9 files.

10. **SECTION 2.5** — Cognitive Routing, Graph Memory, Gitflow Enforcement. A new set of rules that fire on every task automatically. Devs must read this BEFORE invoking /feature.

11. **Execution Mode Menu** — After `/feature` starts, you choose: "Stubs First" (skeleton then fill), "Guided" (one file at a time), or "Full Auto" (read-edit-test no pause). Different modes for different confidence levels.

12. **Cognitive Routing** — The framework's ability to detect when a task spans multiple concerns (e.g., "add auth" touches models, services, routes, tests) and auto-partition the work into layers.

13. **Gitflow** — The branch naming convention enforced by pre-commit hook. Must match: `feature/*`, `fix/*`, `docs/*`, `refactor/*`, `test/*`, or `chore/*`. Commits to `main` or `develop` are blocked unless in a PR.

14. **Branch Prefix** — The leading keyword in your branch name. Examples: `feature/add-dashboard`, `fix/rate-limiter-off-by-one`, `docs/update-readme`. Automation uses this to infer commit type.

15. **Cold Start** — First run of the framework in a new worktree. All memory is blank. The framework auto-generates a checkpoint after the first successful task (see §8).

16. **SKIP_COVENANT** — Emergency environment variable (`SKIP_COVENANT=1 git commit`) that bypasses pre-commit hook. Allowed exactly ONCE per worktree; subsequent uses are blocked unless a human approves and resets the counter. Used only in emergencies.

17. **Bypass** — Temporary suspension of a covenant rule (e.g., "merge a hotfix with 1 test passing instead of 100"). Logged in the receipt; auto-expires after 24 hours; requires human approval on review.

18. **Ref Notes** — Git annotations stored in `.git/refs/notes/` that log covenant receipts. Not visible in commit history; queryable with `git log --notes`.

19. **Pre-commit** — Hook that fires when you run `git commit`. Runs /audit and /review. If either fails with CRITICAL/HIGH, commit is blocked.

20. **Pre-push** — Hook that fires when you run `git push`. Validates that you didn't skip the pre-commit covenant, and enforces the SKIP_COVENANT bypass deadline (24 hours).

</details>

---

## Day 1 Checklist — Post-Installation

After running the init script, verify these three things before starting your first feature:

```bash
# 1. Hooks are wired
git config core.hooksPath
# Output should be: .githooks

# 2. Constitution is readable
cat CLAUDE.md | head -50
# You should see the architecture, naming contracts, and hard stops

# 3. Settings are permissive enough for your workflow
cat .claude/settings.json | grep -A 20 '"allow"'
# You should see your test runner, linter, and git commands
# If anything is missing, add it via /update-config skill
```

Then, **create your first branch and make a trivial change:**

```bash
git checkout -b feature/day-1-test
echo "# Day 1" >> README.md
git add README.md
git commit -m "feat: day 1 verification"
```

Expected outcome:
- Commit succeeds (pre-commit hook runs, audit passes with no CRITICAL findings)
- `git log --oneline` shows your new commit
- `.claude/covenant_state.json` now contains a receipt for this commit

**If the commit fails:** Read the audit output carefully. Usually a missing permission in settings or a stray hard-stop violation.

---

## First Feature Walkthrough — Complete Example

Let's walk through the entire lifecycle of a small feature: "Add email validation to signup endpoint."

### Phase 1: Understand the Scope

```bash
# You're in a greenfield FastAPI project
# Current branch: develop
# Task: Add email validation to signup endpoint

git checkout -b feature/email-validation
```

### Phase 2: Write the Execution Contract

Before invoking `/feature`, think:

- **SCOPE:** Which files will I touch? (`src/application/user_service.py`, `src/presentation/handlers/auth.py`, `tests/application/test_user_service.py`, `tests/presentation/test_auth.py`)
- **OBJECTIVE:** What must be true when done? ("Signup endpoint rejects requests with invalid emails. Invalid email detection uses regex; valid emails pass. All existing tests pass.")
- **CONSTRAINTS:** What rules apply? ("No external email validation APIs. No new dependencies.")
- **VERIFY:** What command proves success? (`pytest tests/application/test_user_service.py tests/presentation/test_auth.py -v`)

### Phase 3: Invoke /feature

```bash
/feature

# Prompt text:
#
# Scope:   src/application/, src/presentation/handlers/auth.py, tests/
# Objective: Email validation on signup endpoint. Rejects invalid addresses.
#            Uses regex (no external APIs). All tests pass.
# Constraints:
#   - No new dependencies
#   - Layer boundaries respected (validation in service, not handler)
#   - Existing tests unmodified
# Verify: pytest tests/application/ tests/presentation/ -v
# Output: File summary, full test output, Conventional Commit message
```

### Phase 4: Execution Mode Menu

The framework asks:

```
Which execution mode?

  [1] Stubs First      Read architecture, create empty functions, ask before filling
  [2] Guided           One file at a time, show diffs before edits
  [3] Full Auto        Read, design, edit, test, fix — no pauses

Your choice (1-3, default 2):
```

**Choose based on your confidence:**
- **Stubs First** — You're new to the codebase or want to review the design first
- **Guided** — Standard; you see each change before it lands
- **Full Auto** — You know exactly what needs to happen; trust the engine

(Let's choose Guided for this walkthrough.)

### Phase 5: Implementation

The framework:
1. **Reads** your constitution, models, existing service and handler code
2. **Designs** the validation function and integration point
3. **Asks (if Guided):** "I'm adding `validate_email()` to `UserService`. Review?" — shows the diff
4. **You reply:** "yes" → it commits the edit
5. **Tests:** Runs `pytest tests/application/` → test fails (no test yet)
6. **Fixes:** Creates test case, re-runs → test passes
7. **Integrates:** Edits handler to call `UserService.validate_email()`, runs integration test
8. **Verifies:** Full suite passes

### Phase 6: Output

```
=== FEATURE COMPLETE ===

Files Modified:
  src/application/user_service.py       | +12 lines (validation function)
  src/presentation/handlers/auth.py     | +2 lines (call validation)
  tests/application/test_user_service.py | +8 lines (unit test)
  tests/presentation/test_auth.py        | +6 lines (integration test)

Test Output (full pytest -v):
  test_user_service.py::test_valid_email PASSED
  test_user_service.py::test_invalid_email PASSED
  test_auth.py::test_signup_rejects_invalid_email PASSED
  [all 87 tests in suite] PASSED

Conventional Commit:
  feat(auth): add email validation to signup endpoint
  
  Validates email format on signup. Rejects invalid addresses.
  Uses regex pattern; no external APIs. All tests passing.
```

### Phase 7: Git Commit & Push

```bash
# Framework shows the commit message and asks
# "Ready to commit?" → you reply "yes"

git commit -m "feat(auth): add email validation to signup endpoint

Validates email format on signup. Rejects invalid addresses.
Uses regex pattern; no external APIs. All tests passing."

# Pre-commit hook fires automatically:
#   ✓ /audit (no CRITICAL/HIGH findings)
#   ✓ /review (architecture clean, test coverage adequate)
# Commit succeeds.

# Now you push:
git push -u origin feature/email-validation

# Pre-push hook fires:
#   ✓ Receipt validated (commit passed both covenants)
#   ✓ No SKIP_COVENANT bypasses pending
# Push succeeds.

# You open a PR; the CI covenant runs one final time.
```

---

## Command Quick Reference

| Command | What It Does | When to Use |
|---|---|---|
| `/feature` | Full implementation pipeline (read → design → edit → test → commit) | Whenever you start a new feature or fix |
| `/audit` | Security + architecture audit on changed files only | Run manually to check your work before commit |
| `/review` | Pre-PR covenant: test coverage, naming, layer boundaries | Run manually to prepare for merge |
| `/prep` | Convert natural language task into execution contract | When you want help structuring a vague task |
| `git commit` | Commit with auto-covenants (pre-commit hook) | Always use; never skip with --no-verify |
| `git push` | Push to remote with auto-covenants (pre-push hook) | Always use; never skip |
| `cc-init-hooks` | Activate the hooks in this clone | Run once after installing |
| `cc-audit` | Alias for `/audit` | Same as /audit |
| `cc-review` | Alias for `/review` | Same as /review |
| `/loop <interval> <command>` | Run a command repeatedly (e.g. `/loop 5m /audit`) | For continuous integration tasks |
| `/update-config` | Edit settings.json and .claude/ config | When you need to adjust permissions or add environment variables |

---

## Reading Path — Where to Go Next

You are here: **SECTION 0 (Getting Started)** ← you just finished this.

**Next:**

1. **SECTION 1** (The Paradigm Shift) — 10 min read
   - Understand the execution contract model
   - See why it's faster and better than conversational chat

2. **SECTION 2** (Enterprise Configuration) — 15 min read
   - Deep dive into CLAUDE.md (your constitution)
   - Understand settings.json and permission boundaries

3. **SECTION 2.5** (Cognitive Routing, Graph Memory, Gitflow Enforcement) — **READ BEFORE /feature**
   - These rules fire on every task automatically
   - You must know them before invoking any skill command

4. **SECTION 3** (The Agentic Pipeline) — 15 min read
   - How /feature actually works internally
   - Why tests run before commit
   - How the engine self-corrects

5. **SECTION 4** (The Stateful Layer) — 10 min read
   - How checkpoints and covenant receipts work
   - The baseline ratchet (brownfield only)

6. **Then:** Pick your workflow:
   - **Just want to ship code?** → Jump to SECTION 10 (Quick Reference)
   - **Building a new team?** → Read SECTION A (30-day Onboarding Path)
   - **Managing legacy debt?** → SECTION 4.3 (Baseline Ratchet — brownfield only)
   - **Optimizing for large test suites?** → SECTION 6 (Testing at Scale)

---

## First-Time Troubleshooting

| Problem | Solution |
|---|---|
| "git commit" blocks with audit error | Read the CLAUDE.md section cited in the error. Usually: wrong layer, missing test, or hard-stop violation. |
| Permission prompt on every /feature invocation | Your tool is not in the allow list. Run `/update-config` and add it. |
| Tests fail after /feature completes | This is expected sometimes. The framework reports it, shows output, and asks permission to iterate. Reply "yes" to fix. |
| I want to skip the covenant (emergency hotfix) | Use `SKIP_COVENANT=1 git commit`. Allowed once. Reset with `git config core.hooksPath ""` (then re-init with cc-init-hooks). 24-hour bypass window. |
| My branch name doesn't match `feature/*` | Pre-commit hook enforces gitflow. Rename: `git branch -m feature/my-fix`. |
| I deleted something by accident in /feature | Worktrees isolate changes. If the main worktree is clean, you can restart in a new worktree. See §8. |

---



---

# SECTION 1 — THE PARADIGM SHIFT

## 1.1 Two Execution Models: One Correct, One Comfortable

Most engineers approach Claude Code like a senior colleague over Slack — ask, receive,
paste, ask again. Wrong mental model. Claude Code is an autonomous execution engine.
Treating it like a chat assistant is hiring a robotics engineer to fetch coffee one cup
at a time.

**Model A — Conversational (the amateur trap):**

```
Engineer                     Claude Code                   Codebase
   |--"add auth to endpoint"----->|                            |
   |                              |--reads 1 file ------------>|
   |<--"here is the middleware"---|                            |
   |--"now add the token check"-->|                            |
   |<--"here is the token logic"--|                            |
   |--"the tests are failing"---->|                            |
   |<--"fix this import path"-----|                            |
   |--"now update the docs"------>|                            |
   |<--"here is the doc block"----|                            |

  [6 round trips | 35k+ tokens | 25 minutes | 6 manual pastes]
  [By turn 6, attention on your CURRENT instruction is diluted
   by 13 prior messages re-read on every turn]
```

**Model B — Agentic Execution Contract (the expert standard):**

```
Engineer                     Claude Code                   Codebase
   |--[single execution contract]>|                            |
   |                              |--grep: locate auth layer-->|
   |                              |--read: handler (targeted)->|
   |                              |--edit: auth handler------->|
   |                              |--bash: run impacted tests->|
   |                              |<--[failure output]---------|
   |                              |--read: root cause--------->|
   |                              |--edit: fix---------------->|
   |                              |--bash: re-run, all pass--->|
   |<--[complete: summary + diff]-|                            |

  [1 round trip | ~7k tokens | 4 minutes | 0 manual pastes]
```

## 1.2 The Token Debt Spiral — Quantified

Every conversational turn carries the full cumulative context as overhead:

```
Turn 1:                                          =  1,280 tokens
Turn 2:  (672 tokens were history — 34% waste)   =  1,950 tokens
Turn 3:  (2,350 tokens were history — 68% waste) =  3,440 tokens
Turn 6:                                          = 14,100 tokens
---------------------------------------------------------------
Total, 6 conversational turns:                   = 35,770 tokens
Same work as a single agentic contract:          =  7,400 tokens
Wasted on context retransmission:                = 28,370 (79%)
```

As history grows, effective attention on your current instruction dilutes. You get less
intelligent output for more tokens.

## 1.3 The Execution Contract — The Fundamental Unit of Work

Stop writing prompts. Write execution contracts — single, complete, machine-executable
specifications that need zero follow-up questions.

| Field | Definition | If Missing |
|---|---|---|
| SCOPE | Explicit list of dirs/files in scope. Everything else is off-limits. | Agent reads unrelated files, wastes tokens |
| OBJECTIVE | The condition that must be TRUE when done — not what to do. | Ambiguous success; agent stops early or overshoots |
| CONSTRAINTS | Rules that cannot be broken: architectural, security, dependency, naming. | Layer violations, security gaps, style drift |
| VERIFY | Exact command(s) producing deterministic pass/fail. | Agent marks complete without evidence |
| OUTPUT | What to produce: diff summary, test results, commit message. | Human cannot quickly validate |

```
# WEAK (forces follow-up, ambiguous success)
"add rate limiting to the API"

# STRONG (self-contained, deterministic, zero follow-up)
Scope:      src/api/handlers/, src/middleware/, tests/unit/middleware/
Objective:  Every public HTTP route handler is protected by per-IP rate
            limiting — 60 req/min. State in process memory only.
            No new infrastructure dependencies.
Constraints:
  - Initialise limiter once at application startup only
  - No business logic inside middleware
  - All existing handler tests pass without modification
Verify:     <test-runner> tests/unit/middleware/test_rate_limiter.py
            Exit code 0. Print full output.
Output:     Table of files touched. Full test output.
            One-line Conventional Commit message.
```

**The Quality Axiom:** Claude Code produces exactly the quality you specify.
The output ceiling is always the prompt floor.

---

# SECTION 2 — ENTERPRISE CONFIGURATION

## 2.1 The Complete Directory Structure

```
your-repository/
|
+-- CLAUDE.md                    <- Constitution (auto-loaded every session)
+-- v1_claude_code_development_guide_existing.md   <- this document (gitignored or docs/)
|
+-- .claude/
|   +-- settings.json            <- Permission boundaries
|   +-- baseline.json            <- Frozen debt identities (BROWNFIELD ONLY — see §4.3)
|   +-- covenant_state.json          <- Covenant receipts ledger (gitignored — see §4.2)
|   +-- checkpoints/             <- Session state snapshots (gitignored — see §4.1)
|   +-- commands/
|       +-- feature.md           <- /feature  full implementation pipeline
|       +-- audit.md             <- /audit    diff-scoped security + architecture audit
|       +-- review.md            <- /review   pre-PR covenant
|       +-- prep.md              <- /prep     natural language -> execution contract
|
+-- .githooks/
|   +-- pre-commit               <- THE COVENANT, mechanically enforced (see §4.5)
|   +-- pre-push                 <- receipt validation + bypass deadline + force guard
|
+-- quarantine.txt               <- committed flaky-test quarantine (see §6 T4)
+-- src/ ...    (or whatever your repo actually uses — see §2.2)
+-- tests/ ...
```

Add to `.gitignore`:

```
.claude/covenant_state.json
.claude/checkpoints/
```

`baseline.json`, `.githooks/`, and `quarantine.txt` ARE committed — the whole team
shares one debt baseline and one covenant. Each clone activates the hooks once:
`git config core.hooksPath .githooks` (wrapped as `cc-init-hooks` in .team_aliases).

## 2.2 CLAUDE.md — The DESCRIPTIVE Constitution

**This is the single most important brownfield rule:**

> In an existing repository, CLAUDE.md must DESCRIBE the architecture that actually
> exists — not prescribe a textbook ideal. A constitution that contradicts the real
> codebase causes every covenant check to fail on every file, and the entire system
> becomes noise the team learns to ignore within a week.

The constitution is generated by the init prompt (see Implementation Package) AFTER
a staged reconnaissance pass and a human-confirmed discovery report. It codifies:

- The layer names and directories your repo ACTUALLY uses
- The naming conventions ALREADY in your code (discovered, not invented)
- Your real test framework, runner commands, and linter
- Security invariants (these ARE universal — see below)
- Hard stops (universal)
- The enforcement scope rule (brownfield-specific — see §2.2.1)

### 2.2.1 The Enforcement Scope Rule (Touched-Files-Only)

```
## ENFORCEMENT SCOPE (BROWNFIELD)
- The constitution applies FULLY to: new files, and any region of an
  existing file modified in the current task.
- Untouched legacy code is EXEMPT until touched (boy-scout rule).
- Never demand a refactor of an unrelated legacy file as a precondition
  for a small change. Flag the debt; do not block on it.
- When touching a legacy file, leave the touched region cleaner than
  found: parameterise the query you edited, type the function you
  modified — but do NOT rewrite the whole file.
```

Without this rule, every small fix demands refactoring a 3,000-line god-file first,
and the team abandons the system. With it, quality ratchets upward with every commit.

### 2.2.2 Universal Security Invariants (identical in every constitution)

```
## SECURITY INVARIANTS (ABSOLUTE — NEVER NEGOTIATE)
- Credentials/secrets/keys NEVER written to any file on disk.
- .env is in .gitignore. Must never be committed.
- Every route exposing data requires explicit auth enforcement.
- Raw exceptions and stack traces NEVER returned to clients.
- User input NEVER interpolated into query strings — parameterised only.
- Secrets NEVER appear in log output at any level.
```

### 2.2.3 Hard Stops (universal)

| Trigger | Why human approval is required |
|---|---|
| New runtime dependency / lockfile alteration | Supply chain; hidden transitive deps bypass review |
| Database schema migration | Irreversible in production |
| Auth/authz logic change | Direct path to access-control bypass |
| New environment variable | Must be provisioned in all environments |
| Deployment/infra config | Misconfiguration causes outages |
| CI/CD pipeline modification | Can silently suppress security checks |
| .gitignore changes | Could unblock accidental secret commits |
| Background job/scheduler | Double-processing or data loss |
| Changes to .claude/baseline.json by hand | Defeats the ratchet (see §4.3) |
| Permission-mode change or settings.json edit | Disabling the prompt layer disables the only mechanical push covenant |
| Editing the CORE_FILES list in CLAUDE.md | Shrinks the tier-3 test trigger silently (see §6) |
| Quarantining a test that covers a CORE_FILES module | Removes the one test that catches a core regression (see §6) |
| Any modification to `.githooks/**` or the CI covenant definition | Direct trust-root compromise; bypassing local or pipeline constraints |

### 2.2.4 Governance Files Are Human-PR-Only

CLAUDE.md, the CORE_FILES list, settings, hooks, and baseline definitions
change exclusively via human-authored pull requests, never via automated agent
edits. The core list grows as the dependency graph grows, but it is updated via
a human engineering pass. The agent never self-maintains the constitution; the
deny list (§2.3) enforces this mechanically.

## 2.3 settings.json — Hard Permission Boundaries

Anything not in the allow list prompts; anything in the deny list is blocked outright.

```json
{
  "permissions": {
    "defaultMode": "default",
    "allow": [
      "Bash(grep:*)", "Bash(find:*)", "Bash(ls:*)", "Bash(cat:*)",
      "Bash(git status:*)", "Bash(git diff:*)", "Bash(git log:*)",
      "Bash(git show:*)", "Bash(git branch:*)", "Bash(git add:*)",
      "Bash(git commit:*)", "Bash(git update-index:*)",
      "Bash(<your-test-runner>:*)",
      "Bash(<your-linter>:*)",
      "Bash(<your-type-checker>:*)",
      "Read(*)", "Edit(*)", "Write(*)"
    ],
    "deny": [
      "Bash(git reset --hard:*)", "Bash(git rebase:*)",
      "Bash(git push --force:*)", "Bash(git push -f:*)",
      "Bash(git push --force-with-lease:*)", "Bash(git push --mirror:*)",
      "Bash(git push --delete:*)", "Bash(git clean:*)",
      "Bash(git commit --no-verify*)", "Bash(git commit -n *)",
      "Bash(git push --no-verify*)", "Bash(git -c core.hooksPath*)",
      "Bash(SKIP_COVENANT=*)",
      "Bash(rm -rf:*)", "Bash(sudo:*)",
      "Bash(DROP TABLE:*)", "Bash(DROP DATABASE:*)",
      "Bash(nc:*)", "Bash(ssh:*)", "Bash(scp:*)",
      "Read(.env)", "Read(**/.env)", "Read(**/.env.*)",
      "Read(**/*.pem)", "Read(**/id_rsa*)", "Read(**/.aws/credentials)",
      "Bash(cat .env:*)", "Bash(cat *.pem:*)",
      "Write(.githooks/**)", "Edit(.githooks/**)",
      "Write(.claude/settings.json)", "Edit(.claude/settings.json)",
      "Write(.claude/baseline.json)", "Edit(.claude/baseline.json)",
      "Write(CLAUDE.md)", "Edit(CLAUDE.md)",
      "Write(v1_claude_code_development_guide_existing.md)",
      "Edit(v1_claude_code_development_guide_existing.md)",
      "Write(v1_implementation_package_existing.md)",
      "Edit(v1_implementation_package_existing.md)",
      "Bash(git notes*remove*)", "Bash(git update-ref -d*)",
      "Bash(git config core.hooksPath*)", "Bash(git config --add core.hooksPath*)",
      "Bash(git commit -a*)", "Bash(git commit -am*)", "Bash(git commit --amend*)"
    ]
  }
}
```

The `--no-verify` and `core.hooksPath` denies exist because `git commit --no-verify`
skips the pre-commit hook entirely — an allow-listed `Bash(git commit:*)` rule
without them is a silent back door around the whole enforcement layer (§4.5).
The trust-root denies (`.githooks/**`, `settings.json`, `baseline.json`,
`CLAUDE.md`, notes removal, ref deletion) mechanically block the agent from
editing the files that constrain it — a covenant the agent can rewrite is not a covenant.
These governance files change only via human-approved PR.

**Critical placement rule for `git push`:** put it in NEITHER list. Not in allow
(no silent pushes), not in deny (a deny rule is a hard block — the user never even
sees an approval dialog). Absent from both lists, every push triggers an interactive
Allow/Deny prompt — which is exactly the human-in-the-loop behavior you want.
The chat-level confirmation (§5.3 Covenant Step 4) and the pre-push hook (§4.5) are the
primary covenants; the dialog is the backstop.

**Boundary caveats (encode all three in CLAUDE.md at init):**

```
P1. PERMISSION MODE: governed repos MUST NOT be operated with
    --dangerously-skip-permissions or defaultMode: bypassPermissions.
    Either nullifies the interactive prompt — the backstop evaporates
    with one CLI flag. defaultMode is pinned to "default" in the
    committed settings.json; changing it is a hard stop (§2.2.3).
P2. COMPOUND COMMANDS: allow rules match command PREFIXES. A compound
    command ("git status && git push origin HEAD") can smuggle a push
    under an allowed prefix on any client with naive prefix matching.
    Rule: git push is ALWAYS issued as a standalone command, never
    inside &&, ;, or | chains — so the prompt always fires.
P3. FORCE-PUSH COVERAGE: the deny list blocks the named force variants,
    but refspec-force syntax (git push origin +main) cannot be
    pattern-matched. It is banned in constitution text and caught by
    the pre-push hook (§4.5) and Covenant Step 4 — never describe force-push
    as "hard-blocked" on the deny list alone.
```

## 2.4 Custom Slash Commands

Each file in `.claude/commands/` becomes a `/commandname`. `$ARGUMENTS` receives the
text after the command name. The Implementation Package generates these with your
repo's real commands substituted in. The four commands and their jobs:

| Command | Job | Brownfield-specific behavior |
|---|---|---|
| /feature | Full implementation pipeline (Phases 0–5, see §3) | Checkpoint writes at phase boundaries; impacted-tests-only during EXECUTE |
| /audit | Security + architecture audit | DIFF-SCOPED by default; compares findings against baseline.json; only NEW findings block |
| /review | Pre-PR covenant | Diff-scoped; consults covenant_state.json to skip already-passed checks |
| /prep | Natural language → execution contract, zero implementation | Flags hard stops at top of contract |

---

# SECTION 2.5 — COGNITIVE ROUTING, GRAPH MEMORY & BRANCH ENFORCEMENT

These rules fire **before** every task — before any file read, before the pipeline, before any tool call. They are entry covenants, not suggestions.

---

## 2.5.1 Gitflow Branch Enforcement (fires first — before anything else)

**Branch validation — mandatory on every task:**

1. Read current branch: `git branch --show-current`
2. If branch is `main`, `master`, or `develop`: **HARD BLOCK**
   - Output exactly: `BRANCH BLOCK: Direct work on protected branch '[branch]' is forbidden. Create a feature/bugfix/hotfix/release branch first.`
   - Zero execution. Zero file reads. Stop entirely.
3. Extract prefix (everything before the first `/`). If prefix does not match `feature|bugfix|hotfix|release`: emit one-line warning, then require explicit user acknowledgement before continuing.

**Dynamic graph strategy by branch prefix — read this table before the first graph call:**

| Branch prefix | Strategy name | Permitted graph tools | Max depth |
|---|---|---|---|
| `feature/` | BROAD | All 5 tools; call `get_architecture_overview_tool` first | Full graph |
| `bugfix/` | NARROW | `get_impact_radius_tool` + `query_graph_tool` only; no architecture overview | 2 hops max |
| `hotfix/` | ULTRA-NARROW | `get_impact_radius_tool` only; single target symbol | 1 hop |
| `release/` | DIFF-ONLY | `get_review_context_tool` only; no code writes permitted | Diff surface |

**After determining strategy, state it before the first tool call:**
`Branch: bugfix/fix-auth-token → Strategy: NARROW. Max 2 hops. Architecture overview suppressed.`

---

## 2.5.2 Cognitive Routing — Model Intercept

**Classify every task before any execution:**

| Tier | Applies to | Recommended model |
|---|---|---|
| LOW | Formatting, single-file test, comment edit, rename | Haiku |
| MEDIUM | Standard feature, multi-file edit, bug fix with side effects | Sonnet |
| HIGH | Architecture decision, cross-layer refactor, new system design, security change | Opus |

**Ambiguity rule:** when classification is unclear between two tiers, always round up.

**LOW-tier tasks:** proceed immediately — no menu, no pause.

**MEDIUM or HIGH tasks — or when `token_spent_today` ≥ 60% of `TOKEN_BUDGET`:** stop and output the Execution Mode Menu (§2.5.3). Zero execution until user replies.

---

## 2.5.3 Execution Mode Menu (HALT & ASK upgrade)

**When triggered (MEDIUM/HIGH tier, or budget ≥ 60%), output this block verbatim — no prose, no paraphrasing:**

```
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
EXECUTION MODE REQUIRED
Classification: [Tier] | Model: [Model]
Token budget used: [X]% of daily limit
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

[1] DIRECT — Single context, self-reviewed
    Cost: 1x | Quality: standard
    Best for: contained features, clear scope

[2] SUBAGENT — Isolated contexts, independent verification covenants
    Cost: 3–5x | Quality: highest
    Best for: architecture, security changes, cross-system refactors
    ⚠ WARNING if budget < 40%: subagent flow may hit hard block mid-run

[3] HYBRID — Isolated implementation, in-thread review
    Cost: 2x | Quality: high
    Best for: medium complexity requiring an independent review covenant

Reply with 1, 2, or 3.
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
```

**Enforcement rules:**
- Hard stop after outputting the menu — zero execution until integer reply received
- No fallback: do not assume Option 1. Do not proceed on ambiguous replies.
- If Option 2 selected AND `token_spent_today` > 60%: output a second confirmation block noting the subagent flow risk before proceeding
- Write selected mode + classification + budget % + timestamp to `.claude/session_state.json` immediately after approval

---

## 2.5.4 Graph Memory Protocol

**Prerequisite check (run once per session, before first exploration):**
- If `.mcp.json` exists in project root AND `code-review-graph status` returns healthy: **graph-first mode active**
- If absent or unhealthy: fall back to standard grep/Read workflow + emit one-line advisory: `Graph inactive — falling back to grep/Read. Run install.sh to enable.`

**Multi-domain graph scope:**
The graph indexes these domains as first-class nodes — not just application code:

| Domain | File patterns |
|---|---|
| Application code | `*.py`, `*.ts`, `*.tsx`, `*.js`, `*.go`, `*.rs`, `*.java` |
| SQL / migrations | `*.sql`, `migrations/**` |
| ORM models | `models/**`, `*model*`, `*schema*` |
| Infrastructure | `Dockerfile*`, `docker-compose*.yml`, `*.tf`, `*.hcl` |
| CI/CD | `.github/workflows/*.yml`, `.circleci/config.yml` |
| Proxy/gateway | `nginx.conf`, `*.conf` |
| Env contracts | `.env.example` |

This means a blast-radius query on a DB column returns: the migration file, the ORM model, the API route, the env variable, and the Dockerfile ENV instruction — as one unified impact set.

**Named tool mandate — exact usage rules:**

| Tool | When to call | Must not replace with |
|---|---|---|
| `get_architecture_overview_tool` | First call on any new session; any `feature/` branch task | Reading README for orientation |
| `semantic_search_nodes_tool` | Any keyword/symbol lookup across the codebase | `grep -r`, `rg`, directory scans |
| `get_impact_radius_tool` | Before touching ANY file — scope blast radius first | Speculative file reads |
| `query_graph_tool` | Finding callers, callees, imports, test coverage, inheritors | `grep -n <symbol>`, manual tracing |
| `get_review_context_tool` | PR review, `release/` branch work, post-feature diff analysis | `git diff`, reading full changed files |

**Result size limits (CRITICAL at 1M+ LOC):**

Graph queries on heavily-imported utilities (logger, config, utils) can return thousands of edges. Without limits, a single query consumes all remaining token budget. **MANDATORY:**

- If a graph query returns >50 results: fetch first 10 only. Ask the tool to prioritize by import frequency or graph depth. Paginate if needed.
- If a single node has >100 edges (transitive callers/callees): query direct callers only (depth 1). Do NOT fetch the full closure.
- If `query_graph_tool` returns >50 edges, stop immediately and narrow your search:
  - Specify file patterns: `query_graph_tool(logger, in_files="app/services/**")`
  - Limit depth: `query_graph_tool(logger, max_depth=1)` (direct calls only)
  - Filter by type: `query_graph_tool(logger, node_types=["FunctionDef"])`
  - Never fetch all 5,000 results "just to see"

**Mandatory sequence before any edit:**
1. `get_impact_radius_tool(<target_symbol>)` — what breaks? (respects depth limit automatically)
2. `query_graph_tool(<target_symbol>)` — who calls this, what does it import, which tests cover it? **If >50 results: narrow your query before continuing.**
3. Load ONLY the specific nodes returned (max 20 files) — never load the containing file in full
4. If edge count is suspicious (e.g., 500+ callers for a utility), the query result is itself the finding: "this node is too central, refactor is needed." Do not attempt to load all 500 callers.

---

## 2.5.5 Context Diet Rules

These rules apply at all times, regardless of graph availability:

- **Never `cat` any file.** Use the `Read` tool with explicit `limit` and `offset` parameters.
- **Max 150 lines per file load** unless a hard stop explicitly justifies more; state the justification inline.
- **`semantic_search_nodes_tool` replaces all broad grep** when graph is active.
- **When graph is inactive:** use `grep -n` or `rg` for symbol lookups — never directory-wide `cat`.
- **Flush on completion:** final output line of every task: `Task complete. Run /clear to flush session context.`
- **AUTOMATED MAP REFRESH:** To eliminate graph entropy and prevent the agent from navigating the repository using stale metadata, the framework implements a background regeneration loop. Every time a change set modifies structural source files, the local git hook asynchronously refreshes the underlying SQLite index. This guarantees that the agent's spatial understanding of the codebase remains synchronized with reality over long-running execution periods.

---

## 2.5.6 Challenge Phase — Pre-Execution Verification

**Before ANY implementation starts, output this exact challenge — never skip:**

```
┌─ CHALLENGE PHASE
├─ Is this the smallest useful wedge? (scope check)
├─ What breaks if this is done wrong? (risk surface)
└─ Can it be reverted in <5 minutes? (rollback time)
```

**Execution rule:** If you cannot answer all three questions with confidence, **STOP and ask the developer for clarification.** Never proceed speculatively.

---

## 2.5.6a Scope Discipline — Minimum Footprint, No Drive-By Edits

**Before finalizing any diff, self-check against both:**

```
MINIMUM FOOTPRINT:
  - No abstraction introduced for a single call site
  - No configurability/flags not requested in the task
  - No error handling for states the current call graph cannot produce
  - If the diff exceeds ~3x the lines a senior engineer would need, cut it down

SURGICAL BOUNDARY:
  - Every changed line must trace to the stated task
  - Do not reformat, re-comment, or "clean up" adjacent code
  - Match existing style even where you would choose differently
  - Orphans YOUR change created: remove them. Pre-existing dead code: name
    it, don't touch it, unless the task asked for it.
```

**Execution rule:** Run this check during PHASE 4 (Verification Loop), before the checkpoint write — not after the diff is already staged.

---

## 2.5.6b Blocking Questions, Not Buried Ones

**Any question that needs a human decision — a HARD STOP, a scope ambiguity, a genuine fork in approach — must be surfaced through a blocking decision mechanism (e.g. a structured question tool), never appended as a sentence inside a long text response.**

A question sitting at the bottom of a wall of recon output, test results, or a diff summary is a question that gets scrolled past. The human's attention was on the last visible thing, not on parsing every paragraph for an embedded "?" — and a HARD STOP that goes unnoticed is functionally identical to no HARD STOP at all. This is not about asking more questions; PIPELINE EXCEPTIONS (Guide §5, execution protocol) still says "no clarifying questions for everything else." This rule only changes *how* the questions that DO warrant asking get delivered.

**Execution rule:**
- If the environment provides a structured, blocking question mechanism (e.g. Claude Code's `AskUserQuestion`), use it for every HARD STOP and every genuine scope fork — not free text.
- If no such mechanism is available in the current environment, the question must be the *entire* message — not the last line of a longer one — and must state plainly that execution is paused pending a reply.
- Never treat a prior, unrelated approval as covering a new decision point. Each blocking question stands on its own.
- A question a human can plausibly miss is worse than no safeguard at all: it creates the appearance of a checkpoint without the substance of one.

This mirrors the existing PUSH CONFIRMATION discipline (Guide §5.3) — that rule already requires a push to be its own explicit, un-missable exchange, never inferred from something said earlier in the same message. This section generalizes that same discipline to every hard-stop and scope-fork decision, not just pushes.

---

## 2.5.7 Reflect Phase — Post-Commit Retrospective

**After every successful commit (lines 3–5 only, appended to `.claude/progress.md`):**

```markdown
## [branch-name] @ [commit-hash]
- ✓ [one sentence: what was delivered]
- ⚠ [one sentence: risk or gotcha discovered]
- ➤ [one sentence: what to do next OR what unblocks the next PR]
```

**Execution rule:** This entry is MANDATORY. If `.claude/progress.md` does not exist, create it. Entries are written ONLY AFTER `git commit` succeeds, never speculatively.

---

## 2.5.8 Caveman Mode — Zero Conversational Filler

**Eliminate all conversational filler, pleasantries, and apologies.** You may output a brief, 2-sentence architectural reasoning (Chain-of-Thought) to ensure logical accuracy, followed immediately by precise code blocks or exact terminal commands.

**Permitted output format:**
1. Optional: **2-sentence Chain-of-Thought** (architectural reasoning only)
2. Code blocks (with language tag: `\`\`\`python`)
3. Exact terminal commands (with \`\`\`bash)
4. Error messages verbatim (no paraphrasing)

**Prohibited output:**
- "I'll now...", "Let me...", "Here's what I'm doing..."
- Apologies, hedging ("might", "could", "probably")
- Explanations of what the code does (the code IS the explanation)
- Multi-paragraph prose or narrative
- Pleasantries ("Thanks!", "Great question!", etc.)

**Example (correct):**
```
Layer boundary violation: route is calling repository directly. Moving call to service layer.

[code blocks follow]
```

**Example (incorrect):**
```
I'll now refactor this to move the repository call into the service layer. This is important because...
[long explanation]
```

---

## 2.5.9 Graph Limit — Strict 50-Edge Cap Per Query

**Before EVERY call to `query_graph_tool`, check the result count explicitly:**

```bash
query_graph_tool("symbol", max_depth=1)
# Receives: "Found 347 callers (showing first 10)"
# Your response: 
#   ✓ Accept the first 10, proceed with analysis
#   ✗ Never attempt to load all 347
```

**Mandatory scoping filters (apply BEFORE querying, not after):**
- `in_files="app/services/**"` (narrow to one layer)
- `max_depth=1` (direct calls only, not transitive)
- `node_types=["FunctionDef"]` (exclude classes, modules if irrelevant)

**Result interpretation rule:** A result count of 500+ callers on a single utility IS the finding — that code is over-centralized and needs refactoring. Do not load the full list; report the symptom and move on.

---

## 2.5.10 Context Flush — Post-Push Cleanup Command

**After `git push` succeeds, output exactly this line:**

```
Task complete. Run `/clear` to flush session context.
```

**Execution rule:** This is non-optional. Every push workflow MUST end with this line. It signals to the developer that the session context is exhausted and should be reset to prevent token budget leakage in subsequent tasks.

---

# SECTION 3 — THE AGENTIC PIPELINE

## 3.1 Workspace Scanning — Token-Efficient Navigation

The single most expensive mistake: reading entire files to find one function.
Strict scanning hierarchy, cheapest first — never use a higher tier when a lower
tier answers the question:

| Tier | Tool | Cost | Use |
|---|---|---|---|
| 1 Structural | `find src/ -name '*.py' \| sort` | 5–50 tokens | Map structure, zero content |
| 2 Location | `grep -rn 'class OrderService' src/` | 10–30/result | Pinpoint file + line |
| 3 Surgical read | `Read(file, offset=N-5, limit=40)` | 100–300 | The 40 lines around target |
| 4 Section read | `Read(file, offset=0, limit=60)` | 200–500 | Imports + signatures only |
| 5 Full file | `Read(file)` | 500–3,000 | Only when entire file is relevant |

```
# CORRECT sequence (~330 tokens total):
find src/ -name "*.py" | head -60                      # map: ~30 tokens
grep -rn "def process_payment" src/ --include="*.py"   # locate: ~15
Read(src/application/payment_service.py, offset=132, limit=35)  # ~250
grep -rn "process_payment" src/ tests/                 # impact radius

# NAIVE equivalent (reading all service files): ~8,000 tokens
# SAVING: ~96% for identical information
```

**At enormous-repo scale this is not an optimisation — it is survival.** A naive
deep-read of a 50k-file monorepo dies before producing anything.

## 3.2 The /feature Pipeline (Phases 0–5)

```
PHASE 0: PRE-FLIGHT
  git status -> clean | branch -> not protected
  test suite -> collects | build -> compiles
        |
PHASE 1: RECONNAISSANCE (zero writes)
  grep -> locate all symbols | Read(targeted)
  Output: explicit change manifest with dependency order
        |
PHASE 2: DESIGN DECLARATION (still zero writes)
  Layer assignment, typed signatures, error states, test list.
  Cannot answer something? STOP and ask. Never assume.
        |
PHASE 2.5: STUBS-FIRST SIGNATURE PROTOCOL [MANDATORY for 3+ files]
  Write ALL stubs simultaneously: real imports + typed signatures
  + empty returns. Compile-check ALL at once. All clean before
  ANY implementation. Locks contracts before logic exists.
        |
PHASE 3: IMPLEMENTATION (dependency order, bottom-up)
  After each file: compile/import check.
  >>> CHECKPOINT EVALUATION (see §4.1) <<<
        |
PHASE 4: VERIFICATION LOOP (max 3 attempts — see §3.3)
  git update-index --refresh BEFORE every diff/re-run.
  Impacted tests -> pass -> tier-2 test selection (§6) -> pass.
  >>> CHECKPOINT EVALUATION <<<
        |
PHASE 5: OUTPUT
  Change manifest | test output verbatim | Conventional Commit msg
  >>> CHECKPOINT WRITE (always, unconditional) <<<
```

### 3.2.1 Phase 2 — Assumption Declaration and Success Criteria

Phase 2's existing rule ("Cannot answer something? STOP and ask. Never assume.") is binary — confident-and-proceed, or stop-and-ask. It has no middle path for a minor ambiguity that doesn't warrant a full stop. Two additions close this:

**Assumption declaration.** If you CAN answer with reasonable confidence but multiple interpretations exist, don't pick silently — state it:

```
ASSUMING: [the interpretation you're proceeding on]
ALTERNATIVE: [what would change if this is wrong]
```

This is a declaration, not a question — it does not block Phase 3. Reserve STOP-and-ask for cases where no interpretation is reasonably safe.

**Success criteria.** Before Phase 3 begins, declare what "done" means for this specific task:

```
GOAL: [concrete, observable outcome]
VERIFY: [specific test/command that confirms it — not "tests pass" generically]
```

Phase 4's Verification Loop already runs impacted tests mechanically; this makes explicit what those tests are being run *for*, so a checkpoint doesn't just report "tests passed" without stating which outcome that was supposed to prove.

### The Stubs-First Protocol — why it works

A stub file contains: all real imports, all signatures fully type-annotated, empty
typed returns, zero logic. Compile-checking all stubs simultaneously:

- Surfaces import errors at stub time, not mid-implementation
- Confirms the dependency graph is coherent before any business logic
- Prevents the hallucination loop where File A invents a signature contradicting File B
- Gives the human a reviewable interface contract before logic is written

```bash
# Compile check across ALL stubs at once:
# Python:     python -c "import all_stub_modules; print('CLEAN')"
# TypeScript: tsc --noEmit
# Go:         go build ./...
# Rust:       cargo check
# Exit code 0 required before Phase 3 begins.
```

## 3.3 Self-Correction — Root Cause, Three Strikes, Loop Invariants

**Root-Cause Reading Protocol** — on any error, answer three questions BEFORE fixing:

```
Error: ImportError: cannot import name 'PaymentService' from 'application'
  Q1: Does the symbol actually exist?       grep -rn "class PaymentService" src/
  Q2: What is the correct path?             Read the defining file's header
  Q3: Where is the bad reference?           grep -rn "from application import"
Root cause stated in ONE sentence -> minimum fix -> verify.
```

Symptom-chasing burns 5 iterations going the wrong way; root-cause-first takes one.

**Mandatory before every re-run and every git diff:**

```bash
git update-index -q --refresh; git diff --no-ext-diff
# IMPORTANT — what --refresh actually does: it reconciles STAT METADATA
# only (clears stale stat-dirty bits when content is unchanged). It does
# NOT import new content, and it cannot rescue a content change hidden
# behind an identical mtime+size (fast editor saves, container clock
# skew). For verification it must be paired with a content-level check:
# git diff --no-ext-diff re-hashes on stat mismatch. When certainty is
# required, use git status --porcelain=v2. Never treat --refresh alone
# as proof the working tree matches the index.
```

**The Three-Strike Rule:**

```
Attempt 1: refresh index, run, read FULL traceback, state root cause
           in ONE sentence, apply minimum fix, re-run.
Attempt 2: DO NOT stack a fix on a fix. Identical error? Attempt 1
           did nothing — revert it. Changed error? New root cause —
           clean fix, re-run.
Attempt 3: STOP. Output: original error verbatim, what each attempt
           changed and produced, best root-cause assessment, what a
           human needs to provide. NO fourth attempt.
```

**Loop-prevention invariants (never break):**

- Never modify a test to make it pass — modify the code under test
- Never add try/except to silence an error — fix the error
- Never add "if test mode" conditionals — that is a mask
- Same error twice across different fixes = your mental model is wrong; restart analysis
- Import errors resolve fully BEFORE running the suite

**Circular imports are structural problems** — resolution order: (1) extract shared
dependency to a third module; (2) dependency inversion via an interface;
(3) TYPE_CHECKING guard — valid ONLY for type-annotation cycles, never runtime.

---

# SECTION 4 — THE STATEFUL LAYER (checkpoints, ledger, baseline)

> This section is what makes the system viable on large existing repos. Without
> state, every covenant re-pays full cost on every run, sessions die with their context,
> and pre-existing debt blocks the first commit forever. Four mechanisms fix this:
> **checkpoints** (session state survives restarts), the **covenant-state ledger**
> (passed covenants are never re-run on identical code), the **baseline ratchet**
> (existing debt never blocks; new debt always does), and the **enforcement layer**
> (git hooks that make all of the above mechanical rather than volunteered —
> without §4.5, everything else in this section is advisory).

## 4.1 The Checkpoint System

### 4.1.1 Purpose

Claude Code sessions lose context: compaction is lossy, restarts are total. A
checkpoint is a **state snapshot, not a conversation summary** — what exists on
disk, what was decided, what remains. A fresh session reading the latest checkpoint
resumes at full competence without re-deriving anything.

### 4.1.2 Storage

```
.claude/checkpoints/<YYYYMMDD-HHMM>-<phase>.md     one file per checkpoint
.claude/checkpoints/LATEST.md                       always overwritten with newest
```

Gitignored. Per-machine, per-engineer state.

### 4.1.3 Trigger Rules (exact — no interpretation)

Claude Code MUST evaluate checkpoint pressure at every phase boundary of /feature
(end of Phase 1, 3, 4) and after completing any /audit or /review. Pressure is HIGH
if ANY of:

```
C1. 3 or more pipeline phases completed this session
C2. 5 or more files modified this session
C3. A hard stop fired and was resolved this session
C4. A test failure was diagnosed and fixed this session
C5. The session has run more than ~2 hours
```

- If HIGH → write checkpoint BEFORE continuing, and tell the user:
  `"Context pressure high — checkpoint written to .claude/checkpoints/<file>"`
- At end of Phase 5 → write checkpoint ALWAYS, unconditionally.
- Claude Code cannot read its own token meter; C1–C5 are the proxy. When in doubt,
  write the checkpoint — a redundant checkpoint costs ~200 tokens; a lost session
  costs an hour.

### 4.1.4 Checkpoint File Schema (every field required)

```markdown
# CHECKPOINT
phase:        <recon | execute | verify | output | audit | review>
git_sha:      <git rev-parse HEAD>
branch:       <git branch --show-current>
dirty_files:  <git status --porcelain | wc -l> uncommitted
timestamp:    <YYYYMMDD-HHMM>

## TASK
<one sentence: what this session is doing and for whom>

## FILES MODIFIED THIS SESSION
- path/to/file — one-line reason

## DECISIONS LOCKED
- <decision>: <why this over the alternative>   (one line each)

## CURRENT STATE
- tests: <last run result, e.g. "144 passed">
- lint/scan: <clean | known findings vs baseline>
- build: <compiles | broken at X>

## PENDING
- <ordered list of what remains before the task is complete>

## RESUME INSTRUCTION
<one sentence: the exact next action a fresh session should take>
```

State only. Never conversation excerpts, never reasoning transcripts.

### 4.1.5 Resume Protocol (exact)

At the start of ANY session in a repo where `.claude/checkpoints/LATEST.md` exists:

```
1. Read LATEST.md (it is ~40 lines — negligible cost).
2. Run: git rev-parse HEAD  and  git status --porcelain
3. If HEAD matches checkpoint git_sha (or descends from it):
     resume from RESUME INSTRUCTION. State to the user:
     "Resuming from checkpoint <timestamp>: <task summary>".
4. If HEAD has diverged (someone else pushed, branch changed):
     state the divergence, ask whether the checkpoint is still valid.
5. If the user starts a clearly NEW task: ignore the checkpoint,
     and note that the old one will be superseded at next write.
```

### 4.1.6 Retention

Keep the 10 most recent checkpoint files; delete older ones at write time.
LATEST.md always reflects the newest.

### 4.1.7 Post-Commit Checkpoint Update (mandatory)

After EVERY successful `git commit`, immediately write LATEST.md using the full
schema from §4.1.4. Not optional — not even on trivial commits. This is the
mechanism that makes `/clear` safe across sessions: a fresh session reads
LATEST.md, executes the RESUME INSTRUCTION, and continues without loss. Write
LATEST.md before any push attempt.

### 4.1.8 Context Degradation Detection and Forced Handoff

Beyond the trigger rules C1–C5 (§4.1.3), monitor continuously for these
signals during a session:

| Signal | Indicator |
|--------|-----------|
| SD1 | Re-reading a file already fully read this session (no new change justifies it) |
| SD2 | Reproducing an error diagnosed and fixed earlier in this session |
| SD3 | Narrating prior steps unprompted — model compensating for lost thread |
| SD4 | Hedging on a decision or file content that was unambiguous earlier in the session |
| SD5 | 5+ phases completed, 8+ files modified, or session > 3 hours since last /clear |

**Forced Handoff Protocol** — when 2+ signals (SD1–SD5) are simultaneously active:

1. Stop current work immediately.
2. Write `.claude/checkpoints/LATEST.md` (full schema, §4.1.4). RESUME
   INSTRUCTION must be written as a briefing for a cold-start agent with zero
   prior context — not a summary for the current session.
3. Output exactly this message (no paraphrasing, no abbreviation):

```
CONTEXT SATURATION DETECTED. Code quality will degrade if this session
continues. To preserve output quality:

  1. Type /clear to flush the session.
  2. The new session will read LATEST.md and resume from exactly where
     we stopped — no context is lost.

LATEST.md written: .claude/checkpoints/LATEST.md
Resume instruction: <RESUME INSTRUCTION verbatim>
```

4. Write no further code until the user runs /clear and opens a new session.
   If the user overrides and asks to continue anyway, state the risk once,
   then comply.

### 4.1a Mechanical Capture (hooks) — What's Enforced vs. What's Still Judgment

`checkpoint_tool.py` (installed to `.claude/checkpoint_tool.py`) mechanizes
part of the protocol above via real Claude Code hooks, so it no longer
depends entirely on the agent noticing its own state:

- **`hook-stop`** blocks a turn from ending once file/commit/session-duration
  thresholds are crossed (`covenant_state.json`'s `thresholds.checkpoint_pressure`)
  — this is the countable half of SD5, plus the "mandatory post-commit
  checkpoint" rule, now enforced rather than merely instructed.
- **`hook-pre-compact`** unconditionally snapshots objective git facts (sha,
  branch, diff-stat) on any compaction — including a user-triggered
  `/compact`, which `Stop` never sees at all.
- **`hook-session-start`**, **`hook-post-bash`**, **`hook-post-write`**
  mechanize the resume-protocol read and the pressure counters themselves.

**What is NOT mechanized, and cannot be with hooks alone:** SD1 (re-reading a
file), SD2 (repeating a diagnosed mistake), SD3 (narrating unprompted), and
SD4 (hedging on a prior fact) are signals in the model's own reasoning — a
`command`-type hook only sees tool-call events, never the reasoning that
produced them. These remain your own judgment, exactly as before. The
`checkpoint-search` command (search → timeline → show, progressive
disclosure — never fetch full checkpoint bodies without filtering first) is
a cheap way to check "have I already done this" before re-doing it, which
helps you avoid triggering SD1/SD2 — it does not detect them for you.

Full design notes and disclosed limitations: `docs/SECURITY_POSTURE.md` §7,
`templates/checkpoint_tool.py`'s own module docstring.

## 4.2 The Covenant-State Ledger

### 4.2.1 The problem it solves

A stateless covenant re-runs the full audit + review + suite even when nothing changed
since the last pass. On a large repo that is minutes of wall-time and thousands of
tokens per push — and it trains engineers to bypass the system. The ledger gives
covenants memory.

### 4.2.2 The ledger file

`.claude/covenant_state.json` (gitignored — per-machine):

```json
{
  "audit":  { "fingerprint": "<hash>", "result": "pass", "new_findings": 0, "ts": "..." },
  "review": { "fingerprint": "<hash>", "result": "pass", "ts": "..." },
  "tests":  { "fingerprint": "<hash>", "result": "212 passed", "scope": "impacted",
              "suite_wall_time_s": 41, "ts": "..." },
  "last_pass_sha": "<commit sha of the last fully-passing state>"
}
```

The ledger is written by the covenant script (§4.5), atomically (`write tmp + rename`),
and is the ONLY writer. Bypass records do NOT live here — they live in the
append-only bypass ledger (§4.4), because an escape-hatch log the escaping party
can edit is not an audit log.

### 4.2.3 The fingerprint

The fingerprint must capture committed state + staged changes + unstaged changes
+ **untracked files**. A fingerprint that omits untracked files is blind to a
brand-new unstaged file — a new SQL-injecting module, a new unauthenticated
route — and every covenant would SKIP loudly while net-new vulnerable code ships:

```bash
fingerprint() {
  {
    git rev-parse 'HEAD^{tree}'
    git -c color.ui=false -c diff.noprefix=false -c diff.context=3 diff --no-ext-diff
    git -c color.ui=false -c diff.noprefix=false -c diff.context=3 diff --no-ext-diff --cached
    git ls-files -z --others --exclude-standard | sort -z | while IFS= read -r -d '' f; do [ -f "$f" ] && shasum "$f"; done
  } | shasum | cut -d' ' -f1
}
```

Rules:

```
F1. A receipt is valid ONLY if untracked, staged, AND unstaged state are
    all unchanged — the fingerprint above encodes all three.
F2. The diff invocations pin color/prefix/context config. git diff output
    is NOT stable across gitconfigs (mnemonicPrefix, noprefix, context,
    color); unpinned diffs make cross-machine receipts meaningless.
F3. Identical fingerprint = identical state = a passed covenant is still
    valid. One changed byte, one new file = miss = the covenant runs.
    Fingerprint state, never time.
F4. TWO FINGERPRINT FORMS — they govern different lifecycle moments and
    must never be conflated:
      a. WORKING-TREE fingerprint (the function above): governs ONLY the
         in-session ledger SKIP — "has anything changed since the last
         covenant run in this directory?"
      b. COMMIT-TREE receipt key: when the pre-commit hook passes, it
         keys the receipt by the TREE OF THE COMMIT BEING CREATED
         (git write-tree on the index being committed). The pre-push
         hook then recomputes git rev-parse 'HEAD^{tree}' and matches
         against THAT key.
    Why the split is mandatory: the working-tree fingerprint is computed
    over dirty state; the instant the commit lands, HEAD moves, the
    staged diff empties, and the working-tree fingerprint can NEVER
    again equal the receipt pre-commit just wrote. Without form (b),
    pre-push either blocks every legitimate push or checks nothing.
```

### 4.2.4 Covenant logic with ledger

```
on commit/push trigger (hook-enforced, §4.5):
  current = fingerprint()                      # working-tree form, F4a
  for each covenant in [audit, review, tests]:
      if ledger[covenant].fingerprint == current and result == pass:
          SKIP — and say so loudly
      else:
          if last_pass_sha is null:            # COLD START — first run
              changed = ALL tracked files + untracked files
              (audit everything once; on pass set last_pass_sha = HEAD)
          else:
              changed = git diff --name-only <last_pass_sha>..HEAD
                        + staged + unstaged + untracked files
          run covenant SCOPED TO that change set
          write new receipt on pass (script writes, atomically),
          keyed per F4: working-tree fp for the session ledger,
          commit-tree hash for the pre-push receipt
```

"Diff since last pass" is computed against `last_pass_sha` (a commit ref recorded
in the ledger) — never against a fingerprint hash, which is not a git object and
cannot be diffed against. The null cold-start branch is not optional: without it,
`git diff null..HEAD` is a fatal git error and the covenant crashes on the very first
commit — the init verification commit itself.

### 4.2.5 Loud skips — the adoption requirement

Silent skips breed distrust; slow re-runs breed abandonment. Every covenant run ends
with a report like:

```
COVENANT REPORT  (emitted by the covenant script — see integrity rule below)
  audit:  SKIPPED — passed at this exact fingerprint 12 min ago
  review: SKIPPED — no changes since last pass
  tests:  3 files changed -> 11 impacted tests run -> all pass
          (full suite deferred to CI)
  Total covenant time: ~20s
```

**Report integrity:** the COVENANT REPORT is emitted by the covenant script (§4.5) to
stdout — never composed by the model. A model-written "COVENANT REPORT" with no
underlying script run is invalid by definition; /review prints the
script-generated report verbatim and may not summarize or reconstruct it.
Engineers who can SEE why a skip was safe — and know the report cannot be
faked — keep using the system.

### 4.2.6 Cross-session trust

Receipts persist on disk and survive sessions and restarts — but trust is earned
per use: before trusting any receipt, RECOMPUTE the full fingerprint (including
untracked files) in the current session and compare. Match → trust. Mismatch →
the covenant runs, no exceptions, including "it was only a comment change."

### 4.2.7 Concurrency

One session per working directory — two concurrent sessions in the same directory
will interleave ledger writes and corrupt the JSON; this is unsupported. Parallel
work belongs in separate worktrees (§8), where each worktree naturally owns its
own `.claude/covenant_state.json`. All ledger writes are atomic (`write tmp + rename`).

## 4.3 The Baseline Ratchet (brownfield's centerpiece)

### 4.3.1 The problem it solves

An existing repo has debt: hundreds of linter findings, legacy patterns, files that
predate the rules. A covenant demanding zero findings blocks the first commit forever →
the team disables the covenant on day one. The ratchet makes the covenant incremental:
**existing debt never blocks; new debt always blocks; total debt only goes down.**

### 4.3.2 The baseline file

`.claude/baseline.json` — generated once by the init prompt, COMMITTED to the repo
(the whole team shares one baseline). The schema stores **per-finding identity**,
not counts — counts cannot distinguish "moved", "masked", or "new":

```json
{
  "generated_at": "<ts>",
  "generated_from_sha": "<sha>",
  "summary": { "security_high": 3, "security_medium": 41, "lint_errors": 230,
               "type_errors": 88, "layer_violations": 54 },
  "scanners": { "security": "<tool name>", "lint": "<tool>",
                "types": "<tool>", "complexity": "NO_SCANNER" },
  "findings": {
    "src/legacy/billing.py": [
      { "rule": "B608", "line_hint": 142,
        "fp": "<hash of the finding's surrounding normalized tokens>" },
      { "rule": "E722", "line_hint": 88, "fp": "<hash>" }
    ]
  }
}
```

The `fp` (finding fingerprint) hashes the normalized code tokens surrounding the
finding — stable across line-number shifts, unique per actual defect. `line_hint`
is advisory only; identity lives in `(rule, fp)`.

**fp normalization MUST be whitespace- and format-insensitive**: normalize to a
canonical token stream (strip whitespace, comments, and line breaks) before
hashing. Otherwise a pure-formatting pass over a legacy file (reflow, import
sort) shifts the surrounding tokens of every grandfathered finding, every fp
reclassifies as NEW, and the boy-scout tidy-up the ratchet exists to enable gets
blocked by hundreds of phantom findings. Additionally: if ALL of a touched
file's findings shift fp simultaneously while rule+file+count are unchanged, the
covenant treats it as a **re-fingerprint event** — re-anchor the baseline fps to the
new positions, do not block.

Every debt category with no available scanner is recorded as `"NO_SCANNER"` and
/review prints `UNPROTECTED: <category>` on every run — a silently absent scanner
must never read as "clean."

### 4.3.3 Ratchet rules (exact)

```
R1. IDENTITY, NOT COUNTS. The covenant keys every current finding by
    (rule, fp) and looks it up in the baseline:
      - present in baseline  -> grandfathered, never blocks
      - absent from baseline -> NEW, always blocks
    A new finding can NEVER be offset by an incidental fix elsewhere:
    deleting one old defect while introducing one new one is a BLOCK,
    even though the count is unchanged. Count-equality masks exactly
    this swap; identity comparison does not.
R2. RATCHET-DOWN. When a baseline finding's (rule, fp) is no longer
    present, the covenant script removes that entry from baseline.json and
    commits it with the task — and records the removed fingerprints in
    the audit receipt. /review verifies every baseline decrease against
    that receipt: a downward delta is legal ONLY if the audit run
    recorded those same fingerprints as removed.
R3. The baseline NEVER increases. There is no mechanism to add debt.
    New debt is fixed before merge, full stop.
R4. Any baseline.json change WITHOUT a matching audit receipt is a
    HARD STOP — this is how the covenant distinguishes its own legal
    ratchet-down writes (R2) from human or model tampering. Baseline
    increases are never legal regardless of receipts.
R5. A finding moving from file A to file B keeps its rule but gets a
    new fp context in B -> it is NEW debt in B and blocks. The per-
    finding schema is what makes this enforceable; per-file counts
    could not distinguish "moved" from "fixed plus added".
```

### 4.3.3a Diff-scoping a file-level scanner (the hunk-intersection rule)

Most scanners (bandit, eslint) report on whole files — they cannot be pointed at
changed lines. Running them on a touched legacy god-file re-surfaces every
grandfathered finding as noise. The covenant therefore intersects:

```
1. Run the scanner on the FULL changed file (the only mode it has).
2. Compute touched line ranges: git diff -U0 <last_pass_sha> -- <file>
   (zero-context hunks give exact changed ranges).
3. For each finding:
     inside a touched hunk  -> evaluate ALWAYS (R1 identity check —
                               new fp blocks, grandfathered fp passes)
     outside touched hunks  -> check against baseline only; block only
                               if this edit INCREASED findings there
                               (which only happens via R5-style moves)
4. The report lists suppressed out-of-hunk grandfathered findings as a
   one-line count, not as noise: "(14 baseline findings outside touched
   hunks — unchanged)".
```

This is the mechanism behind "touched-files-only" (§2.2.1) — without the hunk
intersection, the policy is unimplementable for file-level scanners.

### 4.3.4 The payoff curve

Week 1: covenants pass despite 1,600 findings — nothing blocks, team onboards smoothly.
Month 3: every touched file got slightly cleaner; baseline has ratcheted down ~20%.
Month 12: debt is a fraction of the start, and it was paid for by the boy-scout rule —
nobody ever did a "big cleanup sprint."

## 4.4 The Kill Switch

Emergencies are real. If the covenant cannot be bypassed when production is down, the
team will uninstall the system the first time it is on fire. The bypass exists,
is loud, and is audited — and critically, **it is enforced by the hook layer
(§4.5), not by model goodwill**:

```bash
SKIP_COVENANT=1 git commit -m "hotfix(...): <msg>"
```

Rules:

```
K1. LAYERED, WITH HONEST GUARANTEES. "Claude never invokes SKIP_COVENANT" is
    policy, not a control — a model in a failure loop (or prompt-injected)
    can emit that exact string. The mechanical layers, strongest first:
      a. PRIMARY — settings.json denies "Bash(SKIP_COVENANT=*)". This is the
         un-spoofable layer: the agent cannot form the command at all.
         CAVEAT: verify your client's matcher actually catches env-prefixed
         commands (some tokenizers only match when the program itself is
         the pattern). If unverified, enforce in the hook instead: the
         pre-commit hook refuses SKIP_COVENANT when agent-environment markers
         are present (e.g. $CLAUDECODE set, or no interactive terminal).
      b. SECONDARY — the pre-commit hook, on seeing SKIP_COVENANT set, demands
         confirmation via read -p from /dev/tty. This assumes an agent
         WITHOUT an interactive terminal; an interactive CLI session DOES
         have a controlling TTY, so this is a human-presence backstop,
         not a categorical guarantee. Never describe it as "physically
         impossible" — the deny rule is the hard layer, this is defense
         in depth.
      c. The typed confirmation must include a reason string; empty = abort.
    The documented human path: run the bypass in a PLAIN shell, not
    through the agent — then no matcher semantics are in play at all.
K2. APPEND-ONLY, SHARED AUDIT TRAIL. The hook (never the model, never a
    hand edit) records each bypass as a git note on the bypassed commit
    (git notes --ref=bypasses add). covenant_state.json is NOT the bypass
    log — gitignored mutable per-machine JSON is not an audit trail.
    PROPAGATION IS NOT AUTOMATIC: git does not push refs/notes/* by
    default. The init (§4.5.1) MUST configure:
      git config --add remote.origin.push  'refs/notes/bypasses:refs/notes/bypasses'
      git config --add remote.origin.fetch '+refs/notes/bypasses:refs/notes/bypasses'
    and CI must git fetch origin 'refs/notes/*:refs/notes/*' before its
    deadline check. Without these, the note stays on the laptop and the
    "visible to every clone and CI" guarantee is false.
K3. The next /review reports all bypass notes since the last clean pass
    and re-runs the skipped covenants against the bypassed commits.
K4. 24-HOUR CLOCK ON GIT TIME. The pre-push hook compares each bypassed
    commit's COMMITTER DATE (git-authoritative metadata) against now;
    any bypass older than 24h without a matching clean re-run receipt
    blocks the push. The comparison never uses self-reported ledger
    timestamps — that would re-import the clock-drift failure mode the
    fingerprint design exists to avoid.
```

## 4.5 The Enforcement Layer (git hooks) — what makes everything above real

> Without this section, every "blocks", "auto-triggered", and "HARD STOP" in
> this standard is a behavior the model is asked to volunteer each session — a
> forgetful or jailbroken session bypasses everything silently. The hooks make
> the covenant mechanical: it runs because git runs it, not because the model
> chose to.

**Honest scope statement:** local hooks are evadable by a determined actor
(`git commit --no-verify`, `git -c core.hooksPath=/dev/null`). The deny list
(§2.3) blocks the model from forming the common evasions; the CI run of the same
covenant script is the authoritative layer that catches everything else. Never
describe local hooks as un-bypassable — describe them as the fast layer that
makes the honest path the easy path.

### 4.5.1 Installation (generated at init, committed)

```
.githooks/
  covenant.sh         <- the shared covenant script (hooks and CI both call it)
  pre-commit      <- fingerprint -> scoped covenant -> ledger receipt
  pre-push        <- receipt validation + bypass-deadline check + force guard

Per-clone activation (wrapped as cc-init-hooks in .team_aliases):
  git config core.hooksPath .githooks
  git config --add remote.origin.push  'refs/notes/bypasses:refs/notes/bypasses'
  git config --add remote.origin.fetch '+refs/notes/bypasses:refs/notes/bypasses'
```

Committed to the repo: the hooks ARE the covenant. The notes refspecs are not
optional — without them, bypass notes never leave the laptop (K2).

### 4.5.2 pre-commit responsibilities

```
1. If SKIP_COVENANT is set: apply K1 (deny-first, TTY backstop, reason
   required); on success write the bypass git note (K2) and exit 0.
2. SCAN THE COMMIT TREE, NOT THE WORKING TREE: build the exact tree
   being committed via git write-tree on the index (use a temp index
   for safety). With git commit -a or git add -p partial staging, the
   index differs from the working tree — scanning the working tree
   both blocks findings that aren't being committed and misses hunks
   that are. The working-tree fingerprint (F4a) governs only the
   session-ledger SKIP; the scan target here is the index tree.
   The git commit -a, -am, and --amend flags are strictly blocked via
   hard settings permissions to guarantee that the index tree perfectly
   equals the commit tree at hook time.
3. Receipt valid for this tree? -> emit COVENANT REPORT (skips), exit 0.
4. Else: run the scoped covenant — change set per §4.2.4 (including the
   null cold-start branch), audit with hunk intersection (§4.3.3a) +
   identity ratchet (§4.3.3) + tier-2 tests (algorithm below) — emit
   the COVENANT REPORT, write receipts atomically (working-tree fp for
   the session ledger, write-tree hash for the pre-push key, per F4),
   exit nonzero on any block.

TIER-2 SELECTION ALGORITHM (covenant.sh must implement exactly this):
  a. If test-impact tooling is installed (required at init for any
     repo with >~200 tests — see §6 T3): query it with the change
     set; run the returned set.
  b. If tooling is absent (small repos only): run the naming-contract-
     mapped tests of every changed file PLUS the entire test set of
     every module that depends on any changed CORE_FILES entry
     (transitive, from the init-built import graph) — and label the
     report "TIER 2 (degraded: tooling absent)". grep alone is never
     the selector (§6 T5).

LINTER (hard gate — runs after security scan):
  Run LINT_CMD (recorded in covenant_state.json at init) scoped to changed
  files where the tool supports it. Non-zero exit blocks the commit.
  Absence must be explicit: record NO_LINTER in the covenant report.

TYPE CHECKER (hard gate — runs after linter):
  Run TYPECHECK_CMD (recorded in covenant_state.json at init) on the full
  project. Non-zero exit blocks the commit. Record NO_TYPECHECKER if
  absent.

COVERAGE THRESHOLD (hard gate — runs after test execution):
  Assert line coverage ≥ COVERAGE_THRESHOLD (default 80%, stored in
  covenant_state.json). Block the commit if coverage drops below threshold.
  The threshold is human-editable via PR only — agents cannot lower it.

COMPLEXITY COVENANT (performance proxy — runs on changed files only):
  Run the stack's complexity scanner (radon cc -n C for Python,
  eslint with complexity rule for JS/TS, gocyclo for Go). Block the
  commit if any function exceeds COMPLEXITY_THRESHOLD (default
  cyclomatic complexity 10, stored in covenant_state.json). High complexity
  is the leading structural indicator of performance regression.
```

### 4.5.3 pre-push responsibilities

```
1. Refuse pushes to main/master/develop outright.
2. Refuse any refspec beginning with '+' (force syntax that no
   settings pattern can catch — §2.3 P3).
3. Recompute git rev-parse 'HEAD^{tree}' and require a passing receipt
   keyed by that commit-tree hash (F4b); none -> block with "covenant has
   not passed for this exact state". Never match against the working-
   tree fingerprint — it cannot equal a post-commit state (F4).
4. Refuse any refspec containing a deletion semicolon targeting the
   bypass trail (echo "$@" | grep -qE ":refs/notes/bypasses" must
   return exit code 1) — git notes are not inherently append-only;
   git push origin :refs/notes/bypasses would erase the audit trail.
5. Enforce the bypass 24h deadline (K4) — after fetching
   refs/notes/bypasses so remote bypasses are visible.
```

### 4.5.4 Division of labor — hooks vs. model

```
HOOKS (mechanical, cannot be forgotten):   fingerprint, receipts,
  ratchet arithmetic, hunk intersection, tier execution, bypass
  control, force-push refusal, deadline math, COVENANT REPORT emission.
MODEL (judgment, cannot be mechanized):    root-causing a finding,
  writing the fix, deciding severity context, drafting the PR body,
  the Covenant Step 4 push conversation.
The model orchestrates and explains; the hooks enforce and record.
A model that skips its part produces worse UX; it cannot produce a
bypassed covenant.
```

CI runs the same covenant script as the hooks (same fingerprint, same ratchet) so a
hook-stripped clone still cannot merge unverified code — hooks are the fast local
layer, CI is the authoritative one.

---

# SECTION 5 — CODE QUALITY GUARDRAILS

## 5.1 Atomic Commit Discipline

An atomic commit: exactly one logical change; the suite passes at that commit in
isolation; reviewable in under 5 minutes; the message alone explains WHY.

```
FORMAT:  type(scope): imperative description
TYPES:   feat | fix | refactor | test | perf | security | docs | chore

ACCEPTABLE:
  fix(cache):     close stampede gap by swapping event.set() and map.delete()
  security(auth): route infrastructure probes to hardened prompt path
NOT ACCEPTABLE:
  "fix stuff" | "updates" | "WIP" | "changes"
```

**The anti-blob pattern** — one feature = layered commits, each independently
reviewable and bisectable:

```
commit 1: feat(domain): add Payment entity + repository interface
commit 2: feat(infra):  implement StripePaymentRepository
commit 3: feat(app):    add ProcessPaymentUseCase with retry logic
commit 4: feat(api):    add POST /payments endpoint
commit 5: test(payment): unit + integration coverage
```

## 5.2 Auditable Diffs

At every non-obvious decision, one comment explaining WHY (a message to the
reviewer, not documentation):

```python
# Exponential backoff: provider returns 429 on burst — linear retry
# would saturate the limit
```

Test names are specification sentences:

```
test_process_payment_retries_on_rate_limit_up_to_three_times()
test_process_payment_is_idempotent_with_same_idempotency_key()
```

## 5.3 The Commit/Push Covenant (hook-enforced, ledger-aware)

The covenant runs at TWO layers. The model layer triggers when the user says "commit",
"push", "PR", "ship", "merge" — it orchestrates, explains, and fixes. The hook
layer (§4.5) runs on every `git commit` and `git push` regardless of what the
model does — it is the enforcement. A session that never reads CLAUDE.md still
cannot land an unverified commit. With the ledger (§4.2), repeat runs on unchanged
code skip in seconds.

```
COVENANT STEP 1 — /audit (diff-scoped, baseline-aware)
  Ledger hit at current fingerprint -> SKIP loudly (script-emitted).
  Else: audit files changed since last_pass_sha, hunk-intersected
  (§4.3.3a), identity-checked against baseline (§4.3.3 R1).
  NEW findings: CRITICAL/HIGH -> BLOCK, await human.
  MEDIUM/LOW new findings -> auto-remediate, re-verify.

COVENANT STEP 2 — /review (diff-scoped, ledger-aware)
  Ledger hit -> SKIP loudly.
  Else: layer compliance + secrets-in-diff + test coverage +
  lockfile assertion — on changed files only.
  LOCKFILE RULE: any lockfile diff without an approved dependency
  addition = HARD STOP. Hidden transitive deps bypass review.

COVENANT STEP 3 — git (only if 1 and 2 pass clean)
  git update-index -q --refresh; git diff --no-ext-diff   (§3.3 semantics)
  git add <specific files — NEVER git add -A>
  Conventional Commit message. The pre-commit hook re-verifies
  mechanically — a model that skipped steps 1-2 gets blocked here.

COVENANT STEP 4 — PUSH CONFIRMATION (mandatory, no exceptions)
  State in chat: exact branch and remote.
  Wait for explicit human approval IN THIS CONVERSATION.
  A prior "push" in the same message does NOT count.
  No reply = no push. Ever.
  The pre-push hook independently refuses protected branches,
  +refspec force syntax, missing receipts, and expired bypasses.
```

## 5.4 Pre-PR Manual Covenants

```bash
git update-index --refresh                       # always first
<test-runner per §6 tiers>                       # green required
git diff main...HEAD | grep -iE "password|secret|api_key|token"   # zero matches
git diff main...HEAD --name-only                 # every file explainable
<linter> && <type-checker>                       # no NEW errors vs baseline
```

---

# SECTION 6 — TESTING AT SCALE (3-Tier Selection)

> A 10,000-test suite cannot run on every commit. Running it anyway produces
> 30-minute covenants, and 30-minute covenants produce engineers who stop committing.
> Test selection is tiered by scope; the full suite belongs to CI.

## 6.0 Dynamic Stack Inference (Mandatory — No Hardcoded Runner)

The agent MUST NOT assume a fixed test runner (pytest, jest, etc.). Before any
test command is constructed, inspect repository roots and infer the active
testing architecture programmatically:

```
INFERENCE ORDER (cheapest signal first):
  package.json       → scripts.test, devDependencies (jest, vitest, @playwright/test)
  pyproject.toml     → [tool.pytest], [tool.coverage]
  requirements*.txt  → pytest, unittest, nose
  go.mod             → go test ./...
  Cargo.toml         → cargo test
  pom.xml / build.gradle → mvn test / ./gradlew test
  Makefile / justfile → test targets
  CI config          → .github/workflows, .gitlab-ci.yml (ground truth for CI parity)
```

The inferred runner(s) are logged in the COVENANT REPORT. If multiple runners exist
(e.g. backend unit tests + Playwright E2E), the pipeline sequences ALL of them
and requires exit code 0 from each — never silently skip a suite.

**Zero conversational filler:** the agent deduces test paths, scoping filters,
and runner flags from the repo — never prompts the developer for test
specifications, test file paths, or runner choice.

## 6.1 Browser / E2E Layer — Playwright (Implicit, Never Prompted)

When the change set touches UI components, routing, frontend rendering paths,
proxy/gateway config, or any user-visible behavior:

```
MANDATORY (handled implicitly by /feature — zero human prompts):
  1. Detect Playwright presence: playwright.config.{ts,js,mjs} or
     @playwright/test in package.json
  2. If absent but a frontend/proxy layer exists: scaffold Playwright
     (playwright.config.ts + e2e/ or tests/e2e/ directory) as part of
     Phase 3 — not as a separate ask
  3. Auto-generate a Playwright spec (*.spec.ts or stack equivalent)
     covering browser-side actionability and network contracts
  4. Use web-first async assertions (page.getByRole, expect(locator))
  5. Execute via the inferred runner (npx playwright test) autonomously
  6. Both unit/integration AND Playwright suites must exit 0 at pre-push and CI.
     At pre-commit: tests are opt-in (add [run-tests] to the commit message),
     except when the change touches a CORE_FILES path — then the full suite is
     forced regardless (TIER-3 escalation via covenant_state.json core_files[]).
```

The pipeline NEVER asks the developer to write out test specifications,
describe user journeys, or confirm E2E test paths — the agent derives them
from the change manifest and layer assignment in Phase 2.

## 6.2 Three-Tier Selection

```
TIER 1 — per-file (during /feature Phase 3, after each file):
  Run ONLY the test file(s) mapped to the modified module.
  Mapping source, in order of preference:
    a. Naming contract (tests/<layer>/test_<module>) if the repo has one
    b. Test-impact tooling (stack-specific: pytest-testmon, jest --changedSince,
       vitest related, go test ./changed/..., bazel rdeps queries)
    c. Import-graph reverse lookup (grep) — a LOWER BOUND only, see T5
  Typical cost: seconds.

TIER 2 — impacted set (covenant, pre-commit):
  Tests for all changed files PLUS reverse dependencies:
    - LEAF modules (imported by few others): one level of reverse deps
      is permitted.
    - CORE_FILES (see below): transitive closure to a FIXED POINT.
      One level is NOT enough for shared code: a regression in
      util/money.py breaks services/billing.py whose tests sit TWO
      import hops away — one-level selection misses them and the
      break leaks to staging.
  Typical cost: tens of seconds on a large repo.

TIER 3 — full suite:
  Runs ONLY when: a CORE_FILES match changed, OR before PR creation,
  OR explicitly requested. PREFER running tier 3 in CI, not locally.
```

**CORE_FILES — the explicit list that makes tier 3 deterministic.** "A shared/core
file changed" is a judgment the agent cannot be trusted to make per-session.
CLAUDE.md MUST contain an explicit `CORE_FILES` glob list — the ONLY trigger for
mandatory tier 3. The init populates it mechanically from the dependency graph
(any module imported by more than N≈5 other modules is core, plus config, base
models, DI wiring, conftest/fixtures). The list grows as the dependency graph
grows, but it is updated via a human engineering pass — editing CORE_FILES is a
hard stop (§2.2.3) and changes only via human-authored PR, never agent edit.

Rules:

```
T1. The covenant report ALWAYS states which tier ran and why
    ("3 files changed -> tier 2 -> 41 tests"). Silent scoping reads
    as full coverage when it isn't — that's how trust dies.
T2. A tier-1/2 pass plus a ledger receipt is sufficient for commit.
    PR merge requires a tier-3 pass (CI).
T3. Test-impact tooling is installed AT INIT for any repo with more
    than ~200 tests — never deferred to "when the suite gets slow".
    Deferring creates a window where the suite carries real risk,
    tooling is absent, and grep is admittedly insufficient (T5): the
    covenant would have no reliable tier-2 selector exactly when it
    matters. (Tooling additions are a dependency hard stop — the init
    discovery report requests approval explicitly.) The degraded
    fallback in §4.5.2 exists only for genuinely small repos.
T4. Flaky tests are quarantined in a COMMITTED quarantine.txt with a
    linked issue — never deleted, never retried-until-green inside
    the covenant. /review prints the quarantine count and the modules it
    covers on every run ("QUARANTINED: 3 tests covering money.py,
    auth.py"). A quarantined test covering a CORE_FILES module is a
    HARD STOP, not a deferral — that is the one test that would catch
    a core regression.
T5. grep-based import scanning is semantically blind to re-exports
    (from .util import *), dynamic imports (importlib), DI/fixture
    injection (the dependency arrives via conftest, not an import),
    and string-referenced plugins. It is a LOWER BOUND on impact,
    never the full set. When a changed file is consumed through any
    of these mechanisms, tier 2 is insufficient -> escalate to tier 3.
T6. TIER-TRANSITION ENFORCEMENT: the covenant script records full-suite
    wall time in covenant_state.json on every tier-3 run. When it exceeds
    the threshold (default 60s) twice consecutively, the script emits
    TIER TRANSITION REQUIRED and refuses to default to full-suite
    locally. The trigger lives in the ledger, not in anyone's memory —
    a suite that crosses the line in month 4 is caught in month 4.
T7. IMPORT-GRAPH FRESHNESS: covenant.sh must dynamically rebuild the import
    graph whenever an import statement or a CORE_FILES entry appears in
    the change set, or via a scheduled CI pipeline run — a graph built
    once at init decays as the repo grows. The degraded tier-2 path is a
    short-lived bridge to real tooling, never a permanent state.
```

---

# SECTION 7 — SESSION & CONTEXT MANAGEMENT

## 7.1 What Fills the Window

```
Fixed overhead:        CLAUDE.md (~1.5–3k) + system config        ~2–4k tokens
Active task content:   contract + 3–5 files + test output         ~6–20k
History (danger zone): grows ~3–8k per task iteration
After 15 iterations:                                              ~53–144k
```

Near the limit, quality degrades non-linearly. Older content gets less attention —
Claude becomes less accurate about decisions made early in the session.

### 7.1.1 Cost-Warning Firing

COST-WARNING FIRING: The agent must track active context limits via token
approximations based on round-trip turns. If a single task iteration or
pipeline phase consumes more than 40,000 context tokens, or if history
retransmission waste crosses a 50% threshold, the agent must output a
high-visibility cost warning alert to the terminal: "WARNING: Context
pressure exceeding efficiency thresholds (~[Count] tokens used). /compact
or restart recommended to prevent token inflation."

## 7.2 Compact vs. Restart Decision Tree

```
AFTER EVERY COMPLETED TASK:
  >3 major iterations this session?          -> /compact
  >10 distinct files read?                   -> /compact
  Next task unrelated to current work?       -> FULL RESTART
  All no                                     -> continue

/compact:      same task, mid-implementation, 40–60% context used
FULL RESTART:  different feature/domain, >70% used, degraded output
               despite compact, 2+ hour session, post-merge on fresh main
```

**The checkpoint system (§4.1) supersedes the old manual summary ritual.** Before
any compact or restart: ensure a checkpoint is current (write one if not). After
restart: the resume protocol (§4.1.5) re-anchors automatically — CLAUDE.md reloads
free, LATEST.md restores task state for ~200 tokens.

What full restart clears that /compact does not: terminal buffers, tool trace
objects, file-read caches, confusion from contradictory early instructions.

## 7.3 Context Budget Per Task Tier

| Tier | Description | Expected Context | Session Guidance |
|---|---|---|---|
| Micro | Single function fix, rename, doc | <5k | Several per session |
| Small | One endpoint / one method + tests | 5–15k | One per session ideal |
| Medium | Full feature across layers | 15–40k | One per session; /compact if needed |
| Large | Multi-entity feature, service refactor | 40–80k | Split across 2 sessions by layer |
| XL | Cross-service / architectural change | 80k+ | Decompose; one session per sub-task |

## 7.4 XL Decomposition Pattern

Decompose by layer; each sub-task gets its own session, its own checkpoint, and
its own atomic commit. Git history connects sessions; CLAUDE.md governs all:

```
Session 1 — Domain:    "Implement X value objects. Domain tests pass."
Session 2 — Infra:     "Implement X repository. Integration tests pass."
Session 3 — App:       "Update use cases. Application tests pass."
Session 4 — API:       "Update handlers/middleware. Handler tests pass."
Session 5 — E2E:       "Full suite (CI). Zero regressions."
```

## 7.5 Rate-Limit Recovery

```
On HTTP 429 from any tool:
  1. DO NOT retry in a loop.
  2. Write a checkpoint (§4.1) — this replaces the ad-hoc
     "RATE_LIMIT_CHECKPOINT" printout.
  3. git stash OR wip commit.
  4. Stop. Await human instruction.
```

---

# SECTION 8 — WORKTREE ISOLATION (parallel agentic sessions)

Concurrent agentic test loops sharing local resources contaminate each other's
state. The failures look like flaky tests; they are cross-session pollution.

**Banned in parallel worktrees:** shared local DB port, shared cache instance
(e.g. Redis db 0 on 6379 for everyone), shared queues, shared app ports, shared
test schemas, shared third-party sandbox keys or mock tenants.

**Mandatory: each worktree carries `.env.worktree` (gitignored):**

```
# ../project-auth/.env.worktree      (Engineer A)
APP_PORT=8081
TEST_DB_SCHEMA=test_auth_engineera
CACHE_DB=1
QUEUE_NAMESPACE=wt_auth
STRIPE_TEST_KEY=sk_test_wt_auth_xxx

# ../project-payment/.env.worktree   (Engineer B)
APP_PORT=8082
TEST_DB_SCHEMA=test_payment_priya
CACHE_DB=2
QUEUE_NAMESPACE=wt_payment
STRIPE_TEST_KEY=sk_test_wt_payment_xxx
```

Port standard: 8080 = main, never for parallel work; worktree slots 8081/8082/8083.
Per-worktree DB schema created before the loop, dropped after merge. Sandbox keys
are distinct per worktree and treated as production secrets — never committed,
sourced from .env.worktree only.

A human adds the following to CLAUDE.md via PR (agents cannot edit the
constitution — §2.2.4):

```
## WORKTREE ENVIRONMENT
If .env.worktree exists in project root: source it before every test
run. Never assume default ports or schema names. Always use
${APP_PORT}, ${TEST_DB_SCHEMA}, ${*_TEST_KEY} from .env.worktree.
```

Coordination rules: no two engineers own the same module in the same sprint; the
execution-contract scope list is the unit of coordination — share scopes before
starting. Note: `.claude/covenant_state.json` and `.claude/checkpoints/` are naturally
per-worktree (each worktree has its own working directory) — no extra isolation
needed for the stateful layer.

---

# SECTION 9 — PERFORMANCE RUBRIC

| Signal | Beginner | Intermediate | Expert |
|---|---|---|---|
| Prompt structure | "add auth to the api" | Objective + constraints | Full execution contract with verify step |
| Context per task | Fills window | /compact sometimes | Surgical — <30% of window per tier |
| Session hygiene | One long session | /compact after big tasks | Restart between features; checkpoint before every reset |
| Files read | Whatever seems relevant | Targeted, some over-reading | grep first, surgical Read offset+limit |
| Stubs-first | Sequential files, mid-run import errors | Import check per file | All stubs compiled clean before any implementation |
| Self-correction | Accepts first output | Pushes back sometimes | 3-strike rule; root cause before first fix |
| Layer compliance | Code lands anywhere | Mostly correct | Zero violations on touched files |
| Test discipline | After the feature, maybe | With the feature | Declared in design phase; tiered selection (§6) |
| Commit quality | "fix stuff", batched | Format ok, some batching | Atomic, bisectable, why-explaining, one layer per commit |
| Covenant awareness | Re-runs everything always | Skips manually (risky) | Ledger receipts; loud skips; baseline ratchet trusted |
| State management | Loses work on restart | Manual summaries | Checkpoint at phase boundaries; instant resume |
| Worktree isolation | Single dir for all work | Worktrees, shared DB/port | .env.worktree, isolated everything |

---

# SECTION 0 — GETTING STARTED

## What Is This?

Claude Code is an autonomous execution engine for software development. Unlike conversational AI assistants, it operates under a strict contract system: you specify *what must be true when done* (the objective), not *what steps to take*. The engine then reads your codebase, designs the implementation, applies changes, runs tests, and delivers results — all in one self-correcting loop.

This framework sits on top of Claude Code and standardises that execution. It provides:

- A **constitution** (CLAUDE.md) that codifies your architecture, naming contracts, and security rules once — then enforces them automatically on every task
- A **stateful covenant system** that tracks quality ratchets and prevents regressions
- A **skill command pipeline** (/feature, /audit, /review, /prep) that automate the entire development workflow
- A **worktree isolation layer** so multiple engineers can run parallel agentic sessions without stepping on each other

**Expected reading time for this section: 8 minutes.**  
**Setup time: 5 minutes.**  
**Your first feature: 10 minutes (including git push confirmation).**

---

## Installation at a Glance

```bash
# 1. Clone/enter your repository
cd your-repository

# 2. Run the init script (copies .claude/ and .githooks/ into place)
curl -s https://your-company/installer/claude-code-init.sh | bash

# 3. Verify the installation
git config core.hooksPath .githooks
ls -la .claude/settings.json .claude/commands/ CLAUDE.md

# 4. Activate hooks in this clone
cc-init-hooks  # alias for: git config core.hooksPath .githooks
```

**What got installed:**

| Directory | Purpose | Committed? |
|---|---|---|
| `.claude/settings.json` | Permission boundaries (what tools require confirmation) | ✓ Yes |
| `.claude/baseline.json` (brownfield only) | Frozen debt identities — the ratchet (see §4.3) | ✓ Yes |
| `.claude/covenant_state.json` | Covenant receipt ledger — tracks each commit's quality score | ✗ .gitignored |
| `.claude/checkpoints/` | Session snapshots (memory, context usage) | ✗ .gitignored |
| `.claude/commands/` | Skill command modules (/feature, /audit, /review, /prep) | ✓ Yes |
| `.githooks/pre-commit` | THE COVENANT — runs /audit and /review on every commit | ✓ Yes |
| `.githooks/pre-push` | Push covenant — validates receipt, enforces bypass deadline | ✓ Yes |
| `CLAUDE.md` | Constitution — architecture + naming + security rules | ✓ Yes |
| `quarantine.txt` | Flaky test quarantine (team-wide) | ✓ Yes |

Add to `.gitignore`:
```
.claude/covenant_state.json
.claude/checkpoints/
```

---

## Glossary: 20 Key Terms

<details>
<summary><strong>Click to expand — 20 definitions you'll see everywhere</strong></summary>

1. **Covenant** — Automated enforcement rule that runs on `git commit` and `git push`. Prevents regression, security violations, and architectural drift before code ever leaves your machine.

2. **Ledger** — The `.claude/covenant_state.json` file tracking every commit's quality score. If a commit fails /audit with a HIGH severity finding, the ledger records it; that receipt is validated before push.

3. **Fingerprint** — A hash of a file's content at a specific git commit. Used by the baseline ratchet to detect when a file was touched (and thus subject to full constitution enforcement).

4. **Token** — A unit of input to the LLM. 1,000 tokens ≈ 750 words. Used to calculate budget and context overhead. See §7 for token accounting.

5. **Token Budget** — The context window reserved for a single agentic task. Greenfield: 80k. Brownfield: 60k. Determines how many files can be read before context is exhausted.

6. **Hard Block** — A rule in CLAUDE.md (Section 6) that always requires explicit human approval before Claude Code proceeds. Examples: new runtime dependency, auth/authz change, schema migration.

7. **Graph** — The dependency graph of your codebase. `/audit` uses this to determine scope spillover when a file you edited is imported elsewhere (§3.2).

8. **MCP** — Model Context Protocol. The standardized interface Claude Code uses to invoke tools (read, edit, execute bash, git, etc.) safely.

9. **Blast Radius** — The set of all files affected by a change, including transitive imports. If you edit `auth.py` and 8 other files import it, the blast radius is 9 files.

10. **SECTION 2.5** — Cognitive Routing, Graph Memory, Gitflow Enforcement. A new set of rules that fire on every task automatically. Devs must read this BEFORE invoking /feature.

11. **Execution Mode Menu** — After `/feature` starts, you choose: "Stubs First" (skeleton then fill), "Guided" (one file at a time), or "Full Auto" (read-edit-test no pause). Different modes for different confidence levels.

12. **Cognitive Routing** — The framework's ability to detect when a task spans multiple concerns (e.g., "add auth" touches models, services, routes, tests) and auto-partition the work into layers.

13. **Gitflow** — The branch naming convention enforced by pre-commit hook. Must match: `feature/*`, `fix/*`, `docs/*`, `refactor/*`, `test/*`, or `chore/*`. Commits to `main` or `develop` are blocked unless in a PR.

14. **Branch Prefix** — The leading keyword in your branch name. Examples: `feature/add-dashboard`, `fix/rate-limiter-off-by-one`, `docs/update-readme`. Automation uses this to infer commit type.

15. **Cold Start** — First run of the framework in a new worktree. All memory is blank. The framework auto-generates a checkpoint after the first successful task (see §8).

16. **SKIP_COVENANT** — Emergency environment variable (`SKIP_COVENANT=1 git commit`) that bypasses pre-commit hook. Allowed exactly ONCE per worktree; subsequent uses are blocked unless a human approves and resets the counter. Used only in emergencies.

17. **Bypass** — Temporary suspension of a covenant rule (e.g., "merge a hotfix with 1 test passing instead of 100"). Logged in the receipt; auto-expires after 24 hours; requires human approval on review.

18. **Ref Notes** — Git annotations stored in `.git/refs/notes/` that log covenant receipts. Not visible in commit history; queryable with `git log --notes`.

19. **Pre-commit** — Hook that fires when you run `git commit`. Runs /audit and /review. If either fails with CRITICAL/HIGH, commit is blocked.

20. **Pre-push** — Hook that fires when you run `git push`. Validates that you didn't skip the pre-commit covenant, and enforces the SKIP_COVENANT bypass deadline (24 hours).

</details>

---

## Day 1 Checklist — Post-Installation

After running the init script, verify these three things before starting your first feature:

```bash
# 1. Hooks are wired
git config core.hooksPath
# Output should be: .githooks

# 2. Constitution is readable
cat CLAUDE.md | head -50
# You should see the architecture, naming contracts, and hard stops

# 3. Settings are permissive enough for your workflow
cat .claude/settings.json | grep -A 20 '"allow"'
# You should see your test runner, linter, and git commands
# If anything is missing, add it via /update-config skill
```

Then, **create your first branch and make a trivial change:**

```bash
git checkout -b feature/day-1-test
echo "# Day 1" >> README.md
git add README.md
git commit -m "feat: day 1 verification"
```

Expected outcome:
- Commit succeeds (pre-commit hook runs, audit passes with no CRITICAL findings)
- `git log --oneline` shows your new commit
- `.claude/covenant_state.json` now contains a receipt for this commit

**If the commit fails:** Read the audit output carefully. Usually a missing permission in settings or a stray hard-stop violation.

---

## First Feature Walkthrough — Complete Example

Let's walk through the entire lifecycle of a small feature: "Add email validation to signup endpoint."

### Phase 1: Understand the Scope

```bash
# You're in a greenfield FastAPI project
# Current branch: develop
# Task: Add email validation to signup endpoint

git checkout -b feature/email-validation
```

### Phase 2: Write the Execution Contract

Before invoking `/feature`, think:

- **SCOPE:** Which files will I touch? (`src/application/user_service.py`, `src/presentation/handlers/auth.py`, `tests/application/test_user_service.py`, `tests/presentation/test_auth.py`)
- **OBJECTIVE:** What must be true when done? ("Signup endpoint rejects requests with invalid emails. Invalid email detection uses regex; valid emails pass. All existing tests pass.")
- **CONSTRAINTS:** What rules apply? ("No external email validation APIs. No new dependencies.")
- **VERIFY:** What command proves success? (`pytest tests/application/test_user_service.py tests/presentation/test_auth.py -v`)

### Phase 3: Invoke /feature

```bash
/feature

# Prompt text:
#
# Scope:   src/application/, src/presentation/handlers/auth.py, tests/
# Objective: Email validation on signup endpoint. Rejects invalid addresses.
#            Uses regex (no external APIs). All tests pass.
# Constraints:
#   - No new dependencies
#   - Layer boundaries respected (validation in service, not handler)
#   - Existing tests unmodified
# Verify: pytest tests/application/ tests/presentation/ -v
# Output: File summary, full test output, Conventional Commit message
```

### Phase 4: Execution Mode Menu

The framework asks:

```
Which execution mode?

  [1] Stubs First      Read architecture, create empty functions, ask before filling
  [2] Guided           One file at a time, show diffs before edits
  [3] Full Auto        Read, design, edit, test, fix — no pauses

Your choice (1-3, default 2):
```

**Choose based on your confidence:**
- **Stubs First** — You're new to the codebase or want to review the design first
- **Guided** — Standard; you see each change before it lands
- **Full Auto** — You know exactly what needs to happen; trust the engine

(Let's choose Guided for this walkthrough.)

### Phase 5: Implementation

The framework:
1. **Reads** your constitution, models, existing service and handler code
2. **Designs** the validation function and integration point
3. **Asks (if Guided):** "I'm adding `validate_email()` to `UserService`. Review?" — shows the diff
4. **You reply:** "yes" → it commits the edit
5. **Tests:** Runs `pytest tests/application/` → test fails (no test yet)
6. **Fixes:** Creates test case, re-runs → test passes
7. **Integrates:** Edits handler to call `UserService.validate_email()`, runs integration test
8. **Verifies:** Full suite passes

### Phase 6: Output

```
=== FEATURE COMPLETE ===

Files Modified:
  src/application/user_service.py       | +12 lines (validation function)
  src/presentation/handlers/auth.py     | +2 lines (call validation)
  tests/application/test_user_service.py | +8 lines (unit test)
  tests/presentation/test_auth.py        | +6 lines (integration test)

Test Output (full pytest -v):
  test_user_service.py::test_valid_email PASSED
  test_user_service.py::test_invalid_email PASSED
  test_auth.py::test_signup_rejects_invalid_email PASSED
  [all 87 tests in suite] PASSED

Conventional Commit:
  feat(auth): add email validation to signup endpoint
  
  Validates email format on signup. Rejects invalid addresses.
  Uses regex pattern; no external APIs. All tests passing.
```

### Phase 7: Git Commit & Push

```bash
# Framework shows the commit message and asks
# "Ready to commit?" → you reply "yes"

git commit -m "feat(auth): add email validation to signup endpoint

Validates email format on signup. Rejects invalid addresses.
Uses regex pattern; no external APIs. All tests passing."

# Pre-commit hook fires automatically:
#   ✓ /audit (no CRITICAL/HIGH findings)
#   ✓ /review (architecture clean, test coverage adequate)
# Commit succeeds.

# Now you push:
git push -u origin feature/email-validation

# Pre-push hook fires:
#   ✓ Receipt validated (commit passed both covenants)
#   ✓ No SKIP_COVENANT bypasses pending
# Push succeeds.

# You open a PR; the CI covenant runs one final time.
```

---

## Command Quick Reference

| Command | What It Does | When to Use |
|---|---|---|
| `/feature` | Full implementation pipeline (read → design → edit → test → commit) | Whenever you start a new feature or fix |
| `/audit` | Security + architecture audit on changed files only | Run manually to check your work before commit |
| `/review` | Pre-PR covenant: test coverage, naming, layer boundaries | Run manually to prepare for merge |
| `/prep` | Convert natural language task into execution contract | When you want help structuring a vague task |
| `git commit` | Commit with auto-covenants (pre-commit hook) | Always use; never skip with --no-verify |
| `git push` | Push to remote with auto-covenants (pre-push hook) | Always use; never skip |
| `cc-init-hooks` | Activate the hooks in this clone | Run once after installing |
| `cc-audit` | Alias for `/audit` | Same as /audit |
| `cc-review` | Alias for `/review` | Same as /review |
| `/loop <interval> <command>` | Run a command repeatedly (e.g. `/loop 5m /audit`) | For continuous integration tasks |
| `/update-config` | Edit settings.json and .claude/ config | When you need to adjust permissions or add environment variables |

---

## Reading Path — Where to Go Next

You are here: **SECTION 0 (Getting Started)** ← you just finished this.

**Next:**

1. **SECTION 1** (The Paradigm Shift) — 10 min read
   - Understand the execution contract model
   - See why it's faster and better than conversational chat

2. **SECTION 2** (Enterprise Configuration) — 15 min read
   - Deep dive into CLAUDE.md (your constitution)
   - Understand settings.json and permission boundaries

3. **SECTION 2.5** (Cognitive Routing, Graph Memory, Gitflow Enforcement) — **READ BEFORE /feature**
   - These rules fire on every task automatically
   - You must know them before invoking any skill command

4. **SECTION 3** (The Agentic Pipeline) — 15 min read
   - How /feature actually works internally
   - Why tests run before commit
   - How the engine self-corrects

5. **SECTION 4** (The Stateful Layer) — 10 min read
   - How checkpoints and covenant receipts work
   - The baseline ratchet (brownfield only)

6. **Then:** Pick your workflow:
   - **Just want to ship code?** → Jump to SECTION 10 (Quick Reference)
   - **Building a new team?** → Read SECTION A (30-day Onboarding Path)
   - **Managing legacy debt?** → SECTION 4.3 (Baseline Ratchet — brownfield only)
   - **Optimizing for large test suites?** → SECTION 6 (Testing at Scale)

---

## First-Time Troubleshooting

| Problem | Solution |
|---|---|
| "git commit" blocks with audit error | Read the CLAUDE.md section cited in the error. Usually: wrong layer, missing test, or hard-stop violation. |
| Permission prompt on every /feature invocation | Your tool is not in the allow list. Run `/update-config` and add it. |
| Tests fail after /feature completes | This is expected sometimes. The framework reports it, shows output, and asks permission to iterate. Reply "yes" to fix. |
| I want to skip the covenant (emergency hotfix) | Use `SKIP_COVENANT=1 git commit`. Allowed once. Reset with `git config core.hooksPath ""` (then re-init with cc-init-hooks). 24-hour bypass window. |
| My branch name doesn't match `feature/*` | Pre-commit hook enforces gitflow. Rename: `git branch -m feature/my-fix`. |
| I deleted something by accident in /feature | Worktrees isolate changes. If the main worktree is clean, you can restart in a new worktree. See §8. |

---



---

# SECTION 10 — QUICK REFERENCE FIELD CARD

```
+--------------------------------------+--------------------------------------+
| SESSION START                        | EXECUTION CONTRACT                   |
|  [] Feature branch, clean status     |  Scope / Objective / Constraints     |
|  [] checkpoints/LATEST.md? -> resume |  Verify / Output                     |
|  [] Test suite collects              |                                      |
+--------------------------------------+--------------------------------------+
| SCANNING ORDER                       | WRITE ORDER                          |
|  1. grep/find        (~30 tok)       |  Domain -> Infra -> App ->           |
|  2. Read(offset,limit)(~250)         |  Presentation -> Tests               |
|  3. Full read        (~2000, rare)   |  (or repo's real layer order)        |
+--------------------------------------+--------------------------------------+
| STUBS-FIRST (3+ files)               | SELF-CORRECTION                      |
|  ALL stubs -> compile ALL -> impl    |  Full traceback, root cause 1 line   |
|                                      |  Min fix. 3 strikes -> STOP          |
+--------------------------------------+--------------------------------------+
| STATEFUL LAYER                       | TEST TIERS                           |
|  Checkpoint: phase end if C1-C5      |  1: mapped module tests (per file)   |
|  Ledger: skip on identical           |  2: impacted; CORE_FILES -> closure  |
|  fingerprint (incl. untracked!)      |  3: full suite (CI / pre-PR / CORE)  |
|  Baseline: NEW identity blocks,      |  grep = lower bound, never a tier    |
|  grandfathered never; only shrinks   |  quarantine.txt committed + loud     |
+--------------------------------------+--------------------------------------+
| SESSION HYGIENE                      | HARD STOPS                           |
|  /compact: same task, 40-60% full    |  New dep / lockfile | schema change  |
|  Restart: new feature, >70%, 2h+     |  auth | env var | infra | CI/CD      |
|  Checkpoint BEFORE either            |  .gitignore | baseline | CORE_FILES  |
|                                      |  settings/permission-mode change     |
+--------------------------------------+--------------------------------------+
| COVENANT (hook-enforced, §4.5)           | KILL SWITCH                          |
|  pre-commit: fingerprint -> scoped   |  SKIP_COVENANT=1: settings deny is the   |
|  covenant -> receipt. pre-push: receipt  |  hard layer; TTY adds human-         |
|  + force guard + bypass deadline.    |  presence assurance. Bypass = git    |
|  Model orchestrates; hooks enforce.  |  note on commit. Re-run 24h          |
|  ASK in chat before every push.      |  (committer date) or push blocks.    |
+--------------------------------------+--------------------------------------+
| QUALITY AXIOM: output ceiling = prompt floor                                |
+-----------------------------------------------------------------------------+
```

---

# SECTION A — ONBOARDING PATH (30 days)

| Timeframe | Action | Success Signal |
|---|---|---|
| Day 1 AM | Install CLI: `npm install -g @anthropic-ai/claude-code` | `claude --version` works |
| Day 1 PM | Read this guide end-to-end, no action | You can explain ledger + baseline + checkpoint in 3 sentences |
| Day 2 | Run the Implementation Package init on your repo; review the discovery report CAREFULLY before confirming | Constitution matches your repo's real architecture; baseline.json committed |
| Day 3–4 | First task via /feature on a small ticket; /review before PR | Diff shows only in-scope files; covenant report shows tiered tests |
| Week 1 | 3 features via execution contracts; watch the covenant skip on unchanged code | Zero NEW findings vs baseline; you trust the loud skips |
| Week 2 | Stubs-first on a multi-file task; practice checkpoint-resume (kill a session mid-task deliberately, resume) | Resume takes <1 min, nothing re-derived |
| Week 3 | Parallel worktrees with .env.worktree; mentor a colleague | No cross-session contamination; colleague's first clean /review |
| Month 1 | Propose a CLAUDE.md improvement via human PR; measure your baseline delta | Baseline ratcheted down; 40–60% completion-time reduction |

---

*This document is a living standard. The methodology is durable: scope clearly,
execute contractually, stub-first multi-file work, self-correct with discipline,
checkpoint state, fingerprint covenants, ratchet debt downward, isolate concurrent
agents, verify in tiers, and commit atomically. Engineers who master this do not
just use AI faster — they operate at a quality ceiling manual development cannot
match at any speed.*

---

## APPENDIX B — CANONICAL .team_aliases (written verbatim by init step C8)

```bash
#!/usr/bin/env bash
# Claude Code team aliases — generated by the init package, edited only via PR.
# Source in ~/.zshrc:  echo "source $(pwd)/.team_aliases" >> ~/.zshrc

# One-time activation per clone: hooks + bypass-note propagation.
# (git does not push refs/notes/* by default — without the refspecs the
#  bypass audit trail never leaves this machine.)
cc-init-hooks() {
    git config core.hooksPath .githooks
    git config --add remote.origin.push  'refs/notes/bypasses:refs/notes/bypasses'
    git config --add remote.origin.fetch '+refs/notes/bypasses:refs/notes/bypasses'
    echo "Hooks active: .githooks (bypass-note refspecs configured)"
}

# Branch-guarded feature entry point — the standard way to start any task.
cc-feature() {
    [ -z "$1" ] && echo "Usage: cc-feature <description>" && return 1
    local branch=$(git branch --show-current)
    case "$branch" in
        main|master|develop)
            echo "ERROR: on protected branch '$branch'. Create a feature branch first."
            return 1;;
    esac
    claude "/feature $*"
}

# Scoped audit of current changes (full repo only if no changes).
cc-audit() {
    local changed=$(git diff main...HEAD --name-only | tr '\n' ' ')
    [ -z "$changed" ] && claude "/audit" || claude "/audit Scope: $changed"
}

cc-review() { claude "/review"; }

# Impact radius for a symbol before touching it.
# <source-dirs> is substituted at init with the repo's confirmed
# source and test directories (e.g. "app/ tests/" or "src/ spec/").
cc-scope() {
    [ -z "$1" ] && echo "Usage: cc-scope <symbol>" && return 1
    echo "=== Impact radius for '$1' (grep lower bound — see Guide §6 T5) ==="
    grep -rn "$1" <source-dirs> 2>/dev/null | head -30
}

# cc-checkpoint — the STANDARD manual checkpoint command. Run it on demand to
# write the Guide §4.1.4 state schema straight to .claude/checkpoints/ (state,
# not conversation), refresh LATEST.md, and enforce 10-file retention. Use it
# before /compact, before a restart, or whenever a resumable snapshot is wanted.
cc-checkpoint() {
    mkdir -p .claude/checkpoints
    local ts=$(date +%Y%m%d-%H%M)
    local f=".claude/checkpoints/${ts}-manual.md"
    {
        echo "# CHECKPOINT"
        echo "phase:        manual"
        echo "git_sha:      $(git rev-parse HEAD)"
        echo "branch:       $(git branch --show-current)"
        echo "dirty_files:  $(git status --porcelain | wc -l | tr -d ' ') uncommitted"
        echo "timestamp:    ${ts}"
        echo ""
        echo "## FILES MODIFIED THIS SESSION"
        git diff --name-only HEAD
        echo ""
        echo "## RESUME INSTRUCTION"
        echo "<fill in before closing the session>"
    } > "$f"
    cp "$f" .claude/checkpoints/LATEST.md
    # Retention: keep the 10 most recent checkpoint files.
    find .claude/checkpoints -name '2*.md' -type f 2>/dev/null | sort -r | tail -n +11 | while read -r f; do rm -f "$f"; done
    echo "Checkpoint: $f"
}

# Model-independent human-in-the-loop push. The pre-push hook still runs.
# Confirmation reads /dev/tty directly: piped stdin cannot auto-confirm
# (printf 'branch\n' | cc-push fails by design).
cc-push() {
    local branch=$(git branch --show-current)
    case "$branch" in
        main|master|develop)
            echo "ERROR: direct push to '$branch' is forbidden."
            return 1;;
    esac
    # Resolve the remote the way git push would — never "first remote
    # alphabetically", which silently picks 'fork' over 'origin'.
    local remote=$(git config --get "branch.${branch}.pushRemote" \
                || git config --get remote.pushDefault \
                || echo origin)
    echo "About to push: branch '$branch' -> remote '$remote'"
    printf "Type the branch name to confirm: "
    local confirm
    read -r confirm < /dev/tty || { echo "No TTY — aborted."; return 1; }
    [ "$confirm" != "$branch" ] && echo "Aborted (input did not match)." && return 1
    git push "$remote" "$branch"
}

# Auto-loaded CLAUDE.md token cost per project.
cc-context-size() {
    find . -name "CLAUDE.md" -not -path "*/node_modules/*" | while read -r f; do
        local chars=$(wc -c < "$f")
        echo "  $f: $chars chars (~$((chars/4)) tokens auto-loaded)"
    done
}
```

Notes on the appendix:
- There is deliberately NO cc-hotfix: emergencies go through `cc-feature` on a
  `hotfix/*` branch (full covenant, tier-1 tests are fast) or, for true
  production-down moments, the human-typed `SKIP_COVENANT=1` path with its TTY
  confirmation and git-note audit trail. A separate alias invoking a command
  that may not exist is how phantom workflows are born.
- `cc-push` complements, never replaces, the pre-push hook and the Covenant Step 4
  chat confirmation — three independent layers.


---

# APPENDIX C — TROUBLESHOOTING GUIDE

## Q1: Graph Build Fails or Takes Too Long During install.sh

**Problem Statement:**
You run `install.sh` and it hangs on "Building initial code graph..." with no progress feedback. After several minutes, you assume it crashed and kill the process.

**Root Cause:**
`code-review-graph build` parses the full AST of your codebase and indexes it into an SQLite database. On large repositories (>100k LOC), this takes 2–5 minutes. Without progress output, the user has no way to know it's working.

**Resolution:**
1. Run the build manually with verbose output:
   ```bash
   code-review-graph build --verbose
   ```
2. Watch the live progress output (parsing files, building index, writing database).
3. If it genuinely crashes (actual error, not timeout), check disk space:
   ```bash
   df -h
   ```
4. If disk space is full, free up space and re-run `install.sh`.

**Prevention:**
The `install.sh` script now emits progress messages every 10 seconds during the graph build. If you don't see any output for >30 seconds, the process likely crashed — check the error above the progress line.

---

## Q2: Pre-commit Hook Timeout — "Command Exceeded 30s"

**Problem Statement:**
You run `git commit` and immediately get a message: "⚠ TIMEOUT: 'pytest' exceeded 30s — killed and logged". Your commit is blocked.

**Root Cause:**
The `covenant.sh` script has a `COMMAND_TIMEOUT` of 30 seconds (default). On a large repository, running the full test suite can easily exceed this. The timeout is global and applies to all checks.

**Resolution:**
1. First, confirm the test suite is actually slow:
   ```bash
   pytest -x --tb=short  # Run locally to measure actual time
   ```
2. If tests genuinely take >30s, the timeout is too short for your repo. Increase it:
   ```bash
   # Edit .claude/covenant_state.json
   jq '.thresholds.command_timeout_sec = 120' .claude/covenant_state.json > .tmp && mv .tmp .claude/covenant_state.json
   ```
3. Or, scope your tests to changed files only (see covenant.sh §3):
   ```bash
   # In your pytest config, add:
   # [tool:pytest]
   # addopts = --collect-only | grep <changed-file-pattern>
   ```
4. Re-run the commit:
   ```bash
   git commit -m "..."
   ```

**Prevention:**
Ensure your test framework is configured to run **only** tests affected by changed files. Use pytest `--lf` (last failed) or coverage-based test filtering.

---

## Q3: Token Budget Hard Block at 100%

**Problem Statement:**
You're mid-feature with `/feature` when the output stops and you see: "TOKEN HARD BLOCK — Org-wide daily budget exhausted. Spent: 200,000 / Budget: 200,000 tokens."

**Root Cause:**
The agentic task consumed all 200k tokens within the session. This happens when:
- Large files are read multiple times (context not reused)
- The agent iterates extensively (many failed attempts)
- Conversation is verbose without checkpoint compression

**Resolution:**
1. **Immediate:** Create a checkpoint to preserve progress:
   ```bash
   cc-checkpoint
   ```
   This writes `.claude/checkpoints/LATEST.md` with your current state, git diff, and pending decisions.

2. **Decision:** Choose one path:
   - **A) Wait for daily reset:** The budget resets at 00:00 UTC (tomorrow). Come back then and resume from checkpoint.
   - **B) Request emergency override:** Contact the platform team (or local admin) to raise the org budget temporarily:
     ```bash
     # Show them:
     cat ~/.claude/org_policy.json | grep TOKEN_BUDGET
     ```
   - **C) Partial restart with narrower scope:** Start a fresh session, re-read the checkpoint, and complete the remaining 20% of work with a smaller feature scope.

3. **Resume:** When budget resets, use the checkpoint to resume:
   ```bash
   # Claude Code will automatically load LATEST.md if it exists
   /feature
   # Paste your resume instruction from the checkpoint
   ```

**Prevention:**
- Enable `/compact` when `token_spent_today` exceeds 70% (soft warning fires)
- Write checkpoints before context limits (§7.2)
- Avoid re-reading the same files by citing them in checkpoints
- Scope features to ≤15 files per session (diminishing returns beyond that)

---

## Q4: SKIP_COVENANT TTY Rejection — "Bypass Reason Required"

**Problem Statement:**
You run `SKIP_COVENANT=1 git commit` (emergency hotfix bypass), but it rejects you: "Bypass Reason is Required. Aborting."

**Root Cause:**
The pre-commit hook enforces a **TTY guard** — bypasses must be typed interactively (not piped from a script or automation). This prevents non-interactive CI systems from silently bypassing covenants.

**Resolution:**
1. Run the commit in an interactive terminal (not in a cronjob or piped shell):
   ```bash
   # GOOD (interactive):
   ssh user@machine
   cd repo
   SKIP_COVENANT=1 git commit -m "..."
   # Terminal prompts: "Bypass reason (required): "
   # You type: "hotfix: critical production bug"
   
   # BAD (piped, non-interactive):
   echo 'SKIP_COVENANT=1 git commit -m "..."' | ssh user@machine
   # TTY guard blocks this
   ```

2. If you absolutely must bypass in CI, contact the platform team to temporarily disable the TTY guard (requires human approval):
   ```bash
   # This is never auto-allowed; requires a human PR
   ```

**Prevention:**
- Always run `git commit` in an interactive shell
- Document the bypass reason before committing (keep a record for audit)
- Use the 24-hour bypass deadline window — the ref note auto-expires after 24 hours and must be approved on the PR

---

## Q5: Execution Mode Menu Confusion — Which Option to Choose?

**Problem Statement:**
The framework asks "Which execution mode? [1] DIRECT [2] SUBAGENT [3] HYBRID — Reply 1-3". You don't know which one is right.

**Root Cause:**
The three modes have different cost/quality tradeoffs, and the right choice depends on the task complexity and your confidence level.

**Resolution:**
Use this decision tree:

```
Does the task touch CORE_FILES (fundamental modules like auth, config, DI)?
  ├─ YES, high risk: Choose [2] SUBAGENT
  │     Cost: 3–5x tokens (independent verification covenants)
  │     Quality: highest
  │     Example: "Refactor the dependency injection wiring"
  │
  └─ NO, standard feature:
       Is token budget > 60% used?
         ├─ YES: Choose [3] HYBRID
         │       Cost: 2x tokens (isolated impl + in-thread review)
         │       Quality: high
         │       Example: "Add email validation endpoint" (mid-budget)
         │
         └─ NO, fresh budget: Choose [1] DIRECT
               Cost: 1x tokens (single context, self-reviewed)
               Quality: standard
               Example: "Add logging to error handler" (simple, budget available)
```

**Prevention:**
- Check CORE_FILES before invoking /feature:
  ```bash
  grep -E '^CORE_FILES' CLAUDE.md
  ```
- Monitor token spend before starting large features:
  ```bash
  jq '.token.token_spent_today' .claude/covenant_state.json
  ```

---

## Q6: Pre-push Block — "Cannot Push to main/master"

**Problem Statement:**
You run `git push` and immediately see: "PRE-PUSH BLOCK: Direct push to protected branch 'main' is forbidden. Open a PR."

**Root Cause:**
The pre-push hook enforces that all code changes go through code review (PR), never direct pushes. Protected branches are: `main`, `master`, `develop`, `production`, `release/*`.

**Resolution:**
1. If you're on a feature branch (correct), the block shouldn't happen. Check your current branch:
   ```bash
   git branch --show-current
   ```

2. If you're on a protected branch, create a feature branch:
   ```bash
   git checkout -b feature/my-feature
   git cherry-pick <commits>  # OR git rebase develop
   git push origin feature/my-feature
   ```

3. Open a PR from `feature/my-feature` → `develop` (never to `main` directly).

4. Once the PR is approved and merged, the code lands on `develop` via the GitHub UI (not your direct push).

**Prevention:**
- Always start work on a feature branch: `git checkout -b feature/...`
- Configure git to prevent accidental pushes to protected branches:
  ```bash
  git config push.default upstream  # Never pushes to unintended branch
  ```

---

## Q7: Coverage Threshold Failed — "Test Coverage Below 80%"

**Problem Statement:**
You run `/feature` and it fails with: "COVENANT BLOCK: tests/coverage failed. Coverage: 72%, threshold: 80%."

**Root Cause:**
New code you added is not covered by tests, or existing test files have been modified and their coverage dropped.

**Resolution:**
1. **Identify what's not covered:**
   ```bash
   pytest --cov=src --cov-report=html
   # Open htmlcov/index.html in a browser — shows red lines (uncovered code)
   ```

2. **Write tests for the uncovered lines:**
   - For each red line, ask: "What user action causes this code to execute?"
   - Write a test that exercises that action
   - Re-run: `pytest --cov=src`

3. **Re-invoke /feature:**
   ```bash
   /feature
   # Supply the same task description; it will re-run with full test coverage
   ```

**Prevention:**
- Use `pytest --cov-report=term-missing` to see uncovered lines immediately
- Write tests alongside code (not after) — coverage is easier to achieve in parallel
- For complex branching (if/else), use `pytest-cov` branches mode: `--cov-branch`

---

## Q8: Complexity Check Failed — "Cyclomatic Complexity > 10"

**Problem Statement:**
Covenant.sh reports: "COVENANT BLOCK: complexity exceeds threshold (cc > 10). Function my_function() has cc=14."

**Root Cause:**
Your function has nested conditionals, loops, or switch cases that make it hard to understand and test. Cyclomatic complexity (cc) measures the number of independent code paths.

**Resolution:**
1. **Identify the offending function:**
   ```bash
   radon cc -n C src/  # Lists all functions with cc > threshold
   ```

2. **Refactor to reduce complexity:**

   **Pattern 1: Extract conditional blocks into helper functions**
   ```python
   # BEFORE (cc=12):
   def process_order(order):
       if order.type == 'digital':
           if order.region == 'EU':
               # 20 lines of logic
           else:
               # 20 lines of logic
       else:
           if order.region == 'EU':
               # 20 lines of logic
           else:
               # 20 lines of logic
   
   # AFTER (cc=2 each):
   def process_order(order):
       if order.type == 'digital':
           return handle_digital_order(order)
       return handle_physical_order(order)
   ```

   **Pattern 2: Replace nested if with guard clauses**
   ```python
   # BEFORE (cc=8):
   def validate(user):
       if user.age >= 18:
           if user.email:
               if user.country != 'US':
                   return True
       return False
   
   # AFTER (cc=4):
   def validate(user):
       if user.age < 18: return False
       if not user.email: return False
       if user.country == 'US': return False
       return True
   ```

3. **Re-run covenant:**
   ```bash
   git commit -m "refactor: reduce cyclomatic complexity in process_order()"
   ```

**Prevention:**
- Keep functions small (≤20 lines)
- Use simple, flat control flow (early returns, no deep nesting)
- Test each path separately — if you need >10 test cases, the function is too complex

---

## Q9: Layer Violation — "Presentation Layer Called Repository Directly"

**Problem Statement:**
Covenant.sh reports: "COVENANT BLOCK: Layer violation in routes/auth.py. Routes must call services, not repositories."

**Root Cause:**
You called a repository function directly from a route handler, bypassing the application layer. This violates clean architecture.

**Resolution:**
1. **Understand the layer stack (from bottom to top):**
   ```
   Domain (models.py)       ← Pydantic data contracts, zero framework deps
                   ↑
   Infrastructure          ← Repositories (SQL), tool execution
   (repositories/)
                   ↑
   Application             ← Business logic, orchestration, cache
   (services/)
                   ↑
   Presentation            ← HTTP routes, request parsing, auth
   (routes/)
   ```

2. **Fix the violation:**
   - Move repository calls into the service layer
   - Have the route call the service, which calls the repository

   ```python
   # BEFORE (wrong):
   @app.get("/users/{user_id}")
   async def get_user(user_id: int):
       user = await kpi_repository.fetch_user(user_id)  # ✗ Repository called from route
       return user
   
   # AFTER (correct):
   @app.get("/users/{user_id}")
   async def get_user(user_id: int):
       user = await user_service.get_user(user_id)  # ✓ Service called from route
       return user
   
   # In services/user_service.py:
   async def get_user(user_id: int):
       return await user_repository.fetch_user(user_id)  # ✓ Repository called from service
   ```

3. **Re-commit:**
   ```bash
   git commit -m "fix(arch): move repository call from routes to services layer"
   ```

**Prevention:**
- Before writing code, identify which layer each function belongs in
- Import only from the layer below: routes → services, services → repositories
- CLAUDE.md §1 specifies these boundaries — read them before coding

---

## Q10: Session Spend.tmp Not Found — Is It Critical?

**Problem Statement:**
You see a debug message: "Warning: session_spend.tmp not found. Continuing with zero accumulation."

**Root Cause:**
The file `.claude/session_spend.tmp` is used to track token spend during a session, but it doesn't exist. This happens if:
- It's the first task in the repo
- It was manually deleted
- A previous session crashed before writing it

**Solution:**
This is **not critical**. The covenant.sh script defaults to zero accumulation and continues normally. The next task will create the file.

**Is it safe to delete?**
Yes. `.claude/session_spend.tmp` is:
- Transient (per-session only)
- In `.gitignore` (never committed)
- Regenerated automatically

**What you should NOT delete:**
```bash
# DO NOT DELETE:
.claude/covenant_state.json        # Contains ledger + thresholds
.claude/commands/              # Runtime skill definitions
.claude/settings.json          # Permission boundaries
.claude/baseline.json          # (brownfield only) Debt ratchet
.githooks/                     # Covenant scripts

# OK TO DELETE:
.claude/session_spend.tmp      # Transient
.claude/checkpoints/           # Old snapshots (keep LATEST.md)
.claude/git_cache.json         # Cache (rebuilds automatically)
```

**Prevention:**
Don't manually edit files in `.claude/` except for:
- `settings.json` (via `/update-config` skill)
- `covenant_state.json` (via `jq`, not by hand)

---

