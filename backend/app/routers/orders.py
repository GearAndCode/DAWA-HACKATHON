import datetime
from typing import List
from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy.orm import Session
from app.database import get_db
from app.models.order import Order, OrderStatusHistory
from app.models.invoice import Invoice
from app.schemas.order import OrderCreateRequest, OrderResponse
from app.routers.invoices import _format_invoice_response
from app.core.config import settings

router = APIRouter(prefix="/orders", tags=["Orders & Patient Tracking"])

def _generate_order_number(db: Session) -> str:
    count = db.query(Order).count() + 1
    year = datetime.datetime.utcnow().year
    return f"DAWA-{year}-{count:04d}"

@router.post("/create", response_model=OrderResponse)
def create_order(req: OrderCreateRequest, db: Session = Depends(get_db)):
    """
    Creates an order once the patient approves the invoice and selects
    fulfillment (Pickup or Home Delivery).
    """
    invoice = db.query(Invoice).filter(Invoice.id == req.invoice_id).first()
    if not invoice:
        raise HTTPException(status_code=404, detail="Invoice not found")

    is_delivery = req.fulfillment_type.lower() == "delivery"
    delivery_fee = settings.DEFAULT_DELIVERY_FEE if is_delivery else 0.0
    total_amount = round(invoice.subtotal + delivery_fee, 2)

    # Update invoice delivery fee and total
    invoice.delivery_fee = delivery_fee
    invoice.total_amount = total_amount
    invoice.status = "APPROVED"

    order_number = _generate_order_number(db)
    
    order = Order(
        order_number=order_number,
        patient_id=req.patient_id or invoice.patient_id or 1,
        pharmacy_id=invoice.pharmacy_id,
        invoice_id=invoice.id,
        prescription_id=invoice.prescription_id,
        fulfillment_type="delivery" if is_delivery else "pickup",
        delivery_address=req.delivery_address or ("Gulberg III, Lahore (Demo Address)" if is_delivery else None),
        delivery_latitude=req.delivery_latitude,
        delivery_longitude=req.delivery_longitude,
        delivery_fee=delivery_fee,
        total_amount=total_amount,
        status="Order Placed",
        payment_method=req.payment_method or "Pay at Pickup / Cash on Delivery (Demo)",
    )
    db.add(order)
    db.flush()

    # Add initial history logs
    hist1 = OrderStatusHistory(
        order_id=order.id,
        status="Order Placed",
        notes=f"Order submitted by patient. Fulfillment: {order.fulfillment_type.capitalize()}.",
        changed_by="Patient",
    )
    hist2 = OrderStatusHistory(
        order_id=order.id,
        status="Awaiting Pharmacist Verification",
        notes="Prescription routed to licensed pharmacist for clinical review.",
        changed_by="System",
    )
    db.add(hist1)
    db.add(hist2)

    order.status = "Awaiting Pharmacist Verification"
    db.commit()
    db.refresh(order)

    return _format_order_response(order)

@router.get("", response_model=List[OrderResponse])
def get_patient_orders(db: Session = Depends(get_db)):
    """Get all orders with full status timeline history."""
    orders = db.query(Order).order_by(Order.created_at.desc()).all()
    return [_format_order_response(o) for o in orders]

@router.get("/{order_id}", response_model=OrderResponse)
def get_order_by_id(order_id: int, db: Session = Depends(get_db)):
    order = db.query(Order).filter(Order.id == order_id).first()
    if not order:
        raise HTTPException(status_code=404, detail="Order not found")
    return _format_order_response(order)

def _format_order_response(order: Order) -> OrderResponse:
    return OrderResponse(
        id=order.id,
        order_number=order.order_number,
        patient_id=order.patient_id,
        pharmacy_id=order.pharmacy_id,
        pharmacy_name=order.pharmacy.name if order.pharmacy else "DAWA Pharmacy",
        pharmacy_address=order.pharmacy.address if order.pharmacy else "Lahore, Pakistan",
        invoice_id=order.invoice_id,
        prescription_id=order.prescription_id,
        fulfillment_type=order.fulfillment_type,
        delivery_address=order.delivery_address,
        delivery_fee=order.delivery_fee,
        total_amount=order.total_amount,
        status=order.status,
        payment_method=order.payment_method,
        rejection_reason=order.rejection_reason,
        pharmacist_notes=order.pharmacist_notes,
        created_at=order.created_at,
        updated_at=order.updated_at,
        history=[
            {
                "id": h.id,
                "status": h.status,
                "notes": h.notes,
                "changed_by": h.changed_by,
                "timestamp": h.timestamp,
            }
            for h in order.history
        ],
        invoice=_format_invoice_response(order.invoice) if order.invoice else None
    )
