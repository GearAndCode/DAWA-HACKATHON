from typing import Optional, List
from datetime import datetime
from pydantic import BaseModel
from app.schemas.invoice import InvoiceResponse

class OrderStatusHistoryResponse(BaseModel):
    id: int
    status: str
    notes: Optional[str]
    changed_by: str
    timestamp: datetime

    class Config:
        from_attributes = True

class OrderCreateRequest(BaseModel):
    invoice_id: int
    patient_id: Optional[int] = 1
    fulfillment_type: str = "pickup"  # "pickup" or "delivery"
    delivery_address: Optional[str] = None
    delivery_latitude: Optional[float] = None
    delivery_longitude: Optional[float] = None
    payment_method: Optional[str] = "Pay at Pickup / Cash on Delivery (Demo)"

class OrderStatusUpdateRequest(BaseModel):
    status: str
    notes: Optional[str] = None
    changed_by: Optional[str] = "Pharmacist"
    admin_key: Optional[str] = None

class OrderResponse(BaseModel):
    id: int
    order_number: str
    patient_id: Optional[int]
    pharmacy_id: int
    pharmacy_name: str
    pharmacy_address: str
    invoice_id: Optional[int]
    prescription_id: Optional[int]
    fulfillment_type: str
    delivery_address: Optional[str]
    delivery_fee: float
    total_amount: float
    status: str
    payment_method: str
    rejection_reason: Optional[str]
    pharmacist_notes: Optional[str]
    created_at: datetime
    updated_at: datetime
    history: List[OrderStatusHistoryResponse] = []
    invoice: Optional[InvoiceResponse] = None

    class Config:
        from_attributes = True
