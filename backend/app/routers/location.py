from typing import List, Optional
from fastapi import APIRouter, Depends, Query
from sqlalchemy.orm import Session
from app.database import get_db
from app.models.pharmacy import Pharmacy
from app.schemas.pharmacy import PharmacyResponse, PharmacyWithDistance
from app.services.distance_service import calculate_haversine_distance

router = APIRouter(prefix="/location", tags=["Location & Pharmacies"])

@router.get("/pharmacies", response_model=List[PharmacyResponse])
def get_all_pharmacies(db: Session = Depends(get_db)):
    """Get all registered pharmacies."""
    return db.query(Pharmacy).all()

@router.get("/nearby-pharmacies", response_model=List[PharmacyWithDistance])
def get_nearby_pharmacies(
    lat: float = Query(..., description="Patient actual latitude"),
    lon: float = Query(..., description="Patient actual longitude"),
    db: Session = Depends(get_db)
):
    """
    Returns pharmacies sorted by actual calculated distance from patient coordinates.
    Uses Haversine distance formula.
    """
    pharmacies = db.query(Pharmacy).all()
    results = []

    for p in pharmacies:
        dist = calculate_haversine_distance(lat, lon, p.latitude, p.longitude)
        results.append(
            PharmacyWithDistance(
                id=p.id,
                name=p.name,
                area=p.area,
                address=p.address,
                city=p.city,
                latitude=p.latitude,
                longitude=p.longitude,
                phone=p.phone,
                opening_hours=p.opening_hours,
                description=p.description,
                is_demo=p.is_demo,
                rating=p.rating,
                distance_km=dist,
            )
        )

    results.sort(key=lambda x: x.distance_km)
    return results
