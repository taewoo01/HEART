import 'package:flutter/material.dart';
import '../utils/theme_utils.dart'; // WeatherType, getTextColor, getWeatherGradient
import '../models/memory_model.dart';
import '../widgets/memory_card.dart';
import '../services/storage_service.dart';

class HistoryPage extends StatefulWidget {
  final WeatherType weatherType;
  const HistoryPage({super.key, required this.weatherType});

  @override
  State<HistoryPage> createState() => _HistoryPageState();
}

class _HistoryPageState extends State<HistoryPage> {
  bool _isLoading = true;
  List<MemoryModel> _memories = [];
  Map<String, dynamic>? _profile;
  List<Map<String, dynamic>> _voiceSignals = [];

  @override
  void initState() {
    super.initState();
    _loadMemories();
  }

  Future<void> _loadMemories() async {
    setState(() => _isLoading = true);
    final entries = await StorageService.getMemoryEntries();
    final profile = await StorageService.getUserProfile();
    final voiceSignals = await StorageService.getVoiceSignals();
    final memories = entries.map(_mapToMemory).toList();
    if (memories.isEmpty) {
      memories.addAll(_buildTempMemories());
    }
    setState(() {
      _memories = memories;
      _profile = profile;
      _voiceSignals = voiceSignals;
      _isLoading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final textColor = getTextColor(widget.weatherType);

    return Scaffold(
      body: Stack(
        children: [
          // 배경
          Container(
            decoration: BoxDecoration(
              gradient: getWeatherGradient(widget.weatherType),
            ),
          ),
          SafeArea(
            child: Column(
              children: [
                // 헤더 영역 (간단해서 파일 내부에 private 위젯으로 둬도 무방)
                _buildHeader(context, textColor),

                // 리스트 영역
                Expanded(
                  child: _isLoading
                      ? const Center(child: CircularProgressIndicator(color: Colors.white))
                      : ListView(
                          padding: const EdgeInsets.all(20),
                          children: [
                            _buildAnalysisReport(textColor),
                            const SizedBox(height: 16),
                            if (_memories.isEmpty)
                              const Center(
                                child: Padding(
                                  padding: EdgeInsets.symmetric(vertical: 40),
                                  child: Text(
                                    "아직 기록이 없어요.",
                                    style: TextStyle(color: Colors.white70),
                                  ),
                                ),
                              )
                            else
                              ..._memories.map((m) => MemoryCard(memory: m)),
                          ],
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

  MemoryModel _mapToMemory(Map<String, dynamic> entry) {
    final ts = (entry['ts'] ?? 0) as int;
    final note = (entry['note'] ?? '').toString();
    final icon = _iconFromName((entry['icon'] ?? 'note').toString());
    final dt = DateTime.fromMillisecondsSinceEpoch(ts);
    final date = "${dt.month}월 ${dt.day}일";
    final day = _dayLabel(dt);

    return MemoryModel(
      date: date,
      day: day,
      icon: icon,
      note: note.isNotEmpty ? note : "기록",
    );
  }

  String _dayLabel(DateTime dt) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final target = DateTime(dt.year, dt.month, dt.day);
    final diff = today.difference(target).inDays;
    if (diff == 0) return "오늘";
    if (diff == 1) return "어제";
    const weekdays = ["월요일", "화요일", "수요일", "목요일", "금요일", "토요일", "일요일"];
    return weekdays[dt.weekday - 1];
  }

  IconData _iconFromName(String name) {
    switch (name) {
      case 'camera':
        return Icons.camera_alt;
      case 'fingerprint':
        return Icons.fingerprint;
      case 'edit':
        return Icons.edit_note;
      case 'mic':
        return Icons.mic;
      case 'walk':
        return Icons.directions_walk;
      default:
        return Icons.note_alt;
    }
  }

  Widget _buildAnalysisReport(Color textColor) {
    final profile = _profile ?? {};
    final summary = (profile['chat_summary'] ?? '').toString();
    final keywords = (profile['chat_keywords'] as List?)?.map((e) => e.toString()).toList() ?? <String>[];
    final reason = (profile['analysis_reason'] ?? '').toString();
    final perSoc = profile['per_soc'] ?? 0;
    final perIso = profile['per_iso'] ?? 0;
    final perEmo = profile['per_emo'] ?? 0;

    final metrics = _buildVoiceMetrics();

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.9),
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.08),
            blurRadius: 12,
            offset: const Offset(0, 6),
          )
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            "AI 분석 리포트 (최근 7일)",
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: textColor,
            ),
          ),
          const SizedBox(height: 10),
          _buildChipRow("HQ-25", [
            "대인기피 ${perSoc}%",
            "고립 ${perIso}%",
            "정서 ${perEmo}%",
          ]),
          const SizedBox(height: 8),
          _buildChipRow("음성 신호", [
            "말한 횟수 ${metrics['count']}",
            "평균 길이 ${metrics['avgMs']}ms",
            "평균 글자수 ${metrics['avgLen']}",
            "야간 비율 ${metrics['nightRatio']}%",
          ]),
          const SizedBox(height: 8),
          if (summary.isNotEmpty)
            _buildLabeledText("대화 요약", summary)
          else
            _buildLabeledText("대화 요약", "아직 요약이 없습니다."),
          const SizedBox(height: 6),
          _buildLabeledText(
            "감정 키워드",
            keywords.isNotEmpty ? keywords.join(", ") : "키워드가 아직 없습니다.",
          ),
          const SizedBox(height: 6),
          _buildLabeledText(
            "등급 근거",
            reason.isNotEmpty ? reason : "근거 데이터가 아직 없습니다.",
          ),
        ],
      ),
    );
  }

  Map<String, dynamic> _buildVoiceMetrics() {
    final now = DateTime.now();
    final weekAgo = now.subtract(const Duration(days: 7));
    final recent = _voiceSignals.where((e) {
      final ts = (e['ts'] ?? 0) as int;
      return DateTime.fromMillisecondsSinceEpoch(ts).isAfter(weekAgo);
    }).toList();

    if (recent.isEmpty) {
      return {
        'count': 0,
        'avgMs': 0,
        'avgLen': 0,
        'nightRatio': 0,
      };
    }

    int totalMs = 0;
    int totalLen = 0;
    int nightCount = 0;
    for (final e in recent) {
      totalMs += (e['duration_ms'] ?? 0) as int;
      totalLen += (e['transcript_len'] ?? 0) as int;
      final ts = (e['ts'] ?? 0) as int;
      final dt = DateTime.fromMillisecondsSinceEpoch(ts);
      if (dt.hour >= 22 || dt.hour <= 5) nightCount++;
    }
    final count = recent.length;
    return {
      'count': count,
      'avgMs': (totalMs / count).round(),
      'avgLen': (totalLen / count).round(),
      'nightRatio': ((nightCount / count) * 100).round(),
    };
  }

  Widget _buildChipRow(String label, List<String> items) {
    return Wrap(
      spacing: 6,
      runSpacing: 6,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        Text(
          "$label:",
          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
        ),
        ...items.map((t) => Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: const Color(0xFFE9EEF2),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                t,
                style: const TextStyle(fontSize: 12, color: Colors.black87),
              ),
            )),
      ],
    );
  }

  Widget _buildLabeledText(String label, String text) {
    return RichText(
      text: TextSpan(
        style: const TextStyle(fontSize: 12, color: Colors.black87, height: 1.4),
        children: [
          TextSpan(
            text: "$label: ",
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
          TextSpan(text: text),
        ],
      ),
    );
  }

  List<MemoryModel> _buildTempMemories() {
    final now = DateTime.now();
    final samples = <Map<String, dynamic>>[
      {"offset": 0, "icon": Icons.wb_sunny, "note": "햇살이 따뜻했던 날"},
      {"offset": 1, "icon": Icons.umbrella, "note": "빗소리가 좋았다"},
      {"offset": 2, "icon": Icons.cloud, "note": "조금 우울했지만 괜찮아"},
      {"offset": 3, "icon": Icons.ac_unit, "note": "갑자기 눈이 내렸다"},
    ];

    return samples.map((s) {
      final dt = now.subtract(Duration(days: s["offset"] as int));
      return MemoryModel(
        date: "${dt.month}월 ${dt.day}일",
        day: _dayLabel(dt),
        icon: s["icon"] as IconData,
        note: s["note"] as String,
      );
    }).toList();
  }
}
