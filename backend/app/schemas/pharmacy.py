from typing import Optional, List
from pydantic import BaseModel

class PharmacyBase(BaseModel):
    name: str
    area: str
    address: str
    city: str = "Lahore"
    latitude: float
    longitude: float
    phone: Optional[str] = None
    opening_hours: Optional[str] = "9:00 AM – 11:00 PM"
    description: Optional[str] = None
    is_demo: bool = True
    rating: float = 4.8

class PharmacyResponse(PharmacyBase):
    id: int

    class Config:
        from_attributes = True

class PharmacyWithDistance(PharmacyResponse):
    distance_km: float
    has_all_medicines: Optional[bool] = None
    available_items_count: Optional[int] = None
    total_items_requested: Optional[int] = None
