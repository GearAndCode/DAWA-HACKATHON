import os
import uuid
from fastapi import APIRouter, UploadFile, File, Depends, HTTPException, Form
from sqlalchemy.orm import Session
from app.database import get_db
from app.models.prescription import Prescription, PrescriptionItem
from app.schemas.prescription import OCRResultResponse
from app.services.ocr_service import run_genuine_ocr, parse_prescription_text, extract_metadata
from app.core.config import settings

router = APIRouter(prefix="/ocr", tags=["Prescription OCR"])

@router.post("/upload-prescription", response_model=OCRResultResponse)
async def upload_prescription(
    file: UploadFile = File(...),
    patient_id: int = Form(1),
    db: Session = Depends(get_db)
):
    """
    Accepts an actual uploaded prescription image or PDF.
    Validates file format and size.
    Saves image to uploads folder.
    Runs genuine multi-engine OCR extraction.
    Parses medicine details and patient/doctor metadata from the actual image.
    Never returns hardcoded or fabricated medicine defaults.
    """
    ext = os.path.splitext(file.filename or "")[1].lower()
    if ext not in [".jpg", ".jpeg", ".png", ".webp", ".pdf"]:
        raise HTTPException(
            status_code=400,
            detail="Unsupported format. Please upload JPG, PNG, WEBP, or PDF."
        )

    filename = f"{uuid.uuid4().hex}{ext}"
    filepath = os.path.join(settings.UPLOAD_DIR, filename)

    contents = await file.read()
    if len(contents) == 0:
        raise HTTPException(status_code=400, detail="Uploaded file is empty.")
    if len(contents) > 20 * 1024 * 1024:
        raise HTTPException(status_code=400, detail="File too large (max 20MB allowed).")

    with open(filepath, "wb") as f:
        f.write(contents)

    # Run genuine OCR on the saved file
    raw_ocr_text, ocr_confidence = run_genuine_ocr(filepath)

    # Extract metadata from text
    metadata = extract_metadata(raw_ocr_text)

    # Parse medicine details from the real OCR text
    items, is_uncertain, uncertainty_reason = parse_prescription_text(raw_ocr_text)

    # Save prescription in SQLite database
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
        patient_name=metadata.get("patient_name"),
        patient_age=metadata.get("patient_age"),
        doctor_name=metadata.get("doctor_name"),
        clinic_name=metadata.get("clinic_name"),
        prescription_date=metadata.get("prescription_date"),
        extracted_items=items
    )
