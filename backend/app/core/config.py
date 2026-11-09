import os
from pydantic import BaseModel

class Settings(BaseModel):
    PROJECT_NAME: str = "DAWA Healthcare API"
    VERSION: str = "1.0.0"
    API_PREFIX: str = "/api"
    UPLOAD_DIR: str = os.path.join(
        os.path.dirname(os.path.dirname(os.path.abspath(__file__))), "uploads"
    )
    DEFAULT_DELIVERY_FEE: float = 150.0  # PKR
    DEMO_ADMIN_KEY: str = os.getenv("DEMO_ADMIN_KEY", "dawa-pharmacist-demo-2026")
    OCR_SPACE_API_KEY: str = os.getenv("OCR_SPACE_API_KEY", "helloworld")
    GEMINI_API_KEY: str = os.getenv("GEMINI_API_KEY", "")

settings = Settings()
os.makedirs(settings.UPLOAD_DIR, exist_ok=True)
