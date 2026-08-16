from unittest.mock import MagicMock

from src.application.billing_service import BillingService
from src.domain.models import Invoice


def test_mark_paid_transitions_status():
    repo = MagicMock()
    repo.find_by_id.return_value = Invoice(id="inv_1", customer_id="cust_1", amount_cents=1000, status="sent")
    service = BillingService(repo)

    result = service.mark_paid("inv_1")

    assert result.status == "paid"


def test_mark_paid_rejects_void_invoice():
    repo = MagicMock()
    repo.find_by_id.return_value = Invoice(id="inv_2", customer_id="cust_1", amount_cents=1000, status="void")
    service = BillingService(repo)

    try:
        service.mark_paid("inv_2")
        assert False, "expected ValueError"
    except ValueError:
        pass
