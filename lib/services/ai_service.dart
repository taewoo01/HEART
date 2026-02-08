import 'dart:convert';
import 'dart:io'; 
import 'package:flutter_dotenv/flutter_dotenv.dart'; // 👈 패키지 임포트 필수
import 'package:google_generative_ai/google_generative_ai.dart';
import '../models/mission_model.dart';
import '../services/storage_service.dart'; 

class AIService {
  // 🔐 [보안 적용] .env에서 키 가져오기
  // const 대신 final을 사용해야 합니다 (런타임에 값을 가져오기 때문)
  static final String _apiKey = dotenv.env['GEMINI_API_KEY'] ?? ""; 

  // 1️⃣ [JSON 모드]
  late final GenerativeModel _jsonModel;

  // 2️⃣ [텍스트/멀티모달 모드]
  late final GenerativeModel _chatModel;

  AIService() {
    // 키가 제대로 로드되었는지 확인 (디버깅용)
    if (_apiKey.isEmpty) {
      print("⚠️ [AIService] API Key가 없습니다. .env 파일을 확인해주세요.");
    }

    _jsonModel = GenerativeModel(
      model: 'gemini-flash-latest', // ⚠️ 안정적인 1.5 버전 사용 권장
      apiKey: _apiKey,
      generationConfig: GenerationConfig(
        responseMimeType: 'application/json',
      ),
    );

    _chatModel = GenerativeModel(
      model: 'gemini-flash-latest', // ⚠️ 안정적인 1.5 버전 사용 권장
      apiKey: _apiKey,
    );
  }

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
  // 🎙️ [NEW] 5. 음성 채팅 처리 (텍스트 우선 + 오디오 백업)
  // =========================================================
  Future<String> processVoiceChat({required File audioFile, required String userText}) async {
    final userContext = await _loadUserContext();
    final String nickname = userContext['nickname'];
    final String grade = userContext['grade'];
    
    // 분석 모델 전송 (비동기)
    _sendToAnalysisModel(audioFile, grade);

    String personaGuide = _getPersonaByGrade(grade);
    
    // 입력 상태 확인
    bool isTextValid = userText.isNotEmpty && userText != "(음성 메시지)";

    try {
      if (isTextValid) {
        // ✅ Case A: STT 성공 -> 텍스트로 질문
        print("🚀 [AI Service] 텍스트 모드로 전송: $userText");

        final prompt = '''
          [System]
          User: $nickname (Grade $grade)
          Persona: $personaGuide
          
          [User's Input]
          "$userText"

          [Task]
          Reply naturally in Korean (Warm conversational tone, 해요체).
          Keep it under 3 sentences. Empathize with the user's words.
        ''';

        final response = await _chatModel.generateContent([Content.text(prompt)]);
        return response.text?.trim() ?? "네, 이야기 잘 듣고 있어요.";

      } else {
        // 🎧 Case B: STT 실패 -> 오디오 직접 분석
        print("🎧 [AI Service] 오디오 모드로 전송 (STT 실패 대비)");

        final prompt = '''
          [System]
          User: $nickname (Grade $grade)
          Persona: $personaGuide
          
          [Task]
          Listen to the attached audio carefully.
          Reply naturally in Korean (Warm conversational tone, 해요체).
          Keep it under 3 sentences.
        ''';

        final audioBytes = await audioFile.readAsBytes();
        final content = [
          Content.multi([
            TextPart(prompt),
            DataPart('audio/aac', audioBytes),
          ])
        ];

        final response = await _chatModel.generateContent(content);
        return response.text?.trim() ?? "목소리는 잘 들었는데, 뭐라고 대답해야 할지 고민되네요.";
      }

    } catch (e) {
      print("❌ 제미나이 처리 에러: $e");
      return "죄송해요, 통신 상태가 좋지 않아 답변을 가져오지 못했어요.";
    }
  }

  // 🔬 [분석 모델] 별도의 감정 분석 모델로 전송 (Stub)
  Future<void> _sendToAnalysisModel(File audioFile, String grade) async {
    try {
      await Future.delayed(const Duration(milliseconds: 500)); 
    } catch (e) {
      print("⚠️ 분석 모델 전송 실패: $e");
    }
  }

  // 페르소나 텍스트 관리
  String _getPersonaByGrade(String grade) {
    switch (grade) {
      case 'D': return "Role: Gentle Caregiver. Tone: Very soft, slow, protective. Focus on stability.";
      case 'C': return "Role: Kind Friend. Tone: Warm, encouraging. Focus on small daily joys.";
      case 'B': return "Role: Cheerful Companion. Tone: Bright, slightly energetic. Focus on going outside.";
      case 'A': return "Role: Life Coach. Tone: Professional, witty, motivating. Focus on growth.";
      default: return "Role: Warm Listener.";
    }
  }

  // =========================================================
  // 🎯 1. 데일리 미션 생성
  // =========================================================
  Future<String> generateDailyMission(String locationName, String weatherCondition) async {
    final userContext = await _loadUserContext();
    final String nickname = userContext['nickname'];
    final String grade = userContext['grade']; 
    final int level = userContext['level'];

    String personaGuide = "";
    switch (grade) {
      case 'D': personaGuide = "Target: Mental stability. Tone: Motherly."; break;
      case 'C': personaGuide = "Target: Domestic routine. Tone: Warm friend."; break;
      case 'B': personaGuide = "Target: Light outdoor. Tone: Cheerful."; break;
      case 'A': personaGuide = "Target: Socializing. Tone: Witty Coach."; break;
    }

    final prompt = '''
      [Context] User: $nickname (Lv $level), Loc: $locationName, Weather: $weatherCondition, Grade: $grade
      [Persona] $personaGuide
      [Task] Generate ONE simple daily mission instruction in Korean (해요체). 1-2 sentences. No titles.
      [Weather Logic] Rain->Indoor, Sun->Outdoor(if safe), Night->Sleep/Relax.
    ''';

    try {
      final content = [Content.text(prompt)];
      final response = await _chatModel.generateContent(content);
      return response.text?.replaceAll(RegExp(r'[*"`]'), '').trim() ?? "$locationName의 날씨를 느끼며 쉬어보세요.";
    } catch (e) {
      print("❌ 미션 에러: $e");
      return "오늘은 편안하게 쉬는 날로 해요.";
    }
  }

  // =========================================================
  // 📸 2. 사진 인증
  // =========================================================
  Future<Map<String, dynamic>?> verifyMissionImage({required File imageFile, required String missionTitle}) async {
    final userContext = await _loadUserContext();
    final String grade = userContext['grade'];

    final prompt = '''
      User (Grade $grade) submitted photo for: "$missionTitle".
      1. Is it relevant? (Be generous).
      2. Feedback in Korean (Grade D/C: Warm praise, B/A: Enthusiastic).
      Output JSON: {"is_success": true, "feedback": "Korean text"}
    ''';

    try {
      final imageBytes = await imageFile.readAsBytes();
      final content = [Content.multi([TextPart(prompt), DataPart('image/jpeg', imageBytes)])];
      final response = await _jsonModel.generateContent(content); 
      
      String? text = response.text?.replaceAll('```json', '').replaceAll('```', '').trim();
      if (text == null) return null;
      
      if (text.startsWith('{') && text.endsWith('}')) {
         return jsonDecode(text);
      }
      return jsonDecode(text.substring(text.indexOf('{'), text.lastIndexOf('}') + 1));
    } catch (e) {
      print("❌ 이미지 분석 에러: $e");
      return {"is_success": true, "feedback": "사진 감사합니다! (분석 지연)"};
    }
  }

  // =========================================================
  // 🎁 3. 보너스 미션
  // =========================================================
  Future<MissionModel?> getBonusMission() async {
    final userContext = await _loadUserContext();
    final String grade = userContext['grade'];
    
    final prompt = '''
      User Grade: $grade. Suggest ONE 'Bonus Mission'.
      Output JSON: {"mission_title": "Ko", "mission_content": "Ko", "type": "text/photo", "xp": 30, "difficulty": "$grade", "comment": "Ko"}
    ''';

    try {
      final content = [Content.text(prompt)];
      final response = await _jsonModel.generateContent(content); 
      
      String? text = response.text?.replaceAll('```json', '').replaceAll('```', '').trim();
      if (text == null) return null;
      
      String jsonString = text;
      if (!text.startsWith('{')) {
        int start = text.indexOf('{');
        int end = text.lastIndexOf('}');
        if (start != -1 && end != -1) {
          jsonString = text.substring(start, end + 1);
        }
      }
      final jsonMap = jsonDecode(jsonString);
      
      return MissionModel(
        title: jsonMap['mission_title'] ?? "보너스 미션",
        content: jsonMap['mission_content'] ?? "쉬어가기",
        type: _parseMissionType(jsonMap['type']),
        xp: jsonMap['xp'] is int ? jsonMap['xp'] : 30,
        difficulty: jsonMap['difficulty'] ?? grade,
        message: jsonMap['comment'] ?? "화이팅!",
      );
    } catch (e) {
      return null; 
    }
  }

  // =========================================================
  // 💬 4. 일반 텍스트 상담
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
      final content = [Content.text(prompt)];
      final response = await _chatModel.generateContent(content);
      return response.text?.trim() ?? "이야기를 잘 듣고 있어요.";
    } catch (e) {
      return "잠시 연결이 불안정해요.";
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