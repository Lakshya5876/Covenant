load test_helper

# Regression coverage for a real red-team finding: covenant.sh's cold-start scan
# scope (no last_pass_sha recorded for this branch — a fresh clone, brand
# new branch, or a wiped covenant_state.json ledger) computed CHANGED_FILES via
# `git diff --cached --name-only` even at COVENANT_TRIGGER=pre-push. That's
# correct for pre-commit (files are staged at that point) but wrong for
# pre-push: by the time pre-push runs, the commit has already landed and the
# index is clean, so `--cached` is unconditionally empty regardless of what
# the push actually contains. HAS_BACKEND/HAS_FRONTEND then evaluated false,
# silently skipping lint/type/complexity/layer-boundary for the entire push
# while still printing "COVENANT PASS: all checks clean". Fixed by scanning the
# whole tracked tree (git ls-files) on a pre-push cold start, matching the
# CI cold-start philosophy.

setup() {
    setup_covenant_repo
}

teardown() {
    teardown_covenant_repo
}

@test "pre-push cold start (no last_pass_sha) scans the whole tree, not an empty --cached diff" {
    mkdir -p app/services
    cat > app/services/billing.py <<'EOF'
from fastapi import HTTPException

def charge():
    raise HTTPException(status_code=400, detail="bad")
EOF
    git add app/services/billing.py
    git commit -q -m "feat: add billing service with a real layer violation"

    # A pre-existing checkpoint sidesteps the unrelated pre-push
    # agent-checkpoint check (STEP 4.6) — this test is about scan scope, not
    # agent-checkpoint enforcement. Needed unconditionally: this bats suite
    # may itself be running inside a live Claude Code session, whose process
    # tree the agent-detection fallback can see regardless of CLAUDECODE
    # (see agent_detection.bats's own "a genuinely agent-free process tree
    # isn't achievable here" skip note for the same underlying constraint).
    mkdir -p .claude/checkpoints
    echo "# checkpoint" > .claude/checkpoints/LATEST.md

    # No last_pass_sha recorded for this branch in covenant_state.json (fresh
    # ledger, as setup_covenant_repo leaves it) — this is the cold-start path.
    run run_covenant COVENANT_TRIGGER=pre-push \
        LINT_CMD='true' TYPE_CMD='true' COMPLEXITY_CMD='true' TEST_CMD='true'
    [ "$status" -eq 1 ]
    [[ "$output" == *"cold start with no resolvable base"* ]]
    [[ "$output" == *"backend=true"* ]]
    [[ "$output" == *"Layer boundary violation"* ]]
    [[ "$output" == *"SERVICE_HAS_HTTP"* ]]
}

@test "pre-commit cold start still uses the staged-files diff (no regression)" {
    echo "docs only" > NOTES.md
    git add NOTES.md
    output="$(run_covenant COVENANT_TRIGGER=pre-commit 2>&1)" || true
    [[ "$output" == *"cold start — full scan"* ]]
    [[ "$output" != *"cold start with no resolvable base"* ]]
}

@test "ci cold start behavior is unchanged (still ls-files, own message)" {
    mkdir -p app/services
    cat > app/services/billing.py <<'EOF'
from fastapi import HTTPException
EOF
    git add app/services/billing.py
    git commit -q -m "feat: ci cold start test"
    run run_covenant COVENANT_TRIGGER=ci \
        LINT_CMD='true' TYPE_CMD='true' COMPLEXITY_CMD='true' TEST_CMD='true'
    [ "$status" -eq 1 ]
    [[ "$output" == *"ci cold start with no resolvable base"* ]]
}
