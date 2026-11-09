from sqlalchemy import Column, Integer, String, Float, Boolean, Text
from sqlalchemy.orm import relationship
from app.database import Base

class Medicine(Base):
    __tablename__ = "medicines"

    id = Column(Integer, primary_key=True, index=True)
    brand_name = Column(String(150), nullable=False, index=True)
    generic_name = Column(String(150), nullable=True, index=True)
    strength = Column(String(50), nullable=False)
    dosage_form = Column(String(50), nullable=False)  # Tablet, Syrup, Capsule, etc.
    category = Column(String(100), nullable=True)     # Pain & Fever, Antibiotic, etc.
    prescription_required = Column(Boolean, default=False)
    description = Column(Text, nullable=True)
    default_price = Column(Float, nullable=False)     # in PKR

    inventory_entries = relationship("PharmacyInventory", back_populates="medicine", cascade="all, delete-orphan")
