# Changelog

All notable changes to Covenant are documented here. Format loosely follows
[Keep a Changelog](https://keepachangelog.com/); versions correspond to
`FRAMEWORK_SEMVER` in each platform's installer.

## [Unreleased]

### Added — CovenantWin governance-generation parity
CovenantWin moves from mechanical-enforcement-only to genuine parity with CovenantMac for the
install-time experience, verified with 29 passing end-to-end tests:
- Basket selection (greenfield/brownfield) in `install.ps1`, mirroring `install.sh`'s prompt.
- `/init-governance` command generation from the shared implementation package's `PROMPT
  START`/`PROMPT END` block — no file to copy-paste on Windows either.
- Trust-root `.claude/settings.json` (same deny-list as `install.sh`) and a *real* Bash guard
  hook — reuses CovenantMac's actual `pre_bash_trust_root_guard.sh` (deny-list + `cd`-indirection
  tracking) instead of a no-op stub, since Git for Windows bundles bash and Claude Code's Bash
  tool runs through it on Windows too.
- `pre-commit`/`pre-push` now reuse CovenantMac's actual hook scripts verbatim (`SKIP_COVENANT`
  bypass with TTY/IDE-extension detection + git-notes audit trail; force-push/bypass-tamper/
  protected-branch/24h-clock guards at push) instead of a separate PowerShell implementation —
  hooks call the Python engine directly, no shell-to-PowerShell hop.
- Identity-based debt ratchet (`baseline.json`, brownfield-only), ported from `covenant.sh`'s
  `<path>|<rule_code>` model.
- CODEOWNERS scaffolding; integrity manifest grown to match the real deployed file set, with
  a new `check-integrity` CLI subcommand for CI use.
- Target-repo CI backstop (`.github/workflows/covenant.yml`, ported from `templates/ci-covenant.yml`)
  — previously never written at all, meaning a hook-stripped clone of a Windows-governed repo
  had zero enforcement. Includes the CI cold-start fail-safe fix (`CI_BASE_SHA` diffing,
  full-tree scan when no base is resolvable) mirroring `covenant.sh`'s own fix for the same class
  of fail-open bug.
- `covenantwin.py upgrade` / `install.ps1 -Upgrade`: refreshes hooks/engine, re-fetches the dev guide
  from the shared `v1_release/`, backfills trust-root settings and CODEOWNERS, force-updates
  the CI workflow, re-pins the integrity manifest, and generates `/reconcile-governance`
  (propose-and-approve) when the constitution's source content changed — never silently
  touches `CLAUDE.md` or `baseline.json`.
- `uninstall.ps1` expanded to match: blanket `.claude/` removal, dev-guide/init-package
  cleanup, bypass-refspec cleanup, conditional CI-workflow removal; `CLAUDE.md` kept by
  default (`-RemoveClaudeMd` to opt in), CODEOWNERS never auto-removed.
- Agent-only checkpoint gates ported to `covenantwin.py`: the tier-3 brainstorming block at
  commit (≥5-file agent change with no `.claude/checkpoints/LATEST.md`) and the
  checkpoint-required gate at push, mirroring `covenant.sh`'s STEP 4.4/4.6 exactly.
- Fail-closed behavior when source changes but no test command is configured — previously
  `covenantwin.py` silently passed; now it blocks, matching `covenant.sh`.
- `examples/demo-repo/` + `demo.sh`/`demo.ps1` — a runnable violate → detect → fix → verify
  loop against the real installers on both platforms, not a simulation.
- Root-level `LICENSE` (MIT), `CONTRIBUTING.md`, `CODE_OF_CONDUCT.md`, `SECURITY.md`.

### Fixed — first-run reliability and cross-platform integrity gaps
Found via targeted user feedback and verified against the real engines, not assumed:
- **CovenantWin had no fallback when `commands.test` isn't configured.** Unlike `covenant.sh`,
  which infers a test command from repo topology (`pytest.ini`, `package.json`, `go.mod`, etc.)
  when none is set, `covenantwin.py` depended entirely on `/init-governance` populating
  `commands.test` in `covenant_state.json` — and nothing in the shared `v1_release/` prompt
  content actually instructs writing to that field (it only describes test commands as prose in
  `CLAUDE.md`). A repo with a real, detectable test stack could permanently fail-closed on its
  first source commit with no automated way to recover. `covenantwin.py` now has its own
  topology-based inference (`_infer_test_cmd`), mirroring `covenant.sh`'s stack detection
  (pytest/Jest/Vitest/npm/Go/Cargo/Maven/Gradle) and, like `covenant.sh`, never persisting the
  inferred guess back into committed config.
- **Governance-file integrity drift was only ever caught in CI, disconnected from the edit that
  caused it.** `verify_governance_integrity.sh` (CovenantMac) ran exclusively from
  `ci-covenant.yml`; `check_integrity()` (CovenantWin) ran only at `pre-push`/`ci`. Editing a
  governance file without regenerating `.claude/covenant_integrity.sha256` in the same commit
  passed pre-commit cleanly and only surfaced later, days removed from the actual edit. Both
  engines now run this check at every trigger, including `pre-commit`, so drift is caught in the
  exact commit that introduces it.
- **Neither installer shipped a `.gitattributes` into the repos it installs into.** The integrity
  manifest hashes raw on-disk bytes; a plain `git checkout` on a machine with the commonly
  recommended `core.autocrlf=true` (Windows) silently converts LF to CRLF with zero content
  change, which breaks the pin — and for the bash-shebang files, breaks the script outright. Both
  `install.sh` and `covenantwin.py`'s `install()` now write a `.gitattributes` pinning every
  governance file to `text eol=lf`, backfilled on `--upgrade` for existing installs, and cleaned
  up symmetrically by `uninstall.sh`/`uninstall.ps1`.

### Fixed — CI backstop and secrets-scan gaps
Found by running the real `ci-covenant.yml`/`covenant.yml` workflow against a genuine GitHub
Actions-equivalent runner (`act` + Docker + `actions/checkout@v4`), not by reading the YAML:
- **Branch guard fired in CI mode on both engines.** `actions/checkout@v4` checks out a real
  local branch (not detached HEAD) for a push event, so the branch guard — written assuming
  detached HEAD — blocked every push-triggered CI run against a protected branch, before any
  real check ran. Made the CI backstop permanently failing for every legitimate PR merge, and
  meaningless for the direct-push-bypass case it exists to catch. Fixed by skipping this guard
  when `trigger == ci` on both engines; the direct-push case stays independently blocked by the
  shared `pre-push` hook's own protected-branch guard.
- **`covenant.sh`'s secrets scan never scanned anything in CI or pre-push mode.** It hardcoded
  `git diff --cached`, which is empty in both contexts. A secret pushed with hooks stripped or
  `--no-verify`'d silently produced `COVENANT PASS` in CI. Fixed by reusing the same diff base
  already resolved for the trigger instead of always `--cached`. (`covenantwin.py` reads
  checked-out file content directly rather than a cached diff, so it did not share this bug.)
- Three self-referential secrets-scan false positives: `covenant.sh`'s own STEP 5 comment and
  a print-statement field label matched the very regex they were near, and the framework's
  bare-keyword regex matched ordinary "token budget" prose in its own bundled content —
  together these blocked the first governance commit of *every* fresh install. Fixed by
  requiring an assignment-like delimiter glued to the keyword.
- `checkpoint_tool.py`/`graph_freshness_check.py` (the shipped templates) failed the
  framework's own default lint and complexity bar once the above was fixed, meaning a fresh
  install's own governance commit was never actually passable with `ruff`/`radon` installed.
  Narrowed overbroad exception handling and extracted helpers to bring three functions under
  the complexity threshold — re-verified against the real test suite after the refactor.
- `subprocess` text-mode without explicit `encoding='utf-8'` crashed on Windows' default
  codepage whenever UTF-8 content flowed through any git/child-process output.
- PowerShell scripts containing em-dashes without a BOM corrupted under Windows PowerShell
  5.1's encoding detection; `.ps1` files are now ASCII-only.
- `demo.ps1`'s fix step called `git checkout -- <file>` without first `git reset HEAD <file>`,
  restoring from the still-staged (still-violating) index instead of HEAD.
- `covenantwin.py` refuses to install into its own checkout, mirroring `install.sh`'s
  self-repo guard.

### Changed
- Consolidated the macOS/Linux and Windows implementations into one monorepo, `CovenantMac/`
  and `CovenantWin/`, sharing `v1_release/`'s constitution content and CI/CODEOWNERS at the
  monorepo root (GitHub only discovers either at the true repo root).
- Collapsed the branch strategy to a single default branch, `main`.
- Removed an unsubstantiated "Coverage: Claude Code | Cursor" badge from `CovenantMac/README.md`
  — Cursor support isn't built yet; the badge now states Claude Code only.
- Rewrote the root README around four pillars (repo-specific governance, structured feature
  execution, repository context/memory, independent verification), with an explicit problem
  statement and a limitations section.

### Removed
- An internal engineering-onboarding document set that didn't belong in a public release: it
  contained unverifiable claims about third-party projects, marketing figures explicitly
  disclosed as illustrative rather than measured, and citations that had drifted from the
  actual code after the fixes above. The genuinely useful parts (architecture explanation,
  known issues, a real roadmap) were folded into `CovenantMac/docs/` or this changelog; the
  rest was cut rather than carried forward.
- Self-install artifacts (`.githooks/`, `.claude/hooks/`, `.claude/covenant_state.json`,
  `.claude/covenant_integrity.sha256`) that had been accidentally committed into the
  `CovenantWin` framework repo itself.
- A ~5,000-line archived teaching document whose every code citation referenced a file layout
  and a project name that no longer exist.

## [1.0.0] — CovenantMac

The mature macOS/Linux baseline this changelog picks up from: two-basket
(greenfield/brownfield) install flow, `/init-governance` generated from the implementation
package's prompt content, trust-root lockdown (deny-list + Bash guard + integrity manifest +
CODEOWNERS), identity-based debt ratchet, audited `SKIP_COVENANT` bypass via git notes,
mechanical checkpoint memory, and a `code-review-graph` MCP integration. See
`templates/covenant.sh` for the full enforcement logic, cited to the line in
`CovenantMac/docs/SECURITY_POSTURE.md` and `docs/HUMAN_COMMIT_FLOW.md`. Full prior history is
in `git log` — this changelog starts tracking from the public-release cleanup forward.

## [1.0.0-win] — CovenantWin (initial)

Windows-native mechanical enforcement engine (branch guard, token budget, secrets scan,
layer boundaries, tests/coverage, complexity, integrity, receipts) in pure Python. Did not
yet include the governance-generation layer — closed in [Unreleased] above. Checkpoint
memory and the `code-review-graph` MCP integration remain unported (enhancement layer, not
core governance).
