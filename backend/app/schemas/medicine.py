from typing import Optional
from pydantic import BaseModel

class MedicineBase(BaseModel):
    brand_name: str
    generic_name: Optional[str] = None
    strength: str
    dosage_form: str
    category: Optional[str] = None
    prescription_required: bool = False
    description: Optional[str] = None
    default_price: float

class MedicineResponse(MedicineBase):
    id: int

    class Config:
        from_attributes = True

class InventoryItemResponse(BaseModel):
    pharmacy_id: int
    pharmacy_name: str
    medicine_id: int
    stock_quantity: int
    unit_price: float
    is_available: bool

    class Config:
        from_attributes = True
