import os
import requests
from PIL import Image, ImageDraw

BASE_URL = "http://127.0.0.1:8000/api"

def test_full_pipeline():
    print("=== Testing DAWA Full E2E Pipeline ===")

    # 1. Nearby pharmacies (Gulberg, Lahore: 31.5204, 74.3587)
    res = requests.get(f"{BASE_URL}/location/nearby-pharmacies", params={"lat": 31.5204, "lon": 74.3587})
    assert res.status_code == 200, res.text
    pharmacies = res.json()
    print(f"[OK] Fetched {len(pharmacies)} nearby pharmacies. Closest: {pharmacies[0]['name']} ({pharmacies[0]['distance_km']} km)")

    # 2. Medicine search
    res = requests.get(f"{BASE_URL}/medicines", params={"q": "Panadol"})
    assert res.status_code == 200, res.text
    meds = res.json()
    assert len(meds) > 0
    print(f"[OK] Medicine search returned {meds[0]['brand_name']} ({meds[0]['strength']}) - PKR {meds[0]['default_price']}")

    # 3. Create dummy prescription image and test OCR upload
    test_img_path = "test_prescription.jpg"
    img = Image.new("RGB", (600, 400), color=(255, 255, 255))
    draw = ImageDraw.Draw(img)
    draw.text((30, 30), "DAWA Prescription\n1. Tab. Panadol 500mg\n2. Tab. Augmentin 625mg", fill=(0, 0, 0))
    img.save(test_img_path)

    with open(test_img_path, "rb") as f:
        res = requests.post(
            f"{BASE_URL}/ocr/upload-prescription",
            files={"file": ("test_prescription.jpg", f, "image/jpeg")},
            data={"patient_id": 1}
        )
    assert res.status_code == 200, res.text
    ocr_result = res.json()
    presc_id = ocr_result["prescription_id"]
    extracted = ocr_result.get("medicines") or ocr_result.get("extracted_items") or []
    print(f"[OK] OCR Upload succeeded (ID: {presc_id}). Extracted {len(extracted)} items: {[i.get('original_name', i.get('medicine_name', '')) for i in extracted]}")

    # 4. Confirm medicine review & match pharmacies
    confirmed_items = [
        {"medicine_name": "Panadol", "strength": "500 mg", "dosage_form": "Tablet", "quantity": 10, "instructions": "Take after meals"},
        {"medicine_name": "Augmentin", "strength": "625 mg", "dosage_form": "Tablet", "quantity": 10, "instructions": "Finish full course"},
    ]
    res = requests.post(
        f"{BASE_URL}/prescriptions/confirm-and-match",
        json={
            "prescription_id": presc_id,
            "patient_id": 1,
            "items": confirmed_items,
            "patient_latitude": 31.5204,
            "patient_longitude": 74.3587
        }
    )
    assert res.status_code == 200, res.text
    match_result = res.json()
    matches = match_result["matching_pharmacies"]
    print(f"[OK] Pharmacy Matching returned {len(matches)} pharmacies.")
    top_match = matches[0]
    print(f"     Top Pharmacy: {top_match['pharmacy_name']} (Full Stock: {top_match['has_all_medicines']}, Distance: {top_match['distance_km']} km)")
    chosen_pharmacy_id = top_match["pharmacy_id"]

    # 5. Generate Invoice
    res = requests.post(
        f"{BASE_URL}/invoices/generate",
        params={"prescription_id": presc_id, "pharmacy_id": chosen_pharmacy_id, "delivery": False}
    )
    assert res.status_code == 200, res.text
    invoice = res.json()
    invoice_id = invoice["id"]
    print(f"[OK] Generated Invoice: {invoice['invoice_number']} for PKR {invoice['total_amount']}")

    # 6. Approve Invoice
    res = requests.post(f"{BASE_URL}/invoices/{invoice_id}/decision", json={"approved": True})
    assert res.status_code == 200, res.text
    print(f"[OK] Invoice approved by patient (Status: {res.json()['status']})")

    # 7. Create Order (Pickup)
    res = requests.post(
        f"{BASE_URL}/orders/create",
        json={
            "invoice_id": invoice_id,
            "patient_id": 1,
            "fulfillment_type": "pickup",
        }
    )
    assert res.status_code == 200, res.text
    order = res.json()
    order_id = order["id"]
    order_num = order["order_number"]
    print(f"[OK] Created Order: {order_num} (Status: {order['status']})")

    # 8. Pharmacist Admin - Verify prescription
    res = requests.post(
        f"{BASE_URL}/admin/orders/{order_id}/verify",
        json={"action": "VERIFY", "notes": "Prescription validated. Dosage verified. Stock confirmed."}
    )
    assert res.status_code == 200, res.text
    print(f"[OK] Pharmacist verified order: {res.json()['status']}")

    # 9. Progress order stages
    for next_status in ["Preparing Order", "Ready for Pickup", "Collected"]:
        res = requests.post(
            f"{BASE_URL}/admin/orders/{order_id}/update-status",
            json={"status": next_status, "notes": f"Order moved to {next_status}"}
        )
        assert res.status_code == 200, res.text
        print(f"[OK] Pharmacist updated status -> {next_status}")

    # 10. Check order tracking timeline
    res = requests.get(f"{BASE_URL}/orders/{order_id}")
    assert res.status_code == 200, res.text
    final_order = res.json()
    assert final_order["status"] == "Collected"
    print(f"[SUCCESS] Final Order Timeline has {len(final_order['history'])} milestones. Full pipeline verified!")

    # Cleanup test image
    if os.path.exists(test_img_path):
        os.remove(test_img_path)

if __name__ == "__main__":
    test_full_pipeline()
