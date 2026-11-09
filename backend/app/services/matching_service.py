from typing import List, Dict, Any, Optional
from sqlalchemy.orm import Session
from app.models.pharmacy import Pharmacy
from app.models.medicine import Medicine
from app.models.inventory import PharmacyInventory
from app.schemas.prescription import PrescriptionItemCreate
from app.services.distance_service import calculate_haversine_distance

def find_matching_pharmacies(
    db: Session,
    items: List[PrescriptionItemCreate],
    patient_lat: Optional[float] = None,
    patient_lon: Optional[float] = None
) -> List[Dict[str, Any]]:
    """
    Finds pharmacies matching the requested prescription items.
    Ranks by:
    1. Complete match first (has ALL medicines in stock with requested quantity)
    2. Then by nearest distance to patient (using actual GPS coordinates)
    Also lists missing medicines for partial matches.
    """
    # Default patient location if none provided (Gulberg, Lahore)
    p_lat = patient_lat if patient_lat is not None else 31.5204
    p_lon = patient_lon if patient_lon is not None else 74.3587

    pharmacies = db.query(Pharmacy).all()
    results = []

    for pharmacy in pharmacies:
        dist = calculate_haversine_distance(p_lat, p_lon, pharmacy.latitude, pharmacy.longitude)

        available_items = []
        missing_items = []
        total_price = 0.0

        for req_item in items:
            # Match medicine by name (case-insensitive substring or exact)
            search_name = req_item.medicine_name.strip().lower()
            
            # Query inventory for this pharmacy joined with medicines
            inv_entry = (
                db.query(PharmacyInventory)
                .join(Medicine, PharmacyInventory.medicine_id == Medicine.id)
                .filter(
                    PharmacyInventory.pharmacy_id == pharmacy.id,
                    Medicine.brand_name.ilike(f"%{search_name}%")
                )
                .first()
            )

            if inv_entry and inv_entry.is_available and inv_entry.stock_quantity >= req_item.quantity:
                line_total = inv_entry.unit_price * req_item.quantity
                total_price += line_total
                available_items.append({
                    "medicine_id": inv_entry.medicine_id,
                    "medicine_name": inv_entry.medicine.brand_name,
                    "strength": inv_entry.medicine.strength,
                    "dosage_form": inv_entry.medicine.dosage_form,
                    "requested_quantity": req_item.quantity,
                    "stock_quantity": inv_entry.stock_quantity,
                    "unit_price": inv_entry.unit_price,
                    "line_total": round(line_total, 2),
                    "is_in_stock": True,
                })
            else:
                missing_items.append({
                    "medicine_name": req_item.medicine_name,
                    "strength": req_item.strength or "Standard",
                    "dosage_form": req_item.dosage_form or "Tablet",
                    "requested_quantity": req_item.quantity,
                    "available_stock": inv_entry.stock_quantity if inv_entry else 0,
                    "is_in_stock": False,
                })

        has_all = len(missing_items) == 0 and len(available_items) > 0
        total_req = len(items)
        available_count = len(available_items)

        results.append({
            "pharmacy_id": pharmacy.id,
            "pharmacy_name": pharmacy.name,
            "area": pharmacy.area,
            "address": pharmacy.address,
            "city": pharmacy.city,
            "latitude": pharmacy.latitude,
            "longitude": pharmacy.longitude,
            "phone": pharmacy.phone,
            "opening_hours": pharmacy.opening_hours,
            "rating": pharmacy.rating,
            "distance_km": dist,
            "has_all_medicines": has_all,
            "available_items_count": available_count,
            "total_items_requested": total_req,
            "available_items": available_items,
            "missing_items": missing_items,
            "estimated_subtotal": round(total_price, 2),
        })

    # Sort key:
    # 1) Complete matches first (-has_all_medicines)
    # 2) Highest availability ratio (-available_items_count)
    # 3) Nearest distance (distance_km)
    results.sort(key=lambda x: (not x["has_all_medicines"], -x["available_items_count"], x["distance_km"]))
    return results
