load test_helper

# Verifies uninstall.sh actually removes every trace install.sh (and the
# /init-governance flow it triggers) can leave behind — end to end, against
# the REAL uninstall.sh, not a mirror. Written after a real gap was found:
# .githooks/verify_governance_integrity.sh was missing from the removal
# scan, which meant it (and therefore the whole now-never-empty .githooks/
# directory) silently survived every uninstall run.
#
# Uses run_with_pty (test_helper.bash) to drive uninstall.sh's three
# possible prompts (main confirm, then CLAUDE.md confirm, then docs/
# confirm, each only asked if the corresponding artifact exists) through a
# real pty — plain stdin piping into a `</dev/tty` read is a no-op in this
# sandbox (see test_helper.bash's run_with_pty for the full explanation).
# Assertions avoid bare `[[ ]]` except as a test's final statement — an
# earlier version of these tests used `[[ ]]` mid-test and passed regardless
# of the real removal outcome, because a failing `[[ ]]` that isn't a test's
# last statement does not stop test execution in this environment.
#
# SAFETY: uninstall.sh also touches GLOBAL machine state — ~/.claude/
# org_policy.json and the real code-review-graph pipx install — outside the
# scratch TEST_REPO entirely. Running the real script unmocked against a
# real developer machine's actual HOME risks deleting real config or
# uninstalling a real package. Every invocation below runs through a
# generated wrapper that overrides HOME to an isolated fake directory and
# shadows `pipx` with a no-op stub on PATH, so the global-resource code
# paths execute (proving they don't crash) without ever touching anything
# real. Confirmed necessary, not theoretical: earlier runs of this file
# (before this isolation existed) got stuck mid-prompt and were killed
# before reaching that code, but nothing here should rely on being lucky.

UNINSTALL_SRC="${FRAMEWORK_ROOT}/uninstall.sh"

setup() {
    TEST_REPO="$(mktemp -d "${TMPDIR:-/tmp}/uninstall-full-XXXXXX")"
    cd "$TEST_REPO" || return 1
    git init -q
    git config user.email t@t.com
    git config user.name t

    mkdir -p .githooks .claude/hooks .claude/commands .claude/checkpoints \
        .github/workflows docs src/domain src/application tests

    cp "${SHARED_ROOT}/v1_release/basket-2-greenfield/v1_claude_code_development_guide_new.md" \
        v1_claude_code_development_guide_new.md
    cp "${SHARED_ROOT}/v1_release/basket-2-greenfield/v1_implementation_package_new.md" \
        v1_implementation_package_new.md
    cp "${FRAMEWORK_ROOT}/templates/covenant.sh" .githooks/covenant.sh
    cp "${FRAMEWORK_ROOT}/templates/verify_governance_integrity.sh" .githooks/verify_governance_integrity.sh
    cp "${FRAMEWORK_ROOT}/templates/pre-commit" .githooks/pre-commit
    cp "${FRAMEWORK_ROOT}/templates/pre-push" .githooks/pre-push
    cp "${FRAMEWORK_ROOT}/templates/pre_bash_trust_root_guard.sh" .claude/hooks/pre_bash_trust_root_guard.sh
    cp "${FRAMEWORK_ROOT}/templates/graph_freshness_check.py" .claude/hooks/graph_freshness_check.py
    cp "${FRAMEWORK_ROOT}/templates/checkpoint_tool.py" .claude/checkpoint_tool.py
    cp "${FRAMEWORK_ROOT}/templates/covenant_state.json" .claude/covenant_state.json
    echo '{}' > .claude/settings.json
    echo -n "" > .claude/covenant_integrity.sha256
    echo '{}' > .claude/session_state.json
    touch .claude/checkpoints/index.jsonl
    echo '{"mcpServers":{"code-review-graph":{"command":"code-review-graph"}}}' > .mcp.json
    printf 'name: covenant\nrun: bash .githooks/covenant.sh\n' > .github/workflows/covenant.yml
    printf ".claude/session_state.json\n.claude/session_spend.tmp\n.claude/git_cache.json\n.claude/checkpoints/\n__pycache__/\n*.pyc\n" > .gitignore

    echo "# PRD" > docs/PRD.md
    echo "# TRD" > docs/TRD.md
    echo "# DB Schema" > docs/DB_SCHEMA.md
    echo "# User Flows" > docs/USER_FLOWS.md
    echo "# System Design" > docs/SYSTEM_DESIGN.md
    echo "# ADRs" > docs/ARCHITECTURE_DECISIONS.md
    echo "# CLAUDE.md constitution" > CLAUDE.md
    echo "real app code" > src/domain/__init__.py
    echo "more real code" > src/application/service.py
    echo "def test_x(): pass" > tests/test_x.py

    git add -A
    git commit -q -m "chore: simulate fully-initialized repo" --no-verify

    # Isolation wrapper — see file header. FAKE_HOME/FAKE_BIN live outside
    # TEST_REPO (teardown() only removes TEST_REPO) so they're cleaned up
    # explicitly below.
    FAKE_HOME="$(mktemp -d "${TMPDIR:-/tmp}/uninstall-fakehome-XXXXXX")"
    mkdir -p "$FAKE_HOME/.claude"
    FAKE_BIN="$(mktemp -d "${TMPDIR:-/tmp}/uninstall-fakebin-XXXXXX")"
    cat > "${FAKE_BIN}/pipx" << 'EOF'
#!/bin/bash
# No-op stub: always reports nothing installed, so uninstall.sh's real pipx
# removal branch never has anything to act on during tests.
if [ "$1" = "list" ]; then
    echo "nothing installed (test stub)"
fi
exit 0
EOF
    chmod +x "${FAKE_BIN}/pipx"

    UNINSTALL_WRAPPER="${TEST_REPO}/.uninstall_wrapper.sh"
    {
        echo "#!/bin/bash"
        echo "export HOME='${FAKE_HOME}'"
        echo "export PATH='${FAKE_BIN}:${PATH}'"
        # These tests verify removal completeness, not staleness detection
        # (that's uninstall_bash_compat.bats's job) — skip the real network
        # attempt entirely rather than pay its cost on every single case.
        echo "export COVENANT_SKIP_STALENESS_CHECK=1"
        echo "exec bash '${UNINSTALL_SRC}'"
    } > "$UNINSTALL_WRAPPER"
    chmod +x "$UNINSTALL_WRAPPER"
}

teardown() {
    [ -n "${TEST_REPO:-}" ] && [ -d "$TEST_REPO" ] && rm -rf "$TEST_REPO"
    [ -n "${FAKE_HOME:-}" ] && [ -d "$FAKE_HOME" ] && rm -rf "$FAKE_HOME"
    [ -n "${FAKE_BIN:-}" ] && [ -d "$FAKE_BIN" ] && rm -rf "$FAKE_BIN"
}

@test "manifest scan detects verify_governance_integrity.sh, all docs/ specs, and lists src/ as untouched (not removable)" {
    run run_with_pty "$UNINSTALL_WRAPPER" "n"
    echo "$output" | grep -q '\.githooks/verify_governance_integrity\.sh'
    echo "$output" | grep -q "docs/ spec files: found 6"
    echo "$output" | grep -q "docs/PRD.md"
    echo "$output" | grep -q "docs/ARCHITECTURE_DECISIONS.md"
    echo "$output" | grep -q "NOT touched, on purpose"
    if echo "$output" | grep -q "• src/domain"; then return 1; fi
}

@test "confirming removal deletes verify_governance_integrity.sh and the now-empty .githooks/ directory" {
    run run_with_pty "$UNINSTALL_WRAPPER" "y" "n" "n"
    [ "$status" -eq 0 ]
    [ ! -f ".githooks/verify_governance_integrity.sh" ]
    [ ! -f ".githooks/covenant.sh" ]
    [ ! -d ".githooks" ]
}

@test "declining the docs/ prompt keeps the spec files" {
    run run_with_pty "$UNINSTALL_WRAPPER" "y" "n" "n"
    [ "$status" -eq 0 ]
    [ -f "docs/PRD.md" ]
    [ -f "docs/ARCHITECTURE_DECISIONS.md" ]
}

@test "confirming the docs/ prompt removes all spec files and the now-empty docs/ directory" {
    run run_with_pty "$UNINSTALL_WRAPPER" "y" "n" "y"
    [ "$status" -eq 0 ]
    [ ! -f "docs/PRD.md" ]
    [ ! -f "docs/TRD.md" ]
    [ ! -f "docs/DB_SCHEMA.md" ]
    [ ! -f "docs/USER_FLOWS.md" ]
    [ ! -f "docs/SYSTEM_DESIGN.md" ]
    [ ! -f "docs/ARCHITECTURE_DECISIONS.md" ]
    [ ! -d "docs" ]
}

@test "src/ application code and tests/ are never touched regardless of answers given" {
    run run_with_pty "$UNINSTALL_WRAPPER" "y" "y" "y"
    [ "$status" -eq 0 ]
    [ -f "src/domain/__init__.py" ]
    [ -f "src/application/service.py" ]
    [ -f "tests/test_x.py" ]
    run cat src/domain/__init__.py
    [ "$output" = "real app code" ]
}

@test "CLAUDE.md is kept when its separate confirmation is declined" {
    run run_with_pty "$UNINSTALL_WRAPPER" "y" "n" "n"
    [ "$status" -eq 0 ]
    [ -f "CLAUDE.md" ]
}

@test "CLAUDE.md is removed only when its separate confirmation is explicitly accepted" {
    run run_with_pty "$UNINSTALL_WRAPPER" "y" "y" "n"
    [ "$status" -eq 0 ]
    [ ! -f "CLAUDE.md" ]
}

@test "the new .gitignore entries (__pycache__/, *.pyc) are cleaned up alongside the original four" {
    run run_with_pty "$UNINSTALL_WRAPPER" "y" "n" "n"
    [ "$status" -eq 0 ]
    run grep -c "__pycache__/\|\*\.pyc\|\.claude/session_state\.json" .gitignore
    [ "$status" -eq 1 ]
}

@test "declining the main confirmation removes nothing" {
    run run_with_pty "$UNINSTALL_WRAPPER" "n"
    [ "$status" -eq 0 ]
    [ -f ".githooks/covenant.sh" ]
    [ -f "CLAUDE.md" ]
    [ -f "docs/PRD.md" ]
    [ -f ".claude/covenant_state.json" ]
}

@test "removal is idempotent: running uninstall.sh a second time reports nothing to remove" {
    run run_with_pty "$UNINSTALL_WRAPPER" "y" "y" "y"
    [ "$status" -eq 0 ]
    [ ! -f ".claude/covenant_state.json" ]
    run bash "$UNINSTALL_WRAPPER"
    [ "$status" -eq 1 ]
    echo "$output" | grep -q "No governed repo detected"
}

@test "global resources are never touched: the real ~/.claude/org_policy.json and pipx install are untouched by a full run" {
    REAL_ORG_POLICY="${HOME}/.claude/org_policy.json"
    REAL_ORG_POLICY_BEFORE=""
    [ -f "$REAL_ORG_POLICY" ] && REAL_ORG_POLICY_BEFORE=$(cat "$REAL_ORG_POLICY")
    run run_with_pty "$UNINSTALL_WRAPPER" "y" "y" "y"
    [ "$status" -eq 0 ]
    if [ -n "$REAL_ORG_POLICY_BEFORE" ]; then
        [ -f "$REAL_ORG_POLICY" ]
        run cat "$REAL_ORG_POLICY"
        [ "$output" = "$REAL_ORG_POLICY_BEFORE" ]
    fi
}
