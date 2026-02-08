import 'package:flutter/material.dart';
import '../utils/theme_utils.dart';
import '../models/mission_model.dart';
import '../widgets/quest_card.dart';
import '../services/weather_service.dart';
import '../services/location_service.dart';
import '../services/ai_service.dart';
import '../services/storage_service.dart';
import 'mission_page.dart';
import 'history_page.dart';

class MainScreen extends StatefulWidget {
  const MainScreen({super.key});

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> with SingleTickerProviderStateMixin {
  WeatherType currentWeather = WeatherType.sunny;
  bool _isLoading = true;
  late AnimationController _breathingController;
  final AIService _aiService = AIService();

  // 👤 유저 정보
  String _nickname = "여행자";
  String _location = "마음속"; // ⚠️ 실제 GPS 주소로 업데이트될 예정
  String _grade = "D"; 
  int _currentLevel = 1;

  late MissionModel _todaysMission;
  bool _isMissionCompleted = false;
  bool _isBonusActive = false;

  @override
  void initState() {
    super.initState();
    // 숨쉬는 애니메이션 (AI Orb)
    _breathingController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2000),
    )..repeat(reverse: true);

    _loadAllData(); 
  }

  // =========================================================
  // 🚀 데이터 로딩 (위치 -> 날씨 -> AI 미션 순차 실행)
  // =========================================================
  Future<void> _loadAllData() async {
    if (!mounted) return;
    setState(() => _isLoading = true);

    try {
      // 1. 저장된 내 정보 불러오기
      final userData = await StorageService.getUserProfile();
      if (userData != null) {
        _nickname = userData['nickname'];
        _location = userData['location']; // 기본 저장된 위치
        _grade = userData['grade'] ?? 'D';
        _currentLevel = userData['level'] ?? 1;
      }

      // 2. 실시간 위치 & 날씨 확인
      WeatherService weatherService = WeatherService();
      LocationService locationService = LocationService();
      WeatherType realWeather = WeatherType.sunny;
      String aiWeatherString = "Sunny"; // AI에게 보낼 날씨 문자열

      final position = await locationService.getCurrentLocation();
      if (position != null) {
        // 📍 (선택사항) 여기서 좌표를 주소(ex: 서울시 마포구)로 변환하는 로직이 있다면 _location 변수 업데이트
        // _location = await locationService.getAddressFromLatLng(position); 
        
        final weatherInfo = await weatherService.getCurrentWeather(
          position.latitude,
          position.longitude,
        );
        // 화면용 날씨 Enum
        realWeather = weatherInfo.type;
        // 위치 텍스트를 API에서 받은 도시 이름으로 업데이트
        _location = weatherInfo.cityName;
        await StorageService.updateLocation(_location);
        
        // Enum -> String 변환 (AI 전달용)
        aiWeatherString = _getWeatherString(realWeather);
      }

      // 3. 🤖 AI에게 맞춤 미션 요청 (수정된 부분!)
      // 이제 위치와 날씨 정보를 함께 전달합니다.
      final aiMission = await _aiService.generateDailyMission(
        _location,      // 예: "서울"
        aiWeatherString // 예: "Rainy"
      );
      final String aiMissionText = (aiMission['mission_guide'] ?? "").toString();
      final String aiMissionTitle = (aiMission['mission_title'] ?? "").toString();
      final int aiMissionXp = aiMission['xp_reward'] is int ? aiMission['xp_reward'] : 100;
      final String aiStrategy = (aiMission['strategy_name'] ?? "").toString();
      final String aiReasoning = (aiMission['reasoning'] ?? "").toString();
      final String aiVision = (aiMission['vision_object'] ?? "").toString();
      final String aiMissionTypeStr = (aiMission['mission_type'] ?? "").toString();
      final MissionType aiMissionType = _resolveMissionType(
        aiMissionTypeStr,
        visionObject: aiVision,
        fallbackGrade: _grade,
      );

      if (mounted) {
        setState(() {
          currentWeather = realWeather;
          
          _todaysMission = MissionModel(
            title: aiMissionTitle.isNotEmpty ? aiMissionTitle : _getMissionTitleByGrade(_grade),
            content: aiMissionText.isNotEmpty ? aiMissionText : _getBackupMission().content,
            type: aiMissionType,
            xp: aiMissionXp,
            difficulty: _difficultyByXp(aiMissionXp, _grade),
            message: "$_nickname님, 천천히 시작해봐요.",
            strategyName: aiStrategy.isNotEmpty ? aiStrategy : null,
            reasoning: aiReasoning.isNotEmpty ? aiReasoning : null,
            visionObject: aiVision.isNotEmpty ? aiVision : null,
          );
          StorageService.addRecentMission(
            aiMissionTitle.isNotEmpty ? aiMissionTitle : _getMissionTitleByGrade(_grade),
            aiMissionText.isNotEmpty ? aiMissionText : _getBackupMission().content,
          );
          
          _isMissionCompleted = false;
          _isBonusActive = false;
          _isLoading = false;
        });
      }
    } catch (e) {
      print("🔥 데이터 로딩 에러: $e");
      if (mounted) {
        setState(() {
          _todaysMission = _getBackupMission(); // 에러 시 백업 미션
          _isLoading = false;
        });
      }
    }
  }

  // 🌤️ 날씨 Enum -> String 변환 헬퍼
  String _getWeatherString(WeatherType type) {
    switch (type) {
      case WeatherType.rainy: return "Rainy";
      case WeatherType.snowy: return "Snowy";
      case WeatherType.cloudy: return "Cloudy";
      case WeatherType.night: return "Night";
      default: return "Sunny";
    }
  }

  String _getMissionTitleByGrade(String grade) {
    switch (grade) {
      case 'D': return "내 방, 작은 시작";
      case 'C': return "집안의 온기";
      case 'B': return "바깥 세상으로";
      case 'A': return "성장의 시간";
      default: return "오늘의 미션";
    }
  }

  MissionType _getMissionTypeByGrade(String grade) {
    if (grade == 'D') return MissionType.hold;
    if (grade == 'C') return MissionType.photo;
    if (grade == 'B') return MissionType.step;
    return MissionType.text;
  }

  MissionType _parseMissionType(String typeStr, {required String fallbackGrade}) {
    switch (typeStr.toLowerCase()) {
      case 'photo':
        return MissionType.photo;
      case 'hold':
        return MissionType.hold;
      case 'step':
        return MissionType.step;
      case 'voice':
        return MissionType.voice;
      case 'text':
        return MissionType.text;
      default:
        return _getMissionTypeByGrade(fallbackGrade);
    }
  }

  MissionType _resolveMissionType(
    String typeStr, {
    required String visionObject,
    required String fallbackGrade,
  }) {
    final parsed = _parseMissionType(typeStr, fallbackGrade: fallbackGrade);
    final corrected = _coerceByGrade(parsed, fallbackGrade);
    if (visionObject.trim().isNotEmpty && corrected != MissionType.photo) {
      return MissionType.photo;
    }
    return corrected;
  }

  MissionType _coerceByGrade(MissionType type, String grade) {
    switch (grade) {
      case 'D':
        return (type == MissionType.text || type == MissionType.hold) ? type : MissionType.hold;
      case 'C':
        return (type == MissionType.photo || type == MissionType.text || type == MissionType.hold)
            ? type
            : MissionType.photo;
      case 'B':
        return (type == MissionType.step || type == MissionType.photo || type == MissionType.text)
            ? type
            : MissionType.step;
      case 'A':
        return (type == MissionType.text || type == MissionType.photo || type == MissionType.voice || type == MissionType.step)
            ? type
            : MissionType.text;
      default:
        return type;
    }
  }

  String _difficultyByXp(int xp, String fallbackGrade) {
    if (xp >= 100) return 'S';
    if (xp >= 85) return 'A';
    if (xp >= 65) return 'B';
    if (xp >= 45) return 'C';
    return fallbackGrade.isNotEmpty ? fallbackGrade : 'D';
  }

  MissionModel _getBackupMission() {
    return MissionModel(
      title: "잠시 멈춤",
      content: "창문을 열고 바깥 공기를 3초간 마셔보세요.", // 네트워크 오류 시 기본 미션
      type: MissionType.hold,
      xp: 50,
      difficulty: "D",
      message: "연결이 늦어져도 괜찮아요.",
    );
  }

  // 🆙 레벨업 로직
  Future<void> _handleLevelProgress() async {
    int nextLevel = _currentLevel + 1;
    String nextGrade = _grade;
    bool isPromoted = false;

    // 50레벨마다 등급 업
    if (nextLevel > 50) {
      nextLevel = 1;
      isPromoted = true;
      
      if (_grade == 'D') nextGrade = 'C';
      else if (_grade == 'C') nextGrade = 'B';
      else if (_grade == 'B') nextGrade = 'A';
      else if (_grade == 'A') nextGrade = 'Master';
    }

    await StorageService.updateProgress(grade: nextGrade, level: nextLevel);

    if (mounted) {
      setState(() {
        _currentLevel = nextLevel;
        _grade = nextGrade;
        _isMissionCompleted = true;
      });

      if (isPromoted) {
        _showPromotionDialog(nextGrade);
      }
    }
  }

  void _showPromotionDialog(String newGrade) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return AlertDialog(
          backgroundColor: Colors.white.withOpacity(0.95),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: const Text("🎉 등급 상승! 🎉", textAlign: TextAlign.center),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.verified, color: Color(0xFF6BB8B0), size: 60),
              const SizedBox(height: 15),
              Text(
                "Grade $newGrade 달성!",
                style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 10),
              const Text(
                "당신의 세상이 한 뼘 더 넓어졌습니다.\n새로운 미션이 기다리고 있어요.",
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.grey),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text("멋져요!", style: TextStyle(color: Color(0xFF6BB8B0), fontWeight: FontWeight.bold)),
            )
          ],
        );
      }
    );
  }

  Future<void> _navigateToMission() async {
    final result = await Navigator.push(
      context, 
      MaterialPageRoute(
        builder: (context) => MissionPage(
          weatherType: currentWeather, 
          mission: _todaysMission,
          isBonusMission: _isBonusActive, 
        )
      )
    );

    if (!mounted) return;

    if (result == true) {
      await _handleLevelProgress();
    } 
    // 보너스 미션을 받아왔을 경우
    else if (result is MissionModel) {
      setState(() {
        _isMissionCompleted = false;
        _todaysMission = result;    
        _isBonusActive = true;      
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("✨ 보너스: ${result.title}"), backgroundColor: const Color(0xFF6BB8B0)),
      );
    }
  }

  @override
  void dispose() {
    _breathingController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) return _buildLoadingScreen();

    final textColor = getTextColor(currentWeather);
    
    String stateTitle = "Grade $_grade : 성장 중 🌱";
    if (_grade == 'A') stateTitle = "Grade A : 도약 중 ✨";
    if (_grade == 'Master') stateTitle = "Master : 자유로운 영혼 🕊️";

    return Scaffold(
      // 우측 하단 상담소 플로팅 버튼
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          Navigator.pushNamed(context, '/chat');
        },
        backgroundColor: Colors.white,
        elevation: 4,
        icon: const Icon(Icons.support_agent_rounded, color: Color(0xFF6BB8B0)),
        label: const Text(
          "AI 상담소", 
          style: TextStyle(color: Color(0xFF6BB8B0), fontWeight: FontWeight.bold)
        ),
      ),

      body: Stack(
        children: [
          // 배경: 날씨에 따라 그라데이션 변경
          AnimatedContainer(
            duration: const Duration(milliseconds: 1000),
            decoration: BoxDecoration(gradient: getWeatherGradient(currentWeather)),
          ),
          _buildWeatherDecorations(),
          
          SafeArea(
            child: LayoutBuilder(
              builder: (context, constraints) {
                return SingleChildScrollView(
                  padding: const EdgeInsets.only(bottom: 40),
                  child: ConstrainedBox(
                    constraints: BoxConstraints(minHeight: constraints.maxHeight),
                    child: Column(
                      children: [
                        const SizedBox(height: 20),
                        // 상단 정보바
                        _buildTopBar(context, textColor, stateTitle),

                        const SizedBox(height: 30),

                        // 중앙 AI Orb & 미션 카드
                        Column(
                          children: [
                            _buildAIOrb(),
                            const SizedBox(height: 15),
                            AnimatedSwitcher(
                              duration: const Duration(milliseconds: 500),
                              child: _isMissionCompleted
                                  ? _buildCompletedCard()
                                  : QuestCard(key: ValueKey(_todaysMission.content), mission: _todaysMission),
                            ),
                          ],
                        ),

                        const SizedBox(height: 30),

                        // 하단 버튼 (완료 시 휴식 메시지)
                        _isMissionCompleted ? _buildRestMessage() : _buildActionButtons(context),

                        // 버튼에 가려지지 않게 여백
                        const SizedBox(height: 80),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLoadingScreen() {
    return Scaffold(
      body: Container(
        decoration: BoxDecoration(gradient: getWeatherGradient(WeatherType.sunny)),
        child: const Center(child: CircularProgressIndicator(color: Colors.white)),
      ),
    );
  }

  Widget _buildTopBar(BuildContext context, Color textColor, String stateTitle) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 25),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text("Grade $_grade", style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Color(0xFF6BB8B0))),
                  Text(_nickname, style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: textColor)),
                ],
              ),
              Row(
                children: [
                  IconButton(
                    icon: Icon(Icons.refresh, color: textColor),
                    onPressed: _loadAllData, 
                  ),
                  IconButton(
                    icon: Icon(Icons.calendar_month_outlined, color: textColor),
                    onPressed: () {
                      Navigator.push(context, MaterialPageRoute(builder: (context) => HistoryPage(weatherType: currentWeather)));
                    },
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 15),
          Row(
            children: [
              Icon(Icons.location_on, size: 14, color: textColor.withOpacity(0.6)),
              const SizedBox(width: 4),
              Text(_location, style: TextStyle(color: textColor.withOpacity(0.6), fontSize: 12)),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: textColor.withOpacity(0.15), 
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: textColor.withOpacity(0.3)),
                ),
                child: Text("Lv.$_currentLevel / 50", style: TextStyle(color: textColor, fontWeight: FontWeight.w900, fontSize: 14)),
              ),
            ],
          ),
          const SizedBox(height: 10),
          ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: LinearProgressIndicator(
              value: _currentLevel / 50.0,
              backgroundColor: textColor.withOpacity(0.2),
              valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFF6BB8B0)),
              minHeight: 8,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAIOrb() {
    return AnimatedBuilder(
      animation: _breathingController,
      builder: (context, child) {
        return Container(
          width: 80 + (_breathingController.value * 10),
          height: 80 + (_breathingController.value * 10),
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: Colors.white.withOpacity(0.25),
            border: Border.all(color: Colors.white.withOpacity(0.5), width: 1.5),
            boxShadow: [BoxShadow(color: Colors.white.withOpacity(0.3), blurRadius: 20, spreadRadius: 2)],
          ),
          child: Center(
            child: Icon(
              _isMissionCompleted ? Icons.check_circle_outline : Icons.graphic_eq_rounded, 
              color: Colors.white, size: 40
            )
          ),
        );
      }
    );
  }

  Widget _buildCompletedCard() {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.symmetric(horizontal: 25),
      padding: const EdgeInsets.all(25),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [Colors.orange.shade300.withOpacity(0.9), Colors.amber.shade200.withOpacity(0.9)],
          begin: Alignment.topLeft, end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(25),
        boxShadow: [BoxShadow(color: Colors.orange.withOpacity(0.3), blurRadius: 20, offset: const Offset(0, 10))],
      ),
      child: Column(
        children: [
          const Icon(Icons.star_rounded, color: Colors.white, size: 50),
          const SizedBox(height: 15),
          const Text("오늘의 발견 완료", style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.white)),
          const SizedBox(height: 10),
          const Text("당신의 세상이 한 뼘 더 넓어졌습니다.", textAlign: TextAlign.center, style: TextStyle(fontSize: 16, color: Colors.white)),
        ],
      ),
    );
  }

  Widget _buildRestMessage() {
    return Column(
      children: [
        Text("충분해요. 오늘은 여기까지.", style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: getTextColor(currentWeather))),
        const SizedBox(height: 10),
        Text("남은 하루는 온전히 당신을 위해 쓰세요.", style: TextStyle(fontSize: 15, color: getTextColor(currentWeather).withOpacity(0.8))),
      ],
    );
  }

  Widget _buildActionButtons(BuildContext context) {
    return ElevatedButton.icon(
      onPressed: _navigateToMission, 
      icon: Icon(_getMissionIcon(_todaysMission.type), color: Colors.white),
      label: Text(_isBonusActive ? "보너스 미션 시작!" : "미션 수행하기", style: const TextStyle(fontSize: 18, color: Colors.white)),
      style: ElevatedButton.styleFrom(
        backgroundColor: const Color(0xFF6BB8B0),
        minimumSize: const Size(280, 60),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
        elevation: 5,
      ),
    );
  }

  IconData _getMissionIcon(MissionType type) {
    switch (type) {
      case MissionType.photo: return Icons.camera_alt_rounded;
      case MissionType.hold: return Icons.fingerprint;
      case MissionType.text: return Icons.edit_note_rounded;
      case MissionType.voice: return Icons.mic_rounded;
      case MissionType.step: return Icons.directions_walk_rounded;
    }
  }

  Widget _buildWeatherDecorations() {
    switch (currentWeather) {
      case WeatherType.sunny: return Positioned(top: -40, right: -40, child: Icon(Icons.wb_sunny, size: 150, color: Colors.orange.withOpacity(0.4)));
      case WeatherType.rainy: return const Positioned(top: 50, left: 30, child: Icon(Icons.water_drop, size: 80, color: Colors.white30));
      default: return const SizedBox.shrink();
    }
  }
}
