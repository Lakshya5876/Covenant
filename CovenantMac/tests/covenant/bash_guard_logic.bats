load test_helper

setup() {
    setup_covenant_repo
    deploy_bash_guard
}

teardown() {
    teardown_covenant_repo
}

# This file exercises the REAL matching logic in
# templates/pre_bash_trust_root_guard.sh directly — not a hash of it (that's
# ci_integrity_check.bats's job), and not a hand-copied mirror of its
# PROTECTED_PATHS check. A prior two-audit review found the guard's own
# decision logic had zero behavioral test: only whether a tampered copy of
# the file failed a hash check, never whether the untampered file actually
# blocks what it claims to block or allows what it claims to allow.

@test "guard blocks direct redirection into .githooks/covenant.sh" {
    run run_bash_guard 'echo "malicious" > .githooks/covenant.sh'
    [ "$status" -eq 1 ]
    [[ "$output" == *"'.githooks/'"* ]]
}

@test "guard blocks the exact stealth-neuter bypass — overwriting itself" {
    run run_bash_guard 'echo "exit 0" > .claude/hooks/pre_bash_trust_root_guard.sh'
    [ "$status" -eq 1 ]
    [[ "$output" == *"'.claude/hooks/'"* ]]
}

@test "guard blocks regenerating the integrity manifest to match a weakened covenant.sh" {
    run run_bash_guard 'sha256sum .githooks/covenant.sh > .claude/covenant_integrity.sha256'
    [ "$status" -eq 1 ]
}

@test "guard blocks direct tampering with the covenant's own ledger" {
    run run_bash_guard 'echo "{}" > .claude/covenant_state.json'
    [ "$status" -eq 1 ]
    [[ "$output" == *"'.claude/covenant_state.json'"* ]]
}

@test "guard blocks rewriting the MCP server config" {
    run run_bash_guard 'cat malicious.json > .mcp.json'
    [ "$status" -eq 1 ]
    [[ "$output" == *"'.mcp.json'"* ]]
}

@test "guard blocks gutting the CI workflow file via sed" {
    run run_bash_guard "sed -i '' '/Run governance covenant/,+5d' .github/workflows/covenant.yml"
    [ "$status" -eq 1 ]
    [[ "$output" == *"'.github/workflows/covenant.yml'"* ]]
}

@test "guard blocks tee-based writes, not just redirection" {
    run run_bash_guard 'echo "malicious" | tee .githooks/pre-commit'
    [ "$status" -eq 1 ]
}

@test "guard allows a legitimate read of settings.json (init prompt needs this)" {
    run run_bash_guard 'cat .claude/settings.json'
    [ "$status" -eq 0 ]
}

@test "guard allows a legitimate programmatic edit of settings.json during init" {
    run run_bash_guard "python3 -c \"import json; d=json.load(open('.claude/settings.json'))\""
    [ "$status" -eq 0 ]
}

@test "guard allows writing CLAUDE.md (init prompt must create it)" {
    run run_bash_guard 'echo "# Constitution" > CLAUDE.md'
    [ "$status" -eq 0 ]
}

@test "guard allows an unrelated benign command" {
    run run_bash_guard 'ls -la src/'
    [ "$status" -eq 0 ]
}

@test "guard blocks Bash references to the dev-guide/init-package filenames" {
    run run_bash_guard 'wc -l v1_implementation_package_existing.md'
    [ "$status" -eq 1 ]
    # Reference docs are in the deny-list AND the Bash guard by design (never
    # agent-written, no legitimate need to Bash-reference them either) — this
    # asserts the guard's documented behavior, not a gap. If this ever needs
    # to change, it's a deliberate policy call, not a silent regression.
}

# Regression coverage for a real, confirmed red-team finding: a `cd` into a
# protected directory followed by a relative-path reference never puts the
# literal substring ".githooks/" (or any protected marker) anywhere in the
# command text, so the plain substring match above missed it entirely — a
# demonstrated, no-prompt, no-denial bypass that neutered the covenant outright.

@test "guard blocks cd-indirection into .githooks (the confirmed critical bypass)" {
    run run_bash_guard "cd .githooks && sed -i '' '1a\\nexit 0\\n' covenant.sh"
    [ "$status" -eq 1 ]
    [[ "$output" == *"'.githooks/'"* ]]
}

@test "guard blocks cd-indirection into .claude/hooks (self-neuter via a relative path)" {
    run run_bash_guard 'cd .claude/hooks && echo "exit 0" > pre_bash_trust_root_guard.sh'
    [ "$status" -eq 1 ]
    [[ "$output" == *"'.claude/hooks/'"* ]]
}

@test "guard blocks a two-step nested cd into a protected directory" {
    run run_bash_guard 'cd .claude && cd hooks && rm pre_bash_trust_root_guard.sh'
    [ "$status" -eq 1 ]
    [[ "$output" == *"'.claude/hooks/'"* ]]
}

@test "guard blocks cd-indirection reading the covenant ledger" {
    run run_bash_guard 'cd .claude && cat covenant_state.json'
    [ "$status" -eq 1 ]
    [[ "$output" == *"'.claude/covenant_state.json'"* ]]
}

@test "guard allows an unrelated cd into a benign directory" {
    run run_bash_guard 'cd src && ls -la'
    [ "$status" -eq 0 ]
}

@test "guard refuses 'cd -' rather than silently losing track of it" {
    run run_bash_guard 'cd .githooks && echo hi; cd -'
    [ "$status" -eq 1 ]
}
