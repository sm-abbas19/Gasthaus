from fastapi import APIRouter, Depends, HTTPException, Header
from app.models import (
    RecommendRequest, RecommendResponse,
    InsightsRequest, InsightsResponse,
    ReviewSummaryRequest, ReviewSummaryResponse,
)
from app.database import ai_sessions_collection
from app.config import GEMINI_API_KEY, AI_INTERNAL_KEY
from google import genai
from google.genai import types
from datetime import datetime

client = genai.Client(api_key=GEMINI_API_KEY)


def verify_internal_key(x_internal_key: str = Header(...)):
    if x_internal_key != AI_INTERNAL_KEY:
        raise HTTPException(status_code=403, detail="Forbidden")


router = APIRouter(dependencies=[Depends(verify_internal_key)])


# ─── Helper ───────────────────────────────────────

def format_menu(menu_items: list[dict]) -> str:
    lines = []
    for item in menu_items:
        availability = "Available" if item.get("isAvailable") else "Unavailable"
        lines.append(
            f"- {item['name']} | Rs. {item['price']} | {item.get('description', 'No description')} | {availability}"
        )
    return "\n".join(lines)


# ─── 1. AI Menu Recommendation Chatbot ────────────

@router.post("/recommend", response_model=RecommendResponse)
async def recommend(req: RecommendRequest):
    try:
        # Load existing session from MongoDB
        session = await ai_sessions_collection.find_one({"userId": req.userId})

        # Build conversation history
        contents = []
        if session and session.get("messages"):
            for msg in session["messages"]:
                contents.append(
                    types.Content(
                        role=msg["role"],
                        parts=[types.Part(text=msg["content"])]
                    )
                )

        # System prompt passed as system_instruction — kept separate from user turn
        # This prevents user message from overriding or leaking the system context
        menu_text = format_menu(req.menuItems)
        system_instruction = f"""You are Gustav, a menu assistant for Gasthaus restaurant.
Your personality is warm, knowledgeable, and subtly German — occasionally use light German phrases like "Wunderbar!" or "Sehr gut!" but keep it natural, not overdone.
Your ONLY job is to help customers decide what to order by recommending items from the menu based on their preferences.
You are NOT a waiter. You cannot place, confirm, or accept orders. You have no access to the ordering system.
When a customer says something like "I'll have X" or "order X for me", do NOT say things like "order placed", "coming right up", or "confirmed". Instead, clarify that they need to add it to their cart in the app and place the order themselves.
Always recommend specific items from the menu below and explain why they match the customer's preferences.
Keep responses concise and conversational.
If asked about something not on the menu, politely redirect to available items.

Current Menu:
{menu_text}"""

        # Add current user message as its own turn (not mixed with system context)
        contents.append(
            types.Content(
                role="user",
                parts=[types.Part(text=req.message)]
            )
        )

        # Call Gemini with system_instruction separate from conversation contents
        response = client.models.generate_content(
            model="gemini-3.1-flash-lite-preview",
            contents=contents,
            config=types.GenerateContentConfig(
                system_instruction=system_instruction,
            ),
        )
        reply = response.text

        # Save messages to MongoDB
        now = datetime.utcnow()
        new_messages = [
            {"role": "user", "content": req.message, "timestamp": now},
            {"role": "model", "content": reply, "timestamp": now},
        ]

        if session:
            await ai_sessions_collection.update_one(
                {"userId": req.userId},
                {
                    "$push": {"messages": {"$each": new_messages}},
                    "$set": {"updatedAt": now}
                }
            )
            session_id = str(session["_id"])
        else:
            result = await ai_sessions_collection.insert_one({
                "userId": req.userId,
                "messages": new_messages,
                "createdAt": now,
                "updatedAt": now,
            })
            session_id = str(result.inserted_id)

        return RecommendResponse(reply=reply, sessionId=session_id)

    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))


# ─── 2. Daily Manager Insights ────────────────────

@router.post("/insights", response_model=InsightsResponse)
async def insights(req: InsightsRequest):
    try:
        top_items_text = "\n".join(
            [f"- {item['name']}: {item.get('count', item.get('orders', 0))} orders" for item in req.topItems]
        ) if req.topItems else "No data"
        complaints_text = (
            "\n".join([f"- {c}" for c in req.complaints])
            if req.complaints
            else "No complaints recorded"
        )

        period_label = {"today": "Today", "week": "This Week", "month": "This Month"}.get(req.period, "Today")

        prompt = f"""You are a restaurant analytics assistant for Gasthaus.
Analyze the performance data for {period_label} and give a concise, actionable insight paragraph.
Be specific and factual — only reference what is present in the data below. Do not exaggerate, infer patterns, or use words like "recurring" or "consistent" unless multiple complaints say the same thing.
Highlight both positives and areas for improvement based strictly on the numbers provided.

Performance Data ({period_label}):
- Total Orders: {req.totalOrders}
- Total Revenue: Rs. {req.totalRevenue}
- Busiest Hour: {req.busiestHour or "Not recorded"}
- Top Selling Items:
{top_items_text}
- Customer Complaints ({len(req.complaints) if req.complaints else 0} total):
{complaints_text}

Write a 3-4 sentence insight summary for the manager."""

        response = client.models.generate_content(
            model="gemini-3.1-flash-lite-preview",
            contents=prompt,
        )
        return InsightsResponse(insights=response.text)

    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))


# ─── 3. Review Summarizer ─────────────────────────

@router.post("/review-summary", response_model=ReviewSummaryResponse)
async def review_summary(req: ReviewSummaryRequest):
    try:
        if not req.reviews:
            return ReviewSummaryResponse(
                summary="No reviews yet for this item."
            )

        reviews_text = "\n".join([
            f"- {r.get('rating')}/5 stars: {r.get('comment', 'No comment')}"
            for r in req.reviews
        ])

        prompt = f"""Summarize these customer reviews for '{req.menuItemName}' in 2-3 sentences.
Be balanced — mention both positives and negatives if present.
Write as if speaking directly to a potential customer browsing the menu.
Do not use bullet points, just flowing natural prose.

Reviews:
{reviews_text}"""

        response = client.models.generate_content(
            model="gemini-3.1-flash-lite-preview",
            contents=prompt,
        )
        return ReviewSummaryResponse(summary=response.text)

    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))


# ─── 4. Clear AI Session ──────────────────────────

@router.delete("/session/{user_id}")
async def clear_session(user_id: str):
    result = await ai_sessions_collection.delete_one({"userId": user_id})
    if result.deleted_count == 0:
        raise HTTPException(status_code=404, detail="Session not found")
    return {"message": "Session cleared successfully"}