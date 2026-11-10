import datetime
from sqlalchemy import Column, Integer, String, Boolean, ForeignKey, DateTime, Text
from sqlalchemy.orm import relationship
from app.database import Base

class PatientUrgencyAssessment(Base):
    __tablename__ = "patient_urgency_assessments"

    id = Column(Integer, primary_key=True, index=True)
    patient_id = Column(Integer, ForeignKey("patients.id", ondelete="SET NULL"), nullable=True)
    prescription_id = Column(Integer, ForeignKey("prescriptions.id", ondelete="CASCADE"), nullable=False)
    prescription_item_id = Column(Integer, ForeignKey("prescription_items.id", ondelete="SET NULL"), nullable=True)
    medicine_name = Column(String(150), nullable=True)

    # Question 1: Have you already run out of this medicine?
    # completely_out, few_doses, enough_for_days, new_prescription
    has_run_out = Column(String(50), nullable=False)
    remaining_medicine_status = Column(String(100), nullable=True)

    # Question 2: When do you need this medicine?
    # asap, 24_hours, 2_to_3_days, 4_to_7_days, enough_for_now
    requested_timeframe = Column(String(50), nullable=False)

    # Question 3: Is this medicine part of an ongoing prescribed treatment?
    # ongoing, new_prescription, unsure
    treatment_status = Column(String(50), nullable=False)

    # Question 4: When is your next prescribed dose due?
    # within_few_hours, today, tomorrow, later, unsure
    next_dose_timeframe = Column(String(50), nullable=False)

    # Question 5: Can you obtain this medicine from another pharmacy?
    # yes, no, unsure
    alternative_pharmacy_available = Column(String(20), nullable=False)
    alternative_availability_verified = Column(Boolean, default=False)

    # Question 6: Additional information
    additional_information = Column(Text, nullable=True)

    # Objective rule-based preliminary logistical priority:
    # "Immediate review requested", "High logistical urgency", "Moderate logistical urgency", "Lower logistical urgency", "Insufficient information"
    preliminary_logistical_priority = Column(String(50), default="Insufficient information")

    # Assessment status:
    # "Awaiting Pharmacist Review", "Assessment Verified", "Further Review Required", "Rejected"
    assessment_status = Column(String(50), default="Awaiting Pharmacist Review")

    created_at = Column(DateTime, default=datetime.datetime.utcnow)
    updated_at = Column(DateTime, default=datetime.datetime.utcnow, onupdate=datetime.datetime.utcnow)

    # Relationships
    patient = relationship("Patient")
    prescription = relationship("Prescription")
    prescription_item = relationship("PrescriptionItem")
    pharmacist_review = relationship("PharmacistUrgencyReview", back_populates="assessment", uselist=False, cascade="all, delete-orphan")
    allocations = relationship("ResourceAllocation", back_populates="assessment")


class PharmacistUrgencyReview(Base):
    __tablename__ = "pharmacist_urgency_reviews"

    id = Column(Integer, primary_key=True, index=True)
    urgency_assessment_id = Column(Integer, ForeignKey("patient_urgency_assessments.id", ondelete="CASCADE"), nullable=False, unique=True)
    pharmacist_id = Column(Integer, nullable=True)
    pharmacist_name = Column(String(100), default="Licensed Pharmacist")
    
    # Clinical urgency: "Urgent", "Priority", "Routine", "Further review required"
    clinical_urgency = Column(String(50), nullable=False)
    
    # Verification status: "VERIFIED", "REVIEW_REQUIRED", "REJECTED"
    verification_status = Column(String(50), default="VERIFIED")
    assessment_notes = Column(Text, nullable=True)
    decision_reason = Column(Text, nullable=True)
    reviewed_at = Column(DateTime, default=datetime.datetime.utcnow)
    created_at = Column(DateTime, default=datetime.datetime.utcnow)

    assessment = relationship("PatientUrgencyAssessment", back_populates="pharmacist_review")


class ResourceAllocation(Base):
    __tablename__ = "resource_allocations"

    id = Column(Integer, primary_key=True, index=True)
    urgency_assessment_id = Column(Integer, ForeignKey("patient_urgency_assessments.id", ondelete="SET NULL"), nullable=True)
    pharmacy_id = Column(Integer, ForeignKey("pharmacies.id", ondelete="CASCADE"), nullable=False)
    medicine_id = Column(Integer, ForeignKey("medicines.id", ondelete="CASCADE"), nullable=False)
    patient_id = Column(Integer, ForeignKey("patients.id", ondelete="SET NULL"), nullable=True)
    prescription_id = Column(Integer, ForeignKey("prescriptions.id", ondelete="SET NULL"), nullable=True)
    prescription_item_id = Column(Integer, ForeignKey("prescription_items.id", ondelete="SET NULL"), nullable=True)

    requested_quantity = Column(Integer, nullable=False)
    allocated_quantity = Column(Integer, nullable=False, default=0)
    remaining_quantity = Column(Integer, nullable=False, default=0)

    # "Allocation Pending", "Fully Allocated", "Partially Allocated", "Waitlisted", "Not Allocated", "Cancelled"
    allocation_status = Column(String(50), default="Allocation Pending")
    
    priority_basis = Column(Text, nullable=True)
    allocation_explanation = Column(Text, nullable=False)
    
    pharmacist_approved = Column(Boolean, default=False)
    approved_by = Column(String(100), nullable=True)
    approved_at = Column(DateTime, nullable=True)

    is_overridden = Column(Boolean, default=False)
    override_reason = Column(Text, nullable=True)

    created_at = Column(DateTime, default=datetime.datetime.utcnow)
    updated_at = Column(DateTime, default=datetime.datetime.utcnow, onupdate=datetime.datetime.utcnow)

    assessment = relationship("PatientUrgencyAssessment", back_populates="allocations")
    pharmacy = relationship("Pharmacy")
    medicine = relationship("Medicine")
    patient = relationship("Patient")
    prescription = relationship("Prescription")
    history = relationship("AllocationHistory", back_populates="allocation", cascade="all, delete-orphan", order_by="AllocationHistory.timestamp.asc()")


class AllocationHistory(Base):
    __tablename__ = "allocation_history"

    id = Column(Integer, primary_key=True, index=True)
    allocation_id = Column(Integer, ForeignKey("resource_allocations.id", ondelete="CASCADE"), nullable=False)
    previous_status = Column(String(50), nullable=True)
    new_status = Column(String(50), nullable=False)
    previous_quantity = Column(Integer, nullable=True)
    new_quantity = Column(Integer, nullable=False)
    changed_by = Column(String(100), default="System")
    reason = Column(Text, nullable=True)
    timestamp = Column(DateTime, default=datetime.datetime.utcnow)

    allocation = relationship("ResourceAllocation", back_populates="history")

