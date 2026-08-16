load test_helper

setup() {
    setup_covenant_repo
    python3 - <<'PY'
import json
with open(".claude/covenant_state.json") as f:
    d = json.load(f)
d["core_files"] = ["app/config.py"]
with open(".claude/covenant_state.json", "w") as f:
    json.dump(d, f, indent=2)
PY
    mkdir -p app
}

teardown() {
    teardown_covenant_repo
}

@test "CORE_FILES touch forces tier-3 and mandatory tests at pre-commit" {
    echo "DEBUG=true" > app/config.py
    git add app/config.py
    run run_covenant COVENANT_TRIGGER=pre-commit \
        LINT_CMD='true' \
        TYPE_CMD='true' \
        COMPLEXITY_CMD='true' \
        TEST_CMD='echo tier3-forced; exit 1'
    [ "$status" -eq 1 ]
    [[ "$output" == *"TIER-3"* ]]
    [[ "$output" == *"tier3-forced"* ]]
}

@test "coverage threshold blocks when COVERAGE_CMD reports below threshold" {
    echo "change" > NOTES.md
    git add NOTES.md
    run run_covenant COVENANT_TRIGGER=pre-commit \
        RUN_TESTS=true \
        TEST_CMD='true' \
        COVERAGE_CMD='echo "TOTAL 42%"'
    [ "$status" -eq 1 ]
    [[ "$output" == *"COVENANT BLOCK: coverage"* ]]
}

@test "coverage threshold passes when COVERAGE_CMD meets threshold" {
    echo "change" > NOTES.md
    git add NOTES.md
    run run_covenant COVENANT_TRIGGER=pre-commit \
        RUN_TESTS=true \
        TEST_CMD='true' \
        COVERAGE_CMD='echo "TOTAL 91%"'
    [ "$status" -eq 0 ]
    [[ "$output" == *"coverage 91%"* ]]
}
