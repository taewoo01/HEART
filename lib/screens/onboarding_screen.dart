import 'dart:convert'; // 📌 JSON 파싱을 위해 필수
import 'package:flutter/material.dart';
import 'package:google_generative_ai/google_generative_ai.dart';
import '../utils/theme_utils.dart';
import '../services/storage_service.dart';

class OnboardingScreen extends StatefulWidget {
  final VoidCallback onComplete; 
  final String nickname;
  final String location;

  const OnboardingScreen({
    super.key, 
    required this.onComplete,
    required this.nickname, 
    required this.location, 
  });

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  // ⚠️ 중요: 아까 새로 발급받은 '새 프로젝트의 API 키'를 아래 따옴표 안에 넣으세요.
  final String _apiKey = 'AIzaSyB3w8463q2SnEnb2S5bgNRl8FA5s-2nfao'; 

  final int _questionsPerPage = 5; 
  int _currentPageIndex = 0;
  final Map<int, int> _userAnswers = {};

  // 📝 질문 리스트
  final List<Map<String, dynamic>> _allQuestions = [
    {"q": "1. 사람과 거리를 둔다.", "isReverse": false},
    {"q": "2. 하루 종일 거의 집에서 보낸다.", "isReverse": false},
    {"q": "3. 중요한 일에 대해 의논할 사람이 정말로 아무도 없다.", "isReverse": false},
    {"q": "4. 모르는 사람과 만나는 것을 아주 좋아한다.", "isReverse": true}, 
    {"q": "5. 나의 방에 틀어 박혀 있다.", "isReverse": false},
    {"q": "6. 사람이 귀찮다.", "isReverse": false},
    {"q": "7. 나를 이해해 주려고 하는 사람들이 있다.", "isReverse": true}, 
    {"q": "8. 누군가와 함께 있는 것이 불편하게 느껴진다.", "isReverse": false},
    {"q": "9. 하루 종일 거의 혼자서 지낸다.", "isReverse": false},
    {"q": "10. 몇몇 사람들에게 개인적인 생각을 털어놓을 수 있다.", "isReverse": true}, 
    {"q": "11. 사람들에게 보여지는 것이 싫다.", "isReverse": false},
    {"q": "12. 사람과 직접 만나는 것이 거의 없다.", "isReverse": false},
    {"q": "13. 집단에 들어가는 것이 서투르다.", "isReverse": false},
    {"q": "14. 중요한 문제에 대해서 의논할 사람이 별로 없다.", "isReverse": false},
    {"q": "15. 사람과의 교류는 즐겁다.", "isReverse": true}, 
    {"q": "16. 사회의 규칙과 가치관에 맞춰서 살고 있지 않다.", "isReverse": false},
    {"q": "17. 자신의 인생에 있어서 소중한 사람이 정말로 아무도 없다.", "isReverse": false},
    {"q": "18. 사람과 이야기하는 것을 피한다.", "isReverse": false},
    {"q": "19. 누군가와 연락을 하는 일은 별로 없다.", "isReverse": false},
    {"q": "20. 누군가와 함께 있는 것 보다 혼자 있는 것이 훨씬 좋다.", "isReverse": false},
    {"q": "21. 안심하고 상담할 수 있는 사람이 있다.", "isReverse": true}, 
    {"q": "22. 혼자서 시간을 보내는 것은 거의 없다.", "isReverse": true}, 
    {"q": "23. 사람을 사귀는 것은 즐겁지 않다.", "isReverse": false},
    {"q": "24. 사람과 교류하는 것이 거의 없다.", "isReverse": false},
    {"q": "25. 혼자 있는 것 보다는 누군가와 함께 있는 편이 훨씬 좋다.", "isReverse": true}, 
  ];

  void _setAnswer(int globalIndex, int selectedOptionIndex) {
    bool isReverse = _allQuestions[globalIndex]['isReverse'];
    // 0~4점 부여 (높을수록 고립 성향)
    int score = isReverse ? (4 - selectedOptionIndex) : selectedOptionIndex;
    setState(() {
      _userAnswers[globalIndex] = score;
    });
  }

  void _goNextPage() {
    int totalPages = (_allQuestions.length / _questionsPerPage).ceil();
    if (_currentPageIndex < totalPages - 1) {
      setState(() {
        _currentPageIndex++;
      });
    } else {
      _finishSurvey();
    }
  }

  bool _isCurrentPageCompleted() {
    int start = _currentPageIndex * _questionsPerPage;
    int end = start + _questionsPerPage;
    if (end > _allQuestions.length) end = _allQuestions.length;
    for (int i = start; i < end; i++) {
      if (!_userAnswers.containsKey(i)) return false;
    }
    return true;
  }

  // =========================================================
  // 🧠 1. AI 분석용 데이터 변환 (점수 -> 문맥)
  // =========================================================
  String _buildSurveyDataForAI() {
    StringBuffer buffer = StringBuffer();
    _userAnswers.forEach((index, score) {
      String question = _allQuestions[index]['q'];
      String answerMeaning = "";
      
      // score (0~4)를 AI가 이해하기 쉬운 텍스트로 변환
      if (score == 4) answerMeaning = "매우 그렇다 (강한 고립 징후)";
      else if (score == 3) answerMeaning = "그렇다";
      else if (score == 2) answerMeaning = "보통이다";
      else if (score == 1) answerMeaning = "그렇지 않다";
      else answerMeaning = "전혀 그렇지 않다 (활동적)";

      buffer.writeln("- 질문: $question / 답변: $answerMeaning");
    });
    return buffer.toString();
  }

  // =========================================================
  // 🚀 2. 설문 완료 및 AI 분석 실행 (수정된 핵심 부분)
  // =========================================================
  Future<void> _finishSurvey() async {
    // 로딩 다이얼로그
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const CircularProgressIndicator(color: Colors.white),
            const SizedBox(height: 15),
            Text(
              "${widget.nickname}님의 마음을 깊이 이해하는 중...", 
              style: const TextStyle(color: Colors.white, fontSize: 14, decoration: TextDecoration.none)
            ),
          ],
        ),
      ),
    );

    String userGrade = 'C'; // 기본값
    int calculatedScore = 50; // 기본값
    String aiMessage = "분석을 완료했습니다.";

    try {
      // ✅ 1. AI 모델 준비 (설정 주석 해제 및 모델명 확정)
      final model = GenerativeModel(
        model: 'gemini-flash-latest', // 2026년 기준 안정적인 모델
        apiKey: _apiKey,
        generationConfig: GenerationConfig(
          responseMimeType: 'application/json', // 📌 중요: JSON 형식 강제
          temperature: 0.7,
        ),
      );

      // 2. 프롬프트 생성
      final surveyData = _buildSurveyDataForAI();
      final prompt = '''
        당신은 전문 심리 상담가입니다. 아래 사용자의 설문 답변을 분석하세요.
        
        [사용자 정보]
        닉네임: ${widget.nickname} / 지역: ${widget.location}

        [설문 답변 내역]
        $surveyData

        [임무]
        답변의 맥락을 파악하여 '사회적 고립 등급(Grade)'을 판단하고 JSON으로 출력하세요.
        단순 점수 합산이 아니라, 자발적 고립인지 비자발적 고립인지 뉘앙스를 파악하세요.

        [Grade 기준]
        - A: 활동적, 긍정적, 사회적 교류 활발.
        - B: 일상 생활 가능, 가벼운 외출 가능.
        - C: 사회적 위축, 집안 활동 권장.
        - D: 심각한 고립 또는 대인기피, 절대적 휴식 필요.

        [출력 JSON 형식]
        {
          "grade": "C", 
          "score": 65,  
          "message": "사용자에게 건넬 따뜻한 첫 인사 (한국어, 해요체, 2문장)"
        }
      ''';

      // 3. AI 요청
      final response = await model.generateContent([Content.text(prompt)]);
      print("🤖 AI 응답 원본: ${response.text}"); // 디버깅용 로그

      // ✅ 4. 응답 파싱 (강력해진 파싱 로직)
      String rawText = response.text ?? "{}";
      
      // JSON 부분만 쏙 뽑아내기 ('{' 부터 '}' 까지)
      int startIndex = rawText.indexOf('{');
      int endIndex = rawText.lastIndexOf('}');
      
      if (startIndex != -1 && endIndex != -1) {
        rawText = rawText.substring(startIndex, endIndex + 1);
      }

      final parsedData = jsonDecode(rawText);

      userGrade = parsedData['grade'] ?? 'C';
      calculatedScore = parsedData['score'] is int ? parsedData['score'] : 50;
      aiMessage = parsedData['message'] ?? "만나서 반가워요.";

    } catch (e) {
      // 🚨 AI 오류 시: 기존 단순 합산 로직으로 대체 (Fallback)
      print("AI 분석 실패 (Fallback 실행): $e");
      int totalScore = _userAnswers.values.fold(0, (sum, score) => sum + score);
      
      // 100점 만점으로 환산 (문항수 25 * 4점 = 100)
      calculatedScore = totalScore; 

      if (totalScore >= 70) userGrade = 'D';
      else if (totalScore >= 50) userGrade = 'C';
      else if (totalScore >= 30) userGrade = 'B';
      else userGrade = 'A';
      
      aiMessage = "${widget.nickname}님, 반가워요. 당신의 속도에 맞춰 함께 나아가요.";
    }

    // UI 색상 설정
    Color stateColor = (userGrade == 'D' || userGrade == 'C') 
        ? const Color(0xFF6BB8B0) // 휴식/안정
        : const Color(0xFFE57373); // 활동/에너지

    if (!mounted) return;
    Navigator.pop(context); // 로딩 닫기

    // 5. 저장
    await StorageService.saveUserProfile(
      nickname: widget.nickname,
      location: widget.location,
      level: 1,
      grade: userGrade,
    );

    // 6. 결과 팝업
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.white.withOpacity(0.95),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 10),
            Icon(Icons.psychology, size: 50, color: stateColor),
            const SizedBox(height: 15),
            Text(
              "Grade $userGrade", 
              style: TextStyle(fontSize: 32, fontWeight: FontWeight.bold, color: stateColor),
            ),
            const SizedBox(height: 5),
            Text(
              "마음 고립도: $calculatedScore",
              style: const TextStyle(fontSize: 14, color: Colors.grey),
            ),
            const SizedBox(height: 20),
            Container(
              padding: const EdgeInsets.all(15),
              decoration: BoxDecoration(
                color: Colors.grey[100],
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                aiMessage, 
                textAlign: TextAlign.center, 
                style: const TextStyle(fontSize: 15, height: 1.5, color: Colors.black87)
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              widget.onComplete(); 
            },
            child: Text("여행 시작하기", style: TextStyle(color: stateColor, fontWeight: FontWeight.bold, fontSize: 16)),
          )
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    int startIndex = _currentPageIndex * _questionsPerPage;
    int endIndex = (startIndex + _questionsPerPage < _allQuestions.length) 
        ? startIndex + _questionsPerPage 
        : _allQuestions.length;
    
    List<Map<String, dynamic>> currentQuestions = _allQuestions.sublist(startIndex, endIndex);
    int totalPages = (_allQuestions.length / _questionsPerPage).ceil();

    return Scaffold(
      body: Container(
        decoration: BoxDecoration(gradient: getWeatherGradient(WeatherType.sunny)),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
            child: Column(
              children: [
                // 상단 진행바
                Row(
                  children: [
                    Expanded(
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(10),
                        child: LinearProgressIndicator(
                          value: (_currentPageIndex + 1) / totalPages,
                          backgroundColor: Colors.white30,
                          valueColor: const AlwaysStoppedAnimation<Color>(Colors.white),
                          minHeight: 8,
                        ),
                      ),
                    ),
                    const SizedBox(width: 15),
                    Text(
                      "${_currentPageIndex + 1}/$totalPages",
                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16),
                    )
                  ],
                ),
                const SizedBox(height: 10),

                // 질문 카드 리스트
                Expanded(
                  child: Column(
                    children: List.generate(currentQuestions.length, (index) {
                      int globalIndex = startIndex + index;
                      return Expanded(
                        child: _buildCompactQuestionCard(globalIndex, currentQuestions[index]['q']),
                      );
                    }),
                  ),
                ),
                const SizedBox(height: 10),

                // 하단 버튼
                SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: ElevatedButton(
                    onPressed: _isCurrentPageCompleted() ? _goNextPage : null,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.white,
                      disabledBackgroundColor: Colors.white.withOpacity(0.3),
                      foregroundColor: const Color(0xFF6BB8B0),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                      elevation: 2,
                    ),
                    child: Text(
                      _currentPageIndex == totalPages - 1 ? "결과 보기" : "다음",
                      style: TextStyle(
                        fontSize: 18, 
                        fontWeight: FontWeight.bold,
                        color: _isCurrentPageCompleted() ? const Color(0xFF6BB8B0) : Colors.white60
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildCompactQuestionCard(int globalIndex, String questionText) {
    int? score = _userAnswers[globalIndex];
    int? selectedBtnIndex;
    if (score != null) {
      bool isReverse = _allQuestions[globalIndex]['isReverse'];
      selectedBtnIndex = isReverse ? (4 - score) : score;
    }

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.symmetric(vertical: 4),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.9),
        borderRadius: BorderRadius.circular(15),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Flexible(
            child: Text(
              questionText,
              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Color(0xFF4A4A4A), height: 1.2),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: List.generate(5, (optionIndex) {
              bool isSelected = selectedBtnIndex == optionIndex;
              return GestureDetector(
                onTap: () => _setAnswer(globalIndex, optionIndex),
                child: Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: isSelected ? const Color(0xFF6BB8B0) : Colors.grey[200],
                    shape: BoxShape.circle,
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    "${optionIndex + 1}",
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: isSelected ? Colors.white : Colors.grey[600]),
                  ),
                ),
              );
            }),
          ),
        ],
      ),
    );
  }
}