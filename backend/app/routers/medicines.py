from typing import List, Optional
from fastapi import APIRouter, Depends, Query, HTTPException
from sqlalchemy.orm import Session
from app.database import get_db
from app.models.medicine import Medicine
from app.schemas.medicine import MedicineResponse

router = APIRouter(prefix="/medicines", tags=["Medicines"])

@router.get("", response_model=List[MedicineResponse])
def search_medicines(
    q: Optional[str] = Query(None, description="Search term for brand or generic name"),
    category: Optional[str] = Query(None, description="Filter by category"),
    db: Session = Depends(get_db)
):
    """Search medicine inventory by brand name, generic name, or category."""
    query = db.query(Medicine)
    if q:
        query = query.filter(
            (Medicine.brand_name.ilike(f"%{q.strip()}%")) |
            (Medicine.generic_name.ilike(f"%{q.strip()}%"))
        )
    if category:
        query = query.filter(Medicine.category.ilike(f"%{category.strip()}%"))

    return query.all()

@router.get("/{medicine_id}", response_model=MedicineResponse)
def get_medicine(medicine_id: int, db: Session = Depends(get_db)):
    med = db.query(Medicine).filter(Medicine.id == medicine_id).first()
    if not med:
        raise HTTPException(status_code=404, detail="Medicine not found")
    return med
