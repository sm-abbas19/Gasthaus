from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware
from app.routes import router
from app.config import CORS_ALLOWED_ORIGIN

app = FastAPI(
    title="Gasthaus AI Service",
    description="AI microservice for menu recommendations, insights, and review summaries",
    version="1.0.0",
)

app.add_middleware(
    CORSMiddleware,
    allow_origins=[CORS_ALLOWED_ORIGIN],
    allow_credentials=False,
    allow_methods=["POST", "DELETE"],
    allow_headers=["Content-Type"],
)

app.include_router(router, prefix="/ai")

@app.get("/")
async def root():
    return {"service": "Gasthaus AI", "status": "running"}