"""Presentation layer — HTTP routes. SQL belongs in infrastructure/, never
here (this is one of the three violation classes Covenant's layer-boundary scan
catches on both platforms)."""
from flask import Flask, jsonify
from src.application.billing_service import BillingService

app = Flask(__name__)


@app.route("/invoices/<invoice_id>/pay", methods=["POST"])
def pay_invoice(invoice_id: str):
    service: BillingService = app.config["billing_service"]
    invoice = service.mark_paid(invoice_id)
    return jsonify({"id": invoice.id, "status": invoice.status})
