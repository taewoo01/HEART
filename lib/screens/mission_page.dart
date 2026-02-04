import 'dart:io'; // 📌 파일 처리를 위해 추가
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart'; // 📌 카메라 기능을 위해 추가
import '../utils/theme_utils.dart';
import '../models/mission_model.dart';
import '../models/user_stage.dart';
import '../services/ai_service.dart'; // 📌 AI 서비스 연결
import 'mission_complete_screen.dart';

class MissionPage extends StatefulWidget {
  final WeatherType weatherType;
  final MissionModel mission;
  final bool isBonusMission;

  const MissionPage({
    super.key, 
    required this.weatherType, 
    required this.mission,
    this.isBonusMission = false,
  });

  @override
  State<MissionPage> createState() => _MissionPageState();
}

class _MissionPageState extends State<MissionPage> with TickerProviderStateMixin {
  late AnimationController _holdController;
  late AnimationController _voiceController;
  final TextEditingController _textController = TextEditingController(); 
  
  bool _isAnalyzing = false; // AI 분석 중 로딩 상태
  double _currentSteps = 0;
  final double _targetSteps = 100;

  // 📌 [NEW] 사진 처리를 위한 변수
  File? _selectedImage;
  final ImagePicker _picker = ImagePicker();

  @override
  void initState() {
    super.initState();
    
    _holdController = AnimationController(vsync: this, duration: const Duration(seconds: 3));
    _holdController.addStatusListener((status) {
      if (status == AnimationStatus.completed) _completeMission("마음이 충전되었습니다.");
    });

    _voiceController = AnimationController(vsync: this, duration: const Duration(milliseconds: 1000));
  }

  @override
  void dispose() {
    _holdController.dispose();
    _voiceController.dispose();
    _textController.dispose();
    super.dispose();
  }

  // ------------------------------------------------------------------------
  // 🚀 [NEW] AI 사진 인증 로직
  // ------------------------------------------------------------------------
  Future<void> _pickImage() async {
    final XFile? image = await _picker.pickImage(source: ImageSource.camera);
    if (image != null) {
      setState(() {
        _selectedImage = File(image.path);
      });
    }
  }

  Future<void> _submitPhotoMission() async {
    if (_selectedImage == null) return;

    setState(() => _isAnalyzing = true); // 로딩 시작

    // 1. AI에게 사진 검사 요청
    final result = await AIService().verifyMissionImage(
      imageFile: _selectedImage!,
      missionTitle: widget.mission.title,
    );

    setState(() => _isAnalyzing = false); // 로딩 끝

    if (result != null) {
      // 2. 결과 처리
      if (result['is_success'] == true) {
        // 성공 시: AI의 칭찬 메시지를 가지고 완료 화면으로
        _completeMission(result['feedback']);
      } else {
        // 실패 시: 다이얼로그로 피드백 보여주고 재도전 유도
        _showFeedbackDialog("조금 아쉬워요", result['feedback'], isSuccess: false);
      }
    } else {
      // 에러 시 (네트워크 등) 일단 통과시켜줌 (UX 보호)
      _completeMission("사진이 멋지게 기록되었습니다!");
    }
  }

  // ------------------------------------------------------------------------
  // 🚀 [NEW] AI 텍스트 상담 로직
  // ------------------------------------------------------------------------
  Future<void> _submitTextMission() async {
    if (_textController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("내용을 입력해주세요!")));
      return;
    }

    setState(() => _isAnalyzing = true);

    // 1. AI에게 상담 요청
    final aiReply = await AIService().chatWithCounselor(_textController.text);

    setState(() => _isAnalyzing = false);

    // 2. AI의 답변을 팝업으로 먼저 보여줌 (위로 효과)
    if (!mounted) return;
    showDialog(
      context: context,
      barrierDismissible: false, // 확인 누르기 전엔 안 닫힘
      builder: (ctx) => AlertDialog(
        backgroundColor: Colors.white.withOpacity(0.9),
        title: const Text("💌 답장이 도착했어요"),
        content: Text(aiReply, style: const TextStyle(fontSize: 16, height: 1.4)),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(ctx); // 팝업 닫고
              _completeMission("오늘 하루도 수고했어요."); // 미션 완료 이동
            },
            child: const Text("고마워", style: TextStyle(color: Colors.teal)),
          )
        ],
      ),
    );
  }

  // 📌 실패 피드백 보여주는 팝업
  void _showFeedbackDialog(String title, String content, {required bool isSuccess}) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(title),
        content: Text(content),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text("다시 해볼게요"),
          )
        ],
      ),
    );
  }


  // ✅ 미션 완료 이동 (기존 로직 유지)
  Future<void> _completeMission(String resultMsg) async {
    if (!mounted) return;
    const UserStage currentUserStage = UserStage.rehab; 

    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => MissionCompleteScreen(
          mission: widget.mission,   
          userStage: currentUserStage,
          isBonusMission: widget.isBonusMission, 
        ),
      ),
    );

    if (mounted) {
      if (result != null) {
        Navigator.pop(context, result);
      } else {
        Navigator.pop(context);
      }
    }
  }

  // 단순 시뮬레이션 (Hold, Voice, Step 미션용)
  Future<void> _simulateProcessing(String msg) async {
    setState(() => _isAnalyzing = true);
    await Future.delayed(const Duration(seconds: 2)); 
    if (mounted) {
      setState(() => _isAnalyzing = false);
      _completeMission(msg);
    }
  }

  @override
  Widget build(BuildContext context) {
    final textColor = getTextColor(widget.weatherType);
    final missionType = widget.mission.type;

    return Scaffold(
      resizeToAvoidBottomInset: false,
      body: GestureDetector(
        onTap: () => FocusScope.of(context).unfocus(),
        child: Stack(
          children: [
            Container(decoration: BoxDecoration(gradient: getWeatherGradient(widget.weatherType))),
            SafeArea(
              child: Column(
                children: [
                  _buildHeader(textColor),
                  const Spacer(flex: 1),
                  _buildMissionTitle(),
                  const Spacer(flex: 1),
                  Expanded(
                    flex: 10,
                    child: Center(
                      child: _isAnalyzing 
                        ? _buildLoadingView() 
                        : _buildDynamicContent(missionType),
                    ),
                  ),
                  const Spacer(flex: 2),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(Color textColor) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
      child: Row(
        children: [
          IconButton(
            icon: Icon(Icons.arrow_back_ios_new, color: textColor), 
            onPressed: () => Navigator.pop(context)
          ),
          Text("미션 수행 중", style: TextStyle(color: textColor, fontSize: 18, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }

  Widget _buildMissionTitle() {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 8),
          decoration: BoxDecoration(color: Colors.black.withOpacity(0.6), borderRadius: BorderRadius.circular(20)),
          child: Text(widget.mission.title, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        ),
        const SizedBox(height: 15),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 40),
          child: Text(
            widget.mission.content,
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.white.withOpacity(0.9), fontSize: 16, height: 1.4),
          ),
        ),
      ],
    );
  }

  Widget _buildLoadingView() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: const [
        CircularProgressIndicator(color: Colors.white),
         SizedBox(height: 20),
        Text("AI가 확인하고 있어요...", style: TextStyle(color: Colors.white, fontSize: 16)),
      ],
    );
  }

  Widget _buildDynamicContent(MissionType type) {
    switch (type) {
      case MissionType.photo:
        return _buildPhotoMission();
      case MissionType.hold:
        return _buildHoldMission();
      case MissionType.text:
        return _buildTextMission();
      case MissionType.voice:
        return _buildVoiceMission();
      case MissionType.step:
        return _buildStepMission();
    }
  }

  // 📌 [UPDATE] 사진 미션 UI 수정 (카메라 연동 + 미리보기)
  Widget _buildPhotoMission() {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        GestureDetector(
          onTap: _pickImage, // 누르면 카메라 실행
          child: Container(
            width: 300, height: 350,
            decoration: BoxDecoration(
              color: Colors.black12,
              borderRadius: BorderRadius.circular(30),
              border: Border.all(color: Colors.white54, width: 2),
              image: _selectedImage != null 
                ? DecorationImage(image: FileImage(_selectedImage!), fit: BoxFit.cover) // 찍은 사진 보여주기
                : null,
            ),
            child: _selectedImage == null 
              ? const Center(child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.camera_alt_outlined, color: Colors.white54, size: 60),
                    SizedBox(height: 10),
                    Text("터치해서 사진 찍기", style: TextStyle(color: Colors.white70)),
                  ],
                ))
              : null,
          ),
        ),
        const SizedBox(height: 30),
        
        // 사진이 있을 때만 '제출하기' 버튼 활성화
        if (_selectedImage != null)
          GestureDetector(
            onTap: _submitPhotoMission, // AI 검증 실행
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 15),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(30),
              ),
              child: const Text("인증하기", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            ),
          )
        else
          const Text("사진을 찍어주세요", style: TextStyle(color: Colors.white54)),
      ],
    );
  }

  Widget _buildHoldMission() {
    return GestureDetector(
      onTapDown: (_) => _holdController.forward(),
      onTapUp: (_) => _holdController.status != AnimationStatus.completed ? _holdController.reverse() : null,
      onTapCancel: () => _holdController.reverse(),
      child: Stack(
        alignment: Alignment.center,
        children: [
          SizedBox(
            width: 200, height: 200,
            child: AnimatedBuilder(
              animation: _holdController,
              builder: (context, child) => CircularProgressIndicator(
                value: _holdController.value, strokeWidth: 15,
                valueColor: const AlwaysStoppedAnimation(Color(0xFF6BB8B0)),
                backgroundColor: Colors.white24,
              ),
            ),
          ),
          const Icon(Icons.fingerprint, size: 80, color: Colors.white),
          Positioned(
            bottom: -40,
            child: Text("꾹 눌러주세요", style: TextStyle(color: Colors.white.withOpacity(0.8))),
          )
        ],
      ),
    );
  }

  // 📌 [UPDATE] 텍스트 미션 UI (버튼 연결)
  Widget _buildTextMission() {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Container(
          width: 320,
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.2),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: Colors.white30),
          ),
          child: TextField(
            controller: _textController,
            maxLines: 5,
            style: const TextStyle(color: Colors.white),
            decoration: const InputDecoration(
              hintText: "여기에 당신의 이야기를 들려주세요...",
              hintStyle: TextStyle(color: Colors.white60),
              border: InputBorder.none,
            ),
          ),
        ),
        const SizedBox(height: 30),
        ElevatedButton.icon(
          onPressed: _submitTextMission, // 📌 AI 상담 연결
          icon: const Icon(Icons.send),
          label: const Text("이야기하기"),
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.white, foregroundColor: Colors.black,
            padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 15),
          ),
        )
      ],
    );
  }

  Widget _buildVoiceMission() {
    return GestureDetector(
      onLongPressStart: (_) => _voiceController.repeat(reverse: true),
      onLongPressEnd: (_) {
        _voiceController.stop();
        _simulateProcessing("목소리가 우주로 전송되었습니다.");
      },
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          AnimatedBuilder(
            animation: _voiceController,
            builder: (context, child) {
              return Container(
                width: 150 + (_voiceController.value * 50),
                height: 150 + (_voiceController.value * 50),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.white.withOpacity(0.2 - (_voiceController.value * 0.1)),
                ),
                child: child,
              );
            },
            child: Container(
              width: 150, height: 150,
              decoration: BoxDecoration(shape: BoxShape.circle, color: Colors.white.withOpacity(0.3)),
              child: const Icon(Icons.mic, size: 60, color: Colors.white),
            ),
          ),
          const SizedBox(height: 30),
          const Text("버튼을 누르고 마음껏 외치세요!", style: TextStyle(color: Colors.white70)),
        ],
      ),
    );
  }

  Widget _buildStepMission() {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const Icon(Icons.directions_walk, size: 80, color: Colors.white),
        const SizedBox(height: 20),
        Text(
          "${_currentSteps.toInt()} / ${_targetSteps.toInt()}", 
          style: const TextStyle(fontSize: 40, fontWeight: FontWeight.bold, color: Colors.white)
        ),
        const Text("걸음", style: TextStyle(color: Colors.white70)),
        const SizedBox(height: 30),
        
        Container(
          width: 300, height: 20,
          decoration: BoxDecoration(color: Colors.black26, borderRadius: BorderRadius.circular(10)),
          child: FractionallySizedBox(
            alignment: Alignment.centerLeft,
            widthFactor: (_currentSteps / _targetSteps).clamp(0.0, 1.0),
            child: Container(decoration: BoxDecoration(color: const Color(0xFF6BB8B0), borderRadius: BorderRadius.circular(10))),
          ),
        ),

        const SizedBox(height: 40),
        
        const Text("👇 테스트용: 슬라이더를 밀어서 걸어보세요", style: TextStyle(color: Colors.yellowAccent)),
        Slider(
          value: _currentSteps,
          min: 0, max: _targetSteps,
          activeColor: Colors.white,
          onChanged: (value) {
            setState(() => _currentSteps = value);
            if (_currentSteps >= _targetSteps && !_isAnalyzing) {
              _simulateProcessing("목표 걸음을 달성했습니다!");
            }
          },
        ),
      ],
    );
  }
}