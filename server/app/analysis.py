import json
import requests
from typing import Any, Dict, List, Optional
from .config import OPENAI_API_KEY, OPENAI_BASE_URL


def transcribe_with_timestamps(file_path: str) -> Dict[str, Any]:
    if not OPENAI_API_KEY:
        raise RuntimeError("OPENAI_API_KEY not set")

    url = f"{OPENAI_BASE_URL}/audio/transcriptions"
    headers = {"Authorization": f"Bearer {OPENAI_API_KEY}"}
    files = {"file": open(file_path, "rb")}
    data = {
        "model": "whisper-1",
        "language": "ko",
        "response_format": "verbose_json",
        "timestamp_granularities[]": "word",
    }
    resp = requests.post(url, headers=headers, files=files, data=data, timeout=60)
    if resp.status_code < 200 or resp.status_code >= 300:
        raise RuntimeError(f"Transcription failed: {resp.status_code} {resp.text}")
    return resp.json()


def compute_metrics(words: Optional[List[Dict[str, Any]]], duration_ms: int) -> Dict[str, Any]:
    if not words or duration_ms <= 0:
        return {
            "wpm": 0,
            "pause_ratio": 0,
            "avg_pause_ms": 0,
            "utterance_count": 0,
            "avg_utterance_words": 0,
        }

    duration_sec = duration_ms / 1000.0
    word_count = len(words)

    total_pause = 0.0
    total_speech = 0.0
    prev_end: Optional[float] = None
    utterance_count = 1
    current_utterance_words = 0
    total_utterance_words = 0

    for w in words:
        start = float(w.get("start", 0))
        end = float(w.get("end", 0))
        if end <= start:
            continue
        total_speech += (end - start)
        current_utterance_words += 1

        if prev_end is not None:
            gap = max(0.0, start - prev_end)
            if gap > 0.8:
                utterance_count += 1
                total_utterance_words += current_utterance_words
                current_utterance_words = 0
            total_pause += gap
        prev_end = end

    total_utterance_words += current_utterance_words

    wpm = word_count / (duration_sec / 60.0) if duration_sec > 0 else 0
    pause_ratio = min(1.0, total_pause / duration_sec) if duration_sec > 0 else 0
    avg_pause_ms = int((total_pause / max(1, word_count - 1)) * 1000)
    avg_utterance_words = total_utterance_words / max(1, utterance_count)

    return {
        "wpm": round(wpm, 1),
        "pause_ratio": round(pause_ratio, 2),
        "avg_pause_ms": avg_pause_ms,
        "utterance_count": utterance_count,
        "avg_utterance_words": round(avg_utterance_words, 1),
    }


def build_emotion_estimate(metrics: Dict[str, Any], summary_text: str = "", keywords: Optional[List[str]] = None) -> Dict[str, Any]:
    avg_wpm = metrics.get("wpm", 0)
    pause_ratio = metrics.get("pause_ratio", 0)

    label = "neutral"
    confidence = 0.4
    note = "경향: 뚜렷한 편차 신호는 제한적."

    if (avg_wpm >= 150 and pause_ratio >= 0.2) or (avg_wpm < 95 and pause_ratio >= 0.25):
        label = "tension_fatigue"
        confidence = 0.6
        note = "경향: 긴장/피로 신호 동시 관측 가능."
    elif avg_wpm < 95 and pause_ratio < 0.1:
        label = "low_activation"
        confidence = 0.55
        note = "경향: 저활성/차분 상태 가능."
    elif avg_wpm >= 150 and pause_ratio < 0.1:
        label = "high_activation"
        confidence = 0.55
        note = "경향: 고활성/집중 상태 가능."

    if keywords:
        note += f" 키워드: {', '.join(keywords[:3])}"

    if summary_text:
        note += f" 요약: {summary_text}"

    return {"label": label, "confidence": confidence, "note": note}


def try_summarize_text(text: str) -> Optional[Dict[str, Any]]:
    if not OPENAI_API_KEY or not text.strip():
        return None
    url = f"{OPENAI_BASE_URL}/chat/completions"
    headers = {
        "Authorization": f"Bearer {OPENAI_API_KEY}",
        "Content-Type": "application/json",
    }
    payload = {
        "model": "gpt-4o-mini",
        "messages": [
            {"role": "system", "content": "Return only valid JSON. All strings must be in Korean."},
            {
                "role": "user",
                "content": (
                    "아래 대화를 요약하고 감정 키워드를 추출하세요. 출력은 JSON만.\n\n"
                    f"대화:\n{text}\n\n"
                    "출력 형식:\n"
                    '{ "summary": "2~3문장 요약", "keywords": ["키워드1","키워드2","키워드3"] }'
                ),
            },
        ],
        "temperature": 0.2,
        "response_format": {"type": "json_object"},
    }
    resp = requests.post(url, headers=headers, data=json.dumps(payload), timeout=60)
    if resp.status_code < 200 or resp.status_code >= 300:
        return None
    data = resp.json()
    content = data["choices"][0]["message"]["content"]
    try:
        return json.loads(content)
    except Exception:
        return None
