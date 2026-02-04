import 'dart:convert';
import 'dart:io'; 
import 'package:google_generative_ai/google_generative_ai.dart';
import '../models/mission_model.dart';
import '../services/storage_service.dart'; 

class AIService {
  // ⚠️ [보안 주의] 실제 배포 시에는 API Key를 서버에서 관리하거나 .env 파일을 사용하세요.
  static const String _apiKey = "AIzaSyB3w8463q2SnEnb2S5bgNRl8FA5s-2nfao"; 

  // 1️⃣ [JSON 모드] - 구조화된 데이터 반환용 (사진 분석, 보너스 미션)
  final GenerativeModel _jsonModel = GenerativeModel(
    model: 'gemini-flash-latest', // 최신 모델명 사용 권장
    apiKey: _apiKey,
    generationConfig: GenerationConfig(
      responseMimeType: 'application/json',
    ),
  );

  // 2️⃣ [텍스트 모드] - 자연스러운 대화용 (데일리 미션, 상담)
  final GenerativeModel _chatModel = GenerativeModel(
    model: 'gemini-flash-latest',
    apiKey: _apiKey,
  );

  // =========================================================
  // 🕵️‍♂️ [내부 함수] 유저 정보 로드 (Grade 포함)
  // =========================================================
  Future<Map<String, dynamic>> _loadUserContext() async {
    final userProfile = await StorageService.getUserProfile();

    if (userProfile == null) {
      return {
        'nickname': '여행자',
        'level': 1,
        'grade': 'C', // 기본값
      };
    }
    return userProfile; 
  }

  // =========================================================
  // 🎯 1. 데일리 미션 생성 (위치 & 날씨 반영 🌧️☀️)
  // =========================================================
  // 📌 MainScreen에서 넘겨준 locationName과 weatherCondition을 받습니다.
  Future<String> generateDailyMission(String locationName, String weatherCondition) async {
    
    // 1. 유저 정보 로드 (닉네임, 등급)
    final userContext = await _loadUserContext();
    final String nickname = userContext['nickname'];
    final String grade = userContext['grade']; 
    final int level = userContext['level'];

    // 2. 등급별 페르소나 (말투 및 행동 반경 제한)
    String personaGuide = "";
    
    switch (grade) {
      case 'D': // 🚑 은둔기 (실내, 안정)
        personaGuide = """
        Target: Mental stability & Rest.
        Space: Strictly Bedroom/Indoor only.
        Interaction: Passive (Listening, Breathing).
        Tone: Very gentle, motherly, protective.
        Warning: NEVER suggest going outside. Even if weather is good, suggest opening a window at most.
        """;
        break;
      case 'C': // 🌱 회복기 (집안 생활)
        personaGuide = """
        Target: Small domestic routine.
        Space: Living room, Kitchen.
        Interaction: Light activity (Cooking, Watering plants).
        Tone: Warm, encouraging friend.
        """;
        break;
      case 'B': // 🌿 적응기 (집 근처)
        personaGuide = """
        Target: Light outdoor connection.
        Space: Front of house, Convenience store.
        Interaction: Observation, Walking.
        Tone: Cheerful, slightly challenging.
        """;
        break;
      case 'A': // 🌟 졸업반 (외부 활동)
        personaGuide = """
        Target: Self-growth & Socializing.
        Space: Cafe, Park, Library.
        Interaction: Active, Planning.
        Tone: Witty, Professional Life Coach.
        """;
        break;
    }

    // 3. 🚀 [핵심 프롬프트] 위치와 날씨 정보를 포함하여 구체적 지시
    final prompt = '''
      [Context]
      - User: $nickname (Level $level)
      - Current Location: $locationName
      - Current Weather: $weatherCondition
      - User Grade: $grade

      [Persona Guide]
      $personaGuide

      [Task]
      Generate ONE simple daily mission based on the **Current Weather** and **Grade**.
      
      [Weather Logic]
      - If Rain/Storm: Suggest listening to rain, warm tea, or cozy indoor activity.
      - If Sunny: Suggest sunlight exposure, shadow play, or walking (depending on Grade).
      - If Night: Suggest moonlight, reflection, or sleep preparation.
      - If Snow: Suggest watching snow, warm blanket.

      [Output Rules]
      1. Output ONLY the instruction text in Korean.
      2. No titles, no explanations.
      3. Length: 1-2 sentences.
      4. Tone: Soft conversational Korean (해요체).
    ''';

    try {
      final content = [Content.text(prompt)];
      
      // 실제 API 호출
      final response = await _chatModel.generateContent(content);
      
      // 결과 정제 (특수문자 제거)
      return response.text?.replaceAll(RegExp(r'[*"`]'), '').trim() ?? "$locationName의 날씨를 느끼며 물 한 잔 마셔요.";
    } catch (e) {
      print("❌ 미션 생성 API 에러: $e");
      return "오늘은 잠시 창문을 열고 바람을 느껴보세요."; // 통신 실패 시 기본 미션
    }
  }

  // =========================================================
  // 📸 2. 사진 인증 (피드백 톤 매너 조정)
  // =========================================================
  Future<Map<String, dynamic>?> verifyMissionImage({
    required File imageFile,
    required String missionTitle,
  }) async {
    final userContext = await _loadUserContext();
    final String grade = userContext['grade'];

    final prompt = '''
      User (Grade $grade) submitted a photo for mission: "$missionTitle".
      
      1. Analyze the image. Is it somewhat relevant to "$missionTitle"? (Be generous).
      2. Provide feedback in Korean:
         - Grade D/C: Warm praise. "Just trying is enough."
         - Grade B/A: Enthusiastic praise. "Great quality!"
      
      Output JSON format:
      {
        "is_success": true,
        "feedback": "Your Korean feedback here"
      }
    ''';

    try {
      final imageBytes = await imageFile.readAsBytes();
      final content = [
        Content.multi([
          TextPart(prompt),
          DataPart('image/jpeg', imageBytes), 
        ])
      ];

      final response = await _jsonModel.generateContent(content); 
      String? text = response.text;
      
      if (text == null) return null;

      // JSON 파싱 전처리
      text = text.replaceAll('```json', '').replaceAll('```', '').trim();
      return jsonDecode(text);
    } catch (e) {
      print("❌ 이미지 분석 에러: $e");
      // 에러 나도 유저를 실망시키지 않기 위해 성공 처리
      return {
        "is_success": true,
        "feedback": "사진 전송 감사합니다! 오늘도 한 걸음 나아가셨네요. ✨ (분석 지연)"
      };
    }
  }

  // =========================================================
  // 🎁 3. 보너스 미션 (등급별 난이도 적용)
  // =========================================================
  Future<MissionModel?> getBonusMission() async {
    final userContext = await _loadUserContext();
    final String grade = userContext['grade'];
    
    // 난이도 설정
    String constraint = (grade == 'A' || grade == 'B') 
        ? "Active or Outdoor small task." 
        : "Relaxing Indoor mindfulness task.";

    final prompt = '''
      User Grade: $grade.
      Suggest ONE 'Bonus Mission'.
      Constraint: $constraint
      
      Output JSON format:
      {
        "mission_title": "Short Title (Korean)",
        "mission_content": "Instruction (Korean)",
        "type": "text/photo/hold", 
        "xp": ${grade == 'A' ? 50 : 30},
        "difficulty": "$grade", 
        "comment": "Cheering message (Korean)"
      }
    ''';

    try {
      final content = [Content.text(prompt)];
      final response = await _jsonModel.generateContent(content); 
      
      String? text = response.text;
      if (text == null) return null;

      text = text.replaceAll('```json', '').replaceAll('```', '').trim();
      final jsonMap = jsonDecode(text);
      
      return MissionModel(
        title: jsonMap['mission_title'] ?? "보너스 미션",
        content: jsonMap['mission_content'] ?? "잠시 눈을 감고 쉬세요.",
        type: _parseMissionType(jsonMap['type']),
        xp: jsonMap['xp'] is int ? jsonMap['xp'] : 30,
        difficulty: jsonMap['difficulty'] ?? grade,
        message: jsonMap['comment'] ?? "참 잘했어요!",
      );

    } catch (e) {
      return null; 
    }
  }

  // =========================================================
  // 💬 4. AI 상담 (Grade 반영)
  // =========================================================
  Future<String> chatWithCounselor(String userMessage) async {
    final userContext = await _loadUserContext();
    final String nickname = userContext['nickname'];
    final String grade = userContext['grade'];

    // 페르소나 설정
    String systemInstruction = "";
    if (grade == 'D') {
      systemInstruction = "Role: Empathetic Listener. User is isolated. Be gentle, validate feelings, do NOT advise actions.";
    } else if (grade == 'A') {
      systemInstruction = "Role: Life Coach. User is active. Give constructive feedback and witty support.";
    } else {
      systemInstruction = "Role: Warm Friend. User is recovering. Be supportive.";
    }

    final prompt = '''
      [System]
      User: $nickname (Grade $grade)
      Persona: $systemInstruction
      Language: Korean (Natural conversation)
      
      User said: "$userMessage"
      Reply:
    ''';

    try {
      final content = [Content.text(prompt)];
      final response = await _chatModel.generateContent(content);
      return response.text?.trim() ?? "그렇군요, 이야기를 더 들려주세요.";
    } catch (e) {
      return "지금은 연결이 조금 불안정해요. 잠시 후 다시 말 걸어주세요.";
    }
  }

  // 🛠️ 헬퍼 함수
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