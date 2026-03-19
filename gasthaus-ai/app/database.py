from motor.motor_asyncio import AsyncIOMotorClient
from app.config import MONGODB_URL

client = AsyncIOMotorClient(MONGODB_URL)
db = client.gasthaus_ai

ai_sessions_collection = db.ai_sessions