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
with open('.claude/covenant_receipts.json') as f:
    d = json.load(f)
assert d.get('receipts', {}).get('$tree', {}).get('outcome') == 'pass'
print('receipt ok')
"
}

@test "receipts live in a separate gitignored file, never in covenant_state.json" {
    # Regression: receipts used to live inside covenant_state.json itself —
    # a real, confirmed bug. A receipt is keyed by the tree hash of the
    # commit it describes, and covenant_state.json is part of that same
    # tree, so writing the receipt into it changes its own hash out from
    # under itself (a circular dependency, not a style choice).
    echo "receipt" > NOTES.md
    git add NOTES.md
    run_covenant COVENANT_TRIGGER=pre-commit >/dev/null 2>&1
    git commit -q -m "feat: receipt test"

    run python3 -c "
import json
with open('.claude/covenant_state.json') as f:
    d = json.load(f)
assert 'receipts' not in d
"
    [ "$status" -eq 0 ]
}

@test "covenant_state.json is not left dirty in the working tree after a clean commit" {
    # The actual bug this whole split exists to fix: covenant_state.json
    # used to be left permanently modified-but-unstaged after every commit
    # (the ledger write happens after git snapshots the index), which could
    # even block an ordinary `git checkout` to another branch. It must come
    # back clean after a normal commit now.
    echo "receipt" > NOTES.md
    git add NOTES.md
    run_covenant COVENANT_TRIGGER=pre-commit >/dev/null 2>&1
    git commit -q -m "feat: receipt test"

    run git status --porcelain .claude/covenant_state.json
    [ "$status" -eq 0 ]
    [ -z "$output" ]
}

@test "the receipt's tree hash matches the actual final committed tree, not a stale pre-restage snapshot" {
    # The subtler bug the naive fix (just re-stage covenant_state.json)
    # would have introduced: if the receipt is keyed by a tree hash computed
    # BEFORE covenant_state.json gets re-staged with its own ledger update,
    # the receipt silently never matches what pre-push later computes from
    # the real HEAD^{tree} -- defeating the fast path on every single
    # commit. This is exactly what the STEP 8 recompute-after-restage fixes.
    echo "receipt" > NOTES.md
    git add NOTES.md
    run_covenant COVENANT_TRIGGER=pre-commit >/dev/null 2>&1
    git commit -q -m "feat: receipt test"

    real_tree="$(git rev-parse 'HEAD^{tree}')"
    run python3 -c "
import json
with open('.claude/covenant_receipts.json') as f:
    d = json.load(f)
assert d['receipts']['$real_tree']['outcome'] == 'pass'
"
    [ "$status" -eq 0 ]
}
