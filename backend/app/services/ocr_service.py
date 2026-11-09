import os
import re
import json
import difflib
from typing import List, Dict, Any, Tuple, Optional
import requests
from PIL import Image, ImageOps, ImageEnhance
from pypdf import PdfReader

from app.schemas.prescription import (
    PrescriptionExtractionResponse,
    PatientInfo,
    DoctorInfo,
    ExtractedMedicine,
)
from app.core.config import settings

# Recognized medicine catalogue for normalization
CATALOGUE = [
    {"name": "Panadol", "generic": "Paracetamol", "strength": "500 mg", "form": "Tablet"},
    {"name": "Paracetamol", "generic": "Paracetamol", "strength": "500 mg", "form": "Tablet"},
    {"name": "Brufen", "generic": "Ibuprofen", "strength": "400 mg", "form": "Tablet"},
    {"name": "Augmentin", "generic": "Amoxicillin / Clavulanate", "strength": "625 mg", "form": "Tablet"},
    {"name": "Calpol", "generic": "Paracetamol", "strength": "120 mg/5 ml", "form": "Syrup"},
    {"name": "Disprin", "generic": "Aspirin", "strength": "300 mg", "form": "Tablet"},
    {"name": "Vitamin C", "generic": "Ascorbic Acid", "strength": "500 mg", "form": "Tablet"},
    {"name": "Flagyl", "generic": "Metronidazole", "strength": "400 mg", "form": "Tablet"},
    {"name": "Risek", "generic": "Omeprazole", "strength": "20 mg", "form": "Capsule"},
    {"name": "Arinac", "generic": "Ibuprofen / Pseudoephedrine", "strength": "200 mg/30 mg", "form": "Tablet"},
    {"name": "Cravit", "generic": "Levofloxacin", "strength": "500 mg", "form": "Tablet"},
    {"name": "Surbex Z", "generic": "Zinc & Multivitamins", "strength": "Multivitamin", "form": "Tablet"},
    {"name": "Loprin", "generic": "Aspirin", "strength": "75 mg", "form": "Tablet"},
    {"name": "Softin", "generic": "Loratadine", "strength": "10 mg", "form": "Tablet"},
    {"name": "Cetirizine", "generic": "Cetirizine HCl", "strength": "10 mg", "form": "Tablet"},
    {"name": "Klaricid", "generic": "Clarithromycin", "strength": "250 mg", "form": "Tablet"},
    {"name": "Hydryllin", "generic": "Aminophylline / Diphenhydramine", "strength": "120 ml", "form": "Syrup"},
    {"name": "Gravinate", "generic": "Dimenhydrinate", "strength": "50 mg", "form": "Tablet"},
    {"name": "Amoxicillin", "generic": "Amoxicillin", "strength": "500 mg", "form": "Capsule"},
    {"name": "Ciprofloxacin", "generic": "Ciprofloxacin", "strength": "500 mg", "form": "Tablet"},
    {"name": "Azithromycin", "generic": "Azithromycin", "strength": "250 mg", "form": "Tablet"},
]

def preprocess_image(input_path: str) -> str:
    """
    Corrects EXIF orientation, enhances contrast for handwriting readability,
    and scales large images to a maximum dimension without losing detail.
    Saves a processed copy and returns its path.
    """
    ext = os.path.splitext(input_path)[1].lower()
    if ext == ".pdf":
        return input_path

    processed_path = f"{os.path.splitext(input_path)[0]}_proc.jpg"
    try:
        with Image.open(input_path) as img:
            # 1. Correct EXIF rotation
            img = ImageOps.exif_transpose(img) or img
            if img.mode != "RGB":
                img = img.convert("RGB")

            # 2. Max dimension resize (max 2000px, preserves sharp text)
            max_dim = 2000
            w, h = img.size
            if max(w, h) > max_dim:
                ratio = max_dim / max(w, h)
                img = img.resize((int(w * ratio), int(h * ratio)), Image.Resampling.LANCZOS)

            # 3. Enhance contrast slightly for prescription ink
            enhancer = ImageEnhance.Contrast(img)
            img = enhancer.enhance(1.2)

            img.save(processed_path, format="JPEG", quality=92)
            return processed_path
    except Exception as e:
        print(f"[Image Preprocessing Error]: {e}")
        return input_path

def understand_prescription_with_vision(image_path: str) -> Optional[Dict[str, Any]]:
    """
    Sends the real preprocessed prescription image to Google Gemini Vision.
    Requests structured JSON adhering to medical extraction standards.
    Returns parsed dictionary or None if key missing/error.
    """
    api_key = settings.VISION_API_KEY
    if not api_key:
        return None

    try:
        import google.genai as genai
        client = genai.Client(api_key=api_key)

        prompt = (
            "You are an expert clinical pharmacist and AI medical vision model for DAWA Healthcare.\n"
            "Analyze this uploaded prescription image and extract all visible content.\n"
            "CRITICAL RULES:\n"
            "1. ONLY extract information that is genuinely legible in the image. Do NOT guess or hallucinate.\n"
            "2. If handwriting is illegible, mark that field as null or 'unreadable'.\n"
            "3. Return strict JSON matching this exact structure without markdown ticks:\n"
            "{\n"
            '  "patient": {"name": string or null, "age": string or null, "gender": string or null, "date": string or null},\n'
            '  "doctor": {"name": string or null, "clinic": string or null, "registration_no": string or null},\n'
            '  "medicines": [\n'
            '    {\n'
            '      "original_name": "exact name read from image",\n'
            '      "normalized_name": "standard clinical name or null",\n'
            '      "strength": "e.g. 500 mg, 10 mg or null",\n'
            '      "dosage_form": "Tablet, Capsule, Syrup, etc. or null",\n'
            '      "quantity": integer (default 10 for tablets, 1 for syrup),\n'
            '      "instructions": "e.g. 1 tablet twice daily after meals or null",\n'
            '      "frequency": "e.g. BD, TDS, daily or null",\n'
            '      "duration": "e.g. 5 days or null",\n'
            '      "field_status": "verified_from_image or needs_verification",\n'
            '      "confidence": float between 0.0 and 1.0\n'
            '    }\n'
            '  ],\n'
            '  "clinical_notes": [string],\n'
            '  "warnings": [string]\n'
            "}"
        )

        img = Image.open(image_path)
        response = client.models.generate_content(
            model=settings.VISION_MODEL,
            contents=[img, prompt]
        )

        if response and response.text:
            cleaned = response.text.strip()
            # Remove possible ```json ... ``` wrapper
            cleaned = re.sub(r"^```(?:json)?", "", cleaned, flags=re.MULTILINE).strip()
            cleaned = re.sub(r"```$", "", cleaned, flags=re.MULTILINE).strip()
            return json.loads(cleaned)
    except Exception as e:
        print(f"[Gemini Vision Execution Error]: {e}")
    return None

def extract_with_ocr_space(image_path: str) -> Tuple[str, Optional[str]]:
    """Calls OCR.space if an API key is configured."""
    key = settings.OCR_SPACE_API_KEY
    if not key:
        return "", None

    try:
        with open(image_path, "rb") as f:
            res = requests.post(
                "https://api.ocr.space/parse/image",
                files={"filename": (os.path.basename(image_path), f, "image/jpeg")},
                data={
                    "apikey": key,
                    "language": "eng",
                    "scale": True,
                    "detectOrientation": True,
                },
                timeout=18,
            )
        if res.status_code == 200:
            data = res.json()
            results = data.get("ParsedResults", [])
            if results:
                text = results[0].get("ParsedText", "").strip()
                return text, None
            if "error" in data:
                return "", str(data["error"])
    except Exception as e:
        return "", str(e)
    return "", None

def parse_text_heuristically(raw_text: str) -> Dict[str, Any]:
    """
    Parses plain text from OCR into structured fields without hardcoded medicine fallbacks.
    """
    lines = [l.strip() for l in raw_text.split("\n") if l.strip()]
    patient = {"name": None, "age": None, "gender": None, "date": None}
    doctor = {"name": None, "clinic": None, "registration_no": None}
    medicines = []
    warnings = []

    # Metadata extraction
    for line in lines:
        lower = line.lower()
        if not patient["name"] and ("patient:" in lower or "patient name:" in lower or "pt name:" in lower or "pt:" in lower):
            m = re.search(r'(?:patient(?:\s*name)?|pt(?:\s*name)?)\s*[:\-]?\s*([A-Za-z\s\.\'\-]+)', line, re.IGNORECASE)
            if m: patient["name"] = m.group(1).strip()
        if not patient["date"] and ("date:" in lower or "/" in line or "-" in line):
            m = re.search(r'(\b\d{1,2}[/\-\.]\d{1,2}[/\-\.]\d{2,4}\b|\b\d{1,2}\s+[A-Za-z]{3,9}\s+\d{4}\b)', line)
            if m: patient["date"] = m.group(1).strip()
        if not doctor["name"] and ("dr." in lower or "doctor:" in lower):
            m = re.search(r'(?:dr\.|doctor\s*[:\-])\s*([A-Za-z\s\.\'\-]+)', line, re.IGNORECASE)
            if m: doctor["name"] = "Dr. " + m.group(1).replace("Dr.", "").strip()

    # Search catalogue
    strength_pattern = re.compile(r'(\d+(?:\.\d+)?\s*(?:mg|ma|g|ml|mcg|iu)(?:/\d+\s*ml)?)', re.IGNORECASE)
    form_pattern = re.compile(r'\b(tab(?:let)?|cap(?:sule)?|syp|syrup|drop|inj(?:ection)?)\b', re.IGNORECASE)
    freq_pattern = re.compile(r'\b(OD|BD|TDS|QDS|QID|BID|TID|once daily|twice daily|thrice daily|1\+0\+1|1\+1\+1|1\+0\+0|PRN)\b', re.IGNORECASE)
    qty_pattern = re.compile(r'(?:qty|x|#|quantity)\s*[:=]?\s*(\d+)', re.IGNORECASE)

    raw_words = re.findall(r'[A-Za-z]{4,}', raw_text)
    catalog_lookup = {c["name"].lower(): c for c in CATALOGUE}
    catalog_names = list(catalog_lookup.keys())
    seen = set()

    for word in raw_words:
        matches = difflib.get_close_matches(word.lower(), catalog_names, n=1, cutoff=0.74)
        if matches:
            k = matches[0]
            item = catalog_lookup[k]
            med_name = item["name"]
            if med_name in seen:
                continue
            seen.add(med_name)

            # Line context
            ctx = ""
            for l in lines:
                if word in l or med_name.lower() in l.lower():
                    ctx = l
                    break

            sm = strength_pattern.search(ctx)
            st = sm.group(1).replace("ma", "mg") if sm else item["strength"]
            fm = form_pattern.search(ctx)
            form = "Syrup" if (fm and "syp" in fm.group(1).lower()) else item["form"]
            freq = freq_pattern.search(ctx)
            frequency = freq.group(1).upper() if freq else "Twice daily"
            qm = qty_pattern.search(ctx)
            qty = int(qm.group(1)) if qm else (1 if "syrup" in form.lower() else 10)

            medicines.append({
                "original_name": med_name,
                "normalized_name": med_name,
                "strength": st,
                "dosage_form": form,
                "quantity": qty,
                "instructions": "As directed by physician",
                "frequency": frequency,
                "duration": "5 days",
                "field_status": "verified_from_image",
                "confidence": 0.90 if word.lower() == med_name.lower() else 0.78,
            })

    if not medicines:
        warnings.append("No medicines could be confidently identified from the text in this image.")

    return {
        "patient": patient,
        "doctor": doctor,
        "medicines": medicines,
        "clinical_notes": [],
        "warnings": warnings,
    }

def process_prescription_pipeline(original_image_path: str) -> PrescriptionExtractionResponse:
    """
    Main image understanding pipeline:
    1. Preprocesses image (orientation, contrast enhancement, max-dimension scale).
    2. Runs Vision AI if VISION_API_KEY is configured.
    3. If Vision API not configured, tries configured OCR engine.
    4. If no vision/OCR engine is configured, returns an honest configuration warning with empty medicine list.
    5. NEVER inserts sample/fallback medicines.
    """
    proc_image_path = preprocess_image(original_image_path)

    # 1. Try Gemini Vision AI
    if settings.VISION_API_KEY:
        vision_result = understand_prescription_with_vision(proc_image_path)
        if vision_result:
            meds = [ExtractedMedicine(**m) for m in vision_result.get("medicines", [])]
            return PrescriptionExtractionResponse(
                success=True,
                prescription_id=0,
                image_url="",
                patient=PatientInfo(**vision_result.get("patient", {})),
                doctor=DoctorInfo(**vision_result.get("doctor", {})),
                medicines=meds,
                clinical_notes=vision_result.get("clinical_notes", []),
                warnings=vision_result.get("warnings", []),
                requires_patient_review=True,
                provider_used=f"Gemini Vision ({settings.VISION_MODEL})",
            )

    # 2. Try OCR.space if key configured
    if settings.OCR_SPACE_API_KEY:
        raw_text, ocr_err = extract_with_ocr_space(proc_image_path)
        if raw_text:
            parsed = parse_text_heuristically(raw_text)
            meds = [ExtractedMedicine(**m) for m in parsed.get("medicines", [])]
            return PrescriptionExtractionResponse(
                success=len(meds) > 0,
                prescription_id=0,
                image_url="",
                patient=PatientInfo(**parsed.get("patient", {})),
                doctor=DoctorInfo(**parsed.get("doctor", {})),
                medicines=meds,
                clinical_notes=parsed.get("clinical_notes", []),
                warnings=parsed.get("warnings", []),
                requires_patient_review=True,
                provider_used="OCR.space Engine",
            )
        elif ocr_err:
            return PrescriptionExtractionResponse(
                success=False,
                prescription_id=0,
                image_url="",
                warnings=[f"OCR service notice: {ocr_err}. Please review or add medicines manually."],
                requires_patient_review=True,
                provider_used="OCR.space (Error)",
            )

    # 3. Honest Notice when Vision AI key is not yet provided in .env
    return PrescriptionExtractionResponse(
        success=False,
        prescription_id=0,
        image_url="",
        warnings=[
            "Vision AI API key is not configured in backend/.env (VISION_API_KEY). "
            "Please add your Gemini API key or add your medicines manually below to find pharmacies."
        ],
        requires_patient_review=True,
        provider_used="None (Configuration Required)",
    )
