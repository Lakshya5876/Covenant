#!/usr/bin/env bash
# demo.sh — watch Covenant's core loop end to end, in a few minutes, on a
# disposable copy of examples/demo-repo. No install into your real projects.
#
#   Covenant analyzes a repo -> governance is established -> an AI/developer makes
#   a violating change -> Covenant catches it and explains why -> the change is
#   fixed -> Covenant verifies the repo is compliant again.
#
# Usage: ./demo.sh   (run from anywhere inside the Covenant repo)
set -euo pipefail

RED='\033[0;31m'; YELLOW='\033[1;33m'; GREEN='\033[0;32m'; BLUE='\033[0;34m'; BOLD='\033[1m'; RESET='\033[0m'
_step()  { echo ""; echo -e "${BOLD}${BLUE}▶ $*${RESET}"; }
_note()  { echo -e "${YELLOW}  $*${RESET}"; }
_pause() { read -r -p "  Press Enter to continue... " _ </dev/tty || true; }

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DEMO_SRC="${SCRIPT_DIR}/examples/demo-repo"
INSTALL_SH="${SCRIPT_DIR}/CovenantMac/install.sh"

[ -d "$DEMO_SRC" ] || { echo "Demo source not found at ${DEMO_SRC}" >&2; exit 1; }
[ -f "$INSTALL_SH" ] || { echo "install.sh not found at ${INSTALL_SH}" >&2; exit 1; }

_step "Step 0 — Check demo prerequisites (ruff/mypy/radon/pytest/flask)"
_note "The demo repo is a small Python app; covenant.sh defaults to ruff/mypy/radon for"
_note "Python lint/type/complexity checks. Installing them into a disposable venv..."
WORKDIR="$(mktemp -d)"
DEMO_VENV="${WORKDIR}/venv"
# A venv, not a system-wide pip install: never touches the machine's real
# Python, and works unmodified on PEP 668 "externally-managed-environment"
# systems (the default on modern Debian/Ubuntu, including a fresh WSL2 Ubuntu
# image — confirmed to hard-fail here with a plain `pip install`, which is
# exactly the environment CovenantMac's own docs point Windows users to for
# running this engine at all).
python3 -m venv "$DEMO_VENV" || \
    { echo "Could not create a venv (python3-venv missing?). Install it (e.g. apt install python3-venv) or install the demo's tools yourself: pip install -r ${DEMO_SRC}/requirements.txt" >&2; exit 1; }
# shellcheck disable=SC1091
source "${DEMO_VENV}/bin/activate"
pip install --quiet -r "${DEMO_SRC}/requirements.txt" || \
    { echo "Could not install demo prerequisites into ${DEMO_VENV} — install manually: pip install -r ${DEMO_SRC}/requirements.txt" >&2; exit 1; }

DEMO_REPO="${WORKDIR}/billing-service"
cp -r "$DEMO_SRC" "$DEMO_REPO"

echo -e "${BOLD}"
echo "==============================================================="
echo " Covenant demo — a fresh copy of a small billing service is at:"
echo "   ${DEMO_REPO}"
echo "==============================================================="
echo -e "${RESET}"

_step "Step 1 — Initialize the target repo (this is YOUR repo in real usage)"
cd "$DEMO_REPO"
git init -q -b main
git config user.email "demo@example.test"
git config user.name "Covenant Demo"
git add -A
git commit -q -m "chore: initial billing service"
git checkout -q -b chore/claude-init
_note "Created ${DEMO_REPO}, committed the starting code on 'main', and switched to a setup branch."
_pause

_step "Step 2 — Install Covenant (choose [g] greenfield when prompted)"
_note "This is the real installer — same one you'd run against your own project."
"$INSTALL_SH"
_note "Governance installed: git hooks, trust-root lockdown, CI backstop, /init-governance command."
_pause

_step "Step 3 — Simulate an AI making a violating change (a leaked credential)"
cat >> src/infrastructure/billing_repository.py <<'PYEOF'

# TODO: remove before merging
STRIPE_API_KEY = "hardcoded-secret-do-not-commit-9f8e7d6c5b4a3210"
PYEOF
git add src/infrastructure/billing_repository.py
_note "Staged a change that hardcodes a live-looking API key. Attempting to commit it..."
echo ""
set +e
git commit -m "feat: wire up Stripe key for billing"
COMMIT_EXIT=$?
set -e
echo ""
if [ "$COMMIT_EXIT" -eq 0 ]; then
    _note "⚠ Unexpected: the commit succeeded. Covenant's secrets scan should have blocked this — please report this as a bug."
else
    echo -e "${GREEN}  ^ That's Covenant blocking the commit and explaining exactly what's wrong — no LLM call, just a deterministic pre-commit hook.${RESET}"
fi
_pause

_step "Step 4 — Fix it, and watch Covenant verify the repo again"
git reset -q HEAD src/infrastructure/billing_repository.py
git checkout -q -- src/infrastructure/billing_repository.py
_note "Reverted the leaked key. Committing the same intent without the credential..."
cat >> src/infrastructure/billing_repository.py <<'PYEOF'

# Stripe key is read from the environment, never hardcoded.
PYEOF
git add src/infrastructure/billing_repository.py
git commit -m "feat: document Stripe key handling"
echo ""
echo -e "${GREEN}  ^ Covenant verified the repo is compliant again and let the commit through.${RESET}"
_pause

_step "Step 5 — The audit trail this left behind"
if [ -f .claude/covenant_state.json ]; then
    RECEIPT_COUNT=$(python3 -c "import json; print(len(json.load(open('.claude/covenant_state.json')).get('receipts', {})))" 2>/dev/null || echo "?")
    _note "covenant_state.json now has ${RECEIPT_COUNT} passing-commit receipt(s) — a tree-keyed record pre-push can fast-path against."
fi
echo ""
echo -e "${BOLD}Done.${RESET} The demo repo is left at ${DEMO_REPO} if you want to explore further —"
echo "try 'git log --show-notes=bypasses' after a SKIP_COVENANT=1 commit, or open Claude Code there and run"
echo "/init-governance for real (it'll interrogate you about the stack and generate CLAUDE.md)."
echo ""
