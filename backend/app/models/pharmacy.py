from sqlalchemy import Column, Integer, String, Float, Boolean, Text
from sqlalchemy.orm import relationship
from app.database import Base

class Pharmacy(Base):
    __tablename__ = "pharmacies"

    id = Column(Integer, primary_key=True, index=True)
    name = Column(String(150), nullable=False, index=True)
    area = Column(String(100), nullable=False)
    address = Column(String(255), nullable=False)
    city = Column(String(100), default="Lahore")
    latitude = Column(Float, nullable=False)
    longitude = Column(Float, nullable=False)
    phone = Column(String(50), nullable=True)
    opening_hours = Column(String(100), default="9:00 AM – 11:00 PM")
    description = Column(Text, nullable=True)
    is_demo = Column(Boolean, default=True)
    rating = Column(Float, default=4.8)

    inventory_items = relationship("PharmacyInventory", back_populates="pharmacy", cascade="all, delete-orphan")
    invoices = relationship("Invoice", back_populates="pharmacy")
    orders = relationship("Order", back_populates="pharmacy")
