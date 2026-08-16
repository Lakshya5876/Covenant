load test_helper

setup() {
    setup_covenant_repo
}

teardown() {
    teardown_covenant_repo
}

@test "secrets scan blocks staged credential patterns" {
    printf 'DATABASE_PASSWORD=super_secret_value\n' > config.env
    git add config.env
    run run_covenant COVENANT_TRIGGER=pre-commit
    [ "$status" -eq 1 ]
    [[ "$output" == *"COVENANT BLOCK: Potential secret"* ]]
}

@test "secrets scan allows placeholder wording" {
    printf '# example placeholder for DATABASE_URL\n' > .env.example
    git add .env.example
    run run_covenant COVENANT_TRIGGER=pre-commit
    [ "$status" -eq 0 ]
}

# Adversarial variants: credential formats with no English keyword ("secret",
# "password", "token"...) nearby, which the pure keyword scan cannot catch on
# its own. These are the specific gap a fresh audit found by direct testing —
# confirmed real before fixing (bare AKIA/ghp_ tokens and PKCS8 keys all
# slipped through the original keyword-only regex).

@test "secrets scan blocks a bare AWS access key with no keyword nearby" {
    printf 'x = "AKIAIOSFODNN7EXAMPLE"\n' > config.py
    git add config.py
    run run_covenant COVENANT_TRIGGER=pre-commit
    [ "$status" -eq 1 ]
    [[ "$output" == *"COVENANT BLOCK: Potential secret"* ]]
}

@test "secrets scan blocks a bare GitHub personal access token with no keyword nearby" {
    printf 'x = "ghp_16C7e42F292c6912E7710c838347Ae178B4a"\n' > config.py
    git add config.py
    run run_covenant COVENANT_TRIGGER=pre-commit
    [ "$status" -eq 1 ]
    [[ "$output" == *"COVENANT BLOCK: Potential secret"* ]]
}

@test "secrets scan blocks a bare Slack token with no keyword nearby" {
    printf 'x = "xoxb-dummy1234567890"\n' > config.py
    git add config.py
    run run_covenant COVENANT_TRIGGER=pre-commit
    [ "$status" -eq 1 ]
    [[ "$output" == *"COVENANT BLOCK: Potential secret"* ]]
}

@test "secrets scan blocks a bare Stripe live key with no keyword nearby" {
    printf 'x = "sk_live_dummy1234567890123456"\n' > config.py
    git add config.py
    run run_covenant COVENANT_TRIGGER=pre-commit
    [ "$status" -eq 1 ]
    [[ "$output" == *"COVENANT BLOCK: Potential secret"* ]]
}

@test "secrets scan blocks a PKCS8 private key with no algorithm prefix" {
    # -----BEGIN PRIVATE KEY----- (no RSA/EC/OPENSSH prefix) is the modern
    # default format for most tooling (e.g. openssl genpkey) — the original
    # regex only matched BEGIN (RSA|EC|OPENSSH|PGP), missing this entirely.
    printf -- '-----BEGIN PRIVATE KEY-----\n' > key.pem
    git add key.pem
    run run_covenant COVENANT_TRIGGER=pre-commit
    [ "$status" -eq 1 ]
    [[ "$output" == *"COVENANT BLOCK: Potential secret"* ]]
}

@test "secrets scan still blocks the original RSA/OPENSSH private key formats (no regression)" {
    printf -- '-----BEGIN OPENSSH PRIVATE KEY-----\n' > key.pem
    git add key.pem
    run run_covenant COVENANT_TRIGGER=pre-commit
    [ "$status" -eq 1 ]
    [[ "$output" == *"COVENANT BLOCK: Potential secret"* ]]
}

# Regression for a real, confirmed bug: the framework's OWN bundled content —
# the v1_release/ dev guide (ordinary prose about "Token Budget") and the
# covenant_state.json template itself (a `"token": {...}` schema section) —
# false-positive-blocked the very first commit of a fresh install, because the
# original regex matched the bare words "token"/"secret"/"password" anywhere,
# with no requirement that they precede an assignment. Confirmed by direct
# reproduction before this fix; independently flagged (but not fixed here) in
# CovenantWin's covenantwin.py source comments.
@test "secrets scan does not false-positive on the framework's own bundled dev-guide content" {
    cp "${SHARED_ROOT}/v1_release/basket-1-brownfield/v1_claude_code_development_guide_existing.md" .
    git add v1_claude_code_development_guide_existing.md
    run run_covenant COVENANT_TRIGGER=pre-commit
    [ "$status" -eq 0 ]
    [[ "$output" != *"COVENANT BLOCK: Potential secret"* ]]
}

@test "secrets scan does not false-positive on the covenant_state.json template's own token schema section" {
    # covenant_state.json is already staged by setup_covenant_repo's cp, but not
    # yet git-added there — add it explicitly so this test doesn't depend on
    # that being true forever.
    git add .claude/covenant_state.json
    run run_covenant COVENANT_TRIGGER=pre-commit
    [ "$status" -eq 0 ]
    [[ "$output" != *"COVENANT BLOCK: Potential secret"* ]]
}

@test "secrets scan does not false-positive on covenant.sh's own STEP 5 comment block" {
    # Regression for a real, self-referential bug found via an actual E2E
    # install: covenant.sh itself is committed as .githooks/covenant.sh on
    # every fresh install, and this exact STEP 5 comment block (explaining the
    # assignment-context fix above) originally quoted literal example syntax
    # that matched the very regex it was describing — false-positive-blocking
    # the "install covenant governance" commit of every single fresh install.
    # setup_covenant_repo already deploys the real templates/covenant.sh to
    # .githooks/covenant.sh; this test just actually stages and commits it,
    # which nothing else here previously did.
    git add .githooks/covenant.sh
    run run_covenant COVENANT_TRIGGER=pre-commit
    [ "$status" -eq 0 ]
    [[ "$output" != *"COVENANT BLOCK: Potential secret"* ]]
}

@test "secrets scan still blocks a real token assignment (no regression from the assignment-context fix)" {
    printf 'token = "abc123realvalue"\n' > config.py
    git add config.py
    run run_covenant COVENANT_TRIGGER=pre-commit
    [ "$status" -eq 1 ]
    [[ "$output" == *"COVENANT BLOCK: Potential secret"* ]]
}

@test "secrets scan still blocks a JSON-quoted token value (no regression from the assignment-context fix)" {
    printf '{"token": "abc123realvalue"}\n' > config.json
    git add config.json
    run run_covenant COVENANT_TRIGGER=pre-commit
    [ "$status" -eq 1 ]
    [[ "$output" == *"COVENANT BLOCK: Potential secret"* ]]
}
