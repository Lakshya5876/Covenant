# Upgrading the Governance Framework

## When to run

Run `./install.sh --upgrade` when:

- A new version of `Covenant` is available and you want its covenant.sh enforcement improvements.
- The team lead has announced a framework version bump (e.g. v1.0.0 → v1.1.0).
- `covenant_state.json` shows a `framework_version` older than the installer's `FRAMEWORK_SEMVER`.

Do **not** run it for routine development — it only touches framework infrastructure files.

---

## How to run

From inside the governed repository (same directory you originally ran `install.sh` from):

```bash
/path/to/Covenant/CovenantMac/install.sh --upgrade
```

The script detects `--upgrade`, skips basket selection, and runs a targeted re-copy flow.

---

## What it overwrites

| File | Action |
|------|--------|
| `.githooks/covenant.sh` | Replaced with the new template |
| `.githooks/verify_governance_integrity.sh` | Replaced with the new template |
| `.githooks/pre-commit` | Regenerated from current heredoc |
| `.githooks/pre-push` | Regenerated from current heredoc |
| `v1_claude_code_development_guide_*.md` | Re-fetched from the framework's current release copy |
| `v1_implementation_package_*.md` | Re-fetched from the framework's current release copy |
| `.claude/commands/init-governance.md` | Regenerated from the refreshed init-package content |
| `.claude/settings.json` | Trust-root deny-list + Bash guard hook entries backfilled if missing (repo-specific `permissions.allow` entries are preserved) |
| `.claude/hooks/pre_bash_trust_root_guard.sh` | Replaced with the new template |
| `.claude/checkpoint_tool.py` / checkpoint memory scaffold | Backfilled if missing |
| `.claude/covenant_integrity.sha256` | Re-pinned to cover every file above — **CI will fail until this manifest is committed alongside the files it covers** |
| `.github/workflows/covenant.yml` | Replaced (unlike fresh install, which skips if present) |
| `.claude/covenant_state.json` — `framework_version` | Bumped to new semver |
| `.claude/covenant_state.json` — `framework_last_upgrade` | Set to current UTC timestamp |

---

## What it offers, but never does silently

| Mechanism | When it triggers | What happens |
|---|---|---|
| **Deprecation cleanup** | The framework's `DEPRECATED_SINCE` list names a file that became obsolete in a version newer than this repo's previous `framework_version`, and that file still exists in your repo | Lists the obsolete file(s) and asks a single y/n confirmation before removing anything. Declining leaves them in place — nothing is ever force-deleted. |
| **`/reconcile-governance` generation** | The dev guide's actual *content* changed since your last install/upgrade (not just its version number) | Generates `.claude/commands/reconcile-governance.md`, containing a unified diff of what changed. Running that command has Claude Code propose individually-justified edits to `CLAUDE.md` and wait for your explicit approval on each — `--upgrade` itself never edits `CLAUDE.md`. If the dev guide's content didn't change, no command is generated and nothing prompts you. |

---

## What it never touches

| File / Field | Why preserved |
|---|---|
| `.claude/baseline.json` | Debt ratchet — encodes your team's accepted technical debt; overwriting it would grandfather nothing and block everything |
| `CLAUDE.md` | Repo constitution — team-authored, repo-specific; a framework upgrade never edits this directly (see `/reconcile-governance` above for the propose-and-approve path when the constitution's source content changed) |
| `.mcp.json` | Graph server config — tied to the specific binary path pipx installed; regenerating it would break graph mode |
| `.claude/covenant_receipts.json` | Fingerprint cache (gitignored, per-machine) — losing receipts just forces the next push on that machine to re-run the full test suite once; migrated here automatically if found in the old `covenant_state.json` location |
| `covenant_state.json — token.*` | Budget accounting — clearing it would reset daily spend tracking mid-day |
| `covenant_state.json — thresholds` | Human-tuned — your team may have raised coverage_pct or tightened complexity_max; upgrades don't reset those |
| `covenant_state.json — core_files` | Architecture-critical file list — team-authored; a framework upgrade cannot know which files your team considers critical |

---

## After the upgrade

The upgrade script prints the exact commit command at the end of its own output — use that one verbatim, since it lists every file the run above actually touched (it will differ slightly upgrade to upgrade depending on what was backfilled). As of this version it is:

```bash
git add .githooks/ .claude/covenant_integrity.sha256 .claude/settings.json .claude/hooks/ .claude/checkpoint_tool.py .claude/commands/ .github/workflows/covenant.yml .claude/covenant_state.json
git commit -m 'chore: upgrade governance framework to 1.0.0'
```

If `/reconcile-governance` was generated, run it and resolve it (approve or reject each proposed `CLAUDE.md` edit) **before** this commit, so any resulting `CLAUDE.md` changes land in the same review as the rest of the upgrade rather than a separate follow-up PR.

Push the commit through your normal PR flow. Every team member who pulls it gets the updated hooks automatically — no per-developer re-run of `install.sh` is needed.

---

## Verifying the upgrade

```bash
python3 -c "import json; d=json.load(open('.claude/covenant_state.json')); print(d['framework_version'])"
```

Should print the new semver string.
