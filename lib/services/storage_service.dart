import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

class StorageService {
  // 저장할 키 값들
  static const String _keyNickname = "nickname";
  static const String _keyLocation = "location";
  static const String _keyLevel = "userLevel"; // 현재 등급 내 레벨 (1~50)
  static const String _keyGrade = "userGrade"; // 🆕 등급 (D, C, B, A, Master)
  static const String _keyIsOnboardingDone = "isOnboardingDone";
  static const String _keyPerSoc = "perSoc";
  static const String _keyPerIso = "perIso";
  static const String _keyPerEmo = "perEmo";
  static const String _keyRecentMissions = "recentMissions";
  static const String _keyMemories = "memories";
  static const String _keyAnalysisReason = "analysisReason";
  static const String _keyChatSummary = "chatSummary";
  static const String _keyChatKeywords = "chatKeywords";
  static const String _keyVoiceSignals = "voiceSignals";
  static const String _keyAudioAnalyses = "audioAnalyses";
  static const String _keyDeviceId = "deviceId";

  // 1. 모든 정보 한 번에 저장하기 (초기 설정용)
  static Future<void> saveUserProfile({
    required String nickname,
    required String location,
    int level = 1,      // 기본값 1
    String grade = 'D', // 🆕 기본값 D등급
    int perSoc = 50,
    int perIso = 50,
    int perEmo = 50,
    String analysisReason = "",
  }) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyNickname, nickname);
    await prefs.setString(_keyLocation, location);
    await prefs.setInt(_keyLevel, level);
    await prefs.setString(_keyGrade, grade); // 등급 저장
    await prefs.setInt(_keyPerSoc, perSoc);
    await prefs.setInt(_keyPerIso, perIso);
    await prefs.setInt(_keyPerEmo, perEmo);
    if (analysisReason.isNotEmpty) {
      await prefs.setString(_keyAnalysisReason, analysisReason);
    }
    await prefs.setBool(_keyIsOnboardingDone, true); // 설문 완료 표시
  }

  // 2. 저장된 정보 불러오기 (Map 형태로 반환)
  static Future<Map<String, dynamic>?> getUserProfile() async {
    final prefs = await SharedPreferences.getInstance();
    
    // 설문을 안 했으면 null 반환
    if (prefs.getBool(_keyIsOnboardingDone) != true) return null;

    return {
      'nickname': prefs.getString(_keyNickname) ?? '여행자',
      'location': prefs.getString(_keyLocation) ?? 'Unknown',
      'level': prefs.getInt(_keyLevel) ?? 1,
      'grade': prefs.getString(_keyGrade) ?? 'D', // 🆕 등급 불러오기 (기본 D)
      'per_soc': prefs.getInt(_keyPerSoc) ?? 50,
      'per_iso': prefs.getInt(_keyPerIso) ?? 50,
      'per_emo': prefs.getInt(_keyPerEmo) ?? 50,
      'analysis_reason': prefs.getString(_keyAnalysisReason) ?? '',
      'chat_summary': prefs.getString(_keyChatSummary) ?? '',
      'chat_keywords': prefs.getStringList(_keyChatKeywords) ?? <String>[],
    };
  }

  // 🆕 3. 레벨 및 등급 업데이트 (미션 완료 후 호출)
  static Future<void> updateProgress({
    required String grade,
    required int level,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyGrade, grade);
    await prefs.setInt(_keyLevel, level);
  }

  // 위치 업데이트
  static Future<void> updateLocation(String location) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyLocation, location);
  }

  // 4. 데이터 초기화 (테스트용 - 로그아웃 기능 등에 사용)
  static Future<void> clearData() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.clear();
  }

  // 최근 미션 저장 (중복 방지용)
  static Future<void> addRecentMission(String missionTitle, String missionGuide) async {
    final prefs = await SharedPreferences.getInstance();
    final List<String> current = prefs.getStringList(_keyRecentMissions) ?? [];
    final entry = "$missionTitle|$missionGuide";
    final updated = [entry, ...current.where((e) => e != entry)];
    await prefs.setStringList(_keyRecentMissions, updated.take(5).toList());
  }

  static Future<List<String>> getRecentMissions() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getStringList(_keyRecentMissions) ?? [];
  }

  // 로컬 기록 저장
  static Future<void> addMemoryEntry({
    required String note,
    required String iconName,
    DateTime? timestamp,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final List<String> current = prefs.getStringList(_keyMemories) ?? [];
    final ts = (timestamp ?? DateTime.now()).millisecondsSinceEpoch;
    final entry = jsonEncode({
      'ts': ts,
      'note': note,
      'icon': iconName,
    });
    final updated = [entry, ...current];
    await prefs.setStringList(_keyMemories, updated.take(200).toList());
  }

  static Future<List<Map<String, dynamic>>> getMemoryEntries() async {
    final prefs = await SharedPreferences.getInstance();
    final List<String> current = prefs.getStringList(_keyMemories) ?? [];
    return current.map((e) {
      try {
        final map = jsonDecode(e) as Map<String, dynamic>;
        return map;
      } catch (_) {
        return <String, dynamic>{};
      }
    }).where((e) => e.isNotEmpty).toList();
  }

  // 대화 요약 저장
  static Future<void> saveChatSummary(String summary, List<String> keywords) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyChatSummary, summary);
    await prefs.setStringList(_keyChatKeywords, keywords);
  }

  // 음성 신호 저장
  static Future<void> addVoiceSignal({
    required int durationMs,
    required int transcriptLength,
    required bool hasSpeech,
    double? wpm,
    double? pauseRatio,
    int? avgPauseMs,
    int? utteranceCount,
    double? avgUtteranceWords,
    DateTime? timestamp,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final List<String> current = prefs.getStringList(_keyVoiceSignals) ?? [];
    final ts = (timestamp ?? DateTime.now()).millisecondsSinceEpoch;
    final entry = jsonEncode({
      'ts': ts,
      'duration_ms': durationMs,
      'transcript_len': transcriptLength,
      'has_speech': hasSpeech,
      if (wpm != null) 'wpm': wpm,
      if (pauseRatio != null) 'pause_ratio': pauseRatio,
      if (avgPauseMs != null) 'avg_pause_ms': avgPauseMs,
      if (utteranceCount != null) 'utterance_count': utteranceCount,
      if (avgUtteranceWords != null) 'avg_utterance_words': avgUtteranceWords,
    });
    final updated = [entry, ...current];
    await prefs.setStringList(_keyVoiceSignals, updated.take(100).toList());
  }

  static Future<List<Map<String, dynamic>>> getVoiceSignals() async {
    final prefs = await SharedPreferences.getInstance();
    final List<String> current = prefs.getStringList(_keyVoiceSignals) ?? [];
    return current.map((e) {
      try {
        return jsonDecode(e) as Map<String, dynamic>;
      } catch (_) {
        return <String, dynamic>{};
      }
    }).where((e) => e.isNotEmpty).toList();
  }

  // 음성 분석 결과 저장 (서버 응답)
  static Future<void> addAudioAnalysis(Map<String, dynamic> analysis) async {
    final prefs = await SharedPreferences.getInstance();
    final List<String> current = prefs.getStringList(_keyAudioAnalyses) ?? [];
    final entry = jsonEncode(analysis);
    final updated = [entry, ...current];
    await prefs.setStringList(_keyAudioAnalyses, updated.take(200).toList());
  }

  static Future<List<Map<String, dynamic>>> getAudioAnalyses() async {
    final prefs = await SharedPreferences.getInstance();
    final List<String> current = prefs.getStringList(_keyAudioAnalyses) ?? [];
    return current.map((e) {
      try {
        return jsonDecode(e) as Map<String, dynamic>;
      } catch (_) {
        return <String, dynamic>{};
      }
    }).where((e) => e.isNotEmpty).toList();
  }

  // 기기 ID (로컬 유저 식별용)
  static Future<String> getOrCreateDeviceId() async {
    final prefs = await SharedPreferences.getInstance();
    final existing = prefs.getString(_keyDeviceId);
    if (existing != null && existing.isNotEmpty) return existing;

    final now = DateTime.now().millisecondsSinceEpoch;
    final rand = now ^ (now << 13);
    final id = "device_$now$rand";
    await prefs.setString(_keyDeviceId, id);
    return id;
  }
}
