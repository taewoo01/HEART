import 'dart:convert';
import 'dart:io';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;

import '../models/mission_model.dart';
import '../services/storage_service.dart';

class AIService {
  static final String _apiKey = dotenv.env['OPENAI_API_KEY'] ?? "";
  static const String _baseUrl = "https://api.openai.com/v1";

  // 모델은 필요에 따라 바꿀 수 있습니다.
  static const String _chatModel = "gpt-4o-mini";
  static const String _visionModel = "gpt-4o-mini";
  static const String _transcribeModel = "gpt-4o-mini-transcribe";

  AIService() {
    if (_apiKey.isEmpty) {
      print("⚠️ [AIService] OPENAI_API_KEY가 없습니다. .env 파일을 확인해주세요.");
    }
  }

  // =========================================================
  // 🕵️‍♂️ 유저 정보 로드
  // =========================================================
  Future<Map<String, dynamic>> _loadUserContext() async {
    final userProfile = await StorageService.getUserProfile();
    if (userProfile == null) {
      return {
        'nickname': '여행자',
        'level': 1,
        'grade': 'C',
        'per_soc': 50,
        'per_iso': 50,
        'per_emo': 50,
        'chat_summary': '',
        'chat_keywords': <String>[],
      };
    }
    return userProfile;
  }

  // =========================================================
  // 🎙️ 음성 채팅 처리 (텍스트 우선 + 오디오 전사 백업)
  // =========================================================
  Future<String> processVoiceChat({
    File? audioFile,
    required String userText,
    List<Map<String, String>>? chatHistory,
  }) async {
    final userContext = await _loadUserContext();
    final String nickname = userContext['nickname'];
    final String grade = userContext['grade'];
    final int perSoc = userContext['per_soc'] ?? 50;
    final int perIso = userContext['per_iso'] ?? 50;
    final int perEmo = userContext['per_emo'] ?? 50;
    final String chatSummary = (userContext['chat_summary'] ?? '').toString();
    final List<dynamic> chatKeywordsRaw = userContext['chat_keywords'] ?? <dynamic>[];
    final String chatKeywords = chatKeywordsRaw.isNotEmpty ? chatKeywordsRaw.join(', ') : '';

    if (audioFile != null) {
      _sendToAnalysisModel(audioFile, grade);
    }

    String personaGuide = _getPersonaByGrade(grade);
    bool isTextValid = userText.isNotEmpty && userText != "(음성 메시지)";

    try {
      String finalText = userText;

      if (!isTextValid) {
        if (audioFile == null || !await audioFile.exists()) {
          return "목소리는 잘 들었는데, 뭐라고 대답해야 할지 고민되네요.";
        }
        // STT 실패 → OpenAI 전사 API 사용
        finalText = await transcribeAudio(audioFile);
      }

      if (finalText.trim().isEmpty) {
        return "목소리는 잘 들었는데, 뭐라고 대답해야 할지 고민되네요.";
      }

      final systemPrompt = '''
너는 사용자의 친구 같은 말투로 대화하는 따뜻한 AI 상담자다.
반드시 한국어, 해요체. 짧고 자연스럽게 1~3문장.
공감 1문장 + 필요하면 부드러운 질문 1개.
사용자를 심문하지 말고, 부담을 줄이는 질문으로 현재 상태를 파악한다.
과장된 조언, 진단, 명령은 피한다.
''';

      final contextPrompt = '''
User: $nickname (Grade $grade)
Persona: $personaGuide
HQ-25: Soc ${perSoc}%, Iso ${perIso}%, Emo ${perEmo}%
Previous Summary: ${chatSummary.isEmpty ? "없음" : chatSummary}
Emotion Keywords: ${chatKeywords.isEmpty ? "없음" : chatKeywords}
''';

      final messages = <Map<String, dynamic>>[
        {"role": "system", "content": systemPrompt},
        {"role": "system", "content": contextPrompt},
      ];

      if (chatHistory != null && chatHistory.isNotEmpty) {
        for (final msg in chatHistory.take(12)) {
          final role = msg['role'] == 'user' ? 'user' : 'assistant';
          final text = msg['text'] ?? '';
          if (text.isNotEmpty) {
            messages.add({"role": role, "content": text});
          }
        }
      } else {
        messages.add({"role": "user", "content": finalText});
      }

      final response = await _chatCompletion(
        model: _chatModel,
        messages: messages,
        temperature: 0.8,
      );

      return response.isNotEmpty ? response : "네, 이야기 잘 듣고 있어요.";
    } catch (e) {
      print("❌ OpenAI 처리 에러: $e");
      return "죄송해요, 통신 상태가 좋지 않아 답변을 가져오지 못했어요.";
    }
  }

  // =========================================================
  // 🔬 분석 모델 Stub
  // =========================================================
  Future<void> _sendToAnalysisModel(File audioFile, String grade) async {
    try {
      await Future.delayed(const Duration(milliseconds: 500));
    } catch (e) {
      print("⚠️ 분석 모델 전송 실패: $e");
    }
  }

  // =========================================================
  // 🎯 데일리 미션 생성 (HQ-25 기반)
  // =========================================================
  Future<Map<String, dynamic>> generateDailyMission(String locationName, String weatherCondition) async {
    final userContext = await _loadUserContext();
    final String nickname = userContext['nickname'];
    final String grade = userContext['grade'];
    final int level = userContext['level'];
    final int perSoc = userContext['per_soc'] ?? 50;
    final int perIso = userContext['per_iso'] ?? 50;
    final int perEmo = userContext['per_emo'] ?? 50;

    final String riskSoc = _riskLabel(perSoc);
    final String riskIso = _riskLabel(perIso);
    final String riskEmo = _riskLabel(perEmo);

    final now = DateTime.now();
    final timeNow = "${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')} "
        "${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}";

    final targetRange = _targetRangeByGrade(grade);
    final mood = _inferMood(perSoc, perIso, perEmo);
    final allowedTypes = _allowedTypesByGrade(grade);
    final xpRange = _xpRangeByGrade(grade);
    final recentMissions = await StorageService.getRecentMissions();
    final recentText = recentMissions.isEmpty
        ? "없음"
        : recentMissions.map((e) => "- $e").join("\n");

    final prompt = '''
### 1. System Persona
너는 은둔형 외톨이 재활을 위한 '임상 심리 기반 AI 코치'다.
사용자의  HQ-25 3대 요인(대인기피, 고립, 정서) 을 분석하여,
단순히 '밖에 나가라'는 식이 아닌,  사용자의 심리적 방어기제를 우회하는 정교한 퀘스트 를 설계하라.

### 2. User Profile
-  Level:  Lv.$level
-  Physical Constraint:  반드시  [$targetRange]  범위 내에서 행동해야 함.
-  Environment:  $weatherCondition, $timeNow
-  Mood:  $mood

### 2-1. Constraints
- Grade $grade 사용자는 외출/구매/요리/준비물이 필요한 미션은 피한다.
- "편의점에 가서", "재료를 사서", "요리하기" 같은 지시를 금지한다.
- 집 안에서 5~10분 내에 수행 가능한 행동만 제안한다.

### 2-2. Recent Missions (avoid repetition)
$recentText
같은 미션은 반복하지 말고, 의미만 비슷해도 표현을 바꿔 다른 미션처럼 보이게 하라.

### 3. HQ-25 Factor Analysis (정밀 진단)
각 요인의 점수(%)에 따라 심각도를 판단하라.
1.  대인기피(Socialization):  $perSoc% ->  $riskSoc
2.  물리적 고립(Isolation):  $perIso% ->  $riskIso
3.  정서적 결핍(Emotional):  $perEmo% ->  $riskEmo

### 4. Quest Strategy Matrix (매뉴얼 엄수)

 [A. 심각도 기준 (Severity Thresholds)]
-  High (≥60%):  해당 요인의 직접 노출을 극도로 꺼림.  우회 전략  필수.
-  Mid (30~59%):  약간의 불편함.  점진적 노출  가능.
-  Low (<30%):  해당 요인은 자원(Resource)으로 활용 가능.

 [B. 단일 요인별 공략 가이드 (High일 경우)]
-  Socialization High:  '사람'을 제거하라. (새벽 시간, 무인 점포, 이어폰 끼고 외출)
-  Isolation High:  '장소'를 바꿔라. (방 안에서 1cm라도 밖으로 이동, 문지방 넘기)
-  Emotional High:  '위로'를 투입하라. (나를 위한 선물, 따뜻한 음료, 애착 인형, 식물)

 [C. 복합 요인 교차 전략 (Intersection Strategy)]
두 개 이상의 요인이 High일 경우 아래 전략을 우선 적용하라.

1. Soc(High) + Iso(High) -> "투명인간 전략"
   - 목표: 외출은 하되(Iso 해결), 사람은 마주치지 않는다(Soc 보호).
   - 예시: "모두가 잠든 새벽 5시에 아파트 복도 걷기", "비 오는 날 우산으로 얼굴 가리고 벤치 찍고 오기".

2. Soc(High) + Emo(High) -> "비대면 연결 전략"
   - 목표: 사람과 소통하고 싶지만(Emo), 만나는 건 무섭다(Soc).
   - 예시: "라디오 DJ에게 익명 사연 보내기", "온라인 커뮤니티에 '파이팅' 댓글 하나 달기", "편의점 알바생에게 눈인사만 하고 오기".

3. Iso(High) + Emo(High) -> "공간의 온기 전략"
   - 목표: 고립된 공간(Iso)을 나를 위한 공간(Emo)으로 재정의하거나 확장.
   - 예시: "거실로 나가서 내가 제일 좋아하는 컵에 코코아 타 마시기", "현관 앞에 나를 응원하는 포스트잇 붙이기".

4. All High (Crisis) -> "생존 호흡 전략"
   - 목표: 아무것도 할 수 없는 상태. 아주 작은 생존 신호만 확인.
   - 예시: "창문 1cm만 열고 바깥 공기 3초 마시기", "이불 속에서 가장 편한 자세 찾기".

### 5. Task
위 분석과 전략을 바탕으로 사용자가  지금 당장  수행할 수 있는 퀘스트 1개를 생성하라.

### 6. Output Format (JSON Only)
{
  "strategy_name": "적용한 전략 이름",
  "mission_title": "제목 (감성적)",
  "mission_guide": "행동 지침 (구체적이고 친절하게)",
  "mission_type": "반드시 허용된 타입 중 하나: ${allowedTypes.join('/')}",
  "voice_script": "AI 코칭 메시지",
  "vision_object": "인증 사물 (단어 1개)",
  "xp_reward": ${xpRange.$1}~${xpRange.$2} 사이의 숫자,
  "reasoning": "왜 이 전략을 선택했는지"
}
''';

    try {
      final response = await _chatCompletion(
        model: _chatModel,
        messages: [
          {"role": "system", "content": "Return only valid JSON. All strings must be in Korean."},
          {"role": "user", "content": prompt}
        ],
        temperature: 0.7,
        responseFormat: {"type": "json_object"},
      );
      final jsonMap = _extractJson(response);
      if (jsonMap == null) {
        return {
          "mission_title": "오늘의 작은 시작",
          "mission_guide": "$locationName의 날씨를 느끼며 쉬어보세요.",
          "xp_reward": _xpByGrade(grade),
        };
      }
      print("🧠 [AIService] DailyMission JSON: $jsonMap");

      final title = (jsonMap['mission_title'] ?? "오늘의 작은 시작").toString().trim();
      final guide = (jsonMap['mission_guide'] ?? "").toString().trim();
      final xp = _clampXp(_parseXp(jsonMap['xp_reward'], grade), grade);
      final strategyName = (jsonMap['strategy_name'] ?? "").toString().trim();
      final reasoning = (jsonMap['reasoning'] ?? "").toString().trim();
      final visionObject = (jsonMap['vision_object'] ?? "").toString().trim();
      final missionType = _normalizeMissionType(
        (jsonMap['mission_type'] ?? "").toString().trim(),
        grade,
      );

      return {
        "mission_title": title.isNotEmpty ? title : "오늘의 작은 시작",
        "mission_guide": guide.isNotEmpty ? guide : "$locationName의 날씨를 느끼며 쉬어보세요.",
        "xp_reward": xp,
        "strategy_name": strategyName,
        "reasoning": reasoning,
        "vision_object": visionObject,
        "mission_type": missionType,
      };
    } catch (e) {
      print("❌ 미션 에러: $e");
      return {
        "mission_title": "오늘은 쉬어가기",
        "mission_guide": "오늘은 편안하게 쉬는 날로 해요.",
        "xp_reward": _xpByGrade(grade),
      };
    }
  }

  // =========================================================
  // 🧠 온보딩 설문 분석 (AI 분류)
  // =========================================================
  Future<Map<String, dynamic>?> analyzeSurveyGrade({
    required String nickname,
    required String location,
    required String surveyData,
  }) async {
    final prompt = '''
당신은 전문 심리 상담가입니다.
[사용자 정보] 닉네임: $nickname, 지역: $location
[설문 데이터]
$surveyData

[임무]
1) HQ-25의 3요인(대인기피/고립/정서)에 대해 각각 0~100% 점수를 추정하세요.
2) 아래 기준으로 Grade를 판단하세요.
   - A: 매우 건강하고 활발함
   - B: 양호함, 일상생활 원만
   - C: 다소 위축됨, 관심 필요
   - D: 고립 위험, 적극적 케어 필요
3) 결과를 JSON으로만 출력하세요.

출력 형식(JSON only):
{
  "per_soc": 0,
  "per_iso": 0,
  "per_emo": 0,
  "grade": "C",
  "score": 65,
  "message": "따뜻한 한마디(2문장)",
  "reasoning": "왜 이 등급인지 근거 2~3문장"
}
''';

    try {
      final response = await _chatCompletion(
        model: _chatModel,
        messages: [
          {"role": "system", "content": "Return only valid JSON."},
          {"role": "user", "content": prompt},
        ],
        temperature: 0.3,
        responseFormat: {"type": "json_object"},
      );

      final jsonMap = _extractJson(response);
      if (jsonMap != null) {
        print("🧠 [AIService] Survey JSON: $jsonMap");
      }
      return jsonMap;
    } catch (e) {
      print("❌ 설문 분석 에러: $e");
      return null;
    }
  }

  // =========================================================
  // 💬 대화 요약/감정 키워드
  // =========================================================
  Future<Map<String, dynamic>?> summarizeChat(List<Map<String, String>> chatHistory) async {
    final messagesText = chatHistory
        .where((m) => (m['text'] ?? '').isNotEmpty)
        .map((m) => "${m['role']}: ${m['text']}")
        .join("\n");

    if (messagesText.trim().isEmpty) return null;

    final prompt = '''
아래 대화를 요약하고 감정 키워드를 추출하세요.
출력은 JSON만.

대화:
$messagesText

출력 형식:
{
  "summary": "2~3문장 요약",
  "keywords": ["키워드1","키워드2","키워드3"]
}
''';

    try {
      final response = await _chatCompletion(
        model: _chatModel,
        messages: [
          {"role": "system", "content": "Return only valid JSON. All strings must be in Korean."},
          {"role": "user", "content": prompt},
        ],
        temperature: 0.2,
        responseFormat: {"type": "json_object"},
      );

      final jsonMap = _extractJson(response);
      if (jsonMap != null) {
        print("🧠 [AIService] Chat Summary JSON: $jsonMap");
      }
      return jsonMap;
    } catch (e) {
      print("❌ 대화 요약 에러: $e");
      return null;
    }
  }

  // =========================================================
  // 📸 사진 인증
  // =========================================================
  Future<Map<String, dynamic>?> verifyMissionImage({required File imageFile, required String missionTitle}) async {
    final userContext = await _loadUserContext();
    final String grade = userContext['grade'];

    final prompt = '''
    User (Grade $grade) submitted photo for: "$missionTitle".
    1. Is it relevant? (Be generous).
    2. Feedback in Korean (Grade D/C: Warm praise, B/A: Enthusiastic).
    Output JSON ONLY: {"is_success": true, "feedback": "Korean text"}
    ''';

    try {
      final bytes = await imageFile.readAsBytes();
      final b64 = base64Encode(bytes);
      final dataUrl = "data:image/jpeg;base64,$b64";

      final response = await _chatCompletion(
        model: _visionModel,
        messages: [
          {"role": "system", "content": "You are a strict JSON generator."},
          {
            "role": "user",
            "content": [
              {"type": "text", "text": prompt},
              {"type": "image_url", "image_url": {"url": dataUrl}}
            ]
          }
        ],
        temperature: 0.2,
      );

      return _extractJson(response);
    } catch (e) {
      print("❌ 이미지 분석 에러: $e");
      return {"is_success": true, "feedback": "사진 감사합니다! (분석 지연)"};
    }
  }

  // =========================================================
  // 🎁 보너스 미션
  // =========================================================
  Future<MissionModel?> getBonusMission() async {
    final userContext = await _loadUserContext();
    final String grade = userContext['grade'];
    final allowedTypes = _allowedTypesByGrade(grade);
    final xpRange = _xpRangeByGrade(grade);
    final recentMissions = await StorageService.getRecentMissions();
    final recentText = recentMissions.isEmpty
        ? "없음"
        : recentMissions.map((e) => "- $e").join("\n");
    
    final prompt = '''
    User Grade: $grade. Suggest ONE 'Bonus Mission'.
    All values must be in Korean (Korean-only strings).
    Constraints:
    - Grade $grade 사용자는 외출/구매/요리/준비물이 필요한 미션은 피한다.
    - "편의점에 가서", "재료를 사서", "요리하기" 같은 지시를 금지한다.
    - 집 안에서 5~10분 내에 수행 가능한 행동만 제안한다.
    - mission_type은 반드시 허용된 타입 중 하나: ${allowedTypes.join('/')}
    - xp는 ${xpRange.$1}~${xpRange.$2} 사이 숫자

    Recent Missions (avoid repetition):
    $recentText
    같은 미션은 반복하지 말고, 의미만 비슷해도 표현을 바꿔 다른 미션처럼 보이게 하라.

    Output JSON ONLY:
    {"mission_title": "Korean", "mission_content": "Korean", "type": "${allowedTypes.join('/')}", "xp": ${xpRange.$1}, "difficulty": "$grade", "comment": "Korean"}
    ''';

    try {
      final response = await _chatCompletion(
        model: _chatModel,
        messages: [
          {"role": "system", "content": "Return only valid JSON."},
          {"role": "user", "content": prompt}
        ],
        temperature: 0.2,
        responseFormat: {"type": "json_object"},
      );

      final jsonMap = _extractJson(response);
      if (jsonMap == null) return null;

      String title = jsonMap['mission_title'] ?? "보너스 미션";
      String content = jsonMap['mission_content'] ?? "쉬어가기";
      String comment = jsonMap['comment'] ?? "화이팅!";

      // 안전장치: 한국어가 거의 없으면 기본값 사용
      if (!_hasHangul(title)) title = "보너스 미션";
      if (!_hasHangul(content)) content = "쉬어가기";
      if (!_hasHangul(comment)) comment = "화이팅!";
      final String typeStr = (jsonMap['type'] ?? "").toString().trim();
      final String normalizedType = _normalizeMissionType(typeStr, grade);
      final int xp = _clampXp(_parseXp(jsonMap['xp'], grade), grade);

      return MissionModel(
        title: title,
        content: content,
        type: _parseMissionType(normalizedType),
        xp: xp,
        difficulty: jsonMap['difficulty'] ?? grade,
        message: comment,
      );
    } catch (e) {
      return null;
    }
  }

  // =========================================================
  // 💬 일반 텍스트 상담
  // =========================================================
  Future<String> chatWithCounselor(String userMessage) async {
    final userContext = await _loadUserContext();
    final String grade = userContext['grade'];

    final prompt = '''
    User (Grade $grade).
    Persona: ${_getPersonaByGrade(grade)}
    User said: "$userMessage"
    Reply in Korean (Natural conversation).
    ''';

    try {
      final response = await _chatCompletion(
        model: _chatModel,
        messages: [
          {"role": "system", "content": "You are a warm Korean counselor."},
          {"role": "user", "content": prompt}
        ],
        temperature: 0.7,
      );
      return response.trim().isNotEmpty ? response.trim() : "이야기를 잘 듣고 있어요.";
    } catch (e) {
      return "잠시 연결이 불안정해요.";
    }
  }

  // =========================================================
  // 내부 헬퍼들
  // =========================================================
  Future<String> _chatCompletion({
    required String model,
    required List<Map<String, dynamic>> messages,
    double temperature = 0.7,
    int? maxTokens,
    Map<String, dynamic>? responseFormat,
  }) async {
    final body = <String, dynamic>{
      "model": model,
      "messages": messages,
      "temperature": temperature,
    };
    if (maxTokens != null) {
      body["max_tokens"] = maxTokens;
    }
    if (responseFormat != null) {
      body["response_format"] = responseFormat;
    }

    final data = await _postJson("/chat/completions", body);
    final choices = data["choices"] as List<dynamic>;
    if (choices.isEmpty) return "";

    final message = choices.first["message"];
    final content = message["content"];

    if (content is String) return content.trim();
    if (content is List) {
      final buffer = StringBuffer();
      for (final part in content) {
        if (part is Map && part["type"] == "text") {
          buffer.write(part["text"]);
        }
      }
      return buffer.toString().trim();
    }
    return "";
  }

  Future<String> _transcribeAudio(File audioFile) async {
    final uri = Uri.parse("$_baseUrl/audio/transcriptions");
    final request = http.MultipartRequest("POST", uri)
      ..headers["Authorization"] = "Bearer $_apiKey"
      ..fields["model"] = _transcribeModel
      ..fields["language"] = "ko"
      ..fields["response_format"] = "json"
      ..files.add(await http.MultipartFile.fromPath("file", audioFile.path));

    final streamed = await request.send();
    final response = await http.Response.fromStream(streamed);

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception("Transcription failed: ${response.statusCode} ${response.body}");
    }

    final jsonMap = jsonDecode(response.body) as Map<String, dynamic>;
    return (jsonMap["text"] ?? "").toString().trim();
  }

  Future<Map<String, dynamic>> _postJson(String path, Map<String, dynamic> body) async {
    final uri = Uri.parse("$_baseUrl$path");
    final response = await http.post(
      uri,
      headers: {
        "Authorization": "Bearer $_apiKey",
        "Content-Type": "application/json",
      },
      body: jsonEncode(body),
    );

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception("OpenAI error: ${response.statusCode} ${response.body}");
    }
    return jsonDecode(response.body) as Map<String, dynamic>;
  }

  Map<String, dynamic>? _extractJson(String text) {
    try {
      final trimmed = text.trim();
      if (trimmed.startsWith("{") && trimmed.endsWith("}")) {
        return jsonDecode(trimmed);
      }
      final start = trimmed.indexOf("{");
      final end = trimmed.lastIndexOf("}");
      if (start != -1 && end != -1 && end > start) {
        return jsonDecode(trimmed.substring(start, end + 1));
      }
    } catch (_) {}
    return null;
  }

  bool _hasHangul(String text) {
    return RegExp(r'[가-힣]').hasMatch(text);
  }

  // 외부에서 전사만 필요할 때 사용
  Future<String> transcribeAudio(File audioFile) async {
    return _transcribeAudio(audioFile);
  }

  int _xpByGrade(String grade) {
    switch (grade) {
      case 'D': return 30;
      case 'C': return 50;
      case 'B': return 70;
      case 'A': return 90;
      default: return 60;
    }
  }

  int _parseXp(dynamic value, String grade) {
    if (value is int) return value;
    if (value is String) {
      final parsed = int.tryParse(value);
      if (parsed != null) return parsed;
    }
    return _xpByGrade(grade);
  }

  String _riskLabel(int per) {
    if (per >= 60) return "High";
    if (per >= 30) return "Mid";
    return "Low";
  }

  String _targetRangeByGrade(String grade) {
    switch (grade) {
      case 'D': return "방 안/문 앞";
      case 'C': return "집 안/현관 앞";
      case 'B': return "집 주변/동네";
      case 'A': return "동네/가까운 공원";
      default: return "현재 위치 주변";
    }
  }

  String _inferMood(int perSoc, int perIso, int perEmo) {
    final maxPer = [perSoc, perIso, perEmo].reduce((a, b) => a > b ? a : b);
    if (maxPer >= 70) return "매우 예민하고 조심스러움";
    if (maxPer >= 50) return "조심스럽고 긴장됨";
    return "비교적 안정적";
  }

  List<String> _allowedTypesByGrade(String grade) {
    switch (grade) {
      case 'D':
        return ['hold', 'text'];
      case 'C':
        return ['photo', 'text', 'hold'];
      case 'B':
        return ['step', 'photo', 'text'];
      case 'A':
        return ['text', 'photo', 'voice', 'step'];
      default:
        return ['text', 'photo'];
    }
  }

  (int, int) _xpRangeByGrade(String grade) {
    switch (grade) {
      case 'D':
        return (20, 40);
      case 'C':
        return (35, 60);
      case 'B':
        return (55, 85);
      case 'A':
        return (70, 110);
      default:
        return (40, 70);
    }
  }

  int _clampXp(int xp, String grade) {
    final range = _xpRangeByGrade(grade);
    if (xp < range.$1) return range.$1;
    if (xp > range.$2) return range.$2;
    return xp;
  }

  String _normalizeMissionType(String type, String grade) {
    final allowed = _allowedTypesByGrade(grade);
    if (allowed.contains(type.toLowerCase())) return type.toLowerCase();
    return allowed.first;
  }

  String _getPersonaByGrade(String grade) {
    switch (grade) {
      case 'D': return "Role: Gentle Caregiver. Tone: Very soft, slow, protective. Focus on stability.";
      case 'C': return "Role: Kind Friend. Tone: Warm, encouraging. Focus on small daily joys.";
      case 'B': return "Role: Cheerful Companion. Tone: Bright, slightly energetic. Focus on going outside.";
      case 'A': return "Role: Life Coach. Tone: Professional, witty, motivating. Focus on growth.";
      default: return "Role: Warm Listener.";
    }
  }

  MissionType _parseMissionType(String? typeString) {
    switch (typeString?.toLowerCase()) {
      case 'photo': return MissionType.photo;
      case 'text': return MissionType.text;
      case 'voice': return MissionType.voice;
      case 'step': return MissionType.step;
      default: return MissionType.hold;
    }
  }
}
