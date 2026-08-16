load test_helper

setup() {
    setup_covenant_repo
}

teardown() {
    teardown_covenant_repo
}

@test "expired bypass note blocks pre-push clock check" {
    OLD_EPOCH=$(( $(date +%s) - 90000 ))
    git notes --ref=refs/notes/bypasses add -m "BYPASS | date=${OLD_EPOCH} | reason=test expired" HEAD
    run run_pre_push_hook
    [ "$status" -eq 1 ]
    [[ "$output" == *"Bypass deadline expired"* ]]
}

@test "active bypass note within 24h allows pre-push clock check" {
    NOW_EPOCH=$(date +%s)
    git notes --ref=refs/notes/bypasses add -m "BYPASS | date=${NOW_EPOCH} | reason=test active" HEAD
    run run_pre_push_hook
    [ "$status" -eq 0 ]
}
