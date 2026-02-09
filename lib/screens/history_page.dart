import 'package:flutter/material.dart';
import '../utils/theme_utils.dart'; // WeatherType, getTextColor, getWeatherGradient
import '../models/memory_model.dart';
import '../widgets/memory_card.dart';
import '../services/storage_service.dart';

class HistoryPage extends StatefulWidget {
  final WeatherType weatherType;
  final bool multiUser;
  const HistoryPage({super.key, required this.weatherType, this.multiUser = false});

  @override
  State<HistoryPage> createState() => _HistoryPageState();
}

class _HistoryPageState extends State<HistoryPage> {
  bool _isLoading = true;
  List<MemoryModel> _memories = [];
  List<Map<String, dynamic>> _users = [];
  int _selectedUserIndex = 0;

  @override
  void initState() {
    super.initState();
    _loadMemories();
  }

  Future<void> _loadMemories() async {
    setState(() => _isLoading = true);
    final entries = await StorageService.getMemoryEntries();
    final memories = entries.map(_mapToMemory).toList();
    if (widget.multiUser) {
      _users = _buildSampleUsers(memories);
      _selectedUserIndex = _selectedUserIndex.clamp(0, _users.isEmpty ? 0 : _users.length - 1);
      _memories = _selectedUserMemories();
    } else {
      if (memories.isEmpty) {
        memories.addAll(_buildTempMemories());
      }
      _memories = memories;
    }
    setState(() {
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
                            if (widget.multiUser) _buildUserSelector(textColor),
                            if (widget.multiUser) const SizedBox(height: 12),
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

  Widget _buildUserSelector(Color textColor) {
    if (_users.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.9),
          borderRadius: BorderRadius.circular(12),
        ),
        child: const Text("표시할 사용자가 없습니다.", style: TextStyle(color: Colors.black54)),
      );
    }
    return SizedBox(
      height: 90,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: _users.length,
        separatorBuilder: (_, __) => const SizedBox(width: 10),
        itemBuilder: (context, index) {
          final u = _users[index];
          final isSelected = index == _selectedUserIndex;
          return GestureDetector(
            onTap: () {
              setState(() {
                _selectedUserIndex = index;
                _memories = _selectedUserMemories();
              });
            },
            child: Container(
              width: 140,
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: isSelected ? Colors.white : Colors.white.withOpacity(0.85),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: isSelected ? const Color(0xFF6BB8B0) : Colors.black12, width: isSelected ? 2 : 1),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text("${u['nickname']}", style: const TextStyle(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 6),
                  Text("Grade ${u['grade']}", style: const TextStyle(fontSize: 12)),
                  const Spacer(),
                  Text("${u['recent']}", style: const TextStyle(fontSize: 11, color: Colors.black54), maxLines: 1, overflow: TextOverflow.ellipsis),
                ],
              ),
            ),
          );
        },
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

  List<Map<String, dynamic>> _buildSampleUsers(List<MemoryModel> localMemories) {
    return [
      {
        'nickname': '로컬 사용자',
        'grade': 'C',
        'recent': localMemories.isNotEmpty ? localMemories.first.note : '기록 없음',
        'memories': localMemories.isNotEmpty ? localMemories : _buildTempMemories(),
      },
      {
        'nickname': '유나',
        'grade': 'C',
        'recent': '피곤하지만 괜찮았던 하루',
        'memories': _buildTempMemories(),
      },
      {
        'nickname': '민준',
        'grade': 'B',
        'recent': '외출을 조금 늘리고 싶음',
        'memories': _buildTempMemories(),
      },
      {
        'nickname': '서연',
        'grade': 'D',
        'recent': '불안하지만 견딤',
        'memories': _buildTempMemories(),
      },
    ];
  }

  List<MemoryModel> _selectedUserMemories() {
    if (_users.isEmpty) return [];
    return List<MemoryModel>.from(_users[_selectedUserIndex]['memories'] as List);
  }
}
