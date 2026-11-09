import datetime
import random
from sqlalchemy.orm import Session
from app.models.invoice import Invoice, InvoiceItem
from app.models.pharmacy import Pharmacy
from app.models.inventory import PharmacyInventory
from app.models.medicine import Medicine
from app.schemas.prescription import PrescriptionItemCreate
from app.core.config import settings

def generate_invoice_number() -> str:
    rnd = random.randint(1000, 9999)
    now = datetime.datetime.utcnow()
    return f"INV-{now.year}-{now.strftime('%m%d')}-{rnd}"

def create_invoice_for_pharmacy(
    db: Session,
    pharmacy_id: int,
    items: list[PrescriptionItemCreate],
    prescription_id: int | None = None,
    patient_id: int | None = 1,
    include_delivery_fee: bool = False
) -> Invoice:
    pharmacy = db.query(Pharmacy).filter(Pharmacy.id == pharmacy_id).first()
    if not pharmacy:
        raise ValueError(f"Pharmacy with ID {pharmacy_id} not found")

    invoice_number = generate_invoice_number()
    subtotal = 0.0
    invoice_items = []

    for req in items:
        # Check pharmacy inventory price
        inv_entry = (
            db.query(PharmacyInventory)
            .join(Medicine, PharmacyInventory.medicine_id == Medicine.id)
            .filter(
                PharmacyInventory.pharmacy_id == pharmacy_id,
                Medicine.brand_name.ilike(f"%{req.medicine_name.strip()}%")
            )
            .first()
        )

        unit_price = inv_entry.unit_price if inv_entry else 15.0
        line_total = round(unit_price * req.quantity, 2)
        subtotal += line_total

        invoice_items.append(
            InvoiceItem(
                medicine_name=req.medicine_name,
                strength=req.strength or (inv_entry.medicine.strength if inv_entry else "Standard"),
                quantity=req.quantity,
                unit_price=round(unit_price, 2),
                line_total=line_total,
            )
        )

    delivery_fee = settings.DEFAULT_DELIVERY_FEE if include_delivery_fee else 0.0
    total_amount = round(subtotal + delivery_fee, 2)

    db_invoice = Invoice(
        invoice_number=invoice_number,
        patient_id=patient_id,
        pharmacy_id=pharmacy_id,
        prescription_id=prescription_id,
        subtotal=round(subtotal, 2),
        delivery_fee=round(delivery_fee, 2),
        total_amount=total_amount,
        currency="PKR",
        status="PENDING",
    )
    db.add(db_invoice)
    db.flush()

    for item in invoice_items:
        item.invoice_id = db_invoice.id
        db.add(item)

    db.commit()
    db.refresh(db_invoice)
    return db_invoice
