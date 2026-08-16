load test_helper

setup() {
    setup_covenant_repo
    # pre_bash_trust_root_guard.sh is not a static template (install.sh
    # interpolates two repo-specific filenames into it) — a minimal stub is
    # sufficient here since these tests exercise the manifest mechanism, not
    # that script's own content.
    mkdir -p .claude/hooks
    echo "#!/usr/bin/env bash" > .claude/hooks/pre_bash_trust_root_guard.sh
    echo "exit 0" >> .claude/hooks/pre_bash_trust_root_guard.sh
    chmod +x .claude/hooks/pre_bash_trust_root_guard.sh

    { sha256sum \
        .githooks/covenant.sh \
        .githooks/verify_governance_integrity.sh \
        .githooks/pre-commit \
        .githooks/pre-push \
        .claude/hooks/pre_bash_trust_root_guard.sh \
        2>/dev/null \
      || shasum -a 256 \
        .githooks/covenant.sh \
        .githooks/verify_governance_integrity.sh \
        .githooks/pre-commit \
        .githooks/pre-push \
        .claude/hooks/pre_bash_trust_root_guard.sh; } > .claude/covenant_integrity.sha256
}

teardown() {
    teardown_covenant_repo
}

@test "CI integrity check passes when every manifest file matches its pinned hash" {
    run run_ci_integrity_check
    [ "$status" -eq 0 ]
    [[ "$output" == *"integrity-verified"* ]]
}

@test "CI integrity check blocks when covenant.sh content diverges from the pinned hash" {
    echo "# a PR silently weakening the covenant" >> .githooks/covenant.sh
    run run_ci_integrity_check
    [ "$status" -eq 1 ]
    [[ "$output" == *"do not match the pinned integrity manifest"* ]]
}

@test "CI integrity check blocks when the Bash-guard hook is tampered with (stealth-neuter case)" {
    # The exact bypass a prior audit found: overwriting the guard script with
    # a no-op while leaving its PreToolUse registration in settings.json
    # untouched. The manifest must catch this the same way it catches a
    # tampered covenant.sh.
    echo "exit 0  # neutered" >> .claude/hooks/pre_bash_trust_root_guard.sh
    run run_ci_integrity_check
    [ "$status" -eq 1 ]
    [[ "$output" == *"do not match the pinned integrity manifest"* ]]
}

@test "CI integrity check blocks when pre-commit or pre-push is tampered with" {
    echo "# tampered" >> .githooks/pre-commit
    run run_ci_integrity_check
    [ "$status" -eq 1 ]
    [[ "$output" == *"do not match the pinned integrity manifest"* ]]
}

@test "CI integrity check blocks when the pin file is missing (stripped, not just stale)" {
    rm .claude/covenant_integrity.sha256
    run run_ci_integrity_check
    [ "$status" -eq 1 ]
    [[ "$output" == *"integrity pin stripped"* ]]
}

@test "CI integrity check blocks when .githooks/covenant.sh itself is missing" {
    rm .githooks/covenant.sh
    run run_ci_integrity_check
    [ "$status" -eq 1 ]
    [[ "$output" == *"do not match the pinned integrity manifest"* ]]
}

@test "CI integrity check blocks when .claude/covenant_state.json is missing" {
    rm .claude/covenant_state.json
    run run_ci_integrity_check
    [ "$status" -eq 1 ]
    [[ "$output" == *".claude/covenant_state.json missing"* ]]
}
