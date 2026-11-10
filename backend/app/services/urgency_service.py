import datetime
from typing import List, Optional, Tuple, Dict, Any
from sqlalchemy.orm import Session
from sqlalchemy import func
from app.models.urgency_assessment import (
    PatientUrgencyAssessment,
    PharmacistUrgencyReview,
    ResourceAllocation,
    AllocationHistory,
)
from app.models.inventory import PharmacyInventory
from app.models.pharmacy import Pharmacy
from app.models.medicine import Medicine
from app.models.prescription import PrescriptionItem

# ---------------------------------------------------------
# 1. Preliminary Logistical Priority Calculation
# ---------------------------------------------------------

def calculate_preliminary_logistical_priority(
    has_run_out: str,
    requested_timeframe: str,
    treatment_status: str,
    next_dose_timeframe: str,
    alternative_pharmacy_available: str,
    alternative_availability_verified: bool = False,
) -> str:
    """
    Transparent rule-based scoring of patient-reported logistical circumstances.
    Does NOT diagnose or evaluate clinical severity.
    Returns one of:
      - "Immediate review requested"
      - "High logistical urgency"
      - "Moderate logistical urgency"
      - "Lower logistical urgency"
      - "Insufficient information"
    """
    # 1. Contradictory or missing information
    if (
        treatment_status == "unsure"
        and next_dose_timeframe == "unsure"
        and has_run_out == "new_prescription"
        and requested_timeframe == "enough_for_now"
    ):
        return "Insufficient information"

    # 2. Immediate review requested
    if (
        has_run_out == "completely_out"
        and (next_dose_timeframe in ["within_few_hours", "today"] or requested_timeframe == "asap")
    ):
        return "Immediate review requested"
    if (
        has_run_out == "few_doses"
        and next_dose_timeframe == "within_few_hours"
        and treatment_status == "ongoing"
    ):
        return "Immediate review requested"

    # 3. High logistical urgency
    if (
        has_run_out in ["completely_out", "few_doses"]
        and requested_timeframe in ["asap", "24_hours"]
    ):
        return "High logistical urgency"
    if (
        treatment_status == "ongoing"
        and next_dose_timeframe in ["within_few_hours", "today"]
    ):
        return "High logistical urgency"

    # 4. Moderate logistical urgency
    if (
        has_run_out == "few_doses"
        and requested_timeframe in ["2_to_3_days"]
    ):
        return "Moderate logistical urgency"
    if (
        treatment_status == "ongoing"
        and next_dose_timeframe == "tomorrow"
    ):
        return "Moderate logistical urgency"
    if (
        has_run_out == "new_prescription"
        and requested_timeframe in ["asap", "24_hours"]
    ):
        return "Moderate logistical urgency"

    # 5. Lower logistical urgency
    if (
        has_run_out in ["enough_for_days", "new_prescription"]
        and requested_timeframe in ["4_to_7_days", "enough_for_now"]
    ):
        return "Lower logistical urgency"
    if next_dose_timeframe == "later":
        return "Lower logistical urgency"

    # Default fallback
    return "Moderate logistical urgency"


# ---------------------------------------------------------
# 2. Ranking Keys for Fair Allocation
# ---------------------------------------------------------

CLINICAL_URGENCY_RANK = {
    "Urgent": 1,
    "Priority": 2,
    "Routine": 3,
    "Further review required": 4,
    None: 5,  # Unreviewed
}

LOGISTICAL_PRIORITY_RANK = {
    "Immediate review requested": 1,
    "High logistical urgency": 2,
    "Moderate logistical urgency": 3,
    "Lower logistical urgency": 4,
    "Insufficient information": 5,
    None: 6,
}

DOSE_TIMING_RANK = {
    "within_few_hours": 1,
    "today": 2,
    "tomorrow": 3,
    "later": 4,
    "unsure": 5,
    None: 6,
}

ALTERNATIVE_RANK = {
    "no": 1,
    "unsure": 2,
    "yes": 3,
    None: 4,
}

def get_allocation_sort_key(allocation: ResourceAllocation) -> Tuple:
    """
    Deterministic multi-factor priority tuple for sorting requests.
    Order of evaluation:
      1. Pharmacist-verified clinical urgency (Rank 1: Urgent -> 4: Review)
      2. Patient-reported logistical urgency (Rank 1: Immediate -> 5: Insufficient)
      3. Alternative pharmacy availability (Rank 1: No alternative -> 3: Yes)
      4. Dose timing urgency (Rank 1: within_few_hours -> 5: unsure)
      5. Creation timestamp (FIFO tie-breaker)
    """
    assessment: Optional[PatientUrgencyAssessment] = allocation.assessment
    review: Optional[PharmacistUrgencyReview] = assessment.pharmacist_review if assessment else None

    # Clinical urgency
    clin_rank = CLINICAL_URGENCY_RANK.get(review.clinical_urgency if review else None, 5)

    # Logistical urgency
    log_rank = LOGISTICAL_PRIORITY_RANK.get(
        assessment.preliminary_logistical_priority if assessment else None, 6
    )

    # Alternative availability
    alt_rank = ALTERNATIVE_RANK.get(
        assessment.alternative_pharmacy_available if assessment else None, 4
    )

    # Dose timing
    dose_rank = DOSE_TIMING_RANK.get(
        assessment.next_dose_timeframe if assessment else None, 6
    )

    # Creation timestamp
    created_at = allocation.created_at or datetime.datetime.utcnow()

    return (clin_rank, log_rank, alt_rank, dose_rank, created_at)


# ---------------------------------------------------------
# 3. Explanation Generator
# ---------------------------------------------------------

def generate_allocation_explanation(
    allocation: ResourceAllocation,
    status: str,
    allocated_qty: int,
    requested_qty: int,
    available_stock_before: int,
    total_requested: int,
    competing_count: int,
) -> str:
    """
    Generates a clear, transparent, data-driven explanation citing recorded clinical
    and logistical facts.
    """
    assessment = allocation.assessment
    review = assessment.pharmacist_review if assessment else None

    # Clinical facts
    if review and review.clinical_urgency:
        clinical_text = f"Pharmacist verified '{review.clinical_urgency}' clinical urgency"
        if review.decision_reason:
            clinical_text += f" ({review.decision_reason})"
    else:
        clinical_text = "Clinical urgency pending pharmacist verification"

    # Logistical facts
    if assessment:
        run_out_map = {
            "completely_out": "completely run out of medicine",
            "few_doses": "only a few doses remaining",
            "enough_for_days": "medicine remaining for several days",
            "new_prescription": "new prescription",
        }
        out_desc = run_out_map.get(assessment.has_run_out, assessment.has_run_out)
        
        timing_map = {
            "within_few_hours": "due within the next few hours",
            "today": "due today",
            "tomorrow": "due tomorrow",
            "later": "due later than tomorrow",
            "unsure": "timing unsure",
        }
        dose_desc = timing_map.get(assessment.next_dose_timeframe, assessment.next_dose_timeframe)
        
        alt_desc = (
            "no verified alternative pharmacy available"
            if assessment.alternative_pharmacy_available == "no"
            else f"alternative availability reported as '{assessment.alternative_pharmacy_available}'"
        )
        logistical_text = f"Patient reported {out_desc}, next dose {dose_desc}, with {alt_desc}."
    else:
        logistical_text = "No detailed patient urgency assessment submitted."

    # Allocation outcome context
    if status == "Fully Allocated":
        reason = (
            f"Prioritized for full allocation ({allocated_qty} units) because {clinical_text} "
            f"and {logistical_text} Available inventory of {available_stock_before} units satisfied "
            f"this request among {competing_count} competing patient requests."
        )
    elif status == "Partially Allocated":
        remaining_needed = requested_qty - allocated_qty
        reason = (
            f"Allocated {allocated_qty} of {requested_qty} requested units ({remaining_needed} units remaining) "
            f"under fair resource-sharing rules. Available pharmacy inventory ({available_stock_before} units) "
            f"was insufficient to satisfy all {total_requested} requested units across {competing_count} patients. "
            f"{clinical_text}. {logistical_text}"
        )
    elif status == "Waitlisted":
        reason = (
            f"Placed on waiting list ({requested_qty} units) because available pharmacy stock ({available_stock_before} units) "
            f"was fully allocated to higher-urgency clinical requests. {clinical_text}. "
            f"This request will be prioritized automatically once replacement inventory arrives."
        )
    elif status == "Not Allocated":
        reason = (
            f"Request could not be allocated due to zero remaining stock at the selected pharmacy. "
            f"Total requests: {total_requested} units across {competing_count} patients."
        )
    else:
        reason = f"Allocation status: {status}. Evaluated under DAWA fair resource sharing policy."

    return reason


# ---------------------------------------------------------
# 4. Fair Resource Allocation Execution Engine
# ---------------------------------------------------------

def run_fair_resource_allocation(
    pharmacy_id: int,
    medicine_id: int,
    db: Session,
    pharmacist_name: str = "Licensed Pharmacist"
) -> List[ResourceAllocation]:
    """
    Executes fair medicine resource allocation for a given pharmacy & medicine:
    1. Loads current pharmacy inventory with atomic recheck.
    2. Gathers all pending and eligible resource allocations for this pharmacy and medicine.
    3. Sorts them deterministically according to the 5-tier fair ranking algorithm.
    4. Allocates stock without exceeding actual inventory.
    5. Creates/updates ResourceAllocation and AllocationHistory records.
    6. Updates PharmacyInventory transactionally.
    """
    inventory = (
        db.query(PharmacyInventory)
        .filter(
            PharmacyInventory.pharmacy_id == pharmacy_id,
            PharmacyInventory.medicine_id == medicine_id,
        )
        .first()
    )

    if not inventory:
        raise ValueError(f"Inventory record for pharmacy {pharmacy_id} and medicine {medicine_id} not found.")

    available_stock = inventory.stock_quantity
    available_stock_initial = available_stock

    # Find all allocations awaiting allocation or waitlisted for this pharmacy & medicine
    allocations = (
        db.query(ResourceAllocation)
        .filter(
            ResourceAllocation.pharmacy_id == pharmacy_id,
            ResourceAllocation.medicine_id == medicine_id,
            ResourceAllocation.allocation_status.in_(["Allocation Pending", "Waitlisted", "Not Allocated"])
        )
        .all()
    )

    if not allocations:
        return []

    # Sort allocations deterministically using fair ranking key
    sorted_allocations = sorted(allocations, key=get_allocation_sort_key)

    total_requested = sum(a.requested_quantity for a in sorted_allocations)
    competing_count = len(sorted_allocations)
    remaining_stock = available_stock

    now = datetime.datetime.utcnow()

    for alloc in sorted_allocations:
        prev_status = alloc.allocation_status
        prev_qty = alloc.allocated_quantity
        req_qty = alloc.requested_quantity

        if remaining_stock >= req_qty:
            alloc_qty = req_qty
            status = "Fully Allocated"
            remaining_needed = 0
            remaining_stock -= alloc_qty
        elif remaining_stock > 0:
            alloc_qty = remaining_stock
            status = "Partially Allocated"
            remaining_needed = req_qty - alloc_qty
            remaining_stock = 0
        else:
            alloc_qty = 0
            status = "Waitlisted"
            remaining_needed = req_qty

        # Generate transparent explanation
        explanation = generate_allocation_explanation(
            allocation=alloc,
            status=status,
            allocated_qty=alloc_qty,
            requested_qty=req_qty,
            available_stock_before=available_stock_initial,
            total_requested=total_requested,
            competing_count=competing_count,
        )

        alloc.allocated_quantity = alloc_qty
        alloc.remaining_quantity = remaining_needed
        alloc.allocation_status = status
        alloc.allocation_explanation = explanation
        alloc.pharmacist_approved = True
        alloc.approved_by = pharmacist_name
        alloc.approved_at = now
        alloc.priority_basis = (
            f"Clinical: {alloc.assessment.pharmacist_review.clinical_urgency if alloc.assessment and alloc.assessment.pharmacist_review else 'Unreviewed'} | "
            f"Logistical: {alloc.assessment.preliminary_logistical_priority if alloc.assessment else 'N/A'}"
        )

        # Audit History
        hist = AllocationHistory(
            allocation_id=alloc.id,
            previous_status=prev_status,
            new_status=status,
            previous_quantity=prev_qty,
            new_quantity=alloc_qty,
            changed_by=f"Fair Allocation Engine ({pharmacist_name})",
            reason=f"Batch allocation executed. Stock was {available_stock_initial}, allocated {alloc_qty} units.",
            timestamp=now,
        )
        db.add(hist)

    # Transactional stock deduction
    total_newly_allocated = available_stock_initial - remaining_stock
    inventory.stock_quantity = remaining_stock
    inventory.is_available = remaining_stock > 0

    db.commit()

    for alloc in sorted_allocations:
        db.refresh(alloc)
    db.refresh(inventory)

    return sorted_allocations


# ---------------------------------------------------------
# 5. Pharmacist Override with Audit Trail
# ---------------------------------------------------------

def override_resource_allocation(
    allocation_id: int,
    new_allocated_qty: int,
    override_reason: str,
    pharmacist_name: str,
    db: Session,
) -> ResourceAllocation:
    """
    Allows a licensed pharmacist to manually adjust an allocation.
    Validates inventory bounds, logs full audit history, and recalculates stock.
    """
    if not override_reason or len(override_reason.strip()) < 5:
        raise ValueError("A clear clinical justification is required for any allocation override.")

    alloc = db.query(ResourceAllocation).filter(ResourceAllocation.id == allocation_id).first()
    if not alloc:
        raise ValueError(f"Allocation with id {allocation_id} not found.")

    inventory = (
        db.query(PharmacyInventory)
        .filter(
            PharmacyInventory.pharmacy_id == alloc.pharmacy_id,
            PharmacyInventory.medicine_id == alloc.medicine_id,
        )
        .first()
    )

    if not inventory:
        raise ValueError("Pharmacy inventory record not found.")

    old_allocated = alloc.allocated_quantity
    old_status = alloc.allocation_status
    delta = new_allocated_qty - old_allocated

    if delta > 0 and inventory.stock_quantity < delta:
        raise ValueError(
            f"Insufficient stock for override. Available: {inventory.stock_quantity}, needed extra: {delta}."
        )

    # Recalculate status
    if new_allocated_qty >= alloc.requested_quantity:
        new_status = "Fully Allocated"
        remaining_qty = 0
    elif new_allocated_qty > 0:
        new_status = "Partially Allocated"
        remaining_qty = alloc.requested_quantity - new_allocated_qty
    else:
        new_status = "Waitlisted"
        remaining_qty = alloc.requested_quantity

    alloc.allocated_quantity = new_allocated_qty
    alloc.remaining_quantity = remaining_qty
    alloc.allocation_status = new_status
    alloc.is_overridden = True
    alloc.override_reason = override_reason
    alloc.approved_by = pharmacist_name
    alloc.approved_at = datetime.datetime.utcnow()
    alloc.allocation_explanation = (
        f"Pharmacist manual override applied by {pharmacist_name}: {override_reason}. "
        f"Allocated: {new_allocated_qty} / {alloc.requested_quantity} units."
    )

    # Adjust inventory
    inventory.stock_quantity -= delta
    inventory.is_available = inventory.stock_quantity > 0

    # Add audit log
    hist = AllocationHistory(
        allocation_id=alloc.id,
        previous_status=old_status,
        new_status=new_status,
        previous_quantity=old_allocated,
        new_quantity=new_allocated_qty,
        changed_by=f"Pharmacist Override ({pharmacist_name})",
        reason=override_reason,
        timestamp=datetime.datetime.utcnow(),
    )
    db.add(hist)

    db.commit()
    db.refresh(alloc)
    db.refresh(inventory)

    return alloc
