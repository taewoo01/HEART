import json
import uuid
from typing import Optional
from fastapi import FastAPI, UploadFile, File, Form, HTTPException
from fastapi.responses import JSONResponse
from .db import init_db, get_conn
from .storage import save_audio_file, now_iso
from .analysis import transcribe_with_timestamps, compute_metrics, build_emotion_estimate, try_summarize_text

app = FastAPI(title="Heart Audio Analysis")


def _custom_openapi():
    return {
        "openapi": "3.0.0",
        "info": {"title": "Heart Audio Analysis", "version": "0.1.0"},
        "paths": {},
    }


app.openapi = _custom_openapi


@app.on_event("startup")
def _startup() -> None:
    init_db()


@app.get("/health")
def health():
    return {"status": "ok"}


@app.post("/v1/audio/analyze")
async def analyze_audio(
    file: UploadFile = File(...),
    user_id: str = Form(...),
    session_id: Optional[str] = Form(None),
):
    if not file.filename:
        raise HTTPException(status_code=400, detail="file is required")

    data = await file.read()
    audio_path = save_audio_file(data, suffix=".m4a")

    # Transcribe with timestamps (word-level)
    transcribed = transcribe_with_timestamps(audio_path)
    transcript_text = (transcribed.get("text") or "").strip()
    words = transcribed.get("words") or []
    duration_ms = int(transcribed.get("duration", 0) * 1000)

    metrics = compute_metrics(words, duration_ms)
    summary = try_summarize_text(transcript_text) or {}
    emotion = build_emotion_estimate(metrics, summary.get("summary", ""), summary.get("keywords", []))

    analysis_id = uuid.uuid4().hex
    created_at = now_iso()

    conn = get_conn()
    cur = conn.cursor()
    cur.execute(
        """
        INSERT INTO analyses
        (id, user_id, session_id, created_at, audio_path, transcript_text, words_json, metrics_json, emotion_json, summary_json)
        VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
        """,
        (
            analysis_id,
            user_id,
            session_id,
            created_at,
            audio_path,
            transcript_text,
            json.dumps(words, ensure_ascii=False),
            json.dumps(metrics, ensure_ascii=False),
            json.dumps(emotion, ensure_ascii=False),
            json.dumps(summary, ensure_ascii=False),
        ),
    )
    conn.commit()
    conn.close()

    return {
        "analysis_id": analysis_id,
        "user_id": user_id,
        "session_id": session_id,
        "transcript_text": transcript_text,
        "metrics": metrics,
        "emotion_estimate": emotion,
        "summary": summary,
    }


@app.get("/v1/audio/result/{analysis_id}")
def get_result(analysis_id: str):
    conn = get_conn()
    cur = conn.cursor()
    cur.execute("SELECT * FROM analyses WHERE id = ?", (analysis_id,))
    row = cur.fetchone()
    conn.close()
    if row is None:
        raise HTTPException(status_code=404, detail="not found")

    return JSONResponse(
        {
            "analysis_id": row["id"],
            "user_id": row["user_id"],
            "session_id": row["session_id"],
            "created_at": row["created_at"],
            "transcript_text": row["transcript_text"],
            "metrics": json.loads(row["metrics_json"] or "{}"),
            "emotion_estimate": json.loads(row["emotion_json"] or "{}"),
            "summary": json.loads(row["summary_json"] or "{}"),
        }
    )


@app.post("/v1/batch/run")
def run_batch():
    # Placeholder: daily batch recompute could be added here.
    return {"status": "ok", "message": "batch stub executed"}
