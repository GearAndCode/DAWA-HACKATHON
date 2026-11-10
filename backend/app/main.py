from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware
from app.database import init_db
from app.routers import location, medicines, ocr, prescriptions, invoices, orders, admin, urgency
from app.core.config import settings

app = FastAPI(
    title="DAWA Healthcare API",
    description="Backend services for DAWA (دواء) Healthcare Hackathon Platform",
    version=settings.VERSION,
    docs_url="/docs",
    redoc_url="/redoc"
)

# Enable CORS for Flutter Web, Android Emulator (10.0.2.2), and localhost
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

@app.on_event("startup")
def on_startup():
    init_db()

# Register Routers
app.include_router(location.router, prefix=settings.API_PREFIX)
app.include_router(medicines.router, prefix=settings.API_PREFIX)
app.include_router(ocr.router, prefix=settings.API_PREFIX)
app.include_router(prescriptions.router, prefix=settings.API_PREFIX)
app.include_router(invoices.router, prefix=settings.API_PREFIX)
app.include_router(orders.router, prefix=settings.API_PREFIX)
app.include_router(admin.router, prefix=settings.API_PREFIX)
app.include_router(urgency.router, prefix=settings.API_PREFIX)

@app.get("/")
def root():
    return {
        "app": "DAWA (دواء) Healthcare API",
        "version": settings.VERSION,
        "docs": "/docs",
        "status": "operational"
    }

@app.get("/health")
def health():
    return {"status": "ok"}
