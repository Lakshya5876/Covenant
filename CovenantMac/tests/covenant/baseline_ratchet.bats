load test_helper

setup() {
    setup_covenant_repo
    mkdir -p src
    cat > .claude/baseline.json <<'EOF'
{
  "populated": true,
  "lint_findings": ["src/legacy.py|E501"]
}
EOF
}

teardown() {
    teardown_covenant_repo
}

@test "baseline ratchet grandfathers known lint identity" {
    printf 'x=1\n' > src/legacy.py
    git add src/legacy.py
    run run_covenant COVENANT_TRIGGER=pre-commit \
        LINT_CMD='echo "src/legacy.py:1:1: E501 line too long"; exit 1' \
        TYPE_CMD='true' \
        COMPLEXITY_CMD='true' \
        TEST_CMD='true'
    [ "$status" -eq 0 ]
    [[ "$output" == *"grandfathered"* ]]
}

@test "baseline ratchet blocks new lint identity" {
    printf 'x=1\n' > src/new_module.py
    git add src/new_module.py
    run run_covenant COVENANT_TRIGGER=pre-commit \
        LINT_CMD='echo "src/new_module.py:1:1: E999 new violation"; exit 1' \
        TYPE_CMD='true' \
        COMPLEXITY_CMD='true' \
        TEST_CMD='true'
    [ "$status" -eq 1 ]
    [[ "$output" == *"new lint findings not in baseline"* ]]
}
