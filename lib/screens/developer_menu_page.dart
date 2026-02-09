import 'package:flutter/material.dart';
import '../utils/theme_utils.dart';
import 'admin_dashboard_page.dart';
import 'history_page.dart';
import 'local_data_screen.dart';
import 'natural_chat_screen.dart';

class DeveloperMenuPage extends StatelessWidget {
  final WeatherType weatherType;
  const DeveloperMenuPage({super.key, required this.weatherType});

  @override
  Widget build(BuildContext context) {
    final textColor = getTextColor(weatherType);
    return Scaffold(
      body: Stack(
        children: [
          Container(decoration: BoxDecoration(gradient: getWeatherGradient(weatherType))),
          SafeArea(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
              children: [
                Row(
                  children: [
                    IconButton(
                      icon: Icon(Icons.arrow_back_ios_new, color: textColor),
                      onPressed: () => Navigator.pop(context),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      "개발자 메뉴",
                      style: TextStyle(color: textColor, fontSize: 20, fontWeight: FontWeight.w800),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                _sectionTitle("관리자", textColor),
                _menuTile(
                  context,
                  icon: Icons.dashboard_customize_rounded,
                  title: "관리자 대시보드 (다중 사용자)",
                  subtitle: "DB 연결 시 여러 사용자 데이터를 한눈에",
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => AdminDashboardPage(weatherType: weatherType)),
                  ),
                ),
                const SizedBox(height: 12),
                _sectionTitle("데이터 (개별 사용자)", textColor),
                _menuTile(
                  context,
                  icon: Icons.analytics_outlined,
                  title: "기록 모아보기",
                  subtitle: "다중 사용자 기록 보기",
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => HistoryPage(weatherType: weatherType, multiUser: true)),
                  ),
                ),
                _menuTile(
                  context,
                  icon: Icons.storage_rounded,
                  title: "로컬 데이터",
                  subtitle: "LocalDataScreen (개발자용)",
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const LocalDataScreen(enablePlayback: true, multiUser: true)),
                  ),
                ),
                const SizedBox(height: 12),
                _sectionTitle("테스트", textColor),
                _menuTile(
                  context,
                  icon: Icons.chat_bubble_outline,
                  title: "대화 기록 화면",
                  subtitle: "마이크 없음 (기록 확인용)",
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const NaturalChatScreen.readOnly()),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _sectionTitle(String text, Color textColor) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(
        text,
        style: TextStyle(color: textColor, fontWeight: FontWeight.bold),
      ),
    );
  }

  Widget _menuTile(
    BuildContext context, {
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return Card(
      elevation: 2,
      child: ListTile(
        leading: Icon(icon),
        title: Text(title),
        subtitle: Text(subtitle),
        trailing: const Icon(Icons.chevron_right),
        onTap: onTap,
      ),
    );
  }
}
