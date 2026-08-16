load test_helper

setup() {
    setup_covenant_repo
    mkdir -p app/services
}

teardown() {
    teardown_covenant_repo
}

@test "layer boundary blocks HTTP imports in services layer" {
    cat > app/services/billing.py <<'EOF'
from fastapi import HTTPException

def charge():
    raise HTTPException(status_code=400, detail="bad")
EOF
    git add app/services/billing.py
    run run_covenant COVENANT_TRIGGER=pre-commit \
        LINT_CMD='true' \
        TYPE_CMD='true' \
        COMPLEXITY_CMD='true' \
        TEST_CMD='true'
    [ "$status" -eq 1 ]
    [[ "$output" == *"Layer boundary violation"* ]]
    [[ "$output" == *"SERVICE_HAS_HTTP"* ]]
}

@test "layer boundary blocks SQL in routes layer" {
    mkdir -p app/routes
    cat > app/routes/users.py <<'EOF'
def list_users(conn):
    return conn.execute("SELECT id FROM users")
EOF
    git add app/routes/users.py
    run run_covenant COVENANT_TRIGGER=pre-commit \
        LINT_CMD='true' \
        TYPE_CMD='true' \
        COMPLEXITY_CMD='true' \
        TEST_CMD='true'
    [ "$status" -eq 1 ]
    [[ "$output" == *"ROUTES_HAS_SQL"* ]]
}

@test "layer boundary still blocks an aliased HTTP import (import renaming doesn't evade the grep)" {
    cat > app/services/billing_aliased.py <<'EOF'
from fastapi import HTTPException as HTTPErr

def charge():
    raise HTTPErr(status_code=400, detail="bad")
EOF
    git add app/services/billing_aliased.py
    run run_covenant COVENANT_TRIGGER=pre-commit \
        LINT_CMD='true' \
        TYPE_CMD='true' \
        COMPLEXITY_CMD='true' \
        TEST_CMD='true'
    [ "$status" -eq 1 ]
    [[ "$output" == *"SERVICE_HAS_HTTP"* ]]
}

@test "KNOWN LIMITATION (documented, not fixed): an HTTP import re-exported through an intermediate module evades detection" {
    # A fresh audit correctly noted the layer scanner has no adversarial-
    # evasion tests. This one is written to FAIL the way the scanner
    # actually behaves today — asserting the miss, not asserting a fix —
    # because closing it requires an import-graph/AST parser (the MCP graph
    # server's job), not a bounded grep change. A grep-based scanner can only
    # see what's textually present in the file being scanned; it cannot see
    # that myapp.http_shim (a different file) itself imports fastapi. This
    # test exists so the limitation is pinned and visible, not silently
    # rediscovered by a future audit as if it were new.
    cat > app/services/billing_indirect.py <<'EOF'
from myapp.http_shim import raise_http_error

def charge():
    raise_http_error(400, "bad")
EOF
    git add app/services/billing_indirect.py
    run run_covenant COVENANT_TRIGGER=pre-commit \
        LINT_CMD='true' \
        TYPE_CMD='true' \
        COMPLEXITY_CMD='true' \
        TEST_CMD='true'
    [ "$status" -eq 0 ]
    [[ "$output" != *"SERVICE_HAS_HTTP"* ]]
}
