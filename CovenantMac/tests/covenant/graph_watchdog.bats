load test_helper

# _ensure_graph_alive resilience tests. code-review-graph itself is not
# installed in CI/dev sandboxes, so these tests supply a fake binary on PATH
# that behaves just enough like the real thing (accepts `build`/`serve`,
# shows up as "code-review-graph" in `ps -o command=`) to exercise covenant.sh's
# own watchdog logic — they do not (and cannot) test code-review-graph's
# actual internals.

setup() {
    setup_covenant_repo
    mkdir -p .fakebin
    cat > .fakebin/code-review-graph <<'EOF'
#!/usr/bin/env bash
case "$1" in
    build) exit 0 ;;
    serve) sleep 60 ;;
    *) exit 0 ;;
esac
EOF
    chmod +x .fakebin/code-review-graph
    export PATH="${TEST_REPO}/.fakebin:${PATH}"
    echo '{"mcpServers": {"code-review-graph": {"command": "code-review-graph", "args": ["serve"]}}}' > .mcp.json
    git add .mcp.json
    git commit -q -m "chore: add mcp config"
}

teardown() {
    if [ -n "${FAKE_SERVER_PID:-}" ]; then
        kill -9 "$FAKE_SERVER_PID" 2>/dev/null || true
    fi
    teardown_covenant_repo
}

_commit_non_graph_file() {
    # A .md change never matches _ensure_graph_freshness's extension filter,
    # so freshness's own kill-and-restart path stays out of the way and the
    # watchdog's behavior can be observed in isolation.
    echo "note" >> README.md
    git add README.md
    git commit -q -m "docs: unrelated change"
}

@test "watchdog relaunches a build whose PID died without its cleanup running" {
    _commit_non_graph_file
    ( exit 0 ) &
    dead_pid=$!
    wait "$dead_pid" 2>/dev/null || true
    echo "$dead_pid" > .claude/graph.pid

    run run_covenant COVENANT_TRIGGER=pre-push \
        LINT_CMD='true' TYPE_CMD='true' COMPLEXITY_CMD='true' TEST_CMD='true'
    [ "$status" -eq 0 ]
    [[ "$output" == *"[GRAPH GUARD] code-review-graph build crashed"* ]]
    [[ "$output" == *"restarting (attempt 1/3)"* ]]
    restart_count=$(python3 -c "import json; print(json.load(open('.claude/covenant_state.json'))['mcp_graph']['restart_count'])")
    [ "$restart_count" -eq 1 ]
}

@test "watchdog leaves a genuinely live code-review-graph process alone" {
    _commit_non_graph_file
    code-review-graph serve &
    FAKE_SERVER_PID=$!
    sleep 0.2
    echo "$FAKE_SERVER_PID" > .claude/graph.pid

    run run_covenant COVENANT_TRIGGER=pre-push \
        LINT_CMD='true' TYPE_CMD='true' COMPLEXITY_CMD='true' TEST_CMD='true'
    [ "$status" -eq 0 ]
    [[ "$output" != *"[GRAPH GUARD]"* ]]
}

@test "watchdog treats a PID reused by an unrelated process as crashed" {
    _commit_non_graph_file
    sleep 60 &
    FAKE_SERVER_PID=$!
    sleep 0.2
    echo "$FAKE_SERVER_PID" > .claude/graph.pid

    run run_covenant COVENANT_TRIGGER=pre-push \
        LINT_CMD='true' TYPE_CMD='true' COMPLEXITY_CMD='true' TEST_CMD='true'
    [ "$status" -eq 0 ]
    [[ "$output" == *"reused by unrelated process — treating as crashed"* ]]
    [[ "$output" == *"restarting (attempt 1/3)"* ]]
}

@test "watchdog does not run at pre-commit — only pre-push" {
    ( exit 0 ) &
    dead_pid=$!
    wait "$dead_pid" 2>/dev/null || true
    echo "$dead_pid" > .claude/graph.pid
    echo "note" >> README.md
    git add README.md .claude/graph.pid

    run run_covenant COVENANT_TRIGGER=pre-commit \
        LINT_CMD='true' TYPE_CMD='true' COMPLEXITY_CMD='true' TEST_CMD='true'
    [ "$status" -eq 0 ]
    [[ "$output" != *"[GRAPH GUARD]"* ]]
}

@test "watchdog caps restarts at 3 within a 24h window and surfaces a warning" {
    _commit_non_graph_file
    now_iso=$(date -u +%Y-%m-%dT%H:%M:%SZ)
    python3 -c "
import json
with open('.claude/covenant_state.json') as f: d = json.load(f)
d['mcp_graph']['restart_count'] = 3
d['mcp_graph']['restart_last_ts'] = '$now_iso'
with open('.claude/covenant_state.json', 'w') as f: json.dump(d, f, indent=2)
"
    ( exit 0 ) &
    dead_pid=$!
    wait "$dead_pid" 2>/dev/null || true
    echo "$dead_pid" > .claude/graph.pid

    run run_covenant COVENANT_TRIGGER=pre-push \
        LINT_CMD='true' TYPE_CMD='true' COMPLEXITY_CMD='true' TEST_CMD='true'
    [ "$status" -eq 0 ]
    [[ "$output" == *"auto-restart capped at 3"* ]]
    [[ "$output" != *"restarting (attempt"* ]]
    restart_count=$(python3 -c "import json; print(json.load(open('.claude/covenant_state.json'))['mcp_graph']['restart_count'])")
    [ "$restart_count" -eq 3 ]
}

@test "watchdog's restart cap resets after the 24h window elapses" {
    _commit_non_graph_file
    python3 -c "
import json
with open('.claude/covenant_state.json') as f: d = json.load(f)
d['mcp_graph']['restart_count'] = 3
d['mcp_graph']['restart_last_ts'] = '2020-01-01T00:00:00Z'
with open('.claude/covenant_state.json', 'w') as f: json.dump(d, f, indent=2)
"
    ( exit 0 ) &
    dead_pid=$!
    wait "$dead_pid" 2>/dev/null || true
    echo "$dead_pid" > .claude/graph.pid

    run run_covenant COVENANT_TRIGGER=pre-push \
        LINT_CMD='true' TYPE_CMD='true' COMPLEXITY_CMD='true' TEST_CMD='true'
    [ "$status" -eq 0 ]
    [[ "$output" == *"restarting (attempt 1/3)"* ]]
    [[ "$output" != *"auto-restart capped"* ]]
}

@test "a successful freshness rebuild resets the restart counter" {
    # Stage a .py change so _ensure_graph_freshness's own extension filter
    # fires and it spawns a fresh build for the current HEAD — at which
    # point any earlier crash count is moot.
    python3 -c "
import json
with open('.claude/covenant_state.json') as f: d = json.load(f)
d['mcp_graph']['restart_count'] = 2
with open('.claude/covenant_state.json', 'w') as f: json.dump(d, f, indent=2)
"
    mkdir -p app
    echo "x = 1" > app/main.py
    git add app/main.py

    run run_covenant COVENANT_TRIGGER=pre-commit \
        LINT_CMD='true' TYPE_CMD='true' COMPLEXITY_CMD='true' TEST_CMD='true'
    [ "$status" -eq 0 ]
    restart_count=$(python3 -c "import json; print(json.load(open('.claude/covenant_state.json'))['mcp_graph']['restart_count'])")
    [ "$restart_count" -eq 0 ]
}
