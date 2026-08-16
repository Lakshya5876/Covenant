# CovenantWin

Windows-native governance for Covenant: the same install → `/init-governance` → mechanical
enforcement experience as `CovenantMac`, implemented as a pure Python engine with thin
PowerShell entry points instead of a bash port.

## Requirements

- Windows 10/11, PowerShell 5.1+ (PowerShell 7 supported)
- Git for Windows (Git hooks use its bundled `sh`/`bash` — CovenantWin's pre-commit/pre-push
  scripts and its trust-root guard are the *same* POSIX scripts `CovenantMac` ships, reused as-is)
- Python 3.9+ on `PATH`

## Install into a repository

```powershell
git clone <repository_url> ~/tools/Covenant
Set-Location <your-repository>
& '~/tools/Covenant/CovenantWin/install.ps1'
```

You'll be prompted to choose greenfield (new project) or brownfield (existing codebase) —
pass `-Basket greenfield` / `-Basket brownfield` to skip the prompt. This creates
`.githooks/`, a trust-root `.claude/settings.json` + Bash guard, an integrity manifest, a
`.github/workflows/covenant.yml` CI backstop, `.github/CODEOWNERS`, and (brownfield only) an
unpopulated `.claude/baseline.json`, then configures `core.hooksPath=.githooks`.

**Next step — open Claude Code in the repo and run `/init-governance`.** The installer
already generated that command (`.claude/commands/init-governance.md`) from the shared
implementation package; it interrogates you about your stack, drafts governance docs for
your approval, and generates a repo-specific `CLAUDE.md`.

To upgrade an already-governed repo to the current framework version:
```powershell
& '~/tools/Covenant/CovenantWin/install.ps1' -Upgrade
```

To remove CovenantWin from a repo: `./uninstall.ps1` (pass `-RemoveClaudeMd` to also remove the
generated constitution — kept by default, since it likely holds real decisions by now).

## What the covenant checks

1. protected-branch guard and active-agent token policy
2. staged scope calculation and core-file/TIER-3 escalation
3. agent-only checkpoint gates: a tier-3 (5+ file) agent commit with no
   `.claude/checkpoints/LATEST.md` is blocked at commit, and an agent push touching source with no
   checkpoint is blocked at push — a human commit or push is never subject to either
4. staged-content secret scan (keyword + high-confidence format prefixes, not an entropy scanner)
5. fail-closed when source files changed but no test command is configured — never a silent pass
6. configured lint (with an identity-based debt ratchet once `.claude/baseline.json` is
   populated — brownfield repos grandfather existing findings, blocking only new ones) and
   type-check commands
7. architecture layer-boundary scan (no SQL outside `infrastructure/`, no HTTP-framework
   imports in `services/`/`application/`, no ORM/framework imports in `domain/`)
8. test and optional coverage commands (mandatory at push/TIER-3/CI, opt-in at commit)
9. configured complexity and frontend commands
10. integrity verification (push/CI), receipt and audit-ledger update

Commands live in `.claude/covenant_state.json` under `commands`; they are intentionally empty
until `/init-governance` (or you, manually) chooses stack-specific commands. CovenantWin invokes
those configured commands from the repository root and fails on a non-zero exit.

Bypassing a blocked commit (`SKIP_COVENANT=1 git commit ...`) requires an interactive terminal,
logs a git note to `refs/notes/bypasses` with a 24-hour resolution clock, and is visible to
the whole team via `git log --show-notes=bypasses` — the same audited escape hatch `CovenantMac`
uses, since the hook scripts implementing it are the same file.

## A note on this checkout's shape

`CovenantWin`'s installer reads shared content — `../v1_release/` (the dev-guide/implementation-
package constitution) and `../CovenantMac/templates/` (the pre-commit/pre-push scripts and the
trust-root guard, reused verbatim since none of it is OS-specific) — from sibling directories
under the `Covenant` monorepo. `install`/`upgrade` only work from a checkout that has `CovenantMac/`
and `v1_release/` alongside `CovenantWin/`, i.e. the full `Covenant` repo, not a `CovenantWin`-only
extract. Once installed, the *deployed* copy in your target repo (`.githooks/covenantwin.py` and
friends) has no further dependency on this checkout — see
[Windows implementation notes](docs/MIGRATION.md) and [tests](tests/test_covenantwin.py).
