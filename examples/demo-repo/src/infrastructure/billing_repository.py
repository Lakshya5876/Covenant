"""Infrastructure layer — the only place raw SQL/DB access belongs."""
from src.domain.models import Invoice


class BillingRepository:
    def __init__(self, connection):
        self.connection = connection

    def find_by_id(self, invoice_id: str) -> Invoice:
        cursor = self.connection.cursor()
        cursor.execute("SELECT id, customer_id, amount_cents, status FROM invoices WHERE id = %s", (invoice_id,))
        row = cursor.fetchone()
        return Invoice(id=row[0], customer_id=row[1], amount_cents=row[2], status=row[3])
