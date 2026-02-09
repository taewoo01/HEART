from typing import Any, Dict, Optional
from pydantic import BaseModel


class AnalyzeResponse(BaseModel):
    analysis_id: str
    user_id: str
    session_id: Optional[str]
    transcript_text: str
    metrics: Dict[str, Any]
    emotion_estimate: Dict[str, Any]
    summary: Optional[Dict[str, Any]]
