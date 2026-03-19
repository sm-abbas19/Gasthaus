from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware
from app.routes import router

app = FastAPI(
    title="Gasthaus AI Service",
    description="AI microservice for menu recommendations, insights, and review summaries",
    version="1.0.0",
)

app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

app.include_router(router, prefix="/ai")

@app.get("/")
async def root():
    return {"service": "Gasthaus AI", "status": "running"}