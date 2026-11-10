import datetime
from typing import List, Optional
from pydantic import BaseModel
from fastapi import APIRouter, Depends, HTTPException, Query
from sqlalchemy.orm import Session
from sqlalchemy import func

from app.database import get_db
from app.models.urgency_assessment import (
    PatientUrgencyAssessment,
    PharmacistUrgencyReview,
    ResourceAllocation,
    AllocationHistory,
)
from app.models.inventory import PharmacyInventory
from app.models.pharmacy import Pharmacy
from app.models.medicine import Medicine
from app.models.prescription import Prescription, PrescriptionItem
from app.models.patient import Patient
from app.schemas.urgency import (
    UrgencyAssessmentCreate,
    UrgencyAssessmentBatchCreate,
    UrgencyAssessmentUpdate,
    UrgencyAssessmentResponse,
    PharmacistReviewCreate,
    PharmacistReviewResponse,
    ShortageSummary,
    ResourceAllocationRunRequest,
    ResourceAllocationOverrideRequest,
    ResourceAllocationResponse,
    AllocationHistoryResponse,
)
from app.services.urgency_service import (
    calculate_preliminary_logistical_priority,
    run_fair_resource_allocation,
    override_resource_allocation,
)

router = APIRouter(tags=["Clinical Urgency & Fair Resource Allocation"])

# Helper to format response
def _format_assessment(a: PatientUrgencyAssessment) -> dict:
    review_data = None
    if a.pharmacist_review:
        review_data = {
            "id": a.pharmacist_review.id,
            "urgency_assessment_id": a.pharmacist_review.urgency_assessment_id,
            "pharmacist_id": a.pharmacist_review.pharmacist_id,
            "pharmacist_name": a.pharmacist_review.pharmacist_name,
            "clinical_urgency": a.pharmacist_review.clinical_urgency,
            "verification_status": a.pharmacist_review.verification_status,
            "assessment_notes": a.pharmacist_review.assessment_notes,
            "decision_reason": a.pharmacist_review.decision_reason,
            "reviewed_at": a.pharmacist_review.reviewed_at,
            "created_at": a.pharmacist_review.created_at,
        }

    return {
        "id": a.id,
        "patient_id": a.patient_id,
        "prescription_id": a.prescription_id,
        "prescription_item_id": a.prescription_item_id,
        "medicine_name": a.medicine_name,
        "has_run_out": a.has_run_out,
        "remaining_medicine_status": a.remaining_medicine_status,
        "requested_timeframe": a.requested_timeframe,
        "treatment_status": a.treatment_status,
        "next_dose_timeframe": a.next_dose_timeframe,
        "alternative_pharmacy_available": a.alternative_pharmacy_available,
        "alternative_availability_verified": a.alternative_availability_verified or False,
        "additional_information": a.additional_information,
        "preliminary_logistical_priority": a.preliminary_logistical_priority,
        "assessment_status": a.assessment_status,
        "created_at": a.created_at,
        "updated_at": a.updated_at,
        "pharmacist_review": review_data,
    }


def _format_allocation(alloc: ResourceAllocation) -> dict:
    history_list = []
    if alloc.history:
        for h in alloc.history:
            history_list.append({
                "id": h.id,
                "allocation_id": h.allocation_id,
                "previous_status": h.previous_status,
                "new_status": h.new_status,
                "previous_quantity": h.previous_quantity,
                "new_quantity": h.new_quantity,
                "changed_by": h.changed_by,
                "reason": h.reason,
                "timestamp": h.timestamp,
            })

    return {
        "id": alloc.id,
        "urgency_assessment_id": alloc.urgency_assessment_id,
        "pharmacy_id": alloc.pharmacy_id,
        "pharmacy_name": alloc.pharmacy.name if alloc.pharmacy else None,
        "medicine_id": alloc.medicine_id,
        "medicine_name": alloc.medicine.brand_name if alloc.medicine else None,
        "patient_id": alloc.patient_id,
        "prescription_id": alloc.prescription_id,
        "prescription_item_id": alloc.prescription_item_id,
        "requested_quantity": alloc.requested_quantity,
        "allocated_quantity": alloc.allocated_quantity,
        "remaining_quantity": alloc.remaining_quantity,
        "allocation_status": alloc.allocation_status,
        "priority_basis": alloc.priority_basis,
        "allocation_explanation": alloc.allocation_explanation,
        "pharmacist_approved": alloc.pharmacist_approved,
        "approved_by": alloc.approved_by,
        "approved_at": alloc.approved_at,
        "is_overridden": alloc.is_overridden,
        "override_reason": alloc.override_reason,
        "created_at": alloc.created_at,
        "updated_at": alloc.updated_at,
        "history": history_list,
    }


# ---------------------------------------------------------
# Patient Urgency Assessment Endpoints
# ---------------------------------------------------------

@router.post("/urgency-assessments", response_model=UrgencyAssessmentResponse)
def submit_urgency_assessment(
    req: UrgencyAssessmentCreate,
    db: Session = Depends(get_db)
):
    """
    Patient submits answers regarding medicine urgency for a prescription item.
    Calculates transparent preliminary logistical priority.
    """
    prescription = db.query(Prescription).filter(Prescription.id == req.prescription_id).first()
    if not prescription:
        raise HTTPException(status_code=404, detail="Prescription not found")

    preliminary_priority = calculate_preliminary_logistical_priority(
        has_run_out=req.has_run_out,
        requested_timeframe=req.requested_timeframe,
        treatment_status=req.treatment_status,
        next_dose_timeframe=req.next_dose_timeframe,
        alternative_pharmacy_available=req.alternative_pharmacy_available,
        alternative_availability_verified=req.alternative_availability_verified or False,
    )

    assessment = PatientUrgencyAssessment(
        patient_id=req.patient_id or prescription.patient_id or 1,
        prescription_id=req.prescription_id,
        prescription_item_id=req.prescription_item_id,
        medicine_name=req.medicine_name,
        has_run_out=req.has_run_out,
        remaining_medicine_status=req.remaining_medicine_status,
        requested_timeframe=req.requested_timeframe,
        treatment_status=req.treatment_status,
        next_dose_timeframe=req.next_dose_timeframe,
        alternative_pharmacy_available=req.alternative_pharmacy_available,
        alternative_availability_verified=req.alternative_availability_verified or False,
        additional_information=req.additional_information,
        preliminary_logistical_priority=preliminary_priority,
        assessment_status="Awaiting Pharmacist Review",
    )
    db.add(assessment)
    db.commit()
    db.refresh(assessment)
    return _format_assessment(assessment)


@router.post("/urgency-assessments/batch", response_model=List[UrgencyAssessmentResponse])
def submit_batch_urgency_assessments(
    batch: UrgencyAssessmentBatchCreate,
    db: Session = Depends(get_db)
):
    """
    Submit multiple medicine assessments or prescription-level assessments in a single call.
    """
    prescription = db.query(Prescription).filter(Prescription.id == batch.prescription_id).first()
    if not prescription:
        raise HTTPException(status_code=404, detail="Prescription not found")

    results = []
    for item in batch.items:
        preliminary_priority = calculate_preliminary_logistical_priority(
            has_run_out=item.has_run_out,
            requested_timeframe=item.requested_timeframe,
            treatment_status=item.treatment_status,
            next_dose_timeframe=item.next_dose_timeframe,
            alternative_pharmacy_available=item.alternative_pharmacy_available,
            alternative_availability_verified=item.alternative_availability_verified or False,
        )

        assessment = PatientUrgencyAssessment(
            patient_id=batch.patient_id or prescription.patient_id or 1,
            prescription_id=batch.prescription_id,
            prescription_item_id=item.prescription_item_id,
            medicine_name=item.medicine_name,
            has_run_out=item.has_run_out,
            remaining_medicine_status=item.remaining_medicine_status,
            requested_timeframe=item.requested_timeframe,
            treatment_status=item.treatment_status,
            next_dose_timeframe=item.next_dose_timeframe,
            alternative_pharmacy_available=item.alternative_pharmacy_available,
            alternative_availability_verified=item.alternative_availability_verified or False,
            additional_information=item.additional_information,
            preliminary_logistical_priority=preliminary_priority,
            assessment_status="Awaiting Pharmacist Review",
        )
        db.add(assessment)
        results.append(assessment)

    db.commit()
    for a in results:
        db.refresh(a)
    return [_format_assessment(a) for a in results]


@router.get("/urgency-assessments/{assessment_id}", response_model=UrgencyAssessmentResponse)
def get_urgency_assessment(assessment_id: int, db: Session = Depends(get_db)):
    assessment = db.query(PatientUrgencyAssessment).filter(PatientUrgencyAssessment.id == assessment_id).first()
    if not assessment:
        raise HTTPException(status_code=404, detail="Assessment not found")
    return _format_assessment(assessment)


@router.get("/urgency-assessments/prescription/{prescription_id}", response_model=List[UrgencyAssessmentResponse])
def get_assessments_for_prescription(prescription_id: int, db: Session = Depends(get_db)):
    assessments = (
        db.query(PatientUrgencyAssessment)
        .filter(PatientUrgencyAssessment.prescription_id == prescription_id)
        .all()
    )
    return [_format_assessment(a) for a in assessments]


@router.get("/urgency-assessments/patient/{patient_id}", response_model=List[UrgencyAssessmentResponse])
def get_assessments_for_patient(patient_id: int, db: Session = Depends(get_db)):
    assessments = (
        db.query(PatientUrgencyAssessment)
        .filter(PatientUrgencyAssessment.patient_id == patient_id)
        .order_by(PatientUrgencyAssessment.created_at.desc())
        .all()
    )
    return [_format_assessment(a) for a in assessments]


@router.put("/urgency-assessments/{assessment_id}", response_model=UrgencyAssessmentResponse)
def update_urgency_assessment(
    assessment_id: int,
    req: UrgencyAssessmentUpdate,
    db: Session = Depends(get_db)
):
    """
    Allows a patient to update their responses prior to final pharmacist verification.
    """
    assessment = db.query(PatientUrgencyAssessment).filter(PatientUrgencyAssessment.id == assessment_id).first()
    if not assessment:
        raise HTTPException(status_code=404, detail="Assessment not found")

    if assessment.assessment_status == "Assessment Verified":
        raise HTTPException(
            status_code=400,
            detail="Cannot edit answers after pharmacist clinical verification has been completed."
        )

    if req.has_run_out is not None:
        assessment.has_run_out = req.has_run_out
    if req.remaining_medicine_status is not None:
        assessment.remaining_medicine_status = req.remaining_medicine_status
    if req.requested_timeframe is not None:
        assessment.requested_timeframe = req.requested_timeframe
    if req.treatment_status is not None:
        assessment.treatment_status = req.treatment_status
    if req.next_dose_timeframe is not None:
        assessment.next_dose_timeframe = req.next_dose_timeframe
    if req.alternative_pharmacy_available is not None:
        assessment.alternative_pharmacy_available = req.alternative_pharmacy_available
    if req.alternative_availability_verified is not None:
        assessment.alternative_availability_verified = req.alternative_availability_verified
    if req.additional_information is not None:
        assessment.additional_information = req.additional_information

    # Recalculate logistical priority
    assessment.preliminary_logistical_priority = calculate_preliminary_logistical_priority(
        has_run_out=assessment.has_run_out,
        requested_timeframe=assessment.requested_timeframe,
        treatment_status=assessment.treatment_status,
        next_dose_timeframe=assessment.next_dose_timeframe,
        alternative_pharmacy_available=assessment.alternative_pharmacy_available,
        alternative_availability_verified=assessment.alternative_availability_verified or False,
    )

    db.commit()
    db.refresh(assessment)
    return _format_assessment(assessment)


# ---------------------------------------------------------
# Pharmacist Review & Fair Resource Allocation Endpoints
# ---------------------------------------------------------

@router.get("/admin/urgency-assessments/pending", response_model=List[UrgencyAssessmentResponse])
def get_pending_urgency_assessments(db: Session = Depends(get_db)):
    """
    Pharmacist view of all assessments requiring clinical verification.
    """
    assessments = (
        db.query(PatientUrgencyAssessment)
        .filter(PatientUrgencyAssessment.assessment_status.in_(["Awaiting Pharmacist Review", "Further Review Required"]))
        .order_by(PatientUrgencyAssessment.created_at.asc())
        .all()
    )
    return [_format_assessment(a) for a in assessments]


@router.post("/admin/urgency-assessments/{assessment_id}/review", response_model=UrgencyAssessmentResponse)
def review_urgency_assessment(
    assessment_id: int,
    req: PharmacistReviewCreate,
    db: Session = Depends(get_db)
):
    """
    Authorized pharmacist assigns clinical urgency classification and records rationale.
    """
    assessment = db.query(PatientUrgencyAssessment).filter(PatientUrgencyAssessment.id == assessment_id).first()
    if not assessment:
        raise HTTPException(status_code=404, detail="Assessment not found")

    valid_urgency = ["Urgent", "Priority", "Routine", "Further review required"]
    if req.clinical_urgency not in valid_urgency:
        raise HTTPException(
            status_code=400,
            detail=f"Invalid clinical urgency. Must be one of: {', '.join(valid_urgency)}"
        )

    # Check if review already exists
    review = db.query(PharmacistUrgencyReview).filter(
        PharmacistUrgencyReview.urgency_assessment_id == assessment_id
    ).first()

    now = datetime.datetime.utcnow()
    if review:
        review.clinical_urgency = req.clinical_urgency
        review.verification_status = req.verification_status
        review.assessment_notes = req.assessment_notes
        review.decision_reason = req.decision_reason
        review.pharmacist_id = req.pharmacist_id
        review.pharmacist_name = req.pharmacist_name or "Licensed Pharmacist"
        review.reviewed_at = now
    else:
        review = PharmacistUrgencyReview(
            urgency_assessment_id=assessment_id,
            pharmacist_id=req.pharmacist_id,
            pharmacist_name=req.pharmacist_name or "Licensed Pharmacist",
            clinical_urgency=req.clinical_urgency,
            verification_status=req.verification_status,
            assessment_notes=req.assessment_notes,
            decision_reason=req.decision_reason,
            reviewed_at=now,
        )
        db.add(review)

    # Update assessment status
    if req.verification_status == "VERIFIED":
        assessment.assessment_status = "Assessment Verified"
    elif req.verification_status == "REVIEW_REQUIRED":
        assessment.assessment_status = "Further Review Required"
    elif req.verification_status == "REJECTED":
        assessment.assessment_status = "Rejected"

    db.commit()
    db.refresh(assessment)
    return _format_assessment(assessment)


@router.get("/admin/resource-allocation/shortages", response_model=List[ShortageSummary])
def get_inventory_shortages(db: Session = Depends(get_db)):
    """
    Identifies medicines in pharmacy inventories where total requested quantity exceeds
    available stock.
    """
    # Join allocations grouped by pharmacy and medicine
    results = []
    
    # Check all active pharmacy inventories
    inventories = db.query(PharmacyInventory).all()
    for inv in inventories:
        # Sum requested quantity of pending/waitlisted allocations
        active_allocs = (
            db.query(ResourceAllocation)
            .filter(
                ResourceAllocation.pharmacy_id == inv.pharmacy_id,
                ResourceAllocation.medicine_id == inv.medicine_id,
                ResourceAllocation.allocation_status.in_(["Allocation Pending", "Partially Allocated", "Waitlisted"])
            )
            .all()
        )
        
        total_requested = sum(a.requested_quantity for a in active_allocs)
        if total_requested > inv.stock_quantity or len(active_allocs) > 1:
            shortage = max(0, total_requested - inv.stock_quantity)
            pending_assessments = sum(
                1 for a in active_allocs
                if a.assessment and a.assessment.assessment_status == "Awaiting Pharmacist Review"
            )
            allocated_count = sum(1 for a in active_allocs if a.allocation_status in ["Fully Allocated", "Partially Allocated"])
            waitlisted_count = sum(1 for a in active_allocs if a.allocation_status == "Waitlisted")

            results.append(ShortageSummary(
                pharmacy_id=inv.pharmacy_id,
                pharmacy_name=inv.pharmacy.name if inv.pharmacy else "Pharmacy",
                medicine_id=inv.medicine_id,
                medicine_name=inv.medicine.brand_name if inv.medicine else "Medicine",
                stock_quantity=inv.stock_quantity,
                total_requested_quantity=total_requested,
                shortage_quantity=shortage,
                affected_patients_count=len(active_allocs),
                pending_assessments_count=pending_assessments,
                allocated_count=allocated_count,
                waitlisted_count=waitlisted_count,
            ))

    return results


class CreateAllocationRequest(BaseModel):
    pharmacy_id: int
    medicine_id: int
    patient_id: Optional[int] = 1
    prescription_id: Optional[int] = None
    prescription_item_id: Optional[int] = None
    urgency_assessment_id: Optional[int] = None
    requested_quantity: int


@router.post("/resource-allocation/request", response_model=ResourceAllocationResponse)
def create_allocation_request(
    req: CreateAllocationRequest,
    db: Session = Depends(get_db)
):
    """
    Enters a patient's medicine request into the resource allocation system.
    """
    pharmacy = db.query(Pharmacy).filter(Pharmacy.id == req.pharmacy_id).first()
    if not pharmacy:
        raise HTTPException(status_code=404, detail="Pharmacy not found")

    medicine = db.query(Medicine).filter(Medicine.id == req.medicine_id).first()
    if not medicine:
        raise HTTPException(status_code=404, detail="Medicine not found")

    inv = (
        db.query(PharmacyInventory)
        .filter(
            PharmacyInventory.pharmacy_id == req.pharmacy_id,
            PharmacyInventory.medicine_id == req.medicine_id
        )
        .first()
    )
    current_stock = inv.stock_quantity if inv else 0

    alloc = ResourceAllocation(
        pharmacy_id=req.pharmacy_id,
        medicine_id=req.medicine_id,
        patient_id=req.patient_id,
        prescription_id=req.prescription_id,
        prescription_item_id=req.prescription_item_id,
        urgency_assessment_id=req.urgency_assessment_id,
        requested_quantity=req.requested_quantity,
        allocated_quantity=0,
        remaining_quantity=req.requested_quantity,
        allocation_status="Allocation Pending",
        allocation_explanation=(
            f"Request for {req.requested_quantity} units registered. Current pharmacy stock: {current_stock} units. "
            f"Awaiting clinical review and fair allocation processing."
        ),
    )
    db.add(alloc)
    db.commit()
    db.refresh(alloc)
    return _format_allocation(alloc)


@router.post("/admin/resource-allocation/run", response_model=List[ResourceAllocationResponse])
def run_allocation(
    req: ResourceAllocationRunRequest,
    pharmacist_name: str = Query("Licensed Pharmacist"),
    db: Session = Depends(get_db)
):
    """
    Executes the fair resource allocation engine for the given pharmacy and medicine.
    """
    try:
        results = run_fair_resource_allocation(
            pharmacy_id=req.pharmacy_id,
            medicine_id=req.medicine_id,
            db=db,
            pharmacist_name=pharmacist_name,
        )
        return [_format_allocation(a) for a in results]
    except Exception as e:
        db.rollback()
        raise HTTPException(status_code=400, detail=str(e))


@router.get("/admin/resource-allocation/pharmacy/{pharmacy_id}/medicine/{medicine_id}", response_model=List[ResourceAllocationResponse])
def get_allocations_for_inventory(
    pharmacy_id: int,
    medicine_id: int,
    db: Session = Depends(get_db)
):
    allocs = (
        db.query(ResourceAllocation)
        .filter(
            ResourceAllocation.pharmacy_id == pharmacy_id,
            ResourceAllocation.medicine_id == medicine_id,
        )
        .order_by(ResourceAllocation.created_at.desc())
        .all()
    )
    return [_format_allocation(a) for a in allocs]


@router.get("/patient/resource-allocations/{patient_id}", response_model=List[ResourceAllocationResponse])
def get_patient_allocations(
    patient_id: int,
    db: Session = Depends(get_db)
):
    """
    Patient view of their own allocation outcomes and explanations.
    Does NOT leak information about other patients.
    """
    allocs = (
        db.query(ResourceAllocation)
        .filter(ResourceAllocation.patient_id == patient_id)
        .order_by(ResourceAllocation.created_at.desc())
        .all()
    )
    return [_format_allocation(a) for a in allocs]


@router.get("/resource-allocation/prescription/{prescription_id}", response_model=List[ResourceAllocationResponse])
def get_prescription_allocations(
    prescription_id: int,
    db: Session = Depends(get_db)
):
    allocs = (
        db.query(ResourceAllocation)
        .filter(ResourceAllocation.prescription_id == prescription_id)
        .order_by(ResourceAllocation.created_at.desc())
        .all()
    )
    return [_format_allocation(a) for a in allocs]


@router.post("/admin/resource-allocation/{allocation_id}/override", response_model=ResourceAllocationResponse)
def override_allocation(
    allocation_id: int,
    req: ResourceAllocationOverrideRequest,
    db: Session = Depends(get_db)
):
    """
    Pharmacist manual override with mandatory clinical justification.
    """
    try:
        updated = override_resource_allocation(
            allocation_id=allocation_id,
            new_allocated_qty=req.override_allocated_quantity,
            override_reason=req.override_reason,
            pharmacist_name=req.pharmacist_name or "Licensed Pharmacist",
            db=db,
        )
        return _format_allocation(updated)
    except Exception as e:
        db.rollback()
        raise HTTPException(status_code=400, detail=str(e))


@router.get("/admin/resource-allocation/history", response_model=List[AllocationHistoryResponse])
def get_allocation_audit_history(
    allocation_id: Optional[int] = None,
    limit: int = 50,
    db: Session = Depends(get_db)
):
    """
    Pharmacist audit trail of allocation adjustments and overrides.
    """
    query = db.query(AllocationHistory).order_by(AllocationHistory.timestamp.desc())
    if allocation_id:
        query = query.filter(AllocationHistory.allocation_id == allocation_id)
    history = query.limit(limit).all()
    return history
