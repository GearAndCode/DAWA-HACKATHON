import datetime
from sqlalchemy import Column, Integer, String, Float, ForeignKey, DateTime, Text
from sqlalchemy.orm import relationship
from app.database import Base

class Order(Base):
    __tablename__ = "orders"

    id = Column(Integer, primary_key=True, index=True)
    order_number = Column(String(50), unique=True, index=True, nullable=False)
    patient_id = Column(Integer, ForeignKey("patients.id", ondelete="SET NULL"), nullable=True)
    pharmacy_id = Column(Integer, ForeignKey("pharmacies.id", ondelete="CASCADE"), nullable=False)
    invoice_id = Column(Integer, ForeignKey("invoices.id", ondelete="SET NULL"), nullable=True)
    prescription_id = Column(Integer, ForeignKey("prescriptions.id", ondelete="SET NULL"), nullable=True)
    
    fulfillment_type = Column(String(50), default="pickup")  # "pickup" or "delivery"
    delivery_address = Column(String(255), nullable=True)
    delivery_latitude = Column(Float, nullable=True)
    delivery_longitude = Column(Float, nullable=True)
    delivery_fee = Column(Float, default=0.0)
    total_amount = Column(Float, nullable=False)
    
    status = Column(String(60), default="Order Placed")
    # Allowed:
    # "Order Placed"
    # "Awaiting Pharmacist Verification"
    # "Verified by Pharmacist"
    # "Preparing Order"
    # "Ready for Pickup" / "Out for Delivery"
    # "Delivered" / "Collected"
    # "Rejected by Pharmacist"

    payment_method = Column(String(50), default="Pay at Pickup / Cash on Delivery (Demo)")
    rejection_reason = Column(Text, nullable=True)
    pharmacist_notes = Column(Text, nullable=True)
    created_at = Column(DateTime, default=datetime.datetime.utcnow)
    updated_at = Column(DateTime, default=datetime.datetime.utcnow, onupdate=datetime.datetime.utcnow)

    patient = relationship("Patient", back_populates="orders")
    pharmacy = relationship("Pharmacy", back_populates="orders")
    invoice = relationship("Invoice", back_populates="order")
    prescription = relationship("Prescription", back_populates="orders")
    history = relationship("OrderStatusHistory", back_populates="order", cascade="all, delete-orphan", order_by="OrderStatusHistory.timestamp.asc()")


class OrderStatusHistory(Base):
    __tablename__ = "order_status_history"

    id = Column(Integer, primary_key=True, index=True)
    order_id = Column(Integer, ForeignKey("orders.id", ondelete="CASCADE"), nullable=False)
    status = Column(String(60), nullable=False)
    notes = Column(Text, nullable=True)
    changed_by = Column(String(100), default="System")  # Patient, Pharmacist, System
    timestamp = Column(DateTime, default=datetime.datetime.utcnow)

    order = relationship("Order", back_populates="history")
