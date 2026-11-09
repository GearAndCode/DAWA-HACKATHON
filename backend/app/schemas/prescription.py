from typing import Optional, List
from datetime import datetime
from pydantic import BaseModel

class PrescriptionItemBase(BaseModel):
    medicine_name: str
    strength: Optional[str] = None
    dosage_form: Optional[str] = None
    quantity: int = 1
    frequency: Optional[str] = None
    duration: Optional[str] = None
    instructions: Optional[str] = None
    confidence: float = 0.85

class PrescriptionItemCreate(PrescriptionItemBase):
    pass

class PrescriptionItemResponse(PrescriptionItemBase):
    id: int
    matched_medicine_id: Optional[int] = None

    class Config:
        from_attributes = True

class PrescriptionConfirmRequest(BaseModel):
    prescription_id: int
    patient_id: Optional[int] = 1
    items: List[PrescriptionItemCreate]
    patient_latitude: Optional[float] = None
    patient_longitude: Optional[float] = None

class OCRResultResponse(BaseModel):
    prescription_id: int
    image_url: str
    ocr_raw_text: str
    ocr_confidence: float
    is_uncertain: bool
    uncertainty_reason: Optional[str] = None
    patient_name: Optional[str] = None
    patient_age: Optional[str] = None
    doctor_name: Optional[str] = None
    clinic_name: Optional[str] = None
    prescription_date: Optional[str] = None
    extracted_items: List[PrescriptionItemCreate]

class PrescriptionResponse(BaseModel):
    id: int
    patient_id: Optional[int]
    image_path: str
    ocr_raw_text: Optional[str]
    ocr_confidence: float
    status: str
    created_at: datetime
    items: List[PrescriptionItemResponse] = []

    class Config:
        from_attributes = True
