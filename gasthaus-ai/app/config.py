from dotenv import load_dotenv
import os

load_dotenv()

MONGODB_URL = os.getenv("MONGODB_URL")
GEMINI_API_KEY = os.getenv("GEMINI_API_KEY")
NESTJS_API_URL = os.getenv("NESTJS_API_URL")
AI_INTERNAL_KEY = os.getenv("AI_INTERNAL_KEY")
CORS_ALLOWED_ORIGIN = os.getenv("CORS_ALLOWED_ORIGIN", "http://localhost:8080")

if not GEMINI_API_KEY:
    raise ValueError("GEMINI_API_KEY is not set in .env")
if not MONGODB_URL:
    raise ValueError("MONGODB_URL is not set in .env")
if not AI_INTERNAL_KEY:
    raise ValueError("AI_INTERNAL_KEY is not set in .env")