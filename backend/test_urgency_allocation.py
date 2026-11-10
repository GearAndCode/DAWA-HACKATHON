import pytest
import datetime
from fastapi.testclient import TestClient
from app.main import app
from app.database import get_db, init_db, SessionLocal
from app.models.patient import Patient
from app.models.pharmacy import Pharmacy
from app.models.medicine import Medicine
from app.models.inventory import PharmacyInventory
from app.models.prescription import Prescription, PrescriptionItem
from app.models.urgency_assessment import (
    PatientUrgencyAssessment,
    PharmacistUrgencyReview,
    ResourceAllocation,
    AllocationHistory,
)
from app.services.urgency_service import (
    calculate_preliminary_logistical_priority,
    run_fair_resource_allocation,
    override_resource_allocation,
)

client = TestClient(app)

def test_preliminary_logistical_priority_rules():
    # 1. Immediate review requested: completely out & dose due today
    p1 = calculate_preliminary_logistical_priority(
        has_run_out="completely_out",
        requested_timeframe="asap",
        treatment_status="ongoing",
        next_dose_timeframe="today",
        alternative_pharmacy_available="no",
    )
    assert p1 == "Immediate review requested"

    # 2. High logistical urgency: few doses & within 24 hours
    p2 = calculate_preliminary_logistical_priority(
        has_run_out="few_doses",
        requested_timeframe="24_hours",
        treatment_status="ongoing",
        next_dose_timeframe="tomorrow",
        alternative_pharmacy_available="no",
    )
    assert p2 == "High logistical urgency"

    # 3. Moderate logistical urgency: few doses & 2-3 days
    p3 = calculate_preliminary_logistical_priority(
        has_run_out="few_doses",
        requested_timeframe="2_to_3_days",
        treatment_status="ongoing",
        next_dose_timeframe="tomorrow",
        alternative_pharmacy_available="unsure",
    )
    assert p3 == "Moderate logistical urgency"

    # 4. Lower logistical urgency: enough for days & 4-7 days
    p4 = calculate_preliminary_logistical_priority(
        has_run_out="enough_for_days",
        requested_timeframe="4_to_7_days",
        treatment_status="new_prescription",
        next_dose_timeframe="later",
        alternative_pharmacy_available="yes",
    )
    assert p4 == "Lower logistical urgency"

    # 5. Insufficient info
    p5 = calculate_preliminary_logistical_priority(
        has_run_out="new_prescription",
        requested_timeframe="enough_for_now",
        treatment_status="unsure",
        next_dose_timeframe="unsure",
        alternative_pharmacy_available="unsure",
    )
    assert p5 == "Insufficient information"


def test_e2e_urgency_assessment_and_fair_allocation():
    db = SessionLocal()
    try:
        # 1. Setup Test Pharmacy, Medicine, and Inventory
        pharmacy = db.query(Pharmacy).first()
        if not pharmacy:
            pharmacy = Pharmacy(name="Fair Care Pharmacy", latitude=31.52, longitude=74.35, address="Mall Rd, Lahore", phone="03001234567")
            db.add(pharmacy)
            db.commit()
            db.refresh(pharmacy)

        # Medicine with limited stock of exactly 10 units
        test_med = db.query(Medicine).filter(Medicine.brand_name == "Amoxicillin Test").first()
        if not test_med:
            test_med = Medicine(brand_name="Amoxicillin Test", generic_name="Amoxicillin", strength="500 mg", dosage_form="Capsule", default_price=120.0, category="Antibiotics")
            db.add(test_med)
            db.commit()
            db.refresh(test_med)

        inventory = db.query(PharmacyInventory).filter(
            PharmacyInventory.pharmacy_id == pharmacy.id,
            PharmacyInventory.medicine_id == test_med.id
        ).first()

        if not inventory:
            inventory = PharmacyInventory(
                pharmacy_id=pharmacy.id,
                medicine_id=test_med.id,
                stock_quantity=10,
                unit_price=120.0,
                is_available=True,
            )
            db.add(inventory)
        else:
            inventory.stock_quantity = 10
            inventory.is_available = True

        # Clean any previous allocations for this test
        old_allocs = db.query(ResourceAllocation).filter(
            ResourceAllocation.pharmacy_id == pharmacy.id,
            ResourceAllocation.medicine_id == test_med.id,
        ).all()
        for oa in old_allocs:
            db.delete(oa)

        db.commit()
        db.refresh(inventory)

        # 2. Setup 3 Test Patients & Prescriptions
        patients = []
        for name in ["Patient A (Urgent)", "Patient B (Priority)", "Patient C (Routine)"]:
            p = db.query(Patient).filter(Patient.name == name).first()
            if not p:
                p = Patient(name=name, phone="03001112223")
                db.add(p)
                db.commit()
                db.refresh(p)
            patients.append(p)

        # 3. Patient A: Requests 5 units (Completely out, dose due today -> Urgent)
        rx_a = Prescription(patient_id=patients[0].id, image_path="test_rx_a.jpg", status="CONFIRMED")
        db.add(rx_a)
        db.commit()
        db.refresh(rx_a)

        item_a = PrescriptionItem(
            prescription_id=rx_a.id,
            medicine_name="Amoxicillin Test",
            strength="500 mg",
            dosage_form="Capsule",
            quantity=5,
            matched_medicine_id=test_med.id,
        )
        db.add(item_a)
        db.commit()
        db.refresh(item_a)

        resp_a = client.post("/api/urgency-assessments", json={
            "patient_id": patients[0].id,
            "prescription_id": rx_a.id,
            "prescription_item_id": item_a.id,
            "medicine_name": "Amoxicillin Test",
            "has_run_out": "completely_out",
            "requested_timeframe": "asap",
            "treatment_status": "ongoing",
            "next_dose_timeframe": "today",
            "alternative_pharmacy_available": "no",
            "additional_information": "Post-surgery critical antibiotic cycle.",
        })
        assert resp_a.status_code == 200, resp_a.text
        assess_a_id = resp_a.json()["id"]
        assert resp_a.json()["preliminary_logistical_priority"] == "Immediate review requested"

        # 4. Patient B: Requests 4 units (Few doses, within 24 hours -> Priority)
        rx_b = Prescription(patient_id=patients[1].id, image_path="test_rx_b.jpg", status="CONFIRMED")
        db.add(rx_b)
        db.commit()
        db.refresh(rx_b)

        item_b = PrescriptionItem(
            prescription_id=rx_b.id,
            medicine_name="Amoxicillin Test",
            strength="500 mg",
            dosage_form="Capsule",
            quantity=4,
            matched_medicine_id=test_med.id,
        )
        db.add(item_b)
        db.commit()
        db.refresh(item_b)

        resp_b = client.post("/api/urgency-assessments", json={
            "patient_id": patients[1].id,
            "prescription_id": rx_b.id,
            "prescription_item_id": item_b.id,
            "medicine_name": "Amoxicillin Test",
            "has_run_out": "few_doses",
            "requested_timeframe": "24_hours",
            "treatment_status": "ongoing",
            "next_dose_timeframe": "tomorrow",
            "alternative_pharmacy_available": "no",
            "additional_information": "Day 3 of prescribed 7-day course.",
        })
        assert resp_b.status_code == 200
        assess_b_id = resp_b.json()["id"]

        # 5. Patient C: Requests 3 units (Enough for days -> Routine)
        rx_c = Prescription(patient_id=patients[2].id, image_path="test_rx_c.jpg", status="CONFIRMED")
        db.add(rx_c)
        db.commit()
        db.refresh(rx_c)

        item_c = PrescriptionItem(
            prescription_id=rx_c.id,
            medicine_name="Amoxicillin Test",
            strength="500 mg",
            dosage_form="Capsule",
            quantity=3,
            matched_medicine_id=test_med.id,
        )
        db.add(item_c)
        db.commit()
        db.refresh(item_c)

        resp_c = client.post("/api/urgency-assessments", json={
            "patient_id": patients[2].id,
            "prescription_id": rx_c.id,
            "prescription_item_id": item_c.id,
            "medicine_name": "Amoxicillin Test",
            "has_run_out": "enough_for_days",
            "requested_timeframe": "4_to_7_days",
            "treatment_status": "new_prescription",
            "next_dose_timeframe": "later",
            "alternative_pharmacy_available": "yes",
            "additional_information": "Refill backup supply.",
        })
        assert resp_c.status_code == 200
        assess_c_id = resp_c.json()["id"]

        # 6. Pharmacist Reviews and Verifies Clinical Urgency
        # Verify Patient A as "Urgent"
        rev_a = client.post(f"/api/admin/urgency-assessments/{assess_a_id}/review", json={
            "clinical_urgency": "Urgent",
            "verification_status": "VERIFIED",
            "decision_reason": "Post-operative antibiotic cycle. Interruption risks bacterial resistance.",
            "assessment_notes": "Immediate dose required.",
            "pharmacist_id": 101,
            "pharmacist_name": "Dr. Sarah Khan, PharmD",
        })
        assert rev_a.status_code == 200
        assert rev_a.json()["assessment_status"] == "Assessment Verified"

        # Verify Patient B as "Priority"
        rev_b = client.post(f"/api/admin/urgency-assessments/{assess_b_id}/review", json={
            "clinical_urgency": "Priority",
            "verification_status": "VERIFIED",
            "decision_reason": "Active infection course. Must maintain therapeutic serum concentration.",
            "assessment_notes": "Next dose tomorrow morning.",
            "pharmacist_id": 101,
            "pharmacist_name": "Dr. Sarah Khan, PharmD",
        })
        assert rev_b.status_code == 200

        # Verify Patient C as "Routine"
        rev_c = client.post(f"/api/admin/urgency-assessments/{assess_c_id}/review", json={
            "clinical_urgency": "Routine",
            "verification_status": "VERIFIED",
            "decision_reason": "Maintenance / advance supply. Has active doses remaining.",
            "assessment_notes": "Can wait for stock replenishment or alternative branch.",
            "pharmacist_id": 101,
            "pharmacist_name": "Dr. Sarah Khan, PharmD",
        })
        assert rev_c.status_code == 200

        # 7. Register Allocation Requests for all 3 patients at this Pharmacy
        alloc_a_res = client.post("/api/resource-allocation/request", json={
            "pharmacy_id": pharmacy.id,
            "medicine_id": test_med.id,
            "patient_id": patients[0].id,
            "prescription_id": rx_a.id,
            "prescription_item_id": item_a.id,
            "urgency_assessment_id": assess_a_id,
            "requested_quantity": 5,
        })
        assert alloc_a_res.status_code == 200
        alloc_a_id = alloc_a_res.json()["id"]

        alloc_b_res = client.post("/api/resource-allocation/request", json={
            "pharmacy_id": pharmacy.id,
            "medicine_id": test_med.id,
            "patient_id": patients[1].id,
            "prescription_id": rx_b.id,
            "prescription_item_id": item_b.id,
            "urgency_assessment_id": assess_b_id,
            "requested_quantity": 4,
        })
        assert alloc_b_res.status_code == 200
        alloc_b_id = alloc_b_res.json()["id"]

        alloc_c_res = client.post("/api/resource-allocation/request", json={
            "pharmacy_id": pharmacy.id,
            "medicine_id": test_med.id,
            "patient_id": patients[2].id,
            "prescription_id": rx_c.id,
            "prescription_item_id": item_c.id,
            "urgency_assessment_id": assess_c_id,
            "requested_quantity": 3,
        })
        assert alloc_c_res.status_code == 200
        alloc_c_id = alloc_c_res.json()["id"]

        # 8. Check Shortages Endpoint:
        # Total requested: 5 + 4 + 3 = 12 units. Available stock: 10 units. Shortage: 2 units!
        shortage_res = client.get("/api/admin/resource-allocation/shortages")
        assert shortage_res.status_code == 200
        shortages = shortage_res.json()
        target_shortage = next((s for s in shortages if s["medicine_id"] == test_med.id and s["pharmacy_id"] == pharmacy.id), None)
        assert target_shortage is not None
        assert target_shortage["total_requested_quantity"] == 12
        assert target_shortage["stock_quantity"] == 10
        assert target_shortage["shortage_quantity"] == 2
        assert target_shortage["affected_patients_count"] == 3

        # 9. RUN FAIR RESOURCE ALLOCATION ENGINE
        run_res = client.post("/api/admin/resource-allocation/run", json={
            "pharmacy_id": pharmacy.id,
            "medicine_id": test_med.id,
        }, params={"pharmacist_name": "Dr. Sarah Khan, PharmD"})
        assert run_res.status_code == 200
        allocations = run_res.json()
        assert len(allocations) == 3

        # Verification of results according to fair rules:
        # Stock: 10 units. Total requested: 12 units.
        # Patient A (Urgent): Requested 5 units -> Fully Allocated (5 units). Remaining stock: 5 units.
        # Patient B (Priority): Requested 4 units -> Fully Allocated (4 units). Remaining stock: 1 unit.
        # Patient C (Routine): Requested 3 units -> Partially Allocated (1 unit), remaining 2 units.
        alloc_a = next(a for a in allocations if a["id"] == alloc_a_id)
        alloc_b = next(a for a in allocations if a["id"] == alloc_b_id)
        alloc_c = next(a for a in allocations if a["id"] == alloc_c_id)

        assert alloc_a["allocation_status"] == "Fully Allocated"
        assert alloc_a["allocated_quantity"] == 5
        assert alloc_a["remaining_quantity"] == 0
        assert "Urgent" in alloc_a["allocation_explanation"]

        assert alloc_b["allocation_status"] == "Fully Allocated"
        assert alloc_b["allocated_quantity"] == 4
        assert alloc_b["remaining_quantity"] == 0

        assert alloc_c["allocation_status"] == "Partially Allocated"
        assert alloc_c["allocated_quantity"] == 1
        assert alloc_c["remaining_quantity"] == 2
        assert "Partially Allocated" in alloc_c["allocation_status"]

        # Verify total allocated does not exceed available stock (5 + 4 + 1 = 10 units <= 10)
        total_allocated = sum(a["allocated_quantity"] for a in allocations)
        assert total_allocated == 10

        # Verify Pharmacy Inventory was updated transactionally to 0
        inv_check = db.query(PharmacyInventory).filter(
            PharmacyInventory.pharmacy_id == pharmacy.id,
            PharmacyInventory.medicine_id == test_med.id
        ).first()
        assert inv_check.stock_quantity == 0
        assert inv_check.is_available is False

        # 10. Test Pharmacist Override:
        # Suppose fresh stock of 2 units arrives, pharmacist overrides Patient C to give 2 units with mandatory reason:
        # First add 2 units to stock:
        inv_check.stock_quantity = 2
        inv_check.is_available = True
        db.commit()

        override_res = client.post(f"/api/admin/resource-allocation/{alloc_c_id}/override", json={
            "override_allocated_quantity": 3,  # Full requested 3 units
            "override_reason": "Emergency replenishment shipment arrived from regional depot; patient C granted full allocation.",
            "pharmacist_name": "Dr. Sarah Khan, PharmD",
        })
        assert override_res.status_code == 200
        overridden = override_res.json()
        assert overridden["allocated_quantity"] == 3
        assert overridden["remaining_quantity"] == 0
        assert overridden["allocation_status"] == "Fully Allocated"
        assert overridden["is_overridden"] is True

        # Verify Audit History recorded
        hist_res = client.get(f"/api/admin/resource-allocation/history?allocation_id={alloc_c_id}")
        assert hist_res.status_code == 200
        history = hist_res.json()
        assert len(history) >= 2  # Initial allocation + override
        assert any("Emergency replenishment shipment" in h.get("reason", "") for h in history)

        print("\n[SUCCESS] Urgency Assessment & Fair Resource Allocation End-to-End Test Passed!")
    finally:
        db.close()

if __name__ == "__main__":
    test_preliminary_logistical_priority_rules()
    test_e2e_urgency_assessment_and_fair_allocation()
