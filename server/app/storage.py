import uuid
from pathlib import Path
from datetime import datetime, timezone
from .config import AUDIO_DIR


def save_audio_file(data: bytes, suffix: str = ".m4a") -> str:
    AUDIO_DIR.mkdir(parents=True, exist_ok=True)
    name = f"audio_{uuid.uuid4().hex}{suffix}"
    path = AUDIO_DIR / name
    path.write_bytes(data)
    return str(path)


def now_iso() -> str:
    return datetime.now(timezone.utc).isoformat()
