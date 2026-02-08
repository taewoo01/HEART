import 'dart:convert'; 
import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart'; // 👈 1. 패키지 임포트
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
  // 🔐 2. .env에서 API 키 가져오기
  final String _apiKey = dotenv.env['GEMINI_API_KEY'] ?? ""; 

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
    int score = isReverse ? (4 - selectedOptionIndex) : selectedOptionIndex;
    
    setState(() {
      _userAnswers[globalIndex] = score; 
    });
  }
  
  int? _getUiIndex(int globalIndex) {
    if (!_userAnswers.containsKey(globalIndex)) return null;
    int score = _userAnswers[globalIndex]!;
    bool isReverse = _allQuestions[globalIndex]['isReverse'];
    return isReverse ? (4 - score) : score;
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

  // AI 데이터 생성
  String _buildSurveyDataForAI() {
    StringBuffer buffer = StringBuffer();
    _userAnswers.forEach((index, score) {
      String question = _allQuestions[index]['q'];
      String meaning = "";
      if (score >= 3) meaning = "고립 성향 높음";
      else if (score <= 1) meaning = "사회성 높음";
      else meaning = "보통";

      buffer.writeln("- $question (점수: $score/4, 의미: $meaning)");
    });
    return buffer.toString();
  }

  Future<void> _finishSurvey() async {
    // 키 체크 (개발자 디버깅용)
    if (_apiKey.isEmpty) {
      print("⚠️ API Key가 없습니다. .env 파일을 확인해주세요.");
    }

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

    String userGrade = 'C'; 
    int calculatedScore = 50; 
    String aiMessage = "분석을 완료했습니다.";

    try {
      final model = GenerativeModel(
        // ⚠️ 3. 모델 이름 안정적인 버전으로 통일
        model: 'gemini-flash-latest', 
        apiKey: _apiKey,
        generationConfig: GenerationConfig(
          responseMimeType: 'application/json', 
          temperature: 0.7,
        ),
      );

      final surveyData = _buildSurveyDataForAI();
      final prompt = '''
        당신은 전문 심리 상담가입니다. 
        [사용자 정보] 닉네임: ${widget.nickname}, 지역: ${widget.location}
        [설문 데이터]
        $surveyData
        
        [임무]
        위 데이터를 바탕으로 사회적 고립 등급(Grade)을 판단하고 JSON으로 출력하세요.
        - A: 매우 건강하고 활발함
        - B: 양호함, 일상생활 원만
        - C: 다소 위축됨, 관심 필요
        - D: 고립 위험, 적극적 케어 필요

        형식: {"grade": "C", "score": 65, "message": "따뜻한 한마디(2문장)"}
      ''';

      final response = await model.generateContent([Content.text(prompt)]);
      
      String rawText = response.text ?? "{}";
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
      print("AI 분석 실패 (Fallback): $e");
      int totalScore = _userAnswers.values.fold(0, (sum, score) => sum + score);
      calculatedScore = totalScore; 
      if (totalScore >= 70) userGrade = 'D';
      else if (totalScore >= 50) userGrade = 'C';
      else if (totalScore >= 30) userGrade = 'B';
      else userGrade = 'A';
      aiMessage = "당신의 마음에 귀 기울일게요.";
    }

    Color stateColor = (userGrade == 'D' || userGrade == 'C') 
        ? const Color(0xFF6BB8B0) 
        : const Color(0xFFE57373); 

    if (!mounted) return;
    Navigator.pop(context);

    await StorageService.saveUserProfile(
      nickname: widget.nickname,
      location: widget.location,
      level: 1,
      grade: userGrade,
    );

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
            Text("Grade $userGrade", style: TextStyle(fontSize: 32, fontWeight: FontWeight.bold, color: stateColor)),
            Text("마음 온도: $calculatedScore°C", style: const TextStyle(fontSize: 14, color: Colors.grey)), 
            const SizedBox(height: 20),
            Container(
              padding: const EdgeInsets.all(15),
              decoration: BoxDecoration(color: Colors.grey[100], borderRadius: BorderRadius.circular(10)),
              child: Text(aiMessage, textAlign: TextAlign.center, style: const TextStyle(fontSize: 15, height: 1.5)),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              widget.onComplete(); 
            },
            child: Text("시작하기", style: TextStyle(color: stateColor, fontWeight: FontWeight.bold, fontSize: 16)),
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
                // 1. 상단 진행바
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
                const SizedBox(height: 15),

                // 2. 응답 가이드 (범례)
                Container(
                  padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 20),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text("🙅‍♂️ 1 (전혀 아님)", style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold, fontSize: 13)),
                      Icon(Icons.arrow_right_alt, color: Colors.black),
                      Text("5 (매우 그렇다) 🙌", style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold, fontSize: 13)),
                    ],
                  ),
                ),
                const SizedBox(height: 10),

                // 3. 질문 리스트
                Expanded(
                  child: ListView.builder(
                    itemCount: currentQuestions.length,
                    itemBuilder: (context, index) {
                      int globalIndex = startIndex + index;
                      return _buildCompactQuestionCard(globalIndex, currentQuestions[index]['q']);
                    },
                  ),
                ),
                
                // 4. 다음 버튼
                const SizedBox(height: 10),
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
    int? uiIndex = _getUiIndex(globalIndex); 

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 12), 
      padding: const EdgeInsets.all(20), 
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.95),
        borderRadius: BorderRadius.circular(20), 
        boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 5, offset: Offset(0, 2))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 질문 텍스트
          Text(
            questionText,
            style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w600, color: Color(0xFF222222), height: 1.3),
          ),
          const SizedBox(height: 20),
          
          // 선택 버튼들 (1~5)
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: List.generate(5, (optionIndex) {
              bool isSelected = uiIndex == optionIndex;
              return GestureDetector(
                onTap: () => _setAnswer(globalIndex, optionIndex),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  width: isSelected ? 48 : 42, 
                  height: isSelected ? 48 : 42,
                  decoration: BoxDecoration(
                    color: isSelected ? const Color(0xFF6BB8B0) : Colors.grey[100],
                    border: Border.all(
                      color: isSelected ? const Color(0xFF6BB8B0) : Colors.grey[300]!,
                      width: isSelected ? 2 : 1
                    ),
                    shape: BoxShape.circle,
                    boxShadow: isSelected 
                      ? [BoxShadow(color: const Color(0xFF6BB8B0).withOpacity(0.4), blurRadius: 8, offset: const Offset(0, 4))] 
                      : [],
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    "${optionIndex + 1}",
                    style: TextStyle(
                      fontSize: isSelected ? 20 : 16, 
                      fontWeight: FontWeight.bold, 
                      color: isSelected ? Colors.white : Colors.grey[500]
                    ),
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