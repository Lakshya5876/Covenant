load test_helper

# Verifies the versioned-upgrade mechanism added to install.sh: the
# prerequisite fix (--upgrade previously never refreshed the dev-guide/
# init-package files at all), the deprecation-cleanup mechanism
# (DEPRECATED_SINCE + _offer_deprecated_cleanup), and constitution
# reconciliation (/reconcile-governance, generated only when the dev guide's
# actual content changes).

@test "_version_lt compares dotted versions numerically, not lexically" {
    extract_install_functions
    _version_lt "1.0.0" "1.1.0"
    ! _version_lt "1.1.0" "1.0.0"
    ! _version_lt "1.0.0" "1.0.0"
    # The numeric (not lexical/string) comparison case: "10" < "9" as
    # strings, but 1.0.10 must be treated as newer than 1.0.9.
    _version_lt "1.0.9" "1.0.10"
    ! _version_lt "1.0.10" "1.0.9"
    _version_lt "0.0.0" "1.0.0"
    ! _version_lt "2.0.0" "1.9.9"
}

setup_deprecation_fixture() {
    TEST_REPO="$(mktemp -d "${TMPDIR:-/tmp}/deprecation-XXXXXX")"
    cd "$TEST_REPO" || return 1
    touch old_thing.sh
    extract_install_functions
    DEPRECATED_SINCE=("1.1.0:old_thing.sh")
}

teardown_deprecation_fixture() {
    [ -n "${TEST_REPO:-}" ] && [ -d "$TEST_REPO" ] && rm -rf "$TEST_REPO"
}

@test "_offer_deprecated_cleanup is silent when nothing is deprecated relative to the old version" {
    setup_deprecation_fixture
    DEPRECATED_SINCE=()
    run _offer_deprecated_cleanup "1.0.0"
    [ "$status" -eq 0 ]
    [ -z "$output" ]
    teardown_deprecation_fixture
}

@test "_offer_deprecated_cleanup is silent when the repo is already past the deprecation version" {
    setup_deprecation_fixture
    run _offer_deprecated_cleanup "1.2.0"
    [ "$status" -eq 0 ]
    [ -z "$output" ]
    [ -f "old_thing.sh" ]
    teardown_deprecation_fixture
}

@test "_offer_deprecated_cleanup is silent when the deprecated file is already gone" {
    setup_deprecation_fixture
    rm old_thing.sh
    run _offer_deprecated_cleanup "1.0.0"
    [ "$status" -eq 0 ]
    [ -z "$output" ]
    teardown_deprecation_fixture
}

@test "_offer_deprecated_cleanup lists an obsolete file when the repo predates its deprecation" {
    # _offer_deprecated_cleanup prints the listing, then unconditionally
    # calls _confirm (which reads from /dev/tty) once it finds anything —
    # so, unlike the comment this replaced claimed, this test does depend on
    # tty behavior: a bare `run` with no controlling terminal can hang
    # indefinitely on that `read </dev/tty` instead of failing fast, which is
    # environment-dependent (observed hanging under a deeply nested WSL
    # invocation with an attached-but-non-EOF-delivering /dev/tty, even
    # though a real terminal or a true no-tty CI environment both behave
    # correctly). Using the same real-pty harness its two sibling tests
    # already use avoids depending on that undefined behavior at all.
    setup_deprecation_fixture
    {
        echo "#!/bin/bash"
        cat "$EXTRACTED_FUNCS_FILE"
        echo 'DEPRECATED_SINCE=("1.1.0:old_thing.sh")'
        echo '_offer_deprecated_cleanup "1.0.0"'
    } > "${BATS_TEST_TMPDIR}/listing_runner.sh"
    run run_with_pty "${BATS_TEST_TMPDIR}/listing_runner.sh" "n"
    echo "$output" | grep -q "old_thing.sh"
    echo "$output" | grep -q "obsolete"
    teardown_deprecation_fixture
}

@test "_offer_deprecated_cleanup removes the file when confirmed via a real pty" {
    setup_deprecation_fixture
    {
        echo "#!/bin/bash"
        cat "$EXTRACTED_FUNCS_FILE"
        echo 'DEPRECATED_SINCE=("1.1.0:old_thing.sh")'
        echo '_offer_deprecated_cleanup "1.0.0"'
    } > "${BATS_TEST_TMPDIR}/cleanup_runner.sh"
    run run_with_pty "${BATS_TEST_TMPDIR}/cleanup_runner.sh" "y"
    [ ! -f "old_thing.sh" ]
    teardown_deprecation_fixture
}

@test "_offer_deprecated_cleanup keeps the file when declined via a real pty" {
    setup_deprecation_fixture
    {
        echo "#!/bin/bash"
        cat "$EXTRACTED_FUNCS_FILE"
        echo 'DEPRECATED_SINCE=("1.1.0:old_thing.sh")'
        echo '_offer_deprecated_cleanup "1.0.0"'
    } > "${BATS_TEST_TMPDIR}/cleanup_runner.sh"
    run run_with_pty "${BATS_TEST_TMPDIR}/cleanup_runner.sh" "n"
    [ -f "old_thing.sh" ]
    teardown_deprecation_fixture
}

@test "_write_reconcile_command embeds the diff and never-regenerate-wholesale instructions" {
    extract_install_functions
    TEST_REPO="$(mktemp -d "${TMPDIR:-/tmp}/reconcile-XXXXXX")"
    cd "$TEST_REPO" || return 1
    mkdir -p .claude/commands
    echo "old guide text" > old_guide.md
    echo "new guide text with an added rule" > new_guide.md
    diff -u old_guide.md new_guide.md > diff.txt || true
    _write_reconcile_command "new_guide.md" "diff.txt"
    [ -f ".claude/commands/reconcile-governance.md" ]
    run cat .claude/commands/reconcile-governance.md
    echo "$output" | grep -q "new_guide.md"
    echo "$output" | grep -q "old guide text"
    echo "$output" | grep -q "new guide text with an added rule"
    echo "$output" | grep -q "Do NOT regenerate CLAUDE.md wholesale"
    echo "$output" | grep -q "wait for.*approv\|explicitly approved"
    rm -rf "$TEST_REPO"
}

# ── End-to-end _upgrade() tests ──────────────────────────────────────────────
# _upgrade() itself requires the full install.sh context (REPO_ROOT, git repo,
# REPO_DIR pointing at the real framework checkout) — extract_install_functions
# deliberately stops before _upgrade, so these tests source the REAL,
# untouched install.sh directly and invoke it with --upgrade, exactly as a
# real user would, from inside a fixture repo standing in for a previously-
# installed target repo.

setup_upgrade_fixture() {
    TEST_REPO="$(mktemp -d "${TMPDIR:-/tmp}/upgrade-e2e-XXXXXX")"
    cd "$TEST_REPO" || return 1
    git init -q
    git config user.email t@t.com
    git config user.name t
    mkdir -p .githooks .claude/hooks .claude/commands .github/workflows

    cp "${FRAMEWORK_ROOT}/templates/covenant_state.json" .claude/covenant_state.json
    python3 -c "
import json
with open('.claude/covenant_state.json') as f: d = json.load(f)
d['framework_version'] = '0.9.0'
with open('.claude/covenant_state.json', 'w') as f: json.dump(d, f)
"
    echo "y" > .claude/settings.json
    echo '{"permissions": {"deny": []}}' > .claude/settings.json
    git add -A
    git commit -q -m init --allow-empty --no-verify
}

teardown_upgrade_fixture() {
    [ -n "${TEST_REPO:-}" ] && [ -d "$TEST_REPO" ] && rm -rf "$TEST_REPO"
}

@test "PREREQUISITE FIX: --upgrade actually refreshes a stale dev-guide/init-package pair, not just re-runs against the old content" {
    setup_upgrade_fixture
    echo "this is deliberately stale content, nothing like the real file" > v1_claude_code_development_guide_new.md
    echo "this is deliberately stale content, nothing like the real file" > v1_implementation_package_new.md

    run env COVENANT_SKIP_STALENESS_CHECK=1 bash "${FRAMEWORK_ROOT}/install.sh" --upgrade
    [ "$status" -eq 0 ]

    run diff "v1_implementation_package_new.md" "${SHARED_ROOT}/v1_release/basket-2-greenfield/v1_implementation_package_new.md"
    [ "$status" -eq 0 ]
    run diff "v1_claude_code_development_guide_new.md" "${SHARED_ROOT}/v1_release/basket-2-greenfield/v1_claude_code_development_guide_new.md"
    [ "$status" -eq 0 ]
    teardown_upgrade_fixture
}

@test "--upgrade migrates pre-split receipts out of covenant_state.json, merging with covenant_receipts.json" {
    # Simulates an install from before the receipts split: an old
    # covenant_state.json with receipts written inline. --upgrade must move
    # them into covenant_receipts.json (merging with, not clobbering,
    # anything already there) rather than leave them orphaned forever in a
    # field nothing reads anymore.
    setup_upgrade_fixture
    # Basket detection needs a dev-guide file present to run
    # _write_checkpoint_memory (which creates the governance files the
    # integrity manifest step hashes); without one, upgrade bails out of
    # scaffolding before ever reaching the receipts migration. Content is
    # irrelevant here — this test only cares about the receipts migration.
    echo "stale placeholder" > v1_claude_code_development_guide_new.md
    echo "stale placeholder" > v1_implementation_package_new.md
    python3 -c "
import json
with open('.claude/covenant_state.json') as f: d = json.load(f)
d['receipts'] = {'old-tree-abc': {'timestamp': '2020-01-01T00:00:00Z', 'branch': 'main', 'outcome': 'pass'}}
with open('.claude/covenant_state.json', 'w') as f: json.dump(d, f)
"
    echo '{"receipts": {"newer-tree-xyz": {"outcome": "pass"}}}' > .claude/covenant_receipts.json

    run env COVENANT_SKIP_STALENESS_CHECK=1 bash "${FRAMEWORK_ROOT}/install.sh" --upgrade
    [ "$status" -eq 0 ]

    run python3 -c "
import json
with open('.claude/covenant_state.json') as f:
    assert 'receipts' not in json.load(f)
with open('.claude/covenant_receipts.json') as f:
    merged = json.load(f)['receipts']
assert 'old-tree-abc' in merged
assert 'newer-tree-xyz' in merged
assert merged['old-tree-abc']['outcome'] == 'pass'
"
    [ "$status" -eq 0 ]
    teardown_upgrade_fixture
}

@test "--upgrade generates /reconcile-governance when the dev guide's content actually changed" {
    setup_upgrade_fixture
    echo "this is deliberately stale content, nothing like the real file" > v1_claude_code_development_guide_new.md
    echo "this is deliberately stale content, nothing like the real file" > v1_implementation_package_new.md

    run env COVENANT_SKIP_STALENESS_CHECK=1 bash "${FRAMEWORK_ROOT}/install.sh" --upgrade
    [ "$status" -eq 0 ]
    [ -f ".claude/commands/reconcile-governance.md" ]
    run grep -q "stale content" .claude/commands/reconcile-governance.md
    [ "$status" -eq 0 ]
    teardown_upgrade_fixture
}

@test "--upgrade does NOT generate /reconcile-governance when the dev guide content is already current" {
    setup_upgrade_fixture
    cp "${SHARED_ROOT}/v1_release/basket-2-greenfield/v1_claude_code_development_guide_new.md" .
    cp "${SHARED_ROOT}/v1_release/basket-2-greenfield/v1_implementation_package_new.md" .

    run env COVENANT_SKIP_STALENESS_CHECK=1 bash "${FRAMEWORK_ROOT}/install.sh" --upgrade
    [ "$status" -eq 0 ]
    [ ! -f ".claude/commands/reconcile-governance.md" ]
    teardown_upgrade_fixture
}
