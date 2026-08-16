#!/usr/bin/env bash
# PreToolUse guard — blocks Write/Edit/MultiEdit on branches with code_writes_permitted=false.
# Claude Code invokes this before every file-write tool call via .claude/settings.json.
# Receives tool input JSON on stdin; exits non-zero to reject the call.
set -euo pipefail

GS=".claude/covenant_state.json"
[ -f "$GS" ] || exit 0

CURRENT_BRANCH=$(git branch --show-current 2>/dev/null || echo "")
[ -z "$CURRENT_BRANCH" ] && exit 0
BP="${CURRENT_BRANCH%%/*}"

PERMITTED=$(python3 -c "
import json, sys
try:
    with open(sys.argv[1]) as f:
        d = json.load(f)
    s = d.get('branch_strategy', {}).get(sys.argv[2], {})
    print('false' if s.get('code_writes_permitted') is False else 'true')
except Exception:
    print('true')
" "$GS" "$BP" 2>/dev/null || echo "true")

if [ "$PERMITTED" = "false" ]; then
    printf 'COVENANT: Code writes are blocked on '\''%s'\'' branch (code_writes_permitted=false).\nMove to a feature or bugfix branch before making code changes.\n' "$BP" >&2
    exit 1
fi
exit 0
