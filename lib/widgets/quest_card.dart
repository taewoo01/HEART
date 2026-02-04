import 'package:flutter/material.dart';
import '../models/mission_model.dart';

class QuestCard extends StatelessWidget {
  final MissionModel mission;

  const QuestCard({super.key, required this.mission});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // 말풍선 꼬리 (디자인 요소)
        Icon(Icons.arrow_drop_up, size: 45, color: Colors.white.withOpacity(0.95)),
        
        // 퀘스트 카드 본체
        Container(
          width: double.infinity,
          margin: const EdgeInsets.symmetric(horizontal: 30),
          padding: const EdgeInsets.all(25),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.95),
            borderRadius: BorderRadius.circular(25),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.1),
                blurRadius: 20,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: Column(
            children: [
              // 1. 헤더: 난이도 뱃지 + 제목
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  _buildDifficultyBadge(mission.difficulty),
                  const SizedBox(width: 10),
                  Text(
                    mission.title,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF2D3436),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 15),
              Divider(color: Colors.grey.withOpacity(0.2), thickness: 1),
              const SizedBox(height: 15),

              // 2. 내용 (행동 지침)
              Text(
                mission.content,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 16,
                  height: 1.6,
                  color: Color(0xFF4A4A4A),
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 20),

              // 3. 하단 정보 (XP 보상 + 격려 메시지)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 10),
                decoration: BoxDecoration(
                  color: const Color(0xFFF1F2F6),
                  borderRadius: BorderRadius.circular(15),
                ),
                child: Column(
                  children: [
                    // XP 보상
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.star_rounded, color: Color(0xFFFFC312), size: 20),
                        const SizedBox(width: 5),
                        Text(
                          "보상 XP +${mission.xp}",
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF2F3542),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 5),
                    // 격려 메시지
                    Text(
                      "\"${mission.message}\"",
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontSize: 12,
                        fontStyle: FontStyle.italic,
                        color: Color(0xFF747D8C),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  // 난이도에 따른 뱃지 디자인
  Widget _buildDifficultyBadge(String rank) {
    Color badgeColor;
    switch (rank) {
      case 'S': badgeColor = const Color(0xFF8E44AD); break; // 보라
      case 'A': badgeColor = const Color(0xFFE74C3C); break; // 빨강
      case 'B': badgeColor = const Color(0xFFE67E22); break; // 주황
      case 'C': badgeColor = const Color(0xFFF1C40F); break; // 노랑
      default: badgeColor = const Color(0xFF2ECC71); break;  // 초록 (D, E, F)
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: badgeColor.withOpacity(0.15),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: badgeColor.withOpacity(0.5)),
      ),
      child: Text(
        "$rank급",
        style: TextStyle(
          color: badgeColor,
          fontWeight: FontWeight.bold,
          fontSize: 12,
        ),
      ),
    );
  }
}