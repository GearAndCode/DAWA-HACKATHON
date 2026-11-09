from sqlalchemy import Column, Integer, Float, Boolean, ForeignKey, UniqueConstraint
from sqlalchemy.orm import relationship
from app.database import Base

class PharmacyInventory(Base):
    __tablename__ = "pharmacy_inventories"

    id = Column(Integer, primary_key=True, index=True)
    pharmacy_id = Column(Integer, ForeignKey("pharmacies.id", ondelete="CASCADE"), nullable=False)
    medicine_id = Column(Integer, ForeignKey("medicines.id", ondelete="CASCADE"), nullable=False)
    stock_quantity = Column(Integer, default=0)
    unit_price = Column(Float, nullable=False)  # in PKR
    is_available = Column(Boolean, default=True)

    __table_args__ = (
        UniqueConstraint("pharmacy_id", "medicine_id", name="uq_pharmacy_medicine"),
    )

    pharmacy = relationship("Pharmacy", back_populates="inventory_items")
    medicine = relationship("Medicine", back_populates="inventory_entries")
