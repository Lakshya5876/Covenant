load test_helper

# Verifies templates/checkpoint_tool.py directly — the mechanical checkpoint
# capture + progressive-disclosure retrieval system. Exercises the real
# script (not a mirror), the same fidelity principle as the rest of this
# suite. See the script's own module docstring for the one documented
# limitation these tests do NOT cover: live Claude Code hook-dispatch
# integration (only the script's own decision logic is verified here).

CKPT="${FRAMEWORK_ROOT}/templates/checkpoint_tool.py"

setup() {
    TEST_REPO="$(mktemp -d "${TMPDIR:-/tmp}/ckpt-tool-XXXXXX")"
    cd "$TEST_REPO" || return 1
    git init -q
    git config user.email t@t.com
    git config user.name t
    mkdir -p .claude app
    echo "x = 1" > app/foo.py
    git add app/foo.py
    git commit -q -m "init"
}

teardown() {
    if [ -n "${TEST_REPO:-}" ] && [ -d "$TEST_REPO" ]; then
        rm -rf "$TEST_REPO"
    fi
}

@test "append writes LATEST.md, a dated file, and an index.jsonl entry" {
    run python3 "$CKPT" append --phase execute --title "t1" --task "do the thing" \
        --decisions "chose X: because Y" --pending "write more" --resume "run tests"
    [ "$status" -eq 0 ]
    [ -f ".claude/checkpoints/LATEST.md" ]
    [[ "$(cat .claude/checkpoints/LATEST.md)" == *"# CHECKPOINT"* ]]
    [[ "$(cat .claude/checkpoints/LATEST.md)" == *"do the thing"* ]]
    [ -f ".claude/checkpoints/index.jsonl" ]
    run python3 -c "import json; e = json.loads(open('.claude/checkpoints/index.jsonl').readline()); assert e['task'] == 'do the thing'; print('ok')"
    [[ "$output" == *"ok"* ]]
    dated_count=$(ls .claude/checkpoints/*.md | grep -v LATEST.md | wc -l)
    [ "$dated_count" -eq 1 ]
}

@test "append prunes dated checkpoints beyond the 10 most recent, but index.jsonl keeps all of them" {
    for i in $(seq 1 12); do
        python3 "$CKPT" append --phase execute --title "checkpoint $i" --task "task $i" >/dev/null
    done
    dated_count=$(ls .claude/checkpoints/*.md | grep -v LATEST.md | wc -l)
    [ "$dated_count" -eq 10 ]
    index_count=$(wc -l < .claude/checkpoints/index.jsonl)
    [ "$index_count" -eq 12 ]
}

@test "hook-session-start announces resume when HEAD matches the last checkpoint's sha" {
    python3 "$CKPT" append --phase execute --title "resume-me" --task "t" --resume "continue the thing" >/dev/null
    run bash -c "echo '{}' | python3 '$CKPT' hook-session-start"
    [ "$status" -eq 0 ]
    [[ "$output" == *"Resuming from checkpoint"* ]]
    [[ "$output" == *"continue the thing"* ]]
}

@test "hook-session-start flags divergence when HEAD no longer matches the last checkpoint" {
    python3 "$CKPT" append --phase execute --title "old" --task "t" >/dev/null
    echo "y = 2" >> app/foo.py
    git add -A && git commit -q -m "second"
    run bash -c "echo '{}' | python3 '$CKPT' hook-session-start"
    [ "$status" -eq 0 ]
    [[ "$output" == *"diverged"* ]]
}

@test "hook-session-start is silent when no checkpoint exists yet" {
    run bash -c "echo '{}' | python3 '$CKPT' hook-session-start"
    [ "$status" -eq 0 ]
    [ -z "$output" ]
}

@test "hook-pre-compact unconditionally appends a fact-only entry" {
    run bash -c "echo '{}' | python3 '$CKPT' hook-pre-compact"
    [ "$status" -eq 0 ]
    run python3 -c "import json; e = json.loads(open('.claude/checkpoints/index.jsonl').readline()); assert e['trigger'] == 'pre_compact_auto'; assert e['git_sha']; print('ok')"
    [[ "$output" == *"ok"* ]]
}

@test "hook-post-bash is a no-op for non-commit commands" {
    run bash -c "echo '{\"tool_input\": {\"command\": \"ls -la\"}}' | python3 '$CKPT' hook-post-bash"
    [ "$status" -eq 0 ]
    [ -z "$output" ]
    [ ! -f ".claude/checkpoints/index.jsonl" ]
}

@test "hook-post-bash records a new commit exactly once, not on repeated calls for the same sha" {
    echo "y = 2" >> app/foo.py
    git add -A && git commit -q -m "second"
    run bash -c "echo '{\"tool_input\": {\"command\": \"git commit -m x\"}}' | python3 '$CKPT' hook-post-bash"
    [[ "$output" == *"commit detected"* ]]
    run bash -c "echo '{\"tool_input\": {\"command\": \"git commit -m x\"}}' | python3 '$CKPT' hook-post-bash"
    [ -z "$output" ]
    commit_count=$(python3 -c "
import json
n = sum(1 for l in open('.claude/checkpoints/index.jsonl') if json.loads(l)['trigger'] == 'post_commit_auto')
print(n)
")
    [ "$commit_count" -eq 1 ]
}

@test "hook-post-write tracks touched files in session_state.json" {
    bash -c "echo '{\"tool_input\": {\"file_path\": \"app/a.py\"}}' | python3 '$CKPT' hook-post-write"
    bash -c "echo '{\"tool_input\": {\"file_path\": \"app/b.py\"}}' | python3 '$CKPT' hook-post-write"
    run python3 -c "
import json
d = json.load(open('.claude/session_state.json'))
touched = d['checkpoint']['files_touched_since_checkpoint']
assert set(touched) == {'app/a.py', 'app/b.py'}, touched
print('ok')
"
    [[ "$output" == *"ok"* ]]
}

@test "hook-stop does not block below pressure thresholds" {
    run bash -c "echo '{}' | python3 '$CKPT' hook-stop"
    [ "$status" -eq 0 ]
    [ -z "$output" ]
}

@test "hook-stop blocks once pressure threshold is reached, then fails open and logs after repeated ignores" {
    echo "y = 2" >> app/foo.py
    git add -A && git commit -q -m "second"
    bash -c "echo '{\"tool_input\": {\"command\": \"git commit -m x\"}}' | python3 '$CKPT' hook-post-bash" >/dev/null

    run bash -c "echo '{}' | python3 '$CKPT' hook-stop"
    [[ "$output" == *'"decision": "block"'* ]]
    run bash -c "echo '{}' | python3 '$CKPT' hook-stop"
    [[ "$output" == *'"decision": "block"'* ]]
    run bash -c "echo '{}' | python3 '$CKPT' hook-stop"
    [ -z "$output" ]
    logged=$(python3 -c "
import json
n = sum(1 for l in open('.claude/checkpoints/index.jsonl') if json.loads(l)['trigger'] == 'degradation_nudge_ignored')
print(n)
")
    [ "$logged" -eq 1 ]
}

@test "append resets nudge_attempts and pressure counters" {
    echo "y = 2" >> app/foo.py
    git add -A && git commit -q -m "second"
    bash -c "echo '{\"tool_input\": {\"command\": \"git commit -m x\"}}' | python3 '$CKPT' hook-post-bash" >/dev/null
    bash -c "echo '{}' | python3 '$CKPT' hook-stop" >/dev/null

    python3 "$CKPT" append --phase verify --title "checkpointed" --task "t" >/dev/null
    run python3 -c "
import json
ck = json.load(open('.claude/session_state.json'))['checkpoint']
assert ck['nudge_attempts'] == 0, ck
assert ck['commits_since_checkpoint'] == 0, ck
print('ok')
"
    [[ "$output" == *"ok"* ]]

    run bash -c "echo '{}' | python3 '$CKPT' hook-stop"
    [ -z "$output" ]
}

@test "index --grep filters by keyword across title/task/decisions/pending" {
    python3 "$CKPT" append --title "unrelated" --task "something else" >/dev/null
    python3 "$CKPT" append --title "the auth fix" --task "fixed the login bug" \
        --decisions "used JWT: simpler than sessions" >/dev/null

    run python3 "$CKPT" index --grep "auth"
    [ "$status" -eq 0 ]
    [[ "$output" == *"the auth fix"* ]]
    [[ "$output" != *"unrelated"* ]]
}

@test "timeline shows chronological context around an anchor" {
    python3 "$CKPT" append --title "before" --task "t" >/dev/null
    python3 "$CKPT" append --title "anchor-point" --task "t" >/dev/null
    python3 "$CKPT" append --title "after" --task "t" >/dev/null

    run python3 "$CKPT" timeline --query "anchor-point" --before 2 --after 2
    [ "$status" -eq 0 ]
    [[ "$output" == *"before"* ]]
    [[ "$output" == *">>"*"anchor-point"* ]]
    [[ "$output" == *"after"* ]]
}

@test "show fetches full detail only for the requested ids, batched" {
    python3 "$CKPT" append --title "first" --task "t1" --decisions "d1" >/dev/null
    id1=$(python3 -c "import json; print(json.loads(open('.claude/checkpoints/index.jsonl').readlines()[0])['id'])")
    python3 "$CKPT" append --title "second" --task "t2" --decisions "d2" >/dev/null
    id2=$(python3 -c "import json; print(json.loads(open('.claude/checkpoints/index.jsonl').readlines()[1])['id'])")

    run python3 "$CKPT" show "$id1" "$id2"
    [ "$status" -eq 0 ]
    [[ "$output" == *"t1"* ]]
    [[ "$output" == *"d1"* ]]
    [[ "$output" == *"t2"* ]]
    [[ "$output" == *"d2"* ]]
}

@test "a hand-truncated or corrupted index.jsonl line does not crash retrieval" {
    python3 "$CKPT" append --title "valid entry" --task "t" >/dev/null
    echo '{not valid json' >> .claude/checkpoints/index.jsonl
    run python3 "$CKPT" index --grep "valid"
    [ "$status" -eq 0 ]
    [[ "$output" == *"valid entry"* ]]
}
