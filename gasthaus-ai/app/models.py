from pydantic import BaseModel, Field
from typing import List, Optional
from datetime import datetime

class Message(BaseModel):
    role: str  # "user" or "model"
    content: str
    timestamp: datetime = Field(default_factory=datetime.utcnow)

class RecommendRequest(BaseModel):
    userId: str
    message: str
    menuItems: List[dict]

class RecommendResponse(BaseModel):
    reply: str
    sessionId: Optional[str] = None

class InsightsRequest(BaseModel):
    totalOrders: int
    totalRevenue: float
    topItems: List[dict]
    busiestHour: Optional[str] = None
    complaints: Optional[List[str]] = []

class InsightsResponse(BaseModel):
    insights: str

class ReviewSummaryRequest(BaseModel):
    menuItemName: str
    reviews: List[dict]

class ReviewSummaryResponse(BaseModel):
    summary: str