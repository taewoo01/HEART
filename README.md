# ❤️ HEART – 마음 상담소

> **은둔형 외톨이의 사회 복귀를 위한 AI 디지털 케어 서비스**  
> *"감시가 아닌 응원, 강요가 아닌 성취, 수동적 보호가 아닌 능동적 성장"*

> 🏆 **Note:** 본 프로젝트는 **2025 경상국립대학교 RISE 사업단 [RISE-AI] 생성형 AI+X 활용 아이디어 경진대회** 출품작입니다.

---

## 📖 Project Overview (프로젝트 개요)

**HEART**는 사회적 고립 상태의 사용자가 **안전한 디지털 공간에서 작은 성취를 축적**하며 회복을 준비할 수 있도록 돕는 AI 케어 서비스입니다.

* **HQ‑25 기반 진단:** 설문을 통해 고립/정서/대인기피 요인을 정밀 분석
* **맞춤형 미션 제공:** 사용자 등급과 환경(위치·날씨·시간)에 맞는 행동 퀘스트
* **음성 상담 + 요약/키워드:** 대화 기록을 요약하고 감정 키워드 추출
* **음성 지표 기반 경향 추정:** Whisper‑1 전사 + 단어 타임스탬프 지표로 발화 속도, 멈춤 비율, 발화 길이 분포 계산
* **관리자 대시보드:** 다중 사용자 상태/리포트/음성 분석 결과 통합 확인

---

## 🛠️ Tech Stack (기술 스택)

### 📱 Frontend (Mobile App)

| 구분 | 기술 / 라이브러리 | 사용 목적 |
| :--- | :--- | :--- |
| Framework | Flutter | Android 앱 개발 |
| Language | Dart | UI 구성 및 비동기 로직 |
| Voice Rec | flutter_sound | 고품질 음성 녹음 |
| STT | OpenAI Whisper | 음성 전사 |
| TTS | flutter_tts | AI 응답 음성 출력 |
| Network | http | AI/서버 통신 |
| Storage | shared_preferences | 로컬 데이터 저장 |

### 🧠 AI Core (Intelligence)

| 구분 | 모델 / 기술 | 사용 목적 |
| :--- | :--- | :--- |
| LLM | OpenAI `gpt-4o-mini` | 설문 분석, 미션 생성, 상담 응답 |
| Transcription | OpenAI `whisper-1` | 전사 + 단어 타임스탬프 |
| Vision | OpenAI `gpt-4o-mini` | 미션 사진 인증 |
| Prompt | System Prompting | HQ‑25 기반 분석 및 가이드 |

### 🖥️ Server (Audio Analysis)

| 구분 | 기술 / 라이브러리 | 사용 목적 |
| :--- | :--- | :--- |
| Framework | FastAPI | 오디오 분석 서버 |
| Language | Python | 음성 분석 파이프라인 |
| Storage | SQLite | 분석 결과 저장 |
| API | OpenAI | 전사/요약/분석 |

---

## 📊 Key Features (핵심 기능)

### 1️⃣ 📋 HQ‑25 기반 초기 진단
* 설문 응답으로 **per_soc / per_iso / per_emo** 산출
* 결과로 **A~D 등급** 부여 및 난이도 설정

### 2️⃣ 🎙️ AI 음성 상담
* 녹음 → 전사 → 상담 응답 흐름
* 상담 대화 요약/키워드 저장
* 음성 지표(속도/멈춤/길이) 산출

### 3️⃣ 🌱 맞춤형 미션 생성
* 등급 + 환경 + 최근 미션 + 대화 요약 기반
* 전략/이유를 함께 제시

### 4️⃣ 📸 사진 인증 & 보상
* 미션 수행 후 사진 제출
* 비전 API로 검증하여 성공/실패 판정
* 성공 시 EXP 지급, 실패 시 난이도 하향 대체 퀘스트

### 5️⃣ 🧾 관리자 대시보드
* 다중 사용자 목록 + 상세 리포트
* 감정 추정(경향) + 서버 음성 분석 결과
* 음성 신호 요약/최근 녹음 파일 확인

---

## 🧪 Troubleshooting (개발 이슈 및 해결)

### 🚨 Android 마이크 리소스 충돌(STT + 녹음)
* **문제:** 실시간 인식과 녹음을 동시에 수행 시 충돌
* **해결:** 순차 처리 구조 적용  
  1) 발화 중 녹음  
  2) 녹음 종료 후 Whisper 전사  
  3) 텍스트 기반 상담 진행  

---

## 🚀 Development Environment Setup

### ✅ Prerequisites
* Flutter SDK 3.0+
* Dart SDK 3.0+
* OpenAI API Key
* Python 3.9+

### 📦 App Setup

1. 저장소 클론
```bash
git clone https://github.com/taewoo01/HEART.git
cd HEART
패키지 설치
bash

flutter pub get
.env 설정
env

OPENAI_API_KEY=sk-proj-your-api-key-here
AUDIO_ANALYSIS_BASE_URL=http://<PC_IP>:8000
앱 실행
bash

flutter run
🖥️ Server Setup (Audio Analysis)
bash

cd server
python -m venv .venv
source .venv/Scripts/activate   # Windows Git Bash 기준
pip install -r requirements.txt
export OPENAI_API_KEY=sk-proj-your-api-key-here
uvicorn app.main:app --host 0.0.0.0 --port 8000 --reload
📂 Project Structure
bash

HEART/
├── lib/
│   ├── main.dart
│   ├── screens/
│   │   ├── onboarding_screen.dart
│   │   ├── main_screen.dart
│   │   ├── natural_chat_screen.dart
│   │   ├── history_page.dart
│   │   ├── local_data_screen.dart
│   │   └── admin_dashboard_page.dart
│   ├── services/
│   │   ├── ai_service.dart
│   │   ├── audio_analysis_service.dart
│   │   └── storage_service.dart
│   └── models/
├── server/
│   ├── app/
│   ├── requirements.txt
│   └── README.md
├── assets/
├── .env
└── pubspec.yaml
👨‍💻 Team
Team: 이렇게 삽니다

Role	Name	Dept.	Contact
Team Leader	곽호영	전자공학부	khy05300@naver.com
Team Member	김태우	전자공학부	xodn9402@naver.com
"우리의 기술은 사용자를 통제하는 것이 아니라, 스스로 문을 열고 나갈 수 있도록 돕는 따뜻한 손길이 되는 것을 목표로 합니다."
