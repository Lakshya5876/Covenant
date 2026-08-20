#!/usr/bin/env bash
# Run covenant.sh integration tests via bats-core.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "$ROOT"

if ! command -v bats >/dev/null 2>&1; then
    echo "bats-core is required. Install with: brew install bats-core  (macOS) or apt install bats" >&2
    exit 1
fi

echo "Running covenant.sh integration tests..."
set +e
bats tests/covenant/*.bats
BATS_EXIT=$?
set -e

# Belt-and-suspenders process reaping, independent of any individual test
# file's own teardown. A handful of tests deliberately spawn a background
# process to simulate "something else is running" (graph_watchdog.bats'
# `sleep 60 &` PID-reuse fixture; the genuinely-unroutable-remote fetch in
# the framework-staleness tests, whose git-remote-https child helper
# survives even after _bounded_git_fetch's own wall-clock kill — see
# install.sh's _bounded_git_fetch for that specific fix). Both are meant to
# die in their own test's teardown, but bats forks each test file into its
# own subshell tree, and a background job's PID isn't always still a
# waitable child by the time that teardown runs — found by actually running
# the full suite on genuine Linux (this framework's own local dev testing on
# Windows/WSL never surfaced it, since process/fd inheritance behaves
# differently there), where a single leaked child holding this script's
# inherited stdout/stderr open was enough to make the whole invocation hang
# well past every test having already printed "ok". This is a real fallback
# for a real observed failure mode, not defensive-programming filler — do
# not remove without re-verifying the full suite still exits cleanly.
pkill -9 -f 'git-remote-https.*nonexistent\.git' 2>/dev/null || true
pkill -9 -f 'tests/covenant/.*\.fakebin/code-review-graph' 2>/dev/null || true
pkill -9 -f "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)-test-.*/\.fakebin/code-review-graph" 2>/dev/null || true

exit "$BATS_EXIT"
