load test_helper

# Verifies the real _write_checkpoint_memory and _write_integrity_manifest
# functions from install.sh (extracted, not mirrored — same fidelity
# principle as deny_list_coverage.bats and graph_freshness_hook.bats).

setup() {
    TEST_REPO="$(mktemp -d "${TMPDIR:-/tmp}/ckpt-mem-install-XXXXXX")"
    cd "$TEST_REPO" || return 1
    git init -q
}

teardown() {
    if [ -n "${TEST_REPO:-}" ] && [ -d "$TEST_REPO" ]; then
        rm -rf "$TEST_REPO"
    fi
    if [ -n "${EXTRACTED_FUNCS_FILE:-}" ] && [ -f "$EXTRACTED_FUNCS_FILE" ]; then
        rm -f "$EXTRACTED_FUNCS_FILE"
    fi
}

@test "_write_checkpoint_memory writes the tool, the command file, and registers all 5 hooks" {
    extract_install_functions
    _write_trust_root_settings "v1_claude_code_development_guide_existing.md" "v1_implementation_package_existing.md"
    _write_checkpoint_memory

    [ -x ".claude/checkpoint_tool.py" ]
    [ -f ".claude/commands/checkpoint-search.md" ]
    [ -f ".claude/checkpoints/index.jsonl" ]

    run python3 -c "
import json
with open('.claude/settings.json') as f:
    hooks = json.load(f)['hooks']
assert any('checkpoint_tool.py hook-session-start' in hh['command'] for h in hooks['SessionStart'] for hh in h['hooks'])
assert any('checkpoint_tool.py hook-pre-compact' in hh['command'] for h in hooks['PreCompact'] for hh in h['hooks'])
assert any('checkpoint_tool.py hook-stop' in hh['command'] for h in hooks['Stop'] for hh in h['hooks'])
post = hooks['PostToolUse']
assert any('checkpoint_tool.py hook-post-bash' in hh['command'] for h in post for hh in h['hooks'])
assert any('checkpoint_tool.py hook-post-write' in hh['command'] for h in post for hh in h['hooks'])
print('ok')
"
    [ "$status" -eq 0 ]
    [[ "$output" == *"ok"* ]]
}

@test "_write_checkpoint_memory hook registration is idempotent" {
    extract_install_functions
    _write_trust_root_settings "v1_claude_code_development_guide_existing.md" "v1_implementation_package_existing.md"
    _write_checkpoint_memory
    _write_checkpoint_memory

    run python3 -c "
import json
with open('.claude/settings.json') as f:
    hooks = json.load(f)['hooks']
session_start = [h for h in hooks['SessionStart'] if any('checkpoint_tool.py' in hh['command'] for hh in h['hooks'])]
assert len(session_start) == 1, len(session_start)
post_bash = [h for h in hooks['PostToolUse'] if h.get('matcher') == 'Bash' and any('checkpoint_tool.py' in hh['command'] for hh in h['hooks'])]
assert len(post_bash) == 1, len(post_bash)
print('ok')
"
    [ "$status" -eq 0 ]
    [[ "$output" == *"ok"* ]]
}

@test "_write_checkpoint_memory does not touch an existing non-empty index.jsonl" {
    extract_install_functions
    _write_trust_root_settings "v1_claude_code_development_guide_existing.md" "v1_implementation_package_existing.md"
    mkdir -p .claude/checkpoints
    echo '{"id": "preexisting"}' > .claude/checkpoints/index.jsonl

    _write_checkpoint_memory

    run cat .claude/checkpoints/index.jsonl
    [[ "$output" == *"preexisting"* ]]
}

@test "_write_integrity_manifest covers checkpoint_tool.py alongside the other governance scripts" {
    extract_install_functions
    _write_hooks
    _write_trust_root_settings "v1_claude_code_development_guide_existing.md" "v1_implementation_package_existing.md"
    _write_checkpoint_memory
    _write_integrity_manifest

    [ -f ".claude/covenant_integrity.sha256" ]
    run grep -c "checkpoint_tool.py" .claude/covenant_integrity.sha256
    [ "$output" -eq 1 ]
    run grep -c "graph_freshness_check.py" .claude/covenant_integrity.sha256
    [ "$output" -eq 1 ]
}

@test "checkpoint_tool.py is covered by the deny-list (Write/Edit denied)" {
    extract_install_functions
    _write_trust_root_settings "v1_claude_code_development_guide_existing.md" "v1_implementation_package_existing.md"

    run python3 -c "
import json
deny = json.load(open('.claude/settings.json'))['permissions']['deny']
assert 'Write(.claude/checkpoint_tool.py)' in deny
assert 'Edit(.claude/checkpoint_tool.py)' in deny
print('ok')
"
    [ "$status" -eq 0 ]
    [[ "$output" == *"ok"* ]]
}
