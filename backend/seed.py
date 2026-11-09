import os
import sys

# Ensure backend root is on sys.path
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

from app.database import SessionLocal, init_db
from app.models.patient import Patient
from app.models.pharmacy import Pharmacy
from app.models.medicine import Medicine
from app.models.inventory import PharmacyInventory

def seed():
    init_db()
    db = SessionLocal()

    try:
        # Check if already seeded
        if db.query(Pharmacy).first():
            print("Database already contains data. Skipping seed.")
            return

        print("Seeding DAWA Database...")

        # 1. Demo Patient
        patient = Patient(
            id=1,
            name="Ali Zafar (Demo User)",
            phone="+92 300 1234567",
            email="ali.zafar@example.com",
            address="Gulberg III, Main Boulevard, Lahore",
            latitude=31.5204,
            longitude=74.3587,
        )
        db.add(patient)

        # 2. Four Fictional Demo Pharmacies in Lahore
        pharmacies = [
            Pharmacy(
                id=1,
                name="City Care Pharmacy",
                area="Gulberg III",
                address="Shop 14, Main Market, Gulberg III, Lahore (Demo)",
                city="Lahore",
                latitude=31.5165,
                longitude=74.3436,
                phone="+92 42 35750001",
                opening_hours="9:00 AM – 11:00 PM (demo)",
                description="A licensed fictional neighbourhood pharmacy demonstrating DAWA digital inventory matching.",
                rating=4.9,
                is_demo=True,
            ),
            Pharmacy(
                id=2,
                name="HealthPlus Pharmacy",
                area="Model Town",
                address="Commercial Plaza, Bank Square, Model Town, Lahore (Demo)",
                city="Lahore",
                latitude=31.4820,
                longitude=74.3160,
                phone="+92 42 35850002",
                opening_hours="8:00 AM – 10:00 PM (demo)",
                description="Community demo pharmacy carrying everyday over-the-counter and general medicines.",
                rating=4.7,
                is_demo=True,
            ),
            Pharmacy(
                id=3,
                name="MediPoint Pharmacy",
                area="DHA Phase 5",
                address="Sector C Commercial, DHA Phase 5, Lahore (Demo)",
                city="Lahore",
                latitude=31.4673,
                longitude=74.4024,
                phone="+92 42 37180003",
                opening_hours="24 Hours (demo)",
                description="24/7 demo pharmacy stocked with critical antibiotics and emergency health supplies.",
                rating=4.8,
                is_demo=True,
            ),
            Pharmacy(
                id=4,
                name="MedExpress Pharmacy",
                area="Johar Town",
                address="Block G-4, Near Shaukat Khanum, Johar Town, Lahore (Demo)",
                city="Lahore",
                latitude=31.4697,
                longitude=74.2728,
                phone="+92 42 35310004",
                opening_hours="8:30 AM – 11:30 PM (demo)",
                description="Fictional fast fulfillment pharmacy with express packaging and courier pickup.",
                rating=4.6,
                is_demo=True,
            ),
        ]
        db.add_all(pharmacies)
        db.flush()

        # 3. Medicine Catalog (Prices in PKR)
        medicines = [
            Medicine(
                id=1,
                brand_name="Panadol",
                generic_name="Paracetamol",
                strength="500 mg",
                dosage_form="Tablet",
                category="Pain & Fever",
                prescription_required=False,
                description="Fast relief of headache, body pain, and fever.",
                default_price=45.0,  # 1 strip (10 tablets)
            ),
            Medicine(
                id=2,
                brand_name="Brufen",
                generic_name="Ibuprofen",
                strength="400 mg",
                dosage_form="Tablet",
                category="Pain & Inflammation",
                prescription_required=False,
                description="Non-steroidal anti-inflammatory drug for pain, swelling and inflammation.",
                default_price=60.0,
            ),
            Medicine(
                id=3,
                brand_name="Augmentin",
                generic_name="Amoxicillin + Clavulanic Acid",
                strength="625 mg",
                dosage_form="Tablet",
                category="Antibiotic",
                prescription_required=True,
                description="Broad-spectrum antibiotic requiring valid doctor prescription.",
                default_price=320.0,
            ),
            Medicine(
                id=4,
                brand_name="Calpol",
                generic_name="Paracetamol",
                strength="120 mg/5 ml",
                dosage_form="Syrup",
                category="Pain & Fever",
                prescription_required=False,
                description="Paediatric fever and pain relieving suspension.",
                default_price=110.0,
            ),
            Medicine(
                id=5,
                brand_name="Disprin",
                generic_name="Aspirin",
                strength="300 mg",
                dosage_form="Soluble tablet",
                category="Pain Relief",
                prescription_required=False,
                description="Effervescent pain relief and cardioprotective aspirin.",
                default_price=35.0,
            ),
            Medicine(
                id=6,
                brand_name="Vitamin C",
                generic_name="Ascorbic Acid",
                strength="500 mg",
                dosage_form="Tablet",
                category="Supplement",
                prescription_required=False,
                description="Immune health booster and daily antioxidant support.",
                default_price=150.0,
            ),
            Medicine(
                id=7,
                brand_name="Flagyl",
                generic_name="Metronidazole",
                strength="400 mg",
                dosage_form="Tablet",
                category="Antimicrobial",
                prescription_required=True,
                description="Antibacterial and antiprotozoal medication.",
                default_price=80.0,
            ),
            Medicine(
                id=8,
                brand_name="Risek",
                generic_name="Omeprazole",
                strength="20 mg",
                dosage_form="Capsule",
                category="Antacid & Reflux",
                prescription_required=False,
                description="Proton pump inhibitor for acidity and gastroesophageal reflux.",
                default_price=240.0,
            ),
            Medicine(
                id=9,
                brand_name="Cravit",
                generic_name="Levofloxacin",
                strength="500 mg",
                dosage_form="Tablet",
                category="Antibiotic",
                prescription_required=True,
                description="Fluoroquinolone antibiotic for respiratory and urinary infections.",
                default_price=420.0,
            ),
            Medicine(
                id=10,
                brand_name="Surbex Z",
                generic_name="Zinc + B-Complex + Vitamin C & E",
                strength="Multivitamin",
                dosage_form="Tablet",
                category="Supplement",
                prescription_required=False,
                description="High-potency therapeutic multivitamin with zinc.",
                default_price=310.0,
            ),
        ]
        db.add_all(medicines)
        db.flush()

        # 4. Inventory Matrix
        # City Care (Pharmacy 1): FULL stock of all items
        # HealthPlus (Pharmacy 2): Lacks Augmentin, Cravit (to demo partial match)
        # MediPoint (Pharmacy 3): Full stock of Augmentin, Brufen, Cravit, Risek, Panadol
        # MedExpress (Pharmacy 4): Full stock of Panadol, Brufen, Calpol, Disprin, Vitamin C
        inventory_data = [
            # Pharmacy 1 - City Care (Gulberg) - Full stock
            (1, 1, 120, 45.0),
            (1, 2, 85, 60.0),
            (1, 3, 50, 320.0),
            (1, 4, 30, 110.0),
            (1, 5, 200, 35.0),
            (1, 6, 95, 150.0),
            (1, 7, 70, 80.0),
            (1, 8, 60, 240.0),

            # Pharmacy 2 - HealthPlus (Model Town) - Missing Augmentin & Flagyl!
            (2, 1, 100, 44.0),
            (2, 2, 60, 58.0),
            (2, 3, 0, 325.0),   # OUT OF STOCK
            (2, 4, 25, 110.0),
            (2, 5, 150, 34.0),
            (2, 6, 80, 145.0),
            (2, 10, 40, 305.0),

            # Pharmacy 3 - MediPoint (DHA Phase 5) - Full stock
            (3, 1, 150, 46.0),
            (3, 2, 90, 62.0),
            (3, 3, 75, 318.0),
            (3, 4, 40, 112.0),
            (3, 8, 85, 238.0),
            (3, 9, 45, 420.0),

            # Pharmacy 4 - MedExpress (Johar Town) - Partial stock
            (4, 1, 80, 45.0),
            (4, 2, 50, 60.0),
            (4, 4, 35, 108.0),
            (4, 5, 110, 35.0),
            (4, 6, 65, 148.0),
        ]

        for p_id, m_id, qty, price in inventory_data:
            db.add(
                PharmacyInventory(
                    pharmacy_id=p_id,
                    medicine_id=m_id,
                    stock_quantity=qty,
                    unit_price=price,
                    is_available=qty > 0,
                )
            )

        db.commit()
        print("DAWA database seeded successfully!")

    except Exception as e:
        db.rollback()
        print(f"Error seeding database: {e}")
        raise
    finally:
        db.close()

if __name__ == "__main__":
    seed()
