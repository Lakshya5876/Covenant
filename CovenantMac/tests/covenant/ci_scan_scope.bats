load test_helper

# Verifies the fix for a real bug found via adversarial E2E testing: in a CI
# checkout, nothing is ever staged (the working tree is placed directly at
# HEAD with an empty index), so covenant.sh's normal cold-start path
# ("git diff --cached --name-only") was unconditionally empty regardless of
# what a PR/push actually changed — the CI covenant silently reported PASS having
# scanned zero files. ci-covenant.yml now resolves a CI_BASE_SHA (PR base sha, or
# the push's previous HEAD) and covenant.sh diffs against that instead when
# COVENANT_TRIGGER=ci. When no base is resolvable at all (e.g. a brand-new
# branch's first push reports an all-zeros "before" SHA), it fails SAFE by
# scanning the entire tracked tree rather than fail-open by scanning nothing.

setup() {
    setup_covenant_repo
}

teardown() {
    teardown_covenant_repo
}

@test "CI mode diffs against CI_BASE_SHA instead of the always-empty --cached cold-start path" {
    BASE_SHA=$(git rev-parse HEAD)
    echo "changed" >> README.md
    git add README.md
    git commit -q -m "second commit"
    run run_covenant COVENANT_TRIGGER=ci "CI_BASE_SHA=${BASE_SHA}"
    echo "$output" | grep -q "COVENANT: ci mode — diffing against base ${BASE_SHA}"
}

@test "CI cold start with no CI_BASE_SHA set falls back to a full-tree scan, not a silent no-op" {
    run run_covenant COVENANT_TRIGGER=ci
    echo "$output" | grep -q "scanning entire tree"
}

@test "CI cold start with an unresolvable CI_BASE_SHA (all-zeros 'before', new branch's first push) falls back to a full-tree scan" {
    run run_covenant COVENANT_TRIGGER=ci "CI_BASE_SHA=0000000000000000000000000000000000000000"
    echo "$output" | grep -q "scanning entire tree"
}

@test "non-CI COVENANT_TRIGGER is unaffected — cold start still uses --cached, ignoring any CI_BASE_SHA" {
    BASE_SHA=$(git rev-parse HEAD)
    run run_covenant COVENANT_TRIGGER=pre-commit "CI_BASE_SHA=${BASE_SHA}"
    echo "$output" | grep -q "COVENANT: cold start — full scan"
}

# Regression for a real, severe, previously-undiscovered bug found by running
# the actual ci-covenant.yml workflow via act against a real
# actions/checkout@v4 checkout: STEP 5's secrets scan hardcoded
# `git diff --cached`, completely independent of the CI_BASE_SHA-aware scope
# resolved above. A CI checkout never has anything staged, so the secrets
# scan silently found nothing in every CI run, regardless of what the
# CI_BASE_SHA..HEAD diff actually contained — meaning the CI backstop never
# actually caught a secret pushed straight to a protected branch with local
# hooks bypassed, the exact scenario ci-covenant.yml's own header comment
# says it exists to catch. Every existing secrets_block.bats test only
# exercises COVENANT_TRIGGER=pre-commit, where `--cached` happens to be
# correct — none of them would have caught this.
@test "CI mode secrets scan catches a secret introduced between CI_BASE_SHA and HEAD (not just --cached, which is always empty in CI)" {
    BASE_SHA=$(git rev-parse HEAD)
    printf 'api_key = "sk_live_dummy1234567890123456"\n' > config.py
    git add config.py
    git commit -q -m "add a secret, simulating a hook-bypassed local commit"
    run run_covenant COVENANT_TRIGGER=ci "CI_BASE_SHA=${BASE_SHA}"
    [ "$status" -eq 1 ]
    [[ "$output" == *"COVENANT BLOCK: Potential secret"* ]]
}

@test "CI cold start (no resolvable base) secrets scan catches a secret already committed to the tree, not just new diff lines" {
    printf 'api_key = "sk_live_dummy1234567890123456"\n' > config.py
    git add config.py
    git commit -q -m "add a secret"
    run run_covenant COVENANT_TRIGGER=ci
    [ "$status" -eq 1 ]
    [[ "$output" == *"COVENANT BLOCK: Potential secret"* ]]
}

@test "pre-push incremental scan secrets scan catches a secret committed since the last pass (not just --cached, which is empty by the time pre-push runs)" {
    BASE_SHA=$(git rev-parse HEAD)
    # Simulate a prior passing run at BASE_SHA having advanced the ledger.
    python3 -c "
import json
with open('.claude/covenant_state.json') as f:
    d = json.load(f)
d.setdefault('last_pass_sha', {})['feature/covenant-test'] = '$BASE_SHA'
with open('.claude/covenant_state.json', 'w') as f:
    json.dump(d, f)
"
    printf 'api_key = "sk_live_dummy1234567890123456"\n' > config.py
    git add config.py
    git commit -q -m "add a secret, simulating a hook-bypassed local commit"
    run run_covenant COVENANT_TRIGGER=pre-push
    [ "$status" -eq 1 ]
    [[ "$output" == *"COVENANT BLOCK: Potential secret"* ]]
}

@test "pre-push cold start (no resolvable base) secrets scan catches a secret already committed, not just an empty --cached diff" {
    printf 'api_key = "sk_live_dummy1234567890123456"\n' > config.py
    git add config.py
    git commit -q -m "add a secret"
    run run_covenant COVENANT_TRIGGER=pre-push
    [ "$status" -eq 1 ]
    [[ "$output" == *"COVENANT BLOCK: Potential secret"* ]]
}

# Regression for a second real bug found the same way: actions/checkout@v4
# checks out a real named branch (not detached HEAD) for a push event, so
# STEP 1's branch guard — unconditional before this fix — fired on every
# single ci-covenant.yml push-trigger run against main/master/develop
# (exactly the branches the workflow is configured to run on), before the
# real mechanical checks ever ran. That made the push-triggered CI backstop
# permanently failing for every legitimate PR merge, and meaningless as a
# backstop for the direct-push-bypass case it exists to catch (the branch
# guard blocked first, for the wrong reason, every time).
@test "CI mode does not trigger the protected-branch guard — only pre-commit/pre-push do (a real CI checkout is legitimately on that branch)" {
    git checkout -q -b main-standin
    git branch -M main-standin main 2>/dev/null || git branch -m main
    run run_covenant COVENANT_TRIGGER=ci
    [[ "$output" != *"BRANCH BLOCK"* ]]
}

@test "pre-commit on a protected branch is still blocked (CI exemption does not weaken the local guard)" {
    git checkout -q -b main-standin
    git branch -m main
    run run_covenant COVENANT_TRIGGER=pre-commit
    [ "$status" -eq 1 ]
    [[ "$output" == *"BRANCH BLOCK"* ]]
}
