"""Domain layer — pure data contracts. Zero framework/infrastructure imports,
by design: this is the one layer Covenant's layer-boundary scan protects most
strictly (see CovenantMac/templates/covenant.sh STEP 6.5, or CovenantWin/src/covenantwin.py's
covenant() step 5)."""
from dataclasses import dataclass


@dataclass(frozen=True)
class Invoice:
    id: str
    customer_id: str
    amount_cents: int
    status: str  # "draft" | "sent" | "paid" | "void"
