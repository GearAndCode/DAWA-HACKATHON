import os
from typing import List
from fastapi import APIRouter, Depends, HTTPException
from fastapi.responses import FileResponse
from sqlalchemy.orm import Session
from app.database import get_db
from app.models.prescription import Prescription, PrescriptionItem
from app.schemas.prescription import (
    PrescriptionConfirmRequest,
    PrescriptionResponse,
)
from app.services.matching_service import find_matching_pharmacies
from app.core.config import settings

router = APIRouter(prefix="/prescriptions", tags=["Prescriptions"])

@router.post("/confirm-and-match")
def confirm_and_match_pharmacies(
    req: PrescriptionConfirmRequest,
    db: Session = Depends(get_db)
):
    """
    Patient reviews and confirms the extracted medicine list (with edits).
    Updates database with confirmed items.
    Searches pharmacy inventories and prioritizes the nearest pharmacy that has all medicines.
    """
    presc = db.query(Prescription).filter(Prescription.id == req.prescription_id).first()
    if not presc:
        raise HTTPException(status_code=404, detail="Prescription not found")

    # Clear previous draft items and insert patient-confirmed items
    db.query(PrescriptionItem).filter(PrescriptionItem.prescription_id == presc.id).delete()
    for item in req.items:
        db.add(
            PrescriptionItem(
                prescription_id=presc.id,
                medicine_name=item.medicine_name,
                strength=item.strength,
                dosage_form=item.dosage_form,
                quantity=item.quantity,
                frequency=item.frequency,
                duration=item.duration,
                instructions=item.instructions,
                confidence=1.0,  # Confirmed by user
            )
        )
    presc.status = "CONFIRMED"
    db.commit()

    # Find matching pharmacies based on patient coordinates
    ranked_pharmacies = find_matching_pharmacies(
        db=db,
        items=req.items,
        patient_lat=req.patient_latitude,
        patient_lon=req.patient_longitude,
    )

    return {
        "prescription_id": presc.id,
        "status": presc.status,
        "confirmed_items_count": len(req.items),
        "matching_pharmacies": ranked_pharmacies,
    }

@router.get("/{prescription_id}/image")
def get_prescription_image(prescription_id: int, db: Session = Depends(get_db)):
    """Serves the uploaded prescription image."""
    presc = db.query(Prescription).filter(Prescription.id == prescription_id).first()
    if not presc:
        raise HTTPException(status_code=404, detail="Prescription not found")

    file_path = os.path.join(settings.UPLOAD_DIR, presc.image_path)
    if not os.path.exists(file_path):
        raise HTTPException(status_code=404, detail="Image file not found on server")

    media_type = "image/jpeg"
    if presc.image_path.endswith(".png"):
        media_type = "image/png"
    elif presc.image_path.endswith(".webp"):
        media_type = "image/webp"

    return FileResponse(file_path, media_type=media_type)

@router.get("", response_model=List[PrescriptionResponse])
def get_all_prescriptions(db: Session = Depends(get_db)):
    return db.query(Prescription).order_by(Prescription.created_at.desc()).all()

@router.get("/{prescription_id}", response_model=PrescriptionResponse)
def get_prescription_by_id(prescription_id: int, db: Session = Depends(get_db)):
    presc = db.query(Prescription).filter(Prescription.id == prescription_id).first()
    if not presc:
        raise HTTPException(status_code=404, detail="Prescription not found")
    return presc
