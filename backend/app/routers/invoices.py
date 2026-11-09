from fastapi import APIRouter, Depends, HTTPException, Query
from sqlalchemy.orm import Session
from app.database import get_db
from app.models.invoice import Invoice
from app.models.prescription import Prescription
from app.schemas.prescription import PrescriptionItemCreate
from app.schemas.invoice import InvoiceResponse, InvoiceApprovalRequest
from app.services.invoice_service import create_invoice_for_pharmacy

router = APIRouter(prefix="/invoices", tags=["Invoices"])

@router.post("/generate", response_model=InvoiceResponse)
def generate_invoice(
    prescription_id: int = Query(...),
    pharmacy_id: int = Query(...),
    delivery: bool = Query(False),
    db: Session = Depends(get_db)
):
    """
    Generates an itemized PKR invoice for the chosen pharmacy and prescription items.
    """
    presc = db.query(Prescription).filter(Prescription.id == prescription_id).first()
    if not presc:
        raise HTTPException(status_code=404, detail="Prescription not found")

    items = [
        PrescriptionItemCreate(
            medicine_name=it.medicine_name,
            strength=it.strength,
            dosage_form=it.dosage_form,
            quantity=it.quantity,
            frequency=it.frequency,
            duration=it.duration,
            instructions=it.instructions,
            confidence=it.confidence
        )
        for it in presc.items
    ]

    try:
        invoice = create_invoice_for_pharmacy(
            db=db,
            pharmacy_id=pharmacy_id,
            items=items,
            prescription_id=prescription_id,
            patient_id=presc.patient_id or 1,
            include_delivery_fee=delivery
        )
        return _format_invoice_response(invoice)
    except Exception as e:
        raise HTTPException(status_code=400, detail=str(e))

@router.get("/{invoice_id}", response_model=InvoiceResponse)
def get_invoice(invoice_id: int, db: Session = Depends(get_db)):
    invoice = db.query(Invoice).filter(Invoice.id == invoice_id).first()
    if not invoice:
        raise HTTPException(status_code=404, detail="Invoice not found")
    return _format_invoice_response(invoice)

@router.post("/{invoice_id}/decision", response_model=InvoiceResponse)
def invoice_decision(
    invoice_id: int,
    req: InvoiceApprovalRequest,
    db: Session = Depends(get_db)
):
    """
    Patient approves or rejects the itemized invoice inside the app.
    """
    invoice = db.query(Invoice).filter(Invoice.id == invoice_id).first()
    if not invoice:
        raise HTTPException(status_code=404, detail="Invoice not found")

    invoice.status = "APPROVED" if req.approved else "REJECTED"
    db.commit()
    db.refresh(invoice)
    return _format_invoice_response(invoice)

def _format_invoice_response(invoice: Invoice) -> InvoiceResponse:
    return InvoiceResponse(
        id=invoice.id,
        invoice_number=invoice.invoice_number,
        patient_id=invoice.patient_id,
        pharmacy_id=invoice.pharmacy_id,
        pharmacy_name=invoice.pharmacy.name if invoice.pharmacy else "DAWA Pharmacy",
        pharmacy_address=invoice.pharmacy.address if invoice.pharmacy else "Lahore, Pakistan",
        prescription_id=invoice.prescription_id,
        subtotal=invoice.subtotal,
        delivery_fee=invoice.delivery_fee,
        total_amount=invoice.total_amount,
        currency=invoice.currency,
        status=invoice.status,
        created_at=invoice.created_at,
        items=[
            {
                "id": it.id,
                "medicine_name": it.medicine_name,
                "strength": it.strength,
                "quantity": it.quantity,
                "unit_price": it.unit_price,
                "line_total": it.line_total,
            }
            for it in invoice.items
        ]
    )
