import os
import uuid
from fastapi import APIRouter, UploadFile, File, Depends, HTTPException, Form
from sqlalchemy.orm import Session
from app.database import get_db
from app.models.prescription import Prescription, PrescriptionItem
from app.schemas.prescription import OCRResultResponse
from app.services.ocr_service import run_ocr_on_image, parse_prescription_text
from app.core.config import settings

router = APIRouter(prefix="/ocr", tags=["Prescription OCR"])

@router.post("/upload-prescription", response_model=OCRResultResponse)
async def upload_prescription(
    file: UploadFile = File(...),
    patient_id: int = Form(1),
    db: Session = Depends(get_db)
):
    """
    Accepts an uploaded prescription image.
    Validates file format.
    Saves image securely.
    Runs genuine OCR.
    Extracts structured medicine list.
    Returns OCR text and extracted items for patient review.
    """
    # Validate extension
    ext = os.path.splitext(file.filename or "")[1].lower()
    if ext not in [".jpg", ".jpeg", ".png", ".webp"]:
        raise HTTPException(status_code=400, detail="Invalid image format. Supported formats: JPG, PNG, WEBP.")

    # Unique secure file name
    filename = f"{uuid.uuid4().hex}{ext}"
    filepath = os.path.join(settings.UPLOAD_DIR, filename)

    contents = await file.read()
    if len(contents) == 0:
        raise HTTPException(status_code=400, detail="Empty file uploaded.")
    if len(contents) > 15 * 1024 * 1024:
        raise HTTPException(status_code=400, detail="File too large (maximum 15MB allowed).")

    with open(filepath, "wb") as f:
        f.write(contents)

    # Run genuine OCR
    raw_ocr_text, ocr_confidence = run_ocr_on_image(filepath)

    # Parse medicine details
    items, is_uncertain, uncertainty_reason = parse_prescription_text(raw_ocr_text)

    # Save initial prescription record in SQLite
    db_prescription = Prescription(
        patient_id=patient_id,
        image_path=filename,
        ocr_raw_text=raw_ocr_text,
        ocr_confidence=round(ocr_confidence, 2),
        status="PROCESSED"
    )
    db.add(db_prescription)
    db.commit()
    db.refresh(db_prescription)

    # Save initial items in db
    for it in items:
        db_item = PrescriptionItem(
            prescription_id=db_prescription.id,
            medicine_name=it.medicine_name,
            strength=it.strength,
            dosage_form=it.dosage_form,
            quantity=it.quantity,
            frequency=it.frequency,
            duration=it.duration,
            instructions=it.instructions,
            confidence=it.confidence,
        )
        db.add(db_item)
    db.commit()

    return OCRResultResponse(
        prescription_id=db_prescription.id,
        image_url=f"/api/prescriptions/{db_prescription.id}/image",
        ocr_raw_text=raw_ocr_text,
        ocr_confidence=round(ocr_confidence, 2),
        is_uncertain=is_uncertain,
        uncertainty_reason=uncertainty_reason,
        extracted_items=items
    )
