# Contributing to Covenant

Thanks for considering it. Covenant is a governance/enforcement layer for AI-assisted
development — contributions to the enforcement logic (`CovenantMac/templates/covenant.sh`,
`CovenantWin/src/covenantwin.py`) are held to a higher bar than a typical utility, because a bug
here means governance silently fails to fire. Read this whole document before your first PR
to `templates/covenant.sh`, `install.sh`, or `CovenantWin/src/covenantwin.py` specifically — casual
contributions to docs, examples, and tests need much less ceremony.

## Before you start

- Read [`CovenantMac/docs/SECURITY_POSTURE.md`](CovenantMac/docs/SECURITY_POSTURE.md) and
  [`CovenantMac/docs/HUMAN_COMMIT_FLOW.md`](CovenantMac/docs/HUMAN_COMMIT_FLOW.md) — together they
  cover what the covenant actually checks, what it doesn't, and why it's built this way.
- Skim `templates/covenant.sh` and `CovenantWin/src/covenantwin.py` directly for the enforcement
  logic itself — both are heavily commented, especially around trust-boundary decisions.

## Dev setup

**CovenantMac (macOS/Linux):**
- `git`, `bash` 3.2+ (macOS's default `/bin/bash` is fine — this codebase is deliberately
  3.2-safe; never introduce a bash-4-only construct like `${var,,}`), `python3` (stdlib
  only, no pip dependencies required by the framework itself).
- `bats-core` for the integration suite: `brew install bats-core` (macOS) / `apt install
  bats` (Linux). Entry point: `./CovenantMac/tests/covenant/run_tests.sh`, or per-file:
  `COVENANT_SKIP_STALENESS_CHECK=1 bats CovenantMac/tests/covenant/<file>.bats` (that env var
  skips a network staleness probe you don't want firing on every local test run).

**CovenantWin (Windows):**
- PowerShell 5.1+, Git for Windows, Python 3.9+ on `PATH`.
- `pytest` for the test suite: `python -m pytest CovenantWin/tests`.

## The safe procedure for changing the enforcement engine

`templates/covenant.sh` and `CovenantWin/src/covenantwin.py` are the most sensitive files in this repo —
once installed into a target repo, they're covered by a content-hash integrity manifest, a
Claude Code deny-list/Bash-guard, and (once a team enables it) CODEOWNERS + branch
protection. A careless change here either breaks governance silently or breaks every
downstream repo's next `--upgrade`. When touching either engine:

1. Branch off `main`. Never edit the engine directly on `main`.
2. Make the change small and covered — add or extend a test for the exact behavior you're
   fixing. If you're closing a bug, pin it with a named test the way the existing code does
   (search either engine's comments for "pinned in" to see the pattern).
3. Preserve the crash-guard invariant: a new failure path must exit non-zero with a clear
   message, never fall through to a silent pass.
4. Preserve ledger-write ordering: state (`last_pass_sha`, receipts) is written only *after*
   every check has passed — never speculatively, never on entry. A mid-run failure must never
   advance the ledger.
5. Run the full suite green before opening a PR (`CovenantMac/tests/covenant/run_tests.sh` or
   `python -m pytest CovenantWin/tests`, depending which engine you touched).
6. If you add a new governance script that gets deployed into target repos, it needs to be
   added to the integrity manifest's file list in *both* the fresh-install and `--upgrade`
   code paths, and to the trust-root deny-list if agents must not touch it directly. Missing
   either leaves a real hole — this project's own history (see `git log`) is largely a series
   of exactly these gaps being found and closed.

## Pull requests

- Keep PRs scoped to one change. A bug fix doesn't need an accompanying refactor.
- Describe *why*, not just *what* — the codebase leans heavily on comments explaining
  rationale (especially around trust-boundary decisions); match that style if you're touching
  security-relevant code.
- Tests are required for any change to enforcement logic. Docs-only and example changes
  don't need them.
- Changes to `templates/`, `install.sh`, `uninstall.sh`, `v1_release/`, or their `CovenantWin`
  equivalents require review per [`.github/CODEOWNERS`](.github/CODEOWNERS) (at the repo root,
  not under `CovenantMac/` — GitHub only honors CODEOWNERS at the true repo root).

## Reporting bugs / requesting features

Open a GitHub issue. For anything security-relevant (a way to bypass the trust-root lockdown,
defeat the integrity manifest, or otherwise weaken governance undetected), see `SECURITY.md`
instead — don't file those as public issues.
