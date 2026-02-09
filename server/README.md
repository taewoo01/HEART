# Heart Audio Analysis Server (FastAPI)

로컬 개발용(안전한 기본값) 서버입니다.

## 구성
- DB: SQLite (`server/data/app.db`)
- 오디오 저장: 로컬 파일 (`server/data/audio/`)
- 분석: OpenAI Whisper-1 (단어 타임스탬프)
- 실시간 + 하루 1회 배치 (엔드포인트 제공)

## 실행
1. 가상환경 생성 후 의존성 설치
2. `OPENAI_API_KEY` 환경 변수 설정
3. 서버 실행

```bash
cd server
python -m venv .venv
source .venv/bin/activate  # Windows: .venv\Scripts\activate
pip install -r requirements.txt
export OPENAI_API_KEY=sk-...
uvicorn app.main:app --reload
```

## 엔드포인트
- `POST /v1/audio/analyze`
  - multipart form: `file`, `user_id`, `session_id`(optional)
- `GET /v1/audio/result/{analysis_id}`
- `POST /v1/batch/run`

