load test_helper

# Verifies the real _write_init_command function (extracted from install.sh,
# not a hand-copied mirror — same fidelity principle as deny_list_coverage.bats)
# correctly turns the manual "open the init package and copy-paste it" step
# into a real .claude/commands/init-governance.md slash command, for both
# baskets, with no marker leakage and no content loss.

setup() {
    TEST_REPO="$(mktemp -d "${TMPDIR:-/tmp}/init-cmd-XXXXXX")"
    cd "$TEST_REPO" || return 1
    mkdir -p .claude/commands
}

teardown() {
    if [ -n "${TEST_REPO:-}" ] && [ -d "$TEST_REPO" ]; then
        rm -rf "$TEST_REPO"
    fi
    if [ -n "${EXTRACTED_FUNCS_FILE:-}" ] && [ -f "$EXTRACTED_FUNCS_FILE" ]; then
        rm -f "$EXTRACTED_FUNCS_FILE"
    fi
}

@test "greenfield init package extracts cleanly into init-governance.md" {
    cp "${SHARED_ROOT}/v1_release/basket-2-greenfield/v1_implementation_package_new.md" \
       v1_implementation_package_new.md
    extract_install_functions
    _write_init_command "v1_implementation_package_new.md"

    [ -f ".claude/commands/init-governance.md" ]
    run grep -c "PROMPT START\|PROMPT END" .claude/commands/init-governance.md
    [ "$output" -eq 0 ]
    run head -1 .claude/commands/init-governance.md
    [[ "$output" == *"governance bootstrap"* ]]
    run grep -c "^Read the file .v1_claude_code_development_guide_new.md" .claude/commands/init-governance.md
    [ "$output" -eq 1 ]
}

@test "brownfield init package extracts cleanly into init-governance.md" {
    cp "${SHARED_ROOT}/v1_release/basket-1-brownfield/v1_implementation_package_existing.md" \
       v1_implementation_package_existing.md
    extract_install_functions
    _write_init_command "v1_implementation_package_existing.md"

    [ -f ".claude/commands/init-governance.md" ]
    run grep -c "PROMPT START\|PROMPT END" .claude/commands/init-governance.md
    [ "$output" -eq 0 ]
}

@test "extracted command content matches the source PROMPT block byte-for-byte" {
    cp "${SHARED_ROOT}/v1_release/basket-2-greenfield/v1_implementation_package_new.md" \
       v1_implementation_package_new.md
    extract_install_functions
    _write_init_command "v1_implementation_package_new.md"

    run python3 -c "
with open('v1_implementation_package_new.md') as f:
    lines = f.readlines()
start = next(i for i, l in enumerate(lines) if 'PROMPT START' in l) + 1
end = next(i for i, l in enumerate(lines) if 'PROMPT END' in l)
expected = ''.join(lines[start:end]).strip()

with open('.claude/commands/init-governance.md') as f:
    actual = f.read()

assert expected in actual, 'extracted prompt body not found verbatim in command file'
print('ok')
"
    [ "$status" -eq 0 ]
    [[ "$output" == *"ok"* ]]
}

@test "_write_init_command can re-write the command file on demand (the operation _upgrade's backfill path relies on)" {
    # _upgrade() (install.sh) calls _write_init_command to backfill
    # init-governance.md for repos installed before this feature existed.
    # _upgrade() itself isn't exercised end-to-end by this suite (no existing
    # test does — it requires a fuller pre-existing-install fixture than any
    # test here builds), but the underlying operation it depends on — writing
    # the command file fresh, including onto a repo where it's missing — is
    # verified directly here.
    cp "${SHARED_ROOT}/v1_release/basket-2-greenfield/v1_implementation_package_new.md" \
       v1_implementation_package_new.md
    extract_install_functions

    [ ! -f ".claude/commands/init-governance.md" ]
    _write_init_command "v1_implementation_package_new.md"
    [ -f ".claude/commands/init-governance.md" ]
}
