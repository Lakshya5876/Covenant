load test_helper

setup() {
    setup_covenant_repo
}

teardown() {
    teardown_covenant_repo
}

@test "cold start: last_pass_sha null emits cold scan mode" {
    echo "docs only" > NOTES.md
    git add NOTES.md
    output="$(run_covenant COVENANT_TRIGGER=pre-commit 2>&1)" || true
    [[ "$output" == *"cold start"* ]]
    [[ "$output" == *"scope=cold"* ]]
}
