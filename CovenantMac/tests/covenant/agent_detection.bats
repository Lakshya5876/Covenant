load test_helper

setup() {
    setup_covenant_repo
}

teardown() {
    teardown_covenant_repo
}

# Exercises _is_claude_agent_process, which had zero prior test coverage.
# STEP 4.4's brainstorming-checkpoint hard-block only fires when IS_AGENT is
# true, so it's the natural, already-mechanical way to observe IS_AGENT's
# actual value without adding a separate debug-only code path.

_stage_five_files() {
    for i in 1 2 3 4 5; do
        echo "content $i" > "file${i}.py"
    done
    git add file1.py file2.py file3.py file4.py file5.py
}

@test "human commit (no CLAUDECODE, no claude-code ancestor) is not subject to the brainstorming checkpoint" {
    # env -u explicitly strips CLAUDECODE, but that alone isn't sufficient:
    # if the shell RUNNING this test suite is itself a Claude Code session
    # (an agent working on this repo, in Claude Desktop or the CLI), the real
    # process tree ALREADY contains "claude-code" in an ancestor's own binary
    # path — e.g. .../claude-code/2.1.187/claude.app/Contents/MacOS/claude —
    # which the fallback process-walk correctly detects regardless of the env
    # var. There is no way to fake "definitely no agent involved" from inside
    # the very agent this mechanism is designed to detect. Skip gracefully in
    # that case rather than ship a test that fails for the right reason but
    # looks like a broken test; a human-run or CI-run suite (no claude-code
    # ancestor at all) exercises this for real.
    _AD_PID=$PPID
    _AD_HAS_ANCESTOR=false
    while [ "${_AD_PID:-0}" -gt 1 ] 2>/dev/null; do
        _AD_CMD=$(ps -p "$_AD_PID" -o command= 2>/dev/null | tr -d '\n' || echo "")
        if echo "$_AD_CMD" | grep -qE '@anthropic-ai/claude-code|claude-code'; then
            _AD_HAS_ANCESTOR=true
            break
        fi
        _AD_PPID=$(ps -p "$_AD_PID" -o ppid= 2>/dev/null | tr -d ' \n' || echo "0")
        [ -z "$_AD_PPID" ] || [ "$_AD_PPID" = "0" ] && break
        _AD_PID=$_AD_PPID
    done
    if [ "$_AD_HAS_ANCESTOR" = "true" ]; then
        skip "this test suite is itself running inside a Claude Code session — a genuinely agent-free process tree isn't achievable here"
    fi

    _stage_five_files
    run env -u CLAUDECODE COVENANT_STATE=".claude/covenant_state.json" \
        COVENANT_TRIGGER=pre-commit LINT_CMD='true' TYPE_CMD='true' COMPLEXITY_CMD='true' TEST_CMD='true' \
        bash .githooks/covenant.sh 2>&1
    [[ "$output" != *"Tier 3+ change footprint"* ]]
}

@test "CLAUDECODE=1 triggers the brainstorming checkpoint even with no claude-code process ancestor" {
    # This is the exact detachment scenario the fix closes: bats' own test
    # runner process tree contains no "claude-code" ancestor anywhere (it's
    # bats/bash/git, nothing else) — so before this fix, setting only
    # CLAUDECODE=1 (simulating an agent whose live process-tree link to
    # claude-code was severed by backgrounding/setsid/nohup) would still
    # have produced IS_AGENT=false via the old process-walk-only check.
    _stage_five_files
    run run_covenant COVENANT_TRIGGER=pre-commit CLAUDECODE=1 LINT_CMD='true' TYPE_CMD='true' COMPLEXITY_CMD='true' TEST_CMD='true'
    [ "$status" -eq 1 ]
    [[ "$output" == *"Tier 3+ change footprint"* ]]
    [[ "$output" == *"no brainstorming checkpoint"* ]]
}

@test "CLAUDECODE=1 with a checkpoint present is not blocked" {
    _stage_five_files
    mkdir -p .claude/checkpoints
    echo "# Design brief" > .claude/checkpoints/LATEST.md
    run run_covenant COVENANT_TRIGGER=pre-commit CLAUDECODE=1 LINT_CMD='true' TYPE_CMD='true' COMPLEXITY_CMD='true' TEST_CMD='true'
    [[ "$output" != *"Tier 3+ change footprint"* ]]
}

@test "CLAUDECODE=1 with fewer than 5 files is not blocked" {
    echo "content" > file1.py
    git add file1.py
    run run_covenant COVENANT_TRIGGER=pre-commit CLAUDECODE=1 LINT_CMD='true' TYPE_CMD='true' COMPLEXITY_CMD='true' TEST_CMD='true'
    [[ "$output" != *"Tier 3+ change footprint"* ]]
}
