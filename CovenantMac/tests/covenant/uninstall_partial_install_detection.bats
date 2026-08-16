load test_helper

# Regression coverage for a real red-team finding: uninstall.sh's detection
# gate used to check ONLY `.claude/covenant_state.json` (a gitignored local
# ledger) before agreeing to run at all. A partial/interrupted install, or
# simply a session that ran `rm -rf .claude` mid-work, left every OTHER
# governance artifact in place (.githooks/covenant.sh, CLAUDE.md,
# .claude/settings.json) while covenant_state.json alone was missing — and
# uninstall.sh refused with "No governed repo detected... Nothing to
# remove.", leaving no way to clean up short of hand-deleting files. Fixed
# by detecting via ANY known artifact, not that one file alone.
#
# Reuses uninstall_completeness.bats's HOME/pipx isolation pattern (see that
# file's header for why the isolation is necessary) but with a deliberately
# PARTIAL install so the detection gate itself is what's under test.

UNINSTALL_SRC="${FRAMEWORK_ROOT}/uninstall.sh"

_make_isolated_wrapper() {
    FAKE_HOME="$(mktemp -d "${TMPDIR:-/tmp}/uninstall-detect-fakehome-XXXXXX")"
    mkdir -p "$FAKE_HOME/.claude"
    FAKE_BIN="$(mktemp -d "${TMPDIR:-/tmp}/uninstall-detect-fakebin-XXXXXX")"
    cat > "${FAKE_BIN}/pipx" << 'EOF'
#!/bin/bash
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
        echo "export COVENANT_SKIP_STALENESS_CHECK=1"
        echo "exec bash '${UNINSTALL_SRC}'"
    } > "$UNINSTALL_WRAPPER"
    chmod +x "$UNINSTALL_WRAPPER"
}

setup() {
    TEST_REPO="$(mktemp -d "${TMPDIR:-/tmp}/uninstall-detect-XXXXXX")"
    cd "$TEST_REPO" || return 1
    git init -q
    git config user.email t@t.com
    git config user.name t
    echo "# app" > README.md
    git add -A
    git commit -q -m "init" --no-verify
}

teardown() {
    [ -n "${TEST_REPO:-}" ] && [ -d "$TEST_REPO" ] && rm -rf "$TEST_REPO"
    [ -n "${FAKE_HOME:-}" ] && [ -d "$FAKE_HOME" ] && rm -rf "$FAKE_HOME"
    [ -n "${FAKE_BIN:-}" ] && [ -d "$FAKE_BIN" ] && rm -rf "$FAKE_BIN"
}

@test "refuses to run when truly nothing is installed" {
    _make_isolated_wrapper
    run run_with_pty "$UNINSTALL_WRAPPER"
    [[ "$output" == *"No governed repo detected"* ]]
}

@test "detects a partial install via .githooks/covenant.sh alone (covenant_state.json missing/gitignored)" {
    mkdir -p .githooks
    cp "${FRAMEWORK_ROOT}/templates/covenant.sh" .githooks/covenant.sh
    _make_isolated_wrapper
    run run_with_pty "$UNINSTALL_WRAPPER" "n"
    [[ "$output" != *"No governed repo detected"* ]]
    [[ "$output" == *".githooks/covenant.sh"* ]]
}

@test "detects a partial install via .claude/hooks/pre_bash_trust_root_guard.sh alone" {
    mkdir -p .claude/hooks
    cp "${FRAMEWORK_ROOT}/templates/pre_bash_trust_root_guard.sh" .claude/hooks/pre_bash_trust_root_guard.sh
    _make_isolated_wrapper
    run run_with_pty "$UNINSTALL_WRAPPER" "n"
    [[ "$output" != *"No governed repo detected"* ]]
}

@test "detects a partial install via .claude/settings.json referencing the trust-root guard" {
    mkdir -p .claude
    echo '{"hooks":{"PreToolUse":[{"matcher":"Bash","hooks":[{"type":"command","command":"bash .claude/hooks/pre_bash_trust_root_guard.sh"}]}]}}' > .claude/settings.json
    _make_isolated_wrapper
    run run_with_pty "$UNINSTALL_WRAPPER" "n"
    [[ "$output" != *"No governed repo detected"* ]]
}

@test "still detects the original covenant_state.json-only signal (no regression)" {
    mkdir -p .claude
    cp "${FRAMEWORK_ROOT}/templates/covenant_state.json" .claude/covenant_state.json
    _make_isolated_wrapper
    run run_with_pty "$UNINSTALL_WRAPPER" "n"
    [[ "$output" != *"No governed repo detected"* ]]
}
