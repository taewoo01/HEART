import 'package:flutter/material.dart';
import '../models/mission_model.dart';
import '../models/user_stage.dart';
import '../services/ai_service.dart'; // 📌 AI 서비스 import

class MissionCompleteScreen extends StatefulWidget {
  final MissionModel mission;
  final UserStage userStage;
  final bool isBonusMission;
  
  // 📌 이전 화면(MissionPage)에서 AI가 해준 칭찬 멘트
  final String? customMessage; 

  const MissionCompleteScreen({
    super.key, 
    required this.mission,
    required this.userStage,
    this.isBonusMission = false,
    this.customMessage,
  });

  @override
  State<MissionCompleteScreen> createState() => _MissionCompleteScreenState();
}

class _MissionCompleteScreenState extends State<MissionCompleteScreen> {
  bool _isLoadingBonus = false; // 보너스 미션 로딩 상태

  // 🎁 보너스 미션 받기 (AI 호출)
  Future<void> _fetchAndStartBonusMission() async {
    setState(() => _isLoadingBonus = true);

    try {
      // 📌 [수정됨] 인자를 모두 제거했습니다!
      // AIService 내부에서 StorageService를 통해 레벨을 알아서 확인합니다.
      final MissionModel? bonusMission = await AIService().getBonusMission();

      if (!mounted) return;
      setState(() => _isLoadingBonus = false);

      if (bonusMission != null) {
        // 📌 새로운 미션을 가지고 메인으로 돌아감 (MainScreen에서 처리)
        Navigator.pop(context, bonusMission);
      } else {
        _showErrorSnackBar("보너스 미션을 준비하지 못했어요. 잠시 쉬어가라는 뜻인가 봐요.");
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoadingBonus = false);
        _showErrorSnackBar("네트워크 연결을 확인해주세요.");
      }
    }
  }

  void _showErrorSnackBar(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), backgroundColor: Colors.redAccent.withOpacity(0.8)),
    );
  }

  @override
  Widget build(BuildContext context) {
    String title = "";
    String message = "";
    List<Widget> actionButtons = [];

    // 1. 멘트 설정 (AI 메시지 우선)
    if (widget.customMessage != null && widget.customMessage!.isNotEmpty) {
      title = "참 잘했어요!";
      message = widget.customMessage!;
    } else {
      // 기본 멘트
      switch (widget.userStage) {
        case UserStage.emergency:
          title = "오늘의 미션 완료";
          message = "충분합니다. 오늘의 할 일을 완벽하게 끝냈어요.\n푹 쉬는 게 지금의 가장 중요한 미션입니다.";
          break;
        case UserStage.rehab:
          title = widget.isBonusMission ? "오늘의 재활 완료!" : "미션 성공!";
          message = widget.isBonusMission 
              ? "두 번의 미션을 모두 훌륭하게 해내셨어요.\n이제 편안하게 휴식을 취하세요."
              : "컨디션이 좀 괜찮으신가요?\n원하시면 가벼운 보너스 미션도 준비되어 있어요.";
          break;
        case UserStage.growth:
          title = "훌륭합니다!";
          message = "에너지가 넘치시네요! 챌린지 모드에서 한계를 시험해보시겠어요?";
          break;
      }
    }

    // 2. 버튼 구성
    if (widget.userStage == UserStage.emergency || widget.isBonusMission) {
      // 더 이상 할 게 없는 경우 (휴식 권장)
      actionButtons = [
        _buildMainButton(context, "네, 오늘은 푹 쉴게요 🌙", true),
      ];
    } else {
      // 보너스 미션 제안 가능 (재활/성장 단계 + 첫 미션 완료 시)
      actionButtons = [
        _buildMainButton(context, "오늘은 여기까지 할래요", true),
        const SizedBox(height: 15),
        
        // 로딩 중이면 로딩바, 아니면 버튼
        _isLoadingBonus 
          ? const CircularProgressIndicator(color: Colors.white)
          : _buildSubButton("보너스 미션 받기 ✨"),
      ];
    }

    return Scaffold(
      backgroundColor: const Color(0xFF6BB8B0),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 30),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.check_circle_rounded, size: 100, color: Colors.white),
              const SizedBox(height: 30),
              
              Text(
                title,
                style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: Colors.white),
              ),
              const SizedBox(height: 15),
              
              Text(
                message,
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 16, color: Colors.white70, height: 1.5),
              ),
              const SizedBox(height: 40),
              
              // 경험치 카드
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 20),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 10, offset: const Offset(0, 5))
                  ]
                ),
                child: Column(
                  children: [
                    Text(
                      "+ ${widget.mission.xp} XP",
                      style: const TextStyle(fontSize: 40, fontWeight: FontWeight.bold, color: Color(0xFF6BB8B0)),
                    ),
                    const Text("경험치 획득!", style: TextStyle(color: Colors.grey)),
                  ],
                ),
              ),
              const Spacer(),
              
              ...actionButtons,
              
              const SizedBox(height: 50),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMainButton(BuildContext context, String text, bool goHome) {
    return SizedBox(
      width: double.infinity,
      height: 55,
      child: ElevatedButton(
        onPressed: () {
          // true를 반환하면 MainScreen에서 '완료 상태(휴식)'로 처리
          Navigator.pop(context, true); 
        },
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.white,
          foregroundColor: const Color(0xFF6BB8B0),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
          elevation: 0,
        ),
        child: Text(text, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
      ),
    );
  }

  Widget _buildSubButton(String text) {
    return SizedBox(
      width: double.infinity,
      height: 55,
      child: OutlinedButton(
        onPressed: _fetchAndStartBonusMission, // AI 호출
        style: OutlinedButton.styleFrom(
          side: const BorderSide(color: Colors.white, width: 2),
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
        ),
        child: Text(text, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
      ),
    );
  }
}