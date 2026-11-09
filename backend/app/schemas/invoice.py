from typing import Optional, List
from datetime import datetime
from pydantic import BaseModel

class InvoiceItemResponse(BaseModel):
    id: int
    medicine_name: str
    strength: Optional[str] = None
    quantity: int
    unit_price: float
    line_total: float

    class Config:
        from_attributes = True

class InvoiceResponse(BaseModel):
    id: int
    invoice_number: str
    patient_id: Optional[int]
    pharmacy_id: int
    pharmacy_name: str
    pharmacy_address: str
    prescription_id: Optional[int]
    subtotal: float
    delivery_fee: float
    total_amount: float
    currency: str = "PKR"
    status: str
    created_at: datetime
    items: List[InvoiceItemResponse] = []

    class Config:
        from_attributes = True

class InvoiceApprovalRequest(BaseModel):
    approved: bool
    rejection_reason: Optional[str] = None
