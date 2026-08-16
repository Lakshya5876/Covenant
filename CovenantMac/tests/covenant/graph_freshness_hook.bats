load test_helper

# Verifies both halves of the graph read-time freshness guard:
#   1. install.sh actually writes and registers the hook (mirrors
#      deny_list_coverage.bats's pattern of running the REAL install.sh
#      functions, not a hand-copied mirror).
#   2. templates/graph_freshness_check.py's own staleness detection logic,
#      exercised directly against a real scratch git repo — the same
#      scenarios manually verified during development (stale commit, dirty
#      working tree, fresh index, missing code-review-graph binary).

FRESHNESS_SRC="${FRAMEWORK_ROOT}/templates/graph_freshness_check.py"

setup() {
    TEST_REPO="$(mktemp -d "${TMPDIR:-/tmp}/graph-fresh-XXXXXX")"
    cd "$TEST_REPO" || return 1
    git init -q
    git config user.email t@t.com
    git config user.name t
}

teardown() {
    if [ -n "${TEST_REPO:-}" ] && [ -d "$TEST_REPO" ]; then
        rm -rf "$TEST_REPO"
    fi
    if [ -n "${EXTRACTED_FUNCS_FILE:-}" ] && [ -f "$EXTRACTED_FUNCS_FILE" ]; then
        rm -f "$EXTRACTED_FUNCS_FILE"
    fi
}

@test "install.sh writes and registers the graph freshness hook" {
    extract_install_functions
    _write_hooks
    _write_trust_root_settings "v1_claude_code_development_guide_existing.md" "v1_implementation_package_existing.md"

    [ -f ".claude/hooks/graph_freshness_check.py" ]
    [ -x ".claude/hooks/graph_freshness_check.py" ]

    run python3 -c "
import json
with open('.claude/settings.json') as f:
    hooks = json.load(f)['hooks']['PreToolUse']
matchers = [h.get('matcher') for h in hooks]
assert 'mcp__code-review-graph__.*' in matchers, matchers
entry = next(h for h in hooks if h.get('matcher') == 'mcp__code-review-graph__.*')
assert any('graph_freshness_check.py' in hh['command'] for hh in entry['hooks'])
print('ok')
"
    [ "$status" -eq 0 ]
    [[ "$output" == *"ok"* ]]
}

@test "install.sh hook registration is idempotent across repeated calls" {
    extract_install_functions
    _write_hooks
    _write_trust_root_settings "v1_claude_code_development_guide_existing.md" "v1_implementation_package_existing.md"
    _write_trust_root_settings "v1_claude_code_development_guide_existing.md" "v1_implementation_package_existing.md"

    run python3 -c "
import json
with open('.claude/settings.json') as f:
    hooks = json.load(f)['hooks']['PreToolUse']
matching = [h for h in hooks if h.get('matcher') == 'mcp__code-review-graph__.*']
assert len(matching) == 1, f'expected exactly 1 entry, got {len(matching)}'
print('ok')
"
    [ "$status" -eq 0 ]
    [[ "$output" == *"ok"* ]]
}

@test "freshness check warns on uncommitted changes to indexed-extension files" {
    mkdir -p .claude app
    echo "x = 1" > app/foo.py
    git add app/foo.py
    git commit -q -m "init"
    python3 -c "
import json
from datetime import datetime, timezone
d = {'mcp_graph': {'last_build_timestamp': datetime.now(timezone.utc).strftime('%Y-%m-%dT%H:%M:%SZ')}}
with open('.claude/covenant_state.json', 'w') as f: json.dump(d, f)
"
    echo "y = 2" >> app/foo.py

    run bash -c "echo '{}' | python3 '$FRESHNESS_SRC'"
    [ "$status" -eq 0 ]
    [[ "$output" == *"[GRAPH STALE]"* ]]
    [[ "$output" == *"uncommitted change"* ]]
    [[ "$output" == *"app/foo.py"* ]]
}

@test "freshness check detects a commit made after the last build" {
    mkdir -p .claude app
    echo "x = 1" > app/foo.py
    git add app/foo.py
    git commit -q -m "init"
    python3 -c "
import json
from datetime import datetime, timezone, timedelta
d = {'mcp_graph': {'last_build_timestamp': (datetime.now(timezone.utc) - timedelta(hours=2)).strftime('%Y-%m-%dT%H:%M:%SZ')}}
with open('.claude/covenant_state.json', 'w') as f: json.dump(d, f)
"
    # last_build_timestamp predates the commit above -> STALE_COMMITS
    run bash -c "echo '{}' | python3 '$FRESHNESS_SRC'"
    [ "$status" -eq 0 ]
    [[ "$output" == *"HEAD has moved since the last build"* ]]
}

@test "freshness check does not crash when code-review-graph is not on PATH" {
    mkdir -p .claude app
    echo "x = 1" > app/foo.py
    git add app/foo.py
    git commit -q -m "init"
    python3 -c "
import json
from datetime import datetime, timezone, timedelta
d = {'mcp_graph': {'last_build_timestamp': (datetime.now(timezone.utc) - timedelta(hours=2)).strftime('%Y-%m-%dT%H:%M:%SZ')}}
with open('.claude/covenant_state.json', 'w') as f: json.dump(d, f)
"
    # A bare empty PATH would also break the script's own git/wc subprocess
    # calls (silently, via _run's try/except), which would mask the real
    # behavior under test. Build a minimal PATH instead: symlink just git,
    # wc, and python3 into a private bin dir, so code-review-graph is
    # guaranteed absent while everything the script itself needs still
    # resolves normally, regardless of whether this dev machine happens to
    # have code-review-graph installed elsewhere.
    MINI_BIN="$(mktemp -d "${TMPDIR:-/tmp}/mini-bin-XXXXXX")"
    ln -s "$(command -v git)" "$MINI_BIN/git"
    ln -s "$(command -v wc)" "$MINI_BIN/wc"
    ln -s "$(command -v python3)" "$MINI_BIN/python3"
    run bash -c "echo '{}' | PATH='$MINI_BIN' python3 '$FRESHNESS_SRC'"
    rm -rf "$MINI_BIN"
    [ "$status" -eq 0 ]
    [[ "$output" == *"isn't on PATH to rebuild"* ]]
}

@test "freshness check is silent when the index is genuinely fresh" {
    mkdir -p .claude app
    echo "x = 1" > app/foo.py
    git add app/foo.py
    git commit -q -m "init"
    python3 -c "
import json
from datetime import datetime, timezone
d = {'mcp_graph': {'last_build_timestamp': datetime.now(timezone.utc).strftime('%Y-%m-%dT%H:%M:%SZ')}}
with open('.claude/covenant_state.json', 'w') as f: json.dump(d, f)
"
    run bash -c "echo '{}' | python3 '$FRESHNESS_SRC'"
    [ "$status" -eq 0 ]
    [ -z "$output" ]
}

@test "freshness check no-ops gracefully when covenant_state.json doesn't exist" {
    run bash -c "echo '{}' | python3 '$FRESHNESS_SRC'"
    [ "$status" -eq 0 ]
    [ -z "$output" ]
}
