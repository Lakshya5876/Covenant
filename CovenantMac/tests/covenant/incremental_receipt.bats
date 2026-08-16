load test_helper

setup() {
    setup_covenant_repo
}

teardown() {
    teardown_covenant_repo
}

@test "incremental: after ledger advance uses incremental scan mode" {
    echo "first" > NOTES.md
    git add NOTES.md
    run_covenant COVENANT_TRIGGER=pre-commit >/dev/null 2>&1

    echo "second" >> NOTES.md
    git add NOTES.md
    output="$(run_covenant COVENANT_TRIGGER=pre-commit 2>&1)" || true
    [[ "$output" == *"scope=incremental"* ]]
}

@test "incremental: successful pass writes receipt for pre-push verification" {
    echo "receipt" > NOTES.md
    git add NOTES.md
    run_covenant COVENANT_TRIGGER=pre-commit >/dev/null 2>&1
    git commit -q -m "feat: receipt test"

    tree="$(git rev-parse 'HEAD^{tree}')"
    python3 -c "
import json
with open('.claude/covenant_state.json') as f:
    d = json.load(f)
assert d.get('receipts', {}).get('$tree', {}).get('outcome') == 'pass'
print('receipt ok')
"
}
