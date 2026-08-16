<div align="center">
  <h1>Covenant 🛡️</h1>
  <p><strong>The deterministic, agent-agnostic, un-bypassable governance framework for AI-driven development.</strong></p>

  [![License: MIT](https://img.shields.io/badge/License-MIT-blue.svg)](../LICENSE)
  [![Platform: macOS | Linux](https://img.shields.io/badge/Platform-macOS%20%7C%20Linux-lightgrey)]()
  [![Coverage: Claude Code](https://img.shields.io/badge/Coverage-Claude%20Code-green)]()

</div>

---

## 📖 Overview

Covenant is a **stack-agnostic governance framework** that brings engineering discipline and safety to autonomous AI coding agents at scale. Instead of relying purely on prompts—which agents can ignore, bypass, or hallucinate around—Covenant enforces deterministic architecture, security, testing, and deployment rules at the **git and CI layer**.

Whether you're starting a greenfield project or integrating AI into a mature brownfield codebase, Covenant ensures that no automated changes violate your critical constraints.

### 🌟 Key Features
- **Un-bypassable Governance**: Rules are enforced via Git hooks and CI, meaning humans and AI agents are held to the exact same rigorous standards.
- **Agent-Agnostic at the git/CI Layer**: enforcement lives in git hooks and CI, so it binds any actor's diff — human or AI — regardless of which coding tool produced it. Deeper, tool-specific hardening (the Claude Code hook layer: Bash guard, checkpoint memory) is Claude Code-specific today; Cursor/Codex adapters over the same git+CI covenant are a future direction, not yet shipped.
- **Deterministic Checkpoints**: Catch stray layer boundaries, secret leakage, or missing tests *before* the commit leaves the machine.
- **Graceful Adoption**: Distinct deployment strategies (Baskets) tailor the framework's strictness to brand-new repos vs. legacy codebases.

---

## 🚀 Quick Start & Installation

This implementation (`CovenantMac`) operates via POSIX-compliant shell scripts (`bash`) and
targets macOS/Linux. **Windows users should use `CovenantWin`** (`../CovenantWin/`) — a native Python
port that reaches governance parity with this implementation — rather than running CovenantMac
under WSL2.

### Prerequisites
- `git`
- `bash` (3.2+)
- `python3` (Standard library only; no `pip` dependencies required)
- *Optional:* Claude Code CLI

### Deployment

Everything you need to deploy Covenant is inside the [`v1_release/`](v1_release/) folder. We offer two core deployment strategies depending on your codebase:

1. **[Basket 1: Brownfield](v1_release/basket-1-brownfield/)** — For existing, active codebases. Introduces a "baseline ratchet" that prevents regressions without breaking on legacy technical debt.
2. **[Basket 2: Greenfield](v1_release/basket-2-greenfield/)** — For brand-new projects. Enforces strict layer boundaries, immutable trust roots, and maximum security from day one.

Choose your basket and follow the specific `install.sh` workflow documented within.

---

## 🧪 Testing & CI Integration

Covenant emphasizes high velocity without sacrificing safety. Tests are **opt-in at commit** but **mechanically forced** before pushing.

| Action | Execution Requirement |
|---|---|
| `git commit` | **Opt-in** — Add `--run-tests=true` to your commit message |
| `git commit` (Core paths) | **Forced** — Touching CORE_FILES triggers mandatory full suite |
| `git push` | **Forced** — Requires a verified local test receipt or blocks the push |
| **CI Workflow** | **Authoritative** — The final backstop (`.github/workflows/covenant.yml`) |

---

## 📚 Further reading

For the security model, data flows, and threat boundaries, see
[`docs/SECURITY_POSTURE.md`](docs/SECURITY_POSTURE.md). For a step-by-step walkthrough of what
`git commit` actually does under the covenant, see [`docs/HUMAN_COMMIT_FLOW.md`](docs/HUMAN_COMMIT_FLOW.md).
The enforcement engine itself, `templates/covenant.sh`, is heavily commented — it's the most
authoritative source for exactly how a check behaves.

---
<div align="center">
  <sub>Built with precision to scale AI engineering safely.</sub>
</div>
