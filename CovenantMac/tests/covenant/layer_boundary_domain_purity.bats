load test_helper

# Regression coverage for a real red-team finding: the layer boundary scan
# (covenant.sh STEP 6.5) checked routes/services for cross-layer SQL/HTTP, but
# had no notion of "any framework" leaking into the domain/entities layer —
# a domain entity directly `import sqlalchemy`-ing committed cleanly even
# though CLAUDE.md's four-layer scaffold exists specifically to prevent
# exactly this.

setup() {
    setup_covenant_repo
    mkdir -p app/domain
}

teardown() {
    teardown_covenant_repo
}

@test "layer boundary blocks an ORM import in the domain layer" {
    cat > app/domain/offer.py <<'EOF'
import sqlalchemy

class Offer:
    pass
EOF
    git add app/domain/offer.py
    run run_covenant COVENANT_TRIGGER=pre-commit \
        LINT_CMD='true' \
        TYPE_CMD='true' \
        COMPLEXITY_CMD='true' \
        TEST_CMD='true'
    [ "$status" -eq 1 ]
    [[ "$output" == *"Layer boundary violation"* ]]
    [[ "$output" == *"DOMAIN_HAS_FRAMEWORK_IMPORT"* ]]
}

@test "layer boundary blocks an HTTP framework import in the entities layer" {
    mkdir -p app/entities
    cat > app/entities/user.py <<'EOF'
from fastapi import HTTPException

class User:
    pass
EOF
    git add app/entities/user.py
    run run_covenant COVENANT_TRIGGER=pre-commit \
        LINT_CMD='true' \
        TYPE_CMD='true' \
        COMPLEXITY_CMD='true' \
        TEST_CMD='true'
    [ "$status" -eq 1 ]
    [[ "$output" == *"DOMAIN_HAS_FRAMEWORK_IMPORT"* ]]
}

@test "layer boundary allows pure domain logic with no external imports" {
    cat > app/domain/offer.py <<'EOF'
from dataclasses import dataclass

@dataclass
class Offer:
    price: int

    def is_featured(self) -> bool:
        return self.price > 100
EOF
    git add app/domain/offer.py
    run run_covenant COVENANT_TRIGGER=pre-commit \
        LINT_CMD='true' \
        TYPE_CMD='true' \
        COMPLEXITY_CMD='true' \
        TEST_CMD='true'
    [ "$status" -eq 0 ]
    [[ "$output" != *"DOMAIN_HAS_FRAMEWORK_IMPORT"* ]]
}

@test "layer boundary does not false-positive on a models/ directory (ORM models legitimately import the ORM there)" {
    mkdir -p app/models
    cat > app/models/offer_model.py <<'EOF'
import sqlalchemy

class OfferModel(sqlalchemy.orm.declarative_base()):
    pass
EOF
    git add app/models/offer_model.py
    run run_covenant COVENANT_TRIGGER=pre-commit \
        LINT_CMD='true' \
        TYPE_CMD='true' \
        COMPLEXITY_CMD='true' \
        TEST_CMD='true'
    [ "$status" -eq 0 ]
    [[ "$output" != *"DOMAIN_HAS_FRAMEWORK_IMPORT"* ]]
}
