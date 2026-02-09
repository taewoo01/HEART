import sqlite3
from .config import DB_PATH, DATA_DIR


def get_conn() -> sqlite3.Connection:
    DATA_DIR.mkdir(parents=True, exist_ok=True)
    conn = sqlite3.connect(DB_PATH)
    conn.row_factory = sqlite3.Row
    return conn


def init_db() -> None:
    conn = get_conn()
    cur = conn.cursor()
    cur.execute(
        """
        CREATE TABLE IF NOT EXISTS analyses (
            id TEXT PRIMARY KEY,
            user_id TEXT NOT NULL,
            session_id TEXT,
            created_at TEXT NOT NULL,
            audio_path TEXT NOT NULL,
            transcript_text TEXT,
            words_json TEXT,
            metrics_json TEXT,
            emotion_json TEXT,
            summary_json TEXT
        )
        """
    )
    conn.commit()
    conn.close()
