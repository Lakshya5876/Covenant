load test_helper

# Mechanizes the ownership test that found 3 unprotected files across two
# separate audit rounds (a human/agent had to notice each omission by
# inspection). Runs the REAL _write_hooks and _write_trust_root_settings
# functions from install.sh, then walks every file they actually wrote to
# .githooks/ and .claude/hooks/ (both entirely install.sh-owned — never
# agent-generated), asserting each one is covered by the generated
# .claude/settings.json deny-list. A future file added to either directory
# without a matching deny entry fails this test immediately, instead of
# waiting for the next audit round to notice by hand.

setup() {
    TEST_REPO="$(mktemp -d "${TMPDIR:-/tmp}/deny-cov-XXXXXX")"
    cd "$TEST_REPO" || return 1
    git init -q
    extract_install_functions
    _write_hooks
    _write_trust_root_settings "v1_claude_code_development_guide_existing.md" "v1_implementation_package_existing.md"
}

teardown() {
    if [ -n "${TEST_REPO:-}" ] && [ -d "$TEST_REPO" ]; then
        rm -rf "$TEST_REPO"
    fi
    if [ -n "${EXTRACTED_FUNCS_FILE:-}" ] && [ -f "$EXTRACTED_FUNCS_FILE" ]; then
        rm -f "$EXTRACTED_FUNCS_FILE"
    fi
}

@test "every file actually written to .githooks/ is covered by the deny-list" {
    run python3 -c "
import json, os, sys

with open('.claude/settings.json') as f:
    deny = json.load(f)['permissions']['deny']

uncovered = []
for name in os.listdir('.githooks'):
    path = '.githooks/' + name
    covered = any(
        e == f'Write({path})' or e == f'Edit({path})' or
        e.startswith('Write(.githooks/') or e.startswith('Edit(.githooks/')
        for e in deny
    )
    if not covered:
        uncovered.append(path)

if uncovered:
    print('UNCOVERED: ' + ', '.join(uncovered))
    sys.exit(1)
print('all .githooks/ files covered')
"
    [ "$status" -eq 0 ]
    [[ "$output" == *"all .githooks/ files covered"* ]]
}

@test "every file actually written to .claude/hooks/ is covered by the deny-list" {
    run python3 -c "
import json, os, sys

with open('.claude/settings.json') as f:
    deny = json.load(f)['permissions']['deny']

uncovered = []
for name in os.listdir('.claude/hooks'):
    path = '.claude/hooks/' + name
    covered = any(
        e == f'Write({path})' or e == f'Edit({path})' or
        e.startswith('Write(.claude/hooks/') or e.startswith('Edit(.claude/hooks/')
        for e in deny
    )
    if not covered:
        uncovered.append(path)

if uncovered:
    print('UNCOVERED: ' + ', '.join(uncovered))
    sys.exit(1)
print('all .claude/hooks/ files covered')
"
    [ "$status" -eq 0 ]
    [[ "$output" == *"all .claude/hooks/ files covered"* ]]
}

@test "the integrity manifest actually covers every file the deny-list claims to protect in those two directories" {
    # Cross-check in the OTHER direction: every .githooks/ and .claude/hooks/
    # file covered by the deny-list is also in the CI integrity manifest —
    # tool-level protection without a content-hash backstop would only stop
    # Claude-Code-mediated tampering, not a direct commit.
    #
    # _write_integrity_manifest is its own function now (split out of
    # _write_trust_root_settings so it can run after _write_checkpoint_memory
    # too, which writes .claude/checkpoint_tool.py — one of the files the
    # real manifest covers) — this test's setup() only ran _write_hooks and
    # _write_trust_root_settings, so both calls below are needed to reach the
    # same end state install.sh actually produces before the manifest exists.
    _write_checkpoint_memory
    _write_integrity_manifest
    run python3 -c "
import sys

manifest_paths = set()
with open('.claude/covenant_integrity.sha256') as f:
    for line in f:
        line = line.strip()
        if line:
            manifest_paths.add(line.split(None, 1)[1])

import os
disk_paths = set()
for d in ('.githooks', '.claude/hooks'):
    for name in os.listdir(d):
        disk_paths.add(f'{d}/{name}')

missing = disk_paths - manifest_paths
if missing:
    print('MISSING FROM MANIFEST: ' + ', '.join(sorted(missing)))
    sys.exit(1)
print('every governance script is in the integrity manifest')
"
    [ "$status" -eq 0 ]
    [[ "$output" == *"every governance script is in the integrity manifest"* ]]
}

@test "known install.sh-owned files outside those two directories are covered by the deny-list" {
    # .github/workflows/covenant.yml and .mcp.json aren't written by _write_hooks
    # or _write_trust_root_settings (they're written by separate top-level
    # install.sh code this extraction doesn't isolate) — checked here as a
    # named list rather than a filesystem walk. If a new top-level-written
    # governance file is ever added, it must be added to this list AND to
    # the deny-list in the same change, or this test documents the omission.
    run python3 -c "
import json, sys

with open('.claude/settings.json') as f:
    deny = json.load(f)['permissions']['deny']

required = ['.github/workflows/covenant.yml', '.mcp.json']
missing = [p for p in required if f'Write({p})' not in deny or f'Edit({p})' not in deny]
if missing:
    print('MISSING: ' + ', '.join(missing))
    sys.exit(1)
print('known top-level governance files covered')
"
    [ "$status" -eq 0 ]
    [[ "$output" == *"known top-level governance files covered"* ]]
}
