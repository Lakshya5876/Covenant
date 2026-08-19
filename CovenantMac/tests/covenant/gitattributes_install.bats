load test_helper

# Regression for a real gap: neither install.sh nor install.ps1 wrote a
# .gitattributes into the repo they installed into, so the integrity
# manifest's pinned governance files (hashed as raw on-disk bytes) had no
# protection against a common Windows git config (core.autocrlf=true)
# silently rewriting LF to CRLF on checkout — which changes the hash with
# zero content change, and for the bash-shebang files, breaks the script
# outright. The framework's own repo had this same bug and was fixed
# separately; this covers the actual installer output every governed target
# repo gets, which is a distinct gap from the framework repo's own line
# endings.

setup() {
    TEST_REPO="$(mktemp -d "${TMPDIR:-/tmp}/gitattributes-XXXXXX")"
    cd "$TEST_REPO" || return 1
    git init -q
    extract_install_functions
    _write_hooks
    _write_trust_root_settings "v1_claude_code_development_guide_existing.md" "v1_implementation_package_existing.md"
    _write_checkpoint_memory
    _write_integrity_manifest
}

teardown() {
    if [ -n "${TEST_REPO:-}" ] && [ -d "$TEST_REPO" ]; then
        rm -rf "$TEST_REPO"
    fi
    if [ -n "${EXTRACTED_FUNCS_FILE:-}" ] && [ -f "$EXTRACTED_FUNCS_FILE" ]; then
        rm -f "$EXTRACTED_FUNCS_FILE"
    fi
}

@test "_write_gitattributes covers every file listed in the integrity manifest" {
    _write_gitattributes
    [ -f .gitattributes ]
    while read -r hash rel; do
        run grep -qF "${rel} text eol=lf" .gitattributes
        [ "$status" -eq 0 ]
    done < .claude/covenant_integrity.sha256
}

@test "_write_gitattributes is idempotent and preserves pre-existing content" {
    echo "*.png binary" > .gitattributes
    _write_gitattributes
    _write_gitattributes
    run grep -c "\.githooks/covenant\.sh text eol=lf" .gitattributes
    [ "$status" -eq 0 ]
    [ "$output" -eq 1 ]
    run grep -qF "*.png binary" .gitattributes
    [ "$status" -eq 0 ]
}

@test "a fresh install actually writes .gitattributes covering all 7 governance files" {
    run grep -c "text eol=lf" .gitattributes
    [ "$status" -ne 0 ] || [ "$output" -eq 0 ]
    _write_gitattributes
    run grep -c "text eol=lf" .gitattributes
    [ "$status" -eq 0 ]
    [ "$output" -eq 7 ]
}
