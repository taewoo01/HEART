enum MissionType {
  photo, // 📸 인증샷
  hold,  // 👆 꾹 누르기 (버튼 상호작용)
  text,  // 📝 텍스트 기록 (일기/대화)
  voice, // 🎙️ 음성 (소리 지르기/말하기)
  step   // 👣 만보기 (걸음 수)
}

class MissionModel {
  final String title;      // 퀘스트 제목
  final String content;    // 행동 지침
  final String difficulty; // 난이도 (F~S)
  final int xp;            // 보상 경험치
  final String message;    // 격려의 한마디
  final MissionType type;
  final String? strategyName; // 적용 전략 이름
  final String? reasoning;    // 전략 선택 이유
  final String? visionObject; // 인증 객체

  MissionModel({
    required this.title,
    required this.content,
    required this.difficulty,
    required this.xp,
    required this.message,
    required this.type,
    this.strategyName,
    this.reasoning,
    this.visionObject,
  });

  // 📌 [추가됨] AI가 보낸 JSON 데이터를 MissionModel로 변환하는 생성자
  factory MissionModel.fromJson(Map<String, dynamic> json) {
    return MissionModel(
      // AI가 가끔 실수로 비워둘 수 있으니 '??' 뒤에 기본값을 넣어 안전하게 처리
      title: json['mission_title'] ?? "오늘의 발견",
      content: json['mission_content'] ?? "잠시 숨을 고르는 시간을 가지세요.",
      difficulty: json['difficulty'] ?? "C",
      xp: (json['xp'] is int) ? json['xp'] : 50, // 숫자가 아니면 기본 50
      message: json['comment'] ?? "당신의 오늘을 응원합니다.",
      type: _stringToType(json['type']), // 문자열을 enum으로 변환
      strategyName: json['strategy_name'],
      reasoning: json['reasoning'],
      visionObject: json['vision_object'],
    );
  }

  // 📌 [추가됨] 문자열(String)을 MissionType(Enum)으로 바꾸는 도우미 함수
  static MissionType _stringToType(String? typeStr) {
    switch (typeStr?.toLowerCase()) {
      case 'photo':
        return MissionType.photo;
      case 'hold':
        return MissionType.hold;
      case 'voice':
        return MissionType.voice;
      case 'step':
        return MissionType.step;
      case 'text':
      default:
        // AI가 이상한 타입을 보내거나 비어있으면 기본적으로 '글쓰기' 미션으로 처리
        return MissionType.text;
    }
  }
}
