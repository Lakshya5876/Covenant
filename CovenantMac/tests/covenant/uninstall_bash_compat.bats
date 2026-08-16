load test_helper

# Pins a real bug reported from a live user run: uninstall.sh's _confirm used
# ${answer,,} (bash 4+ lowercase parameter expansion). macOS ships bash 3.2 as
# /bin/bash by default (Apple never ships GPLv3 bash, and does not upgrade
# it) — most Mac users never install a newer bash via Homebrew, so this hit
# on the very first real macOS run: "uninstall.sh: line 49: ${answer,,}: bad
# substitution", right after the user typed "y" at the removal-confirmation
# prompt, aborting before anything was actually removed.
#
# IMPORTANT: assertions in this file deliberately avoid bare `[[ ]]` for
# anything that isn't the LAST statement in a test. Empirically confirmed in
# this environment: a failing `[[ expr ]]` that is NOT the test's final
# statement does not stop test execution or fail the test — only the exit
# status of the actual last command does. `[ ]` (POSIX test) and external
# commands (grep, etc.) do not have this problem. An earlier version of this
# file used bare `[[ ]]` mid-test and was a false positive as a result — it
# "passed" while _confirm was silently declining every input, y/Y/yes/YES
# included, because /dev/tty genuinely does not resolve to a working device
# in this sandbox when read from plain (non-pty) subshells. Fixed by driving
# the real function through an actual pty (run_with_pty, test_helper.bash),
# which is also what makes /dev/tty resolve correctly at all.

@test "_confirm (uninstall.sh) accepts y/Y/yes/YES and declines everything else" {
    start_line=$(grep -n '^_confirm() {' "${FRAMEWORK_ROOT}/uninstall.sh" | head -1 | cut -d: -f1)
    end_line=$(awk -v s="$start_line" 'NR>s && /^}/{print NR; exit}' "${FRAMEWORK_ROOT}/uninstall.sh")
    {
        echo "#!/bin/bash"
        sed -n "${start_line},${end_line}p" "${FRAMEWORK_ROOT}/uninstall.sh"
        echo '_confirm "Proceed?" && echo CONFIRMED || echo DECLINED'
    } > "${BATS_TEST_TMPDIR}/confirm_runner.sh"

    for input in y Y yes YES; do
        run run_with_pty "${BATS_TEST_TMPDIR}/confirm_runner.sh" "$input"
        if echo "$output" | grep -q "bad substitution"; then return 1; fi
        echo "$output" | grep -q "CONFIRMED"
    done

    for input in n N no garbage; do
        run run_with_pty "${BATS_TEST_TMPDIR}/confirm_runner.sh" "$input"
        if echo "$output" | grep -q "bad substitution"; then return 1; fi
        echo "$output" | grep -q "DECLINED"
    done
}

setup_staleness_pair() {
    # Real local+remote git repos (not mocked), so _check_framework_staleness
    # exercises its actual fetch/rev-list logic end to end.
    STALE_ROOT="$(mktemp -d "${TMPDIR:-/tmp}/staleness-XXXXXX")"
    git init -q -b main --bare "${STALE_ROOT}/remote.git"
    git clone -q "${STALE_ROOT}/remote.git" "${STALE_ROOT}/origin_clone"
    (
        cd "${STALE_ROOT}/origin_clone"
        git config user.email t@t.com
        git config user.name t
        echo v1 > f.txt && git add f.txt && git commit -q -m v1
        git push -q origin main
    )
    git clone -q "${STALE_ROOT}/remote.git" "${STALE_ROOT}/local_stale"

    start_line=$(grep -n '^_bounded_git_fetch() {' "${FRAMEWORK_ROOT}/install.sh" | head -1 | cut -d: -f1)
    end_line=$(grep -n '^_upgrade() {' "${FRAMEWORK_ROOT}/install.sh" | head -1 | cut -d: -f1)
    sed -n "${start_line},$((end_line - 1))p" "${FRAMEWORK_ROOT}/install.sh" > "${BATS_TEST_TMPDIR}/staleness_func.sh"
    source "${BATS_TEST_TMPDIR}/staleness_func.sh"
}

teardown_staleness_pair() {
    [ -n "${STALE_ROOT:-}" ] && [ -d "$STALE_ROOT" ] && rm -rf "$STALE_ROOT"
}

@test "_check_framework_staleness warns when the local clone is behind its upstream" {
    setup_staleness_pair
    (
        cd "${STALE_ROOT}/origin_clone"
        echo v2 > f.txt && git add f.txt && git commit -q -m v2
        git push -q origin main
    )
    run _check_framework_staleness "${STALE_ROOT}/local_stale"
    [ "$status" -eq 0 ]
    echo "$output" | grep -q "1 commit(s)"
    echo "$output" | grep -q "behind origin/main"
    teardown_staleness_pair
}

@test "_check_framework_staleness is silent when the clone is already up to date" {
    setup_staleness_pair
    run _check_framework_staleness "${STALE_ROOT}/origin_clone"
    [ "$status" -eq 0 ]
    [ -z "$output" ]
    teardown_staleness_pair
}

@test "COVENANT_SKIP_STALENESS_CHECK=1 skips the check entirely, even against a genuinely stale clone" {
    setup_staleness_pair
    (
        cd "${STALE_ROOT}/origin_clone"
        echo v2 > f.txt && git add f.txt && git commit -q -m v2
        git push -q origin main
    )
    START_TS=$(date +%s)
    run env COVENANT_SKIP_STALENESS_CHECK=1 bash -c "source '${BATS_TEST_TMPDIR}/staleness_func.sh'; _check_framework_staleness '${STALE_ROOT}/local_stale'"
    END_TS=$(date +%s)
    [ "$status" -eq 0 ]
    [ -z "$output" ]
    [ "$((END_TS - START_TS))" -lt 2 ]
    teardown_staleness_pair
}

@test "_check_framework_staleness degrades silently (no crash) when not a git repo" {
    NOTAREPO="$(mktemp -d "${TMPDIR:-/tmp}/not-a-repo-XXXXXX")"
    start_line=$(grep -n '^_bounded_git_fetch() {' "${FRAMEWORK_ROOT}/install.sh" | head -1 | cut -d: -f1)
    end_line=$(grep -n '^_upgrade() {' "${FRAMEWORK_ROOT}/install.sh" | head -1 | cut -d: -f1)
    sed -n "${start_line},$((end_line - 1))p" "${FRAMEWORK_ROOT}/install.sh" > "${BATS_TEST_TMPDIR}/staleness_func2.sh"
    source "${BATS_TEST_TMPDIR}/staleness_func2.sh"
    run _check_framework_staleness "$NOTAREPO"
    [ "$status" -eq 0 ]
    [ -z "$output" ]
    rm -rf "$NOTAREPO"
}

@test "_check_framework_staleness degrades silently (no crash) when the remote is unreachable" {
    setup_staleness_pair
    git -C "${STALE_ROOT}/local_stale" remote set-url origin "/nonexistent/path/${STALE_ROOT##*/}.git"
    run _check_framework_staleness "${STALE_ROOT}/local_stale"
    [ "$status" -eq 0 ]
    [ -z "$output" ]
    teardown_staleness_pair
}

@test "_check_framework_staleness does not hang indefinitely when the remote is unroutable (real bug found in testing)" {
    # git's http.lowSpeedLimit/http.lowSpeedTime only bound the TRANSFER
    # phase — they do nothing for a hanging DNS lookup or TCP connect. Found
    # by this exact scenario hanging for 3+ minutes during development,
    # against a genuinely unroutable address (10.255.255.1, TEST-NET-3
    # reserved, guaranteed to hang at connect rather than fail fast the way
    # a bad local path or a rejected connection would).
    setup_staleness_pair
    (
        cd "${STALE_ROOT}/local_stale"
        git remote set-url origin "https://10.255.255.1/nonexistent.git"
    )
    START_TS=$(date +%s)
    run _check_framework_staleness "${STALE_ROOT}/local_stale"
    END_TS=$(date +%s)
    ELAPSED=$((END_TS - START_TS))
    [ "$status" -eq 0 ]
    [ "$ELAPSED" -lt 15 ]
    teardown_staleness_pair
}

@test "no shipped shell script uses bash-4-only syntax (macOS's default /bin/bash is 3.2)" {
    # Grep, not a bash-version check, so this catches the class of bug
    # regardless of what bash the CI/dev machine happens to have installed —
    # the constraint is about what macOS ships by default, not what any one
    # box running this test suite has. Excludes comment-only lines (`#...`)
    # since this file's own explanatory comments legitimately reference the
    # banned syntax by name when documenting why it's banned.
    run bash -c "grep -rnE '\\\$\\{[A-Za-z_][A-Za-z0-9_]*(\\[[^]]*\\])?,,|\\\$\\{[A-Za-z_][A-Za-z0-9_]*(\\[[^]]*\\])?\\^\\^|declare -A|readarray|mapfile' '${FRAMEWORK_ROOT}/install.sh' '${FRAMEWORK_ROOT}/uninstall.sh' '${FRAMEWORK_ROOT}'/templates/*.sh | grep -vE '^[^:]+:[0-9]+: *#'"
    [ "$status" -eq 1 ]
    [ -z "$output" ]
}
