load test_helper

# Pins a real bug found via an actual end-to-end `git commit` test (not by
# inspection): _json_append_audit had no [ -f "$COVENANT_STATE" ] guard, unlike
# every other COVENANT_STATE-touching function. When covenant_state.json was
# missing, the LAST call in covenant.sh's success path (_json_append_audit ...
# "pass", right before "COVENANT PASS" prints) raised an unguarded
# FileNotFoundError inside set -e, silently aborting the whole script — a
# commit that passed every real check (lint, type check, layer boundary,
# complexity) still failed, with a raw Python traceback instead of a clear
# message.

setup() {
    setup_covenant_repo
}

teardown() {
    teardown_covenant_repo
}

@test "covenant.sh reaches COVENANT PASS even when covenant_state.json is missing" {
    [ ! -f ".claude/covenant_state.json" ] || mv .claude/covenant_state.json /tmp/covenant_state_moved_aside.json

    echo "def add(a, b): return a + b" > helper.py
    git add helper.py
    run run_covenant COVENANT_TRIGGER=pre-commit \
        LINT_CMD='true' TYPE_CMD='true' COMPLEXITY_CMD='true' TEST_CMD='true'

    [ "$status" -eq 0 ]
    [[ "$output" == *"COVENANT PASS"* ]]
    [[ "$output" != *"Traceback"* ]]
    [[ "$output" != *"FileNotFoundError"* ]]

    [ -f "/tmp/covenant_state_moved_aside.json" ] && mv /tmp/covenant_state_moved_aside.json .claude/covenant_state.json
}

@test "a real git commit succeeds when covenant_state.json is missing (end-to-end, not just covenant.sh in isolation)" {
    mv .claude/covenant_state.json /tmp/covenant_state_moved_aside2.json

    echo "def multiply(a, b): return a * b" > helper2.py
    git add helper2.py
    TEST_CMD='true' LINT_CMD='true' TYPE_CMD='true' COMPLEXITY_CMD='true' run git commit -m "feat: add helper2"

    [ "$status" -eq 0 ]
    run git log --oneline -1
    [[ "$output" == *"add helper2"* ]]

    mv /tmp/covenant_state_moved_aside2.json .claude/covenant_state.json
}

@test "audit log is simply skipped (not fabricated) when covenant_state.json is missing" {
    mv .claude/covenant_state.json /tmp/covenant_state_moved_aside3.json

    echo "def sub(a, b): return a - b" > helper3.py
    git add helper3.py
    run run_covenant COVENANT_TRIGGER=pre-commit \
        LINT_CMD='true' TYPE_CMD='true' COMPLEXITY_CMD='true' TEST_CMD='true'
    [ "$status" -eq 0 ]
    [ ! -f ".claude/covenant_state.json" ]

    mv /tmp/covenant_state_moved_aside3.json .claude/covenant_state.json
}
