"""Application layer — business logic orchestration. No SQL, no HTTP
framework imports here (that's exactly what Covenant's layer-boundary scan
blocks) — only domain objects and calls to the infrastructure layer."""
from src.domain.models import Invoice
from src.infrastructure.billing_repository import BillingRepository


class BillingService:
    def __init__(self, repository: BillingRepository):
        self.repository = repository

    def mark_paid(self, invoice_id: str) -> Invoice:
        invoice = self.repository.find_by_id(invoice_id)
        if invoice.status == "void":
            raise ValueError(f"cannot mark a void invoice as paid: {invoice_id}")
        return Invoice(id=invoice.id, customer_id=invoice.customer_id,
                        amount_cents=invoice.amount_cents, status="paid")
