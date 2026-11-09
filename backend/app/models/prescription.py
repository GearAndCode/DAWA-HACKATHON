import datetime
from sqlalchemy import Column, Integer, String, Float, ForeignKey, DateTime, Text
from sqlalchemy.orm import relationship
from app.database import Base

class Prescription(Base):
    __tablename__ = "prescriptions"

    id = Column(Integer, primary_key=True, index=True)
    patient_id = Column(Integer, ForeignKey("patients.id", ondelete="SET NULL"), nullable=True)
    image_path = Column(String(255), nullable=False)
    ocr_raw_text = Column(Text, nullable=True)
    ocr_confidence = Column(Float, default=0.0)
    status = Column(String(50), default="PROCESSED")  # UPLOADED, PROCESSED, CONFIRMED, REJECTED
    notes = Column(Text, nullable=True)
    created_at = Column(DateTime, default=datetime.datetime.utcnow)
    updated_at = Column(DateTime, default=datetime.datetime.utcnow, onupdate=datetime.datetime.utcnow)

    patient = relationship("Patient", back_populates="prescriptions")
    items = relationship("PrescriptionItem", back_populates="prescription", cascade="all, delete-orphan")
    invoices = relationship("Invoice", back_populates="prescription")
    orders = relationship("Order", back_populates="prescription")


class PrescriptionItem(Base):
    __tablename__ = "prescription_items"

    id = Column(Integer, primary_key=True, index=True)
    prescription_id = Column(Integer, ForeignKey("prescriptions.id", ondelete="CASCADE"), nullable=False)
    medicine_name = Column(String(150), nullable=False)
    strength = Column(String(50), nullable=True)
    dosage_form = Column(String(50), nullable=True)
    quantity = Column(Integer, default=1)
    frequency = Column(String(100), nullable=True)    # e.g., "1 tablet twice daily"
    duration = Column(String(100), nullable=True)     # e.g., "5 days"
    instructions = Column(String(255), nullable=True) # e.g., "Take after meals"
    confidence = Column(Float, default=0.85)
    matched_medicine_id = Column(Integer, ForeignKey("medicines.id", ondelete="SET NULL"), nullable=True)

    prescription = relationship("Prescription", back_populates="items")
    matched_medicine = relationship("Medicine")
