<div align="center">

# Covenant 🛡️

### Make AI-generated code easier to trust before it reaches production.

**Repo-specific governance · Structured feature execution · Persistent repository context · Deterministic Git + CI verification**

[![License: MIT](https://img.shields.io/badge/License-MIT-blue.svg)](LICENSE)

</div>

---

## The problem

AI coding agents can generate a working feature in minutes.

The harder question is whether that code is actually ready to live in your repository.

A feature can work and still:

- ignore the architecture already in place
- duplicate logic the repository already has
- violate project conventions
- skip edge cases and tests
- introduce security issues
- make the next change harder than it should be
- lose important context between sessions
- repeatedly rediscover the same codebase and waste tokens

A rule in `CLAUDE.md` helps, but it is still an instruction to a probabilistic model.

Covenant is designed to close the gap between:

```text
"Claude Code generated something that works"
                    ↓
"this change belongs in the codebase and is safe to ship"
```

It does this by establishing repository-specific governance, structuring how work is executed, preserving useful repository context, and independently verifying changes at the Git and CI boundaries.

---

## What Covenant does

```text
                 YOUR REPOSITORY
                        │
                        ▼
              ┌───────────────────┐
              │ Analyze the repo  │
              │ before governing  │
              └─────────┬─────────┘
                        ▼
              ┌───────────────────┐
              │ Repo-specific     │
              │ governance        │
              └─────────┬─────────┘
                        ▼
              ┌───────────────────┐
              │ Structured        │
              │ feature execution │
              └─────────┬─────────┘
                        ▼
              ┌───────────────────┐
              │ Repository        │
              │ context + memory  │
              └─────────┬─────────┘
                        ▼
              ┌───────────────────┐
              │ Independent Git   │
              │ + CI verification │
              └─────────┬─────────┘
                        ▼
                    CHANGE
                 ALLOWED TO LAND
```

Covenant is not another generic prompt file.

It attempts to make AI-assisted development more disciplined across the entire lifecycle of a change:

1. **Understand the repository**
2. **Establish governance specific to that repository**
3. **Turn work into a structured execution contract**
4. **Execute within defined scope and constraints**
5. **Preserve useful context across work and sessions**
6. **Verify the resulting change independently**
7. **Block defined violations from landing**

The goal is simple:

> Give the agent enough structure and repository context to make better changes, then avoid trusting the agent to certify its own work.

---

# Repository-specific governance

## Your repository is not a template

A generic instruction such as:

```text
Always write tests.
Follow clean architecture.
Use proper error handling.
Keep functions modular.
```

does not describe how **your repository** actually works.

`/init-governance` begins by examining the repository before generating its governance.

For existing repositories, Covenant can build its understanding from the repository's actual structure and tooling, including relevant project configuration and conventions.

The initialization flow is designed around discovery first.

Conceptually:

```text
READ THE REPOSITORY
        ↓
DISCOVER STACK AND STRUCTURE
        ↓
IDENTIFY CONVENTIONS AND CONSTRAINTS
        ↓
SHOW DISCOVERY RESULTS
        ↓
WAIT FOR REVIEW / APPROVAL
        ↓
GENERATE REPO-SPECIFIC GOVERNANCE
```

Rather than immediately applying a universal constitution, the goal is to generate governance that reflects the repository being governed.

Depending on the repository, discovery can establish information such as:

* languages and frameworks
* project structure
* build commands
* linting and type-checking configuration
* test commands and test structure
* architectural boundaries
* dependency direction
* existing conventions
* existing technical debt baseline
* architecture-critical files

The resulting governance is therefore intended to describe the repository that exists, rather than the repository a generic template assumes exists.

---

# Structured feature execution

## Stop solving one feature through five disconnected prompts

A vague request such as:

```text
Add rate limiting to the API.
```

often becomes a sequence:

```text
Add rate limiting.
        ↓
No, not like that.
        ↓
Use the existing middleware.
        ↓
Add tests.
        ↓
Handle this edge case.
        ↓
Move this logic out of the route.
        ↓
Fix what broke.
```

Each correction exists because important requirements were either missing, forgotten, or discovered after implementation began.

Covenant structures work around a more complete unit of execution.

Before implementation, a task can be shaped around information such as:

```text
OBJECTIVE
What needs to change?

SCOPE
Which parts of the repository are relevant?

CONSTRAINTS
What existing architecture and rules must be respected?

SUCCESS CRITERIA
How do we know the work is complete?

VERIFICATION
Which real commands or checks prove the result?
```

The exact governance is repository-specific, but the principle remains the same:

> The agent should understand the job before repeatedly being corrected into understanding it.

A typical feature lifecycle can include:

```text
01  RECON
    Understand relevant code before changing it.

02  CONTRACT
    Define the objective, scope, constraints, and proof of completion.

03  PLAN
    Determine the intended change before implementation expands.

04  EXECUTE
    Make the change within the established boundaries.

05  VERIFY
    Run the checks that demonstrate whether the work actually succeeded.
```

This does not guarantee that every feature succeeds in one prompt.

That would be a dishonest claim.

The purpose is to reduce avoidable correction loops by making the initial unit of work more complete.

---

# Repository context and memory

## The agent should not have to rediscover the repository every session

Large repositories contain relationships that matter during development:

```text
What depends on this file?
What will this change affect?
Where is this behavior already implemented?
Which layer owns this responsibility?
What was decided earlier?
```

Repeatedly searching or rereading large parts of the repository consumes context and tokens while reconstructing information that was already discovered.

Covenant includes context-oriented enhancement layers intended to reduce unnecessary rediscovery.

### Code-review graph

A structural representation of repository relationships can be used to answer relevant questions without treating every request as a fresh full-codebase exploration.

The graph is also checked for staleness so context does not silently drift away from the repository state.

### Freshness checks

Repository context is only useful if it reflects the code being worked on.

Relevant changes can trigger freshness checks and rebuilding behavior so stale structural information is surfaced rather than silently trusted.

### Checkpoint memory

Work does not always fit inside one session.

Checkpoints preserve useful information about work such as:

* current task
* decisions already made
* relevant findings
* completed work
* remaining work

The goal is to make continuation more reliable instead of forcing a new session to reconstruct everything from scratch.

> Context is an enhancement layer, not the enforcement boundary. Better context helps the agent make better decisions. Independent verification determines whether defined rules were actually satisfied.

---

# Independent verification

## Instructions shape behavior. Exit codes decide what passes.

`CLAUDE.md`, execution contracts, repository context, and checkpoints help shape what an agent attempts to do.

They are not the final authority on whether a change is allowed to land.

Covenant establishes multiple layers around that distinction:

```text
AI AGENT
   │
   ▼
Guidance and agent-side controls
   │
   ▼
GIT
   │
   ▼
Mechanical verification
   │
   ▼
CI
   │
   ▼
Authoritative backstop
```

The same enforcement logic is used at the relevant Git and CI boundaries so local and remote checks are aligned.

A human-authored change and an AI-authored change are subject to the same defined repository checks.

Covenant does not need to determine who typed the command.

The relevant question is whether the change satisfies the rules.

---

# What Covenant checks

The installed governance can include checks such as:

| Check                        | Purpose                                                                          |
| ----------------------------- | ---------------------------------------------------------------------------------- |
| **Protected branches**       | Prevent direct commits or pushes to configured protected branches                |
| **Secrets scan**             | Detect defined credential patterns in staged changes                             |
| **Layer boundaries**         | Detect configured architectural boundary violations                              |
| **Lint / type / complexity** | Prevent new findings while allowing a brownfield baseline                        |
| **Tests + coverage**         | Require configured verification at the appropriate boundary                      |
| **Token budget**             | Limit a cooperating AI session's configured spend without blocking human commits |
| **Receipts**                 | Avoid repeating verification for an unchanged tree that already passed           |
| **Audited bypass**           | Record exceptional bypasses with a reason and limited validity                   |

Checks are scoped according to Covenant's installed configuration rather than blindly treating every changed commit as a reason to run every possible operation across the entire repository.

For brownfield repositories, the debt-ratchet approach is intended to avoid demanding that all historical problems be fixed before any new work can proceed.

The principle is:

```text
Existing debt may be baselined.
New debt should not silently increase.
```

---

# Trust root

## An agent that can rewrite its own rules has no meaningful rules.

Governance is weaker if the system being governed can freely modify the files that define the governance.

Covenant therefore protects its governance files through multiple mechanisms, including the trust-root protections and integrity checks installed for the governed repository.

The CI layer verifies the relevant integrity state.

For stronger protection against governance changes, repository ownership and branch protection remain external controls that a human repository administrator must configure.

Covenant deliberately does not pretend that a local script alone creates an externally anchored security boundary.

See the security and architecture documentation for the exact threat model and limitations.

---

# Platform status

|                                                                          | macOS / Linux (`CovenantMac/`) | Windows (`CovenantWin/`)         |
| ------------------------------------------------------------------------- | ------------------------------- | ---------------------------------- |
| Mechanical enforcement                                                   | ✅                              | ✅                                |
| Repo analysis + `/init-governance`                                       | ✅                              | ✅                                |
| Repo-specific governance generation                                      | ✅                              | ✅                                |
| Trust-root lockdown                                                      | ✅                              | ✅                                |
| Debt ratchet / brownfield baseline                                       | ✅                              | ✅                                |
| Audited bypass trail                                                     | ✅                              | ✅                                |
| CI backstop installation                                                 | ✅                              | ✅                                |
| Upgrade / reconciliation path                                            | ✅                              | ✅                                |
| Agent-only checkpoint gates                                              | ✅                              | ✅                                |
| Fail-closed behavior for unconfigured test verification where applicable | ✅                              | ✅                                |
| Framework integration tests                                              | 178 bats tests / 31 files       | 35 pytest tests                  |
| Cross-session checkpoint memory                                          | ✅                              | Enhancement layer not yet ported |
| `code-review-graph` integration                                          | ✅                              | Enhancement layer not yet ported |

**Honest summary:** both platform implementations provide the core governance-generation and enforcement flow, including installation, `/init-governance`, trust-root protection, integrity manifests, debt baselines, bypass auditing, CI backstops, upgrade paths, checkpoint gates, and fail-closed behavior for the supported verification cases.

The remaining Windows gap is in enhancement layers: cross-session checkpoint memory and `code-review-graph` integration. These inform repository understanding and review; they are distinct from the enforcement gates.

---

# See it work

The fastest way to understand Covenant is to run the real demo.

### macOS / Linux

```bash
./demo.sh
```

### Windows

```powershell
.\demo.ps1
```

The demo:

1. creates a disposable copy of a small billing-service repository
2. runs the real Covenant installer
3. stages a real-looking hardcoded API key
4. runs the actual Git hook
5. shows the resulting `COVENANT BLOCK`
6. fixes the violation
7. commits again
8. shows the resulting `COVENANT PASS`

It uses the same installer and enforcement implementation used for governed repositories.

It is not a simulated terminal recording.

---

# Quick start

## 1. Clone Covenant beside the repository you want to govern

Covenant is designed to live as a sibling of the target repository.

```bash
cd projects
git clone https://github.com/Lakshya5876/Covenant.git
```

Your directory can look like:

```text
projects/
├── your-project/
└── Covenant/
    ├── CovenantMac/
    └── CovenantWin/
```

---

## 2. Install into your repository

### macOS / Linux

```bash
cd your-project
/path/to/Covenant/CovenantMac/install.sh
```

### Windows

```powershell
Set-Location your-project
& '\path\to\Covenant\CovenantWin\install.ps1'
```

The installer guides you through the relevant setup path, including the distinction between greenfield and brownfield repositories.

---

## 3. Initialize repository-specific governance

Open Claude Code from inside the target repository:

```bash
claude
```

Then run:

```text
/init-governance
```

The initialization flow analyzes the repository before generating its governance.

It is intended to establish repository-specific rules based on the stack, structure, tooling, tests, and conventions it discovers rather than applying one generic configuration everywhere.

See:

* [`v1_release/basket-1-brownfield/README.md`](v1_release/basket-1-brownfield/README.md) — existing repositories
* [`v1_release/basket-2-greenfield/README.md`](v1_release/basket-2-greenfield/README.md) — new repositories

for the complete walkthrough.

---

# Uninstall

Run the platform-specific uninstaller from inside the governed repository.

## macOS / Linux

```bash
cd your-project
/path/to/Covenant/CovenantMac/uninstall.sh
```

## Windows

```powershell
Set-Location your-project
& '\path\to\Covenant\CovenantWin\uninstall.ps1'
```

The uninstallers remove Covenant framework artifacts, including applicable hooks, governance state, integrity files, installed CI workflow artifacts, and related configuration.

Safety behavior differs where human-authored files are involved.

For example:

* `.github/CODEOWNERS` is not automatically removed because repository ownership may have been customized after installation.
* `CLAUDE.md` is treated as potentially human-authored content and is not silently deleted.

On macOS/Linux, `uninstall.sh` prompts before removing `CLAUDE.md`.
On Windows, `uninstall.ps1` keeps it unless `-RemoveClaudeMd` is explicitly supplied.

---

# Documentation

Start here:

* [`CovenantMac/docs/SECURITY_POSTURE.md`](CovenantMac/docs/SECURITY_POSTURE.md) — security posture, permissions, threat boundaries, and what Covenant does **not** protect against
* [`CovenantMac/docs/HUMAN_COMMIT_FLOW.md`](CovenantMac/docs/HUMAN_COMMIT_FLOW.md) — what `git commit` actually does, step by step
* [`CovenantMac/docs/UPGRADE.md`](CovenantMac/docs/UPGRADE.md) — what `--upgrade` overwrites vs. preserves
* [`CovenantWin/docs/MIGRATION.md`](CovenantWin/docs/MIGRATION.md) — how the Windows engine relates to the macOS/Linux one

Project files:

* [`CONTRIBUTING.md`](CONTRIBUTING.md)
* [`SECURITY.md`](SECURITY.md)
* [`CODE_OF_CONDUCT.md`](CODE_OF_CONDUCT.md)
* [`CHANGELOG.md`](CHANGELOG.md)

---

# Limitations

Covenant is explicit about its limits.

Examples:

* Local Git hooks can be bypassed; CI is the authoritative backstop.
* An integrity manifest without an external trust anchor cannot by itself prevent a privileged repository change from changing both the governed file and its recorded hash.
* Secrets scanning is pattern-based and is not a replacement for dedicated secret-scanning tools.
* Agent detection and token-budget controls apply to cooperating client-side environments and are not central access-control systems.
* Regex-based architectural checks do not provide the guarantees of full AST or import-graph analysis where those checks are not implemented.
* Repository branch protection and CODEOWNERS configuration remain human-controlled repository settings.

See [`SECURITY_POSTURE.md`](CovenantMac/docs/SECURITY_POSTURE.md) for the complete limitations and threat model.

> Covenant is intended to improve the discipline, context, verification, and repeatability of AI-assisted development. It does not make generated code automatically correct or production-safe.

---

<div align="center">

## Covenant

**Make the path from AI-generated code to production-ready code more structured, contextual, and independently verifiable.**

[View source](https://github.com/Lakshya5876/Covenant) · [MIT License](LICENSE)

</div>
