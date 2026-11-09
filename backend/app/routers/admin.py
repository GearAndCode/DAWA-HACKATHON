import datetime
from typing import List, Optional
from fastapi import APIRouter, Depends, HTTPException, Header
from pydantic import BaseModel
from sqlalchemy.orm import Session
from app.database import get_db
from app.models.order import Order, OrderStatusHistory
from app.schemas.order import OrderResponse
from app.routers.orders import _format_order_response
from app.core.config import settings

router = APIRouter(prefix="/admin", tags=["Pharmacist Admin Interface"])

class PharmacistVerificationRequest(BaseModel):
    action: str  # "VERIFY" or "REJECT"
    notes: Optional[str] = None
    rejection_reason: Optional[str] = None

class PharmacistStatusUpdateRequest(BaseModel):
    status: str
    notes: Optional[str] = None

@router.get("/orders", response_model=List[OrderResponse])
def get_incoming_orders(
    status_filter: Optional[str] = None,
    db: Session = Depends(get_db)
):
    """
    Returns all incoming orders for the pharmacist review portal.
    """
    query = db.query(Order).order_by(Order.created_at.desc())
    if status_filter:
        query = query.filter(Order.status == status_filter)
    orders = query.all()
    return [_format_order_response(o) for o in orders]

@router.post("/orders/{order_id}/verify", response_model=OrderResponse)
def verify_prescription_order(
    order_id: int,
    req: PharmacistVerificationRequest,
    db: Session = Depends(get_db)
):
    """
    Pharmacist verifies the prescription against the medicines ordered,
    or rejects the order with a clear clinical reason.
    """
    order = db.query(Order).filter(Order.id == order_id).first()
    if not order:
        raise HTTPException(status_code=404, detail="Order not found")

    if req.action.upper() == "VERIFY":
        order.status = "Verified by Pharmacist"
        order.pharmacist_notes = req.notes or "Prescription verified by licensed pharmacist. Stock confirmed."
        
        hist = OrderStatusHistory(
            order_id=order.id,
            status="Verified by Pharmacist",
            notes=order.pharmacist_notes,
            changed_by="Pharmacist",
        )
        db.add(hist)
    elif req.action.upper() == "REJECT":
        order.status = "Rejected by Pharmacist"
        order.rejection_reason = req.rejection_reason or "Unreadable prescription or missing mandatory doctor signature."
        order.pharmacist_notes = req.notes
        
        hist = OrderStatusHistory(
            order_id=order.id,
            status="Rejected by Pharmacist",
            notes=f"Order rejected: {order.rejection_reason}",
            changed_by="Pharmacist",
        )
        db.add(hist)
    else:
        raise HTTPException(status_code=400, detail="Action must be 'VERIFY' or 'REJECT'")

    db.commit()
    db.refresh(order)
    return _format_order_response(order)

@router.post("/orders/{order_id}/update-status", response_model=OrderResponse)
def update_order_stage(
    order_id: int,
    req: PharmacistStatusUpdateRequest,
    db: Session = Depends(get_db)
):
    """
    Updates the operational progress of an order:
    - "Preparing Order"
    - "Ready for Pickup" or "Out for Delivery"
    - "Delivered" or "Collected"
    """
    order = db.query(Order).filter(Order.id == order_id).first()
    if not order:
        raise HTTPException(status_code=404, detail="Order not found")

    valid_statuses = [
        "Awaiting Pharmacist Verification",
        "Verified by Pharmacist",
        "Preparing Order",
        "Ready for Pickup",
        "Out for Delivery",
        "Delivered",
        "Collected",
        "Rejected by Pharmacist"
    ]

    if req.status not in valid_statuses:
        raise HTTPException(
            status_code=400,
            detail=f"Invalid status '{req.status}'. Allowed: {', '.join(valid_statuses)}"
        )

    order.status = req.status
    if req.notes:
        order.pharmacist_notes = req.notes

    hist = OrderStatusHistory(
        order_id=order.id,
        status=req.status,
        notes=req.notes or f"Order transitioned to {req.status}.",
        changed_by="Pharmacist",
    )
    db.add(hist)
    db.commit()
    db.refresh(order)
    return _format_order_response(order)
