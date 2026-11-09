from typing import Optional, List, Dict, Any
from datetime import datetime
from pydantic import BaseModel

class PatientInfo(BaseModel):
    name: Optional[str] = None
    age: Optional[str] = None
    gender: Optional[str] = None
    date: Optional[str] = None

class DoctorInfo(BaseModel):
    name: Optional[str] = None
    clinic: Optional[str] = None
    registration_no: Optional[str] = None

class ExtractedMedicine(BaseModel):
    original_name: str
    normalized_name: Optional[str] = None
    strength: Optional[str] = None
    dosage_form: Optional[str] = None
    quantity: int = 1
    instructions: Optional[str] = None
    frequency: Optional[str] = None
    duration: Optional[str] = None
    field_status: str = "verified_from_image" # verified_from_image, needs_verification, manually_entered
    confidence: float = 0.90

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

class PrescriptionExtractionResponse(BaseModel):
    success: bool
    prescription_id: int
    image_url: str
    patient: PatientInfo = PatientInfo()
    doctor: DoctorInfo = DoctorInfo()
    medicines: List[ExtractedMedicine] = []
    clinical_notes: List[str] = []
    warnings: List[str] = []
    requires_patient_review: bool = True
    provider_used: str = "none"

class PrescriptionConfirmItem(BaseModel):
    medicine_name: str
    strength: Optional[str] = None
    dosage_form: Optional[str] = None
    quantity: int = 1
    frequency: Optional[str] = None
    duration: Optional[str] = None
    instructions: Optional[str] = None
    confidence: float = 1.0

class PrescriptionConfirmRequest(BaseModel):
    prescription_id: int
    patient_id: Optional[int] = 1
    items: List[PrescriptionConfirmItem]
    patient_latitude: Optional[float] = None
    patient_longitude: Optional[float] = None

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
