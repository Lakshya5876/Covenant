load test_helper

# Regression: verify_governance_integrity.sh previously ran only in CI
# (ci-covenant.yml) — never from pre-commit, pre-push, or covenant.sh
# itself. Editing a governance file without regenerating
# .claude/covenant_integrity.sha256 in the same commit passed every local
# commit/push cleanly and only surfaced days later at the next CI run,
# disconnected in time from the edit that actually caused it. covenant.sh's
# new STEP 1.6 runs the same check locally, at commit time, so the drift is
# caught in the exact commit that introduced it.

setup() {
    setup_covenant_repo
    deploy_bash_guard
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
    git add .
    git commit -q -m "scaffold with a fresh, matching integrity manifest"
}

teardown() {
    teardown_covenant_repo
}

@test "STEP 1.6 passes locally when the manifest matches every governance file's current content" {
    echo "x" > note.txt
    git add note.txt
    run run_covenant COVENANT_TRIGGER=pre-commit
    [ "$status" -eq 0 ]
    [[ "$output" == *"COVENANT PASS"* ]]
}

@test "STEP 1.6 blocks locally when covenant.sh is edited without regenerating the manifest" {
    echo "# a governance edit with no matching hash regen" >> .githooks/covenant.sh
    git add .githooks/covenant.sh
    run run_covenant COVENANT_TRIGGER=pre-commit
    [ "$status" -eq 1 ]
    [[ "$output" == *"do not match the pinned integrity manifest"* ]]
}

@test "STEP 1.6 blocks locally when the Bash-guard hook is edited without regenerating the manifest" {
    echo "# tampered" >> .claude/hooks/pre_bash_trust_root_guard.sh
    git add .claude/hooks/pre_bash_trust_root_guard.sh
    run run_covenant COVENANT_TRIGGER=pre-commit
    [ "$status" -eq 1 ]
    [[ "$output" == *"do not match the pinned integrity manifest"* ]]
}

@test "STEP 1.6 is a no-op before the manifest exists yet (cold-start / not-yet-installed)" {
    rm .claude/covenant_integrity.sha256
    echo "x" > note.txt
    git add note.txt
    run run_covenant COVENANT_TRIGGER=pre-commit
    [ "$status" -eq 0 ]
    [[ "$output" == *"COVENANT PASS"* ]]
}

@test "STEP 1.6 runs before STEP 5's secrets scan, catching drift even on an otherwise-clean commit" {
    echo "# a governance edit with no matching hash regen" >> .githooks/pre-commit
    git add .githooks/pre-commit
    run run_covenant COVENANT_TRIGGER=pre-commit
    [ "$status" -eq 1 ]
    [[ "$output" == *"do not match the pinned integrity manifest"* ]]
    [[ "$output" != *"Potential secret"* ]]
}
