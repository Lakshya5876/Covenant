load test_helper

# Regression coverage for a real red-team finding: covenant.sh's test-runner
# auto-inference (_infer_backend_test_cmd / _infer_playwright_cmd) checked
# manifest files (requirements*.txt, pytest.ini, package.json, ...) ONLY at
# the repo root. A very common brownfield layout — backend/requirements.txt
# + frontend/package.json, nothing at root — matched none of those checks,
# so TEST_RUNNERS stayed empty and every commit hit the "no test runner
# found" hard block until a human manually exported TEST_CMD/
# FRONTEND_TEST_CMD, despite the layout being ordinary, not an edge case.
# Fixed by also checking backend/server/api (backend) and frontend/web/
# client/ui (frontend) subdirectories.

setup() {
    setup_covenant_repo
}

teardown() {
    teardown_covenant_repo
}

@test "backend/requirements.txt (pytest) is discovered when nothing is at repo root" {
    mkdir -p backend
    echo "pytest==8.0.0" > backend/requirements.txt
    mkdir -p backend/app
    echo "def add(a, b): return a + b" > backend/app/util.py
    git add backend/requirements.txt backend/app/util.py
    run run_covenant COVENANT_TRIGGER=pre-commit \
        LINT_CMD='true' TYPE_CMD='true' COMPLEXITY_CMD='true'
    [[ "$output" == *"inferred test runners"* ]]
    [[ "$output" == *"pytest"* ]]
    [[ "$output" != *"no test runner was found"* ]]
}

@test "the inferred backend pytest command is scoped to the changed file with the backend/ prefix stripped" {
    mkdir -p backend
    echo "pytest==8.0.0" > backend/requirements.txt
    mkdir -p backend/app
    echo "def add(a, b): return a + b" > backend/app/util.py
    git add backend/requirements.txt backend/app/util.py
    run run_covenant COVENANT_TRIGGER=pre-commit \
        LINT_CMD='true' TYPE_CMD='true' COMPLEXITY_CMD='true'
    [[ "$output" == *"cd 'backend'"* ]]
    [[ "$output" == *"app/util.py"* ]]
    [[ "$output" != *"backend/app/util.py"* ]]
}

@test "frontend/package.json (jest) is discovered when nothing is at repo root" {
    mkdir -p frontend
    cat > frontend/package.json <<'EOF'
{"name": "web", "scripts": {"test": "jest"}, "devDependencies": {"jest": "^29.0.0"}}
EOF
    mkdir -p frontend/src
    echo "export const x = 1;" > frontend/src/util.ts
    git add frontend/package.json frontend/src/util.ts
    run run_covenant COVENANT_TRIGGER=pre-commit \
        LINT_CMD='true' TYPE_CMD='true' COMPLEXITY_CMD='true'
    [[ "$output" == *"inferred test runners"* ]]
    [[ "$output" == *"cd 'frontend'"* ]]
    [[ "$output" != *"no test runner was found"* ]]
}

@test "root-level manifests still take priority over subdirectory manifests (no regression)" {
    echo "pytest==8.0.0" > requirements.txt
    echo "def add(a, b): return a + b" > util.py
    git add requirements.txt util.py
    run run_covenant COVENANT_TRIGGER=pre-commit \
        LINT_CMD='true' TYPE_CMD='true' COMPLEXITY_CMD='true'
    [[ "$output" == *"inferred test runners"* ]]
    [[ "$output" != *"cd '"* ]]
}

@test "no manifest anywhere (root or known subdirs) still hard-blocks a backend change" {
    mkdir -p backend/app
    echo "def add(a, b): return a + b" > backend/app/util.py
    git add backend/app/util.py
    run run_covenant COVENANT_TRIGGER=pre-commit \
        LINT_CMD='true' TYPE_CMD='true' COMPLEXITY_CMD='true'
    [ "$status" -eq 1 ]
    [[ "$output" == *"no test runner was found"* ]]
}
