# Human Developer Commit Flow

> **The short answer:** `git commit` runs a fast local bash script (covenant.sh). No AI, no network, no LLM calls. Tests are opt-in at commit time — mandatory only at push, on CI, or when you touch architecture-critical files. A normal commit with no issues clears in under 2 seconds.

---

## What happens when you type `git commit`

```
git commit -m "fix: correct null check in billing"
```

The pre-commit hook fires covenant.sh. Here is the exact sequence:

| Step | What runs | Blocks? | Typical time |
|------|-----------|---------|-------------|
| **1 — Branch check** | Rejects commits directly to `main`, `master`, `develop`. Warns (not blocks) if branch name doesn't follow `feature/*`, `bugfix/*`, `hotfix/*`, `release/*`. | Yes on protected branches | < 0.1 s |
| **2 — Token harness** | Reads `~/.claude/org_policy.json` + `.claude/covenant_state.json`. Date-rolls the daily counter if it's a new day. See [Token budget behavior](#token-budget-behavior). | Only if an active Claude session hit 100% budget | < 0.3 s |
| **3 — Graph staleness** | Checks when `code-review-graph build` was last run. If >7 days ago, prints a one-line note — once per day, not per commit. | Never | < 0.1 s |
| **4 — Scan scope** | First commit in a session: full scan of staged files. Subsequent commits: incremental diff from `last_pass_sha`. Logs `scope=cold` or `scope=incremental`. | Never | < 0.1 s |
| **4.3 — CORE_FILES check** | Checks if any staged file matches a glob in `covenant_state.json core_files[]`. If yes → TIER-3 escalation (see [TIER-3](#tier-3-core-files-escalation)). | No (escalation only) | < 0.2 s |
| **4.5 — Fingerprint** | Computes `git write-tree` hash of the staged index. Writes a receipt on pass so pre-push can skip re-running checks on the same tree. | Never | < 0.1 s |
| **5 — Secrets scan** | Fast grep on staged file content for patterns like `api_key`, `BEGIN RSA PRIVATE KEY`, `aws_access_key_id`. Scoped to changed files only. | Yes on match | < 0.5 s |
| **5.5 — Tool injection** | Infers `LINT_CMD`, `TYPE_CMD`, `TEST_CMD`, etc. from repo topology (pytest.ini, package.json, go.mod). No-op if no matching files. | Never | < 0.1 s |
| **6a — Lint** | Runs the inferred lint command scoped to changed files only. New findings not in `.claude/baseline.json` block; grandfathered identities pass. | Yes on new findings | ~1–3 s |
| **6b — Type check** | Runs the inferred type checker scoped to changed files. | Yes on errors | ~1–3 s |
| **6.5 — Layer boundary** | Grep on changed files for SQL in route/controller layers, HTTP framework imports in service layers. | Yes on violation | < 0.2 s |
| **6c — Tests** | **Skipped by default at pre-commit.** See [Test opt-in](#test-opt-in). | Only if opted in or TIER-3 | varies |
| **6d — Coverage** | Only runs if tests ran. Blocks if below `thresholds.coverage_pct` (default: 80%). | Only if tests ran | — |
| **6e — Complexity** | Scoped complexity check. Blocks if above `thresholds.complexity_max` (default: 10). | Yes on violation | < 1 s |
| **7 — Frontend** | Runs `FRONTEND_LINT_CMD`, `FRONTEND_TYPE_CMD` if set. Tests run via the shared test queue. | Yes on failure | varies |
| **8 — Receipt + ledger** | Writes the fingerprint receipt to `.claude/covenant_receipts.json` (gitignored — never `covenant_state.json`, which is committed and would create a circular tree-hash dependency). Advances `last_pass_sha` in `covenant_state.json` and re-stages it so the update rides along in this commit. Clears `session_spend.tmp`. | Never | < 0.2 s |

A clean commit with no lint/type issues and tests skipped: **1–3 seconds end-to-end.**

---

## What you'll see in your terminal

A typical clean commit on a feature branch:

```
COVENANT: scope=incremental | backend=true | frontend=false
COVENANT: layer boundary scan clean.
COVENANT PASS: all checks clean | branch=feature/billing-fix | mode=incremental | tier3=false | token=12400/200000
[feature/billing-fix abc1234] fix: correct null check in billing
```

A first commit in a new session (cold start):

```
COVENANT: cold start — full scan
COVENANT: layer boundary scan clean.
COVENANT PASS: all checks clean | branch=feature/billing-fix | mode=cold | tier3=false | token=0/200000
```

---

## How this differs from a Claude-assisted commit

When Claude Code runs `/feature` or makes a commit on your behalf, the covenant runs identically — the same hook, the same checks. The differences are accounting ones:

| | Human commit | Claude-assisted commit |
|---|---|---|
| `session_spend.tmp` | 0 (not present or empty — covenant clears it after every pass) | Non-zero — Claude Code writes token spend here during the session |
| Token budget block at 100% | **Never blocked.** Covenant detects `SESSION_SPEND_VAL=0` and passes with a once-per-day warning. | **Blocked.** Covenant detects active session spend and stops Claude from making further commits. |
| Who types the commit message | You | Claude (following Conventional Commits format) |
| `/feature` pipeline | Does not run | Runs (RECON → CONTRACT → EXECUTE → AUDIT → REVIEW → git) |
| covenant.sh | Runs once (pre-commit hook) | Runs once (same hook) |

**Key point:** Claude's `/feature` pipeline is a Claude Code workflow that runs _before_ `git commit`. When it reaches the commit step, the same pre-commit hook fires as when you commit manually. The covenant cannot tell who typed the command — it only checks `session_spend.tmp` to know whether a Claude session is actively accumulating spend.

---

## Test opt-in

Tests are **skipped by default at pre-commit** to keep the commit loop fast. They run automatically at pre-push, on CI, and on CORE_FILES changes (TIER-3).

To run tests at commit time, either:

**Option A — commit message flag:**
```bash
git commit -m "feat: add billing endpoint [run-tests]"
```
The covenant detects `[run-tests]` in the message and enables the full test suite for this commit only.

**Option B — env variable:**
```bash
RUN_TESTS=true git commit -m "feat: add billing endpoint"
```

Neither option affects pre-push or CI behavior — tests always run there regardless.

---

## TIER-3: CORE_FILES escalation

`covenant_state.json core_files[]` lists glob patterns for architecture-critical files (e.g., `app/config.py`, `db/migrations/**`). If any staged file matches a glob:

- Tests become **mandatory at pre-commit** (same as pre-push behavior).
- The full test suite runs — no changed-file scoping.
- The covenant prints `COVENANT: TIER-3 — CORE_FILES touched ('app/config.py'). Full suite + mandatory tests.`

`core_files[]` is edited only via human-authored PR. The covenant treats it as immutable from a developer's perspective.

---

## Token budget behavior

The budget counts tokens spent by Claude Code during the current day. It does not count keystrokes, commits, or any human activity.

| Situation | What the covenant does |
|-----------|-------------------|
| Under 80% budget used | Nothing — no output |
| 80–99% budget used | Prints a one-line yellow warning **once per day** (not every commit) |
| 100% budget used, no active Claude session | Prints a one-line yellow warning **once per day**, then passes |
| 100% budget used, active Claude session (`SESSION_SPEND_VAL > 0`) | **Blocks** the Claude session from committing. Human commits are unaffected. |

If you're blocked by the token limit from an active session and need to push anyway:

```bash
SKIP_COVENANT=1 git commit -m "your message"
```

This prompts for a typed bypass reason, logs it to `refs/notes/bypasses` with a 24-hour resolution clock, and proceeds. The bypass is visible to the whole team via `git log --show-notes=bypasses`.

---

## Bypassing the covenant (SKIP_COVENANT)

`SKIP_COVENANT=1` is the human escape hatch for situations where the covenant is blocking something that genuinely needs to go through right now — a hotfix, an emergency rollback, a test-infrastructure change.

```bash
SKIP_COVENANT=1 git commit -m "hotfix: revert broken migration"
# Covenant prompts: "Bypass reason (required): "
# You type: "emergency rollback of migration 0047 — breaks prod auth"
# Covenant logs the note and exits 0.
```

**Requirements:**
- Must be run from an interactive terminal (not an IDE extension).
- A non-empty reason is required — the covenant rejects empty strings.
- The bypass note attached to HEAD travels to the remote with `git push`.
- At pre-push, the covenant checks the note's age. If >24 hours: **push is blocked** until the underlying issue is fixed or a new bypass window is opened.

`SKIP_COVENANT=1` is not a permanent override. It opens a 24-hour window. Fix the root cause within that window.

---

## What the covenant never does

- Makes LLM or API calls of any kind.
- Reads files outside the git working tree.
- Modifies your source code.
- Runs on branches named `main`, `master`, or `develop` — those branches reject direct commits, so the covenant never reaches them locally.
- Sends telemetry anywhere. All state lives in `.claude/covenant_state.json` (local, committed).
