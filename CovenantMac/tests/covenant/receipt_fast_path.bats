load test_helper

setup() {
    setup_covenant_repo
}

teardown() {
    teardown_covenant_repo
}

@test "pre-push receipt fast-path skips mechanical re-run" {
    echo "change" > NOTES.md
    git add NOTES.md
    run_covenant COVENANT_TRIGGER=pre-commit >/dev/null 2>&1
    git commit -q -m "feat: notes"

    run run_covenant COVENANT_TRIGGER=pre-push
    [ "$status" -eq 0 ]
    [[ "$output" == *"receipt verified"* ]]
}
