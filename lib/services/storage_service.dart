import 'package:shared_preferences/shared_preferences.dart';

class StorageService {
  // 저장할 키 값들
  static const String _keyNickname = "nickname";
  static const String _keyLocation = "location";
  static const String _keyLevel = "userLevel"; // 현재 등급 내 레벨 (1~50)
  static const String _keyGrade = "userGrade"; // 🆕 등급 (D, C, B, A, Master)
  static const String _keyIsOnboardingDone = "isOnboardingDone";

  // 1. 모든 정보 한 번에 저장하기 (초기 설정용)
  static Future<void> saveUserProfile({
    required String nickname,
    required String location,
    int level = 1,      // 기본값 1
    String grade = 'D', // 🆕 기본값 D등급
  }) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyNickname, nickname);
    await prefs.setString(_keyLocation, location);
    await prefs.setInt(_keyLevel, level);
    await prefs.setString(_keyGrade, grade); // 등급 저장
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

  // 4. 데이터 초기화 (테스트용 - 로그아웃 기능 등에 사용)
  static Future<void> clearData() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.clear();
  }
}