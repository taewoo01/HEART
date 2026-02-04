import 'package:flutter/material.dart';
import '../utils/theme_utils.dart'; // WeatherType, getTextColor, getWeatherGradient
import '../models/memory_model.dart';
import '../widgets/memory_card.dart';

class HistoryPage extends StatelessWidget {
  final WeatherType weatherType;
  const HistoryPage({super.key, required this.weatherType});

  @override
  Widget build(BuildContext context) {
    final textColor = getTextColor(weatherType);

    // 더미 데이터 생성 (나중에는 DB나 API에서 가져오는 부분)
    final List<MemoryModel> memories = [
      MemoryModel(date: "3월 24일", day: "오늘", icon: Icons.wb_sunny, note: "햇살이 따뜻했던 날"),
      MemoryModel(date: "3월 23일", day: "어제", icon: Icons.umbrella, note: "빗소리가 좋았다"),
      MemoryModel(date: "3월 21일", day: "금요일", icon: Icons.cloud, note: "조금 우울했지만 괜찮아"),
      MemoryModel(date: "3월 20일", day: "목요일", icon: Icons.ac_unit, note: "갑자기 눈이 내렸다"),
    ];

    return Scaffold(
      body: Stack(
        children: [
          // 배경
          Container(
            decoration: BoxDecoration(
              gradient: getWeatherGradient(weatherType),
            ),
          ),
          SafeArea(
            child: Column(
              children: [
                // 헤더 영역 (간단해서 파일 내부에 private 위젯으로 둬도 무방)
                _buildHeader(context, textColor),

                // 리스트 영역
                Expanded(
                  child: ListView.builder(
                    padding: const EdgeInsets.all(20),
                    itemCount: memories.length,
                    itemBuilder: (context, index) {
                      return MemoryCard(memory: memories[index]);
                    },
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // 헤더 위젯 (코드가 짧아서 private 메서드로 추출)
  Widget _buildHeader(BuildContext context, Color textColor) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
      child: Row(
        children: [
          IconButton(
            icon: Icon(Icons.arrow_back_ios_new, color: textColor),
            onPressed: () => Navigator.pop(context),
          ),
          Text(
            "마음 기록장",
            style: TextStyle(
              color: textColor,
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }
}