import datetime
from typing import List, Optional
from pydantic import BaseModel, Field

class UrgencyAssessmentCreate(BaseModel):
    patient_id: Optional[int] = 1
    prescription_id: int
    prescription_item_id: Optional[int] = None
    medicine_name: Optional[str] = None
    has_run_out: str  # completely_out, few_doses, enough_for_days, new_prescription
    remaining_medicine_status: Optional[str] = None
    requested_timeframe: str  # asap, 24_hours, 2_to_3_days, 4_to_7_days, enough_for_now
    treatment_status: str  # ongoing, new_prescription, unsure
    next_dose_timeframe: str  # within_few_hours, today, tomorrow, later, unsure
    alternative_pharmacy_available: str  # yes, no, unsure
    alternative_availability_verified: Optional[bool] = False
    additional_information: Optional[str] = None

class UrgencyAssessmentBatchCreate(BaseModel):
    prescription_id: int
    patient_id: Optional[int] = 1
    items: List[UrgencyAssessmentCreate]

class UrgencyAssessmentUpdate(BaseModel):
    has_run_out: Optional[str] = None
    remaining_medicine_status: Optional[str] = None
    requested_timeframe: Optional[str] = None
    treatment_status: Optional[str] = None
    next_dose_timeframe: Optional[str] = None
    alternative_pharmacy_available: Optional[str] = None
    alternative_availability_verified: Optional[bool] = None
    additional_information: Optional[str] = None

class PharmacistReviewCreate(BaseModel):
    clinical_urgency: str  # Urgent, Priority, Routine, Further review required
    verification_status: str = "VERIFIED"  # VERIFIED, REVIEW_REQUIRED, REJECTED
    assessment_notes: Optional[str] = None
    decision_reason: Optional[str] = None
    pharmacist_id: Optional[int] = 1
    pharmacist_name: Optional[str] = "Licensed Pharmacist"

class PharmacistReviewResponse(BaseModel):
    id: int
    urgency_assessment_id: int
    pharmacist_id: Optional[int] = None
    pharmacist_name: Optional[str] = None
    clinical_urgency: str
    verification_status: str
    assessment_notes: Optional[str] = None
    decision_reason: Optional[str] = None
    reviewed_at: datetime.datetime
    created_at: datetime.datetime

    class Config:
        from_attributes = True

class UrgencyAssessmentResponse(BaseModel):
    id: int
    patient_id: Optional[int] = None
    prescription_id: int
    prescription_item_id: Optional[int] = None
    medicine_name: Optional[str] = None
    has_run_out: str
    remaining_medicine_status: Optional[str] = None
    requested_timeframe: str
    treatment_status: str
    next_dose_timeframe: str
    alternative_pharmacy_available: str
    alternative_availability_verified: bool
    additional_information: Optional[str] = None
    preliminary_logistical_priority: str
    assessment_status: str
    created_at: datetime.datetime
    updated_at: datetime.datetime
    pharmacist_review: Optional[PharmacistReviewResponse] = None

    class Config:
        from_attributes = True

class ShortageSummary(BaseModel):
    pharmacy_id: int
    pharmacy_name: str
    medicine_id: int
    medicine_name: str
    stock_quantity: int
    total_requested_quantity: int
    shortage_quantity: int
    affected_patients_count: int
    pending_assessments_count: int
    allocated_count: int
    waitlisted_count: int

class ResourceAllocationRunRequest(BaseModel):
    pharmacy_id: int
    medicine_id: int

class ResourceAllocationOverrideRequest(BaseModel):
    override_allocated_quantity: int
    override_reason: str
    pharmacist_name: Optional[str] = "Licensed Pharmacist"

class AllocationHistoryResponse(BaseModel):
    id: int
    allocation_id: int
    previous_status: Optional[str] = None
    new_status: str
    previous_quantity: Optional[int] = None
    new_quantity: int
    changed_by: str
    reason: Optional[str] = None
    timestamp: datetime.datetime

    class Config:
        from_attributes = True

class ResourceAllocationResponse(BaseModel):
    id: int
    urgency_assessment_id: Optional[int] = None
    pharmacy_id: int
    pharmacy_name: Optional[str] = None
    medicine_id: int
    medicine_name: Optional[str] = None
    patient_id: Optional[int] = None
    prescription_id: Optional[int] = None
    prescription_item_id: Optional[int] = None
    requested_quantity: int
    allocated_quantity: int
    remaining_quantity: int
    allocation_status: str
    priority_basis: Optional[str] = None
    allocation_explanation: str
    pharmacist_approved: bool
    approved_by: Optional[str] = None
    approved_at: Optional[datetime.datetime] = None
    is_overridden: bool
    override_reason: Optional[str] = None
    created_at: datetime.datetime
    updated_at: datetime.datetime
    history: Optional[List[AllocationHistoryResponse]] = []

    class Config:
        from_attributes = True

