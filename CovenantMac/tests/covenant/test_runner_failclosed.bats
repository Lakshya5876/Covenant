load test_helper

setup() {
    setup_covenant_repo
    mkdir -p app/services
}

teardown() {
    teardown_covenant_repo
}

@test "backend change with no explicit or inferable test command is hard-blocked" {
    # No pytest.ini/conftest.py/pyproject.toml exists in this fresh repo, so
    # _infer_backend_test_cmd finds nothing either — TEST_RUNNERS stays empty.
    echo "def charge(): pass" > app/services/billing.py
    git add app/services/billing.py
    run run_covenant COVENANT_TRIGGER=pre-commit
    [ "$status" -eq 1 ]
    [[ "$output" == *"CRITICAL"* || "$output" == *"no test runner was found"* ]]
}

@test "docs-only change is never blocked by the missing-test-runner check" {
    # No backend/frontend file touched — HAS_BACKEND and HAS_FRONTEND both
    # stay false, so the check must not fire regardless of TEST_CMD state.
    # This is the exact regression the original (uncorrected) fix would have
    # caused: it would have blocked markdown-only commits like this one.
    echo "docs change" > NOTES.md
    git add NOTES.md
    run run_covenant COVENANT_TRIGGER=pre-commit
    [ "$status" -eq 0 ]
}

@test "backend change with an explicit TEST_CMD is not blocked" {
    echo "def charge(): pass" > app/services/billing.py
    git add app/services/billing.py
    run run_covenant COVENANT_TRIGGER=pre-commit \
        LINT_CMD='true' \
        TYPE_CMD='true' \
        COMPLEXITY_CMD='true' \
        TEST_CMD='true'
    [ "$status" -eq 0 ]
}
