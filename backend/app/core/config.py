import os
from pydantic import BaseModel
from dotenv import load_dotenv

# Automatically load environment variables from backend/.env if present
env_path = os.path.join(os.path.dirname(os.path.dirname(os.path.abspath(__file__))), ".env")
load_dotenv(env_path)

class Settings(BaseModel):
    PROJECT_NAME: str = "DAWA Healthcare API"
    VERSION: str = "1.0.0"
    API_PREFIX: str = "/api"
    UPLOAD_DIR: str = os.path.join(
        os.path.dirname(os.path.dirname(os.path.abspath(__file__))), "uploads"
    )
    DEFAULT_DELIVERY_FEE: float = 150.0  # PKR
    DEMO_ADMIN_KEY: str = os.getenv("DEMO_ADMIN_KEY", "dawa-pharmacist-demo-2026")
    
    # Vision AI Model configuration
    VISION_API_KEY: str = os.getenv("VISION_API_KEY", os.getenv("GEMINI_API_KEY", ""))
    VISION_MODEL: str = os.getenv("VISION_MODEL", "gemini-2.5-flash")
    
    # Document OCR API Key
    OCR_SPACE_API_KEY: str = os.getenv("OCR_SPACE_API_KEY", "")

settings = Settings()
os.makedirs(settings.UPLOAD_DIR, exist_ok=True)
