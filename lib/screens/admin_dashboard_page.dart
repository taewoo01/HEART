import 'dart:io';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import '../utils/theme_utils.dart';
import '../services/storage_service.dart';

class AdminDashboardPage extends StatefulWidget {
  final WeatherType weatherType;
  const AdminDashboardPage({super.key, required this.weatherType});

  @override
  State<AdminDashboardPage> createState() => _AdminDashboardPageState();
}

class _AdminDashboardPageState extends State<AdminDashboardPage> {
  bool _isLoading = true;
  Map<String, dynamic>? _profile;
  List<Map<String, dynamic>> _voiceSignals = [];
  List<FileSystemEntity> _audioFiles = [];
  List<Map<String, dynamic>> _users = [];
  int _selectedUserIndex = 0;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    final profile = await StorageService.getUserProfile();
    final voiceSignals = await StorageService.getVoiceSignals();
    final dir = await getApplicationDocumentsDirectory();
    final files = dir
        .listSync()
        .where((f) => f is File && f.path.contains("voice_") && f.path.endsWith(".m4a"))
        .toList();
    files.sort((a, b) => b.statSync().modified.compareTo(a.statSync().modified));
    final users = _buildSampleUsers(profile);
    setState(() {
      _profile = profile;
      _voiceSignals = voiceSignals;
      _audioFiles = files;
      _users = users;
      _selectedUserIndex = _selectedUserIndex.clamp(0, users.isEmpty ? 0 : users.length - 1);
      _isLoading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final textColor = getTextColor(widget.weatherType);
    return Scaffold(
      body: Stack(
        children: [
          Container(decoration: BoxDecoration(gradient: getWeatherGradient(widget.weatherType))),
          SafeArea(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator(color: Colors.white))
                : ListView(
                    padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
                    children: [
                      _buildHeader(context, textColor),
                      const SizedBox(height: 14),
                      _buildHero(textColor),
                      const SizedBox(height: 16),
                      _buildDashboardSummary(textColor),
                      const SizedBox(height: 16),
                      _buildUserSelector(textColor),
                      const SizedBox(height: 16),
                      _buildUserTable(textColor),
                      const SizedBox(height: 16),
                      _buildAnalysisReportCard(textColor),
                      const SizedBox(height: 16),
                      _buildLocalDataCard(textColor),
                      const SizedBox(height: 16),
                      _buildSignalsCard(textColor),
                      const SizedBox(height: 16),
                      _buildAudioSummaryCard(textColor),
                    ],
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader(BuildContext context, Color textColor) {
    return Row(
      children: [
        IconButton(
          icon: Icon(Icons.arrow_back_ios_new, color: textColor),
          onPressed: () => Navigator.pop(context),
        ),
        const SizedBox(width: 6),
        Text(
          "관리자 대시보드",
          style: TextStyle(
            color: textColor,
            fontSize: 20,
            fontWeight: FontWeight.w800,
            letterSpacing: 0.2,
          ),
        ),
        const Spacer(),
        IconButton(
          icon: Icon(Icons.refresh, color: textColor),
          onPressed: _loadData,
        ),
      ],
    );
  }

  Widget _buildHero(Color textColor) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.12),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.white24),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            "다중 사용자 데이터 대시보드 (미리보기)",
            style: TextStyle(color: textColor, fontSize: 16, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 6),
          Text(
            "DB 연결 시 여러 사용자의 대화·미션·감정 신호를 통합해 한눈에 분석합니다.",
            style: TextStyle(color: textColor.withOpacity(0.85), height: 1.4, fontSize: 12),
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: const [
              _Pill(label: "DEMO", color: Color(0xFF0F9D58)),
              _Pill(label: "DB 연결 전", color: Color(0xFF3949AB)),
              _Pill(label: "다중 사용자", color: Color(0xFF00897B)),
              _Pill(label: "음성 신호", color: Color(0xFF6A1B9A)),
              _Pill(label: "AI 리포트", color: Color(0xFF5E35B1)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildAnalysisReportCard(Color textColor) {
    final user = _selectedUser();
    final summary = (user['chat_summary'] ?? '').toString();
    final keywords = (user['chat_keywords'] as List?)?.map((e) => e.toString()).toList() ?? <String>[];
    final reason = (user['analysis_reason'] ?? '').toString();
    final perSoc = user['per_soc'] ?? 0;
    final perIso = user['per_iso'] ?? 0;
    final perEmo = user['per_emo'] ?? 0;

    return _glassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _sectionTitle("AI 분석 리포트 (선택된 사용자)", textColor),
          const SizedBox(height: 8),
          _chipRow("HQ-25", [
            "대인기피 ${perSoc}%",
            "고립 ${perIso}%",
            "정서 ${perEmo}%",
          ]),
          const SizedBox(height: 8),
          _labeledText("대화 요약", summary.isNotEmpty ? summary : "아직 요약이 없습니다."),
          const SizedBox(height: 6),
          _labeledText(
            "감정 키워드",
            keywords.isNotEmpty ? keywords.join(", ") : "키워드가 아직 없습니다.",
          ),
          const SizedBox(height: 6),
          _labeledText("등급 근거", reason.isNotEmpty ? reason : "근거 데이터가 아직 없습니다."),
        ],
      ),
    );
  }

  Widget _buildLocalDataCard(Color textColor) {
    final profile = _selectedUser();
    return _glassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _sectionTitle("사용자 프로파일 (로컬 샘플)", textColor),
          const SizedBox(height: 8),
          if (profile.isEmpty) const Text("저장된 사용자 데이터가 없습니다.", style: TextStyle(fontSize: 12))
          else ...[
            _kv("닉네임", "${profile['nickname'] ?? '-'}"),
            _kv("위치", "${profile['location'] ?? '-'}"),
            _kv("등급", "${profile['grade'] ?? '-'}"),
            _kv("레벨", "${profile['level'] ?? '-'}"),
          ],
        ],
      ),
    );
  }

  Widget _buildSignalsCard(Color textColor) {
    final metrics = _buildVoiceMetrics();
    return _glassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _sectionTitle("음성 신호 요약 (선택된 사용자)", textColor),
          const SizedBox(height: 8),
          _chipRow("최근 7일", [
            "말한 횟수 ${metrics['count']}",
            "평균 길이 ${metrics['avgMs']}ms",
            "평균 글자수 ${metrics['avgLen']}",
            "야간 비율 ${metrics['nightRatio']}%",
          ]),
          const SizedBox(height: 8),
          if (_voiceSignals.isEmpty)
            const Text("저장된 음성 신호가 없습니다.", style: TextStyle(fontSize: 12))
          else
            ..._voiceSignals.take(3).map((e) {
              final ts = (e['ts'] ?? 0) as int;
              final dt = DateTime.fromMillisecondsSinceEpoch(ts);
              final duration = (e['duration_ms'] ?? 0) as int;
              final len = (e['transcript_len'] ?? 0) as int;
              final hasSpeech = (e['has_speech'] ?? false) as bool;
              return Padding(
                padding: const EdgeInsets.only(top: 6),
                child: Text(
                  "${dt.month}/${dt.day} ${dt.hour}:${dt.minute.toString().padLeft(2, '0')} · ${duration}ms · $len 글자 · 말함 $hasSpeech",
                  style: const TextStyle(fontSize: 12),
                ),
              );
            }),
        ],
      ),
    );
  }

  Widget _buildAudioSummaryCard(Color textColor) {
    final samples = _selectedAudioSamples();
    final totalCount = samples.length;
    int totalKb = 0;
    for (final s in samples) {
      totalKb += (s['size_kb'] ?? 0) as int;
    }
    return _glassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _sectionTitle("녹음 파일 요약 (선택된 사용자)", textColor),
          const SizedBox(height: 8),
          _chipRow("로컬 저장", [
            "파일 수 $totalCount",
            "총 용량 ${totalKb}KB",
          ]),
          const SizedBox(height: 8),
          if (samples.isEmpty)
            const Text("저장된 녹음 파일이 없습니다.", style: TextStyle(fontSize: 12))
          else
            ...samples.take(3).map((s) {
              return Padding(
                padding: const EdgeInsets.only(top: 6),
                child: Text(
                  "${s['name']} · ${s['modified']} · ${s['size_kb']}KB",
                  style: const TextStyle(fontSize: 12),
                ),
              );
            }),
        ],
      ),
    );
  }

  Widget _glassCard({required Widget child}) {
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
      child: child,
    );
  }

  Widget _sectionTitle(String text, Color textColor) {
    return Text(
      text,
      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.black87),
    );
  }

  Widget _chipRow(String label, List<String> items) {
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

  Widget _labeledText(String label, String text) {
    return RichText(
      text: TextSpan(
        style: const TextStyle(fontSize: 12, color: Colors.black87, height: 1.4),
        children: [
          TextSpan(text: "$label: ", style: const TextStyle(fontWeight: FontWeight.bold)),
          TextSpan(text: text),
        ],
      ),
    );
  }

  Widget _kv(String k, String v) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Text("$k: $v", style: const TextStyle(fontSize: 12)),
    );
  }

  Map<String, dynamic> _buildVoiceMetrics() {
    final selected = _selectedUser();
    if (selected.isNotEmpty && selected['voice_metrics'] is Map) {
      return Map<String, dynamic>.from(selected['voice_metrics'] as Map);
    }
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

  Widget _buildDashboardSummary(Color textColor) {
    final totalUsers = _users.length;
    final activeUsers = _users.where((u) => (u['active'] ?? false) == true).length;
    final highRisk = _users.where((u) {
      final perSoc = (u['per_soc'] ?? 0) as int;
      final perIso = (u['per_iso'] ?? 0) as int;
      final perEmo = (u['per_emo'] ?? 0) as int;
      return perSoc >= 60 || perIso >= 60 || perEmo >= 60;
    }).length;

    return _glassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _sectionTitle("대시보드 요약", textColor),
          const SizedBox(height: 8),
          _chipRow("전체", [
            "총 사용자 $totalUsers",
            "활성 사용자 $activeUsers",
            "고위험 $highRisk",
          ]),
        ],
      ),
    );
  }

  Widget _buildUserSelector(Color textColor) {
    if (_users.isEmpty) {
      return _glassCard(
        child: const Text("표시할 사용자가 없습니다.", style: TextStyle(fontSize: 12)),
      );
    }
    return _glassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _sectionTitle("사용자 목록", textColor),
          const SizedBox(height: 8),
          SizedBox(
            height: 110,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: _users.length,
              separatorBuilder: (_, __) => const SizedBox(width: 10),
              itemBuilder: (context, index) {
                final u = _users[index];
                final isSelected = index == _selectedUserIndex;
                return GestureDetector(
                  onTap: () => setState(() => _selectedUserIndex = index),
                  child: Container(
                    width: 150,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: isSelected ? Colors.white : Colors.white.withOpacity(0.85),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color: isSelected ? const Color(0xFF6BB8B0) : Colors.black12,
                        width: isSelected ? 2 : 1,
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          "${u['nickname'] ?? '사용자'}",
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 6),
                        Text("Grade ${u['grade'] ?? '-'}", style: const TextStyle(fontSize: 12)),
                        const SizedBox(height: 4),
                        Text("HQ ${u['per_soc'] ?? 0}/${u['per_iso'] ?? 0}/${u['per_emo'] ?? 0}", style: const TextStyle(fontSize: 11)),
                        const Spacer(),
                        Text(
                          (u['active'] ?? false) ? "활성" : "비활성",
                          style: TextStyle(
                            fontSize: 11,
                            color: (u['active'] ?? false) ? const Color(0xFF2ECC71) : Colors.grey,
                          ),
                        ),
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

  Widget _buildUserTable(Color textColor) {
    if (_users.isEmpty) return const SizedBox.shrink();
    return _glassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _sectionTitle("사용자 요약 테이블", textColor),
          const SizedBox(height: 8),
          ..._users.map((u) {
            final index = _users.indexOf(u);
            final isSelected = index == _selectedUserIndex;
            return Padding(
              padding: const EdgeInsets.symmetric(vertical: 6),
              child: InkWell(
                borderRadius: BorderRadius.circular(8),
                onTap: () => setState(() => _selectedUserIndex = index),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 6),
                  decoration: BoxDecoration(
                    color: isSelected ? const Color(0xFFE9F5F3) : Colors.transparent,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    children: [
                      Expanded(flex: 2, child: Text("${u['nickname'] ?? '-'}", style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold))),
                      Expanded(flex: 1, child: Text("G ${u['grade'] ?? '-'}", style: const TextStyle(fontSize: 12))),
                      Expanded(flex: 2, child: Text("HQ ${u['per_soc'] ?? 0}/${u['per_iso'] ?? 0}/${u['per_emo'] ?? 0}", style: const TextStyle(fontSize: 11))),
                      Expanded(flex: 3, child: Text("${u['recent_summary'] ?? '요약 없음'}", style: const TextStyle(fontSize: 11, color: Colors.black54))),
                    ],
                  ),
                ),
              ),
            );
          }),
        ],
      ),
    );
  }

  Map<String, dynamic> _selectedUser() {
    if (_users.isEmpty) return {};
    return _users[_selectedUserIndex];
  }

  List<Map<String, dynamic>> _selectedAudioSamples() {
    final selected = _selectedUser();
    if (selected.isNotEmpty && selected['voice_samples'] is List) {
      return List<Map<String, dynamic>>.from(selected['voice_samples'] as List);
    }
    // 로컬 사용자일 경우 실제 파일로 샘플 생성
    return _audioFiles.map((f) {
      final stat = f.statSync();
      final sizeKb = (stat.size / 1024).round();
      final name = f.path.split(Platform.pathSeparator).last;
      return {
        'name': name,
        'modified': stat.modified,
        'size_kb': sizeKb,
      };
    }).toList();
  }

  List<Map<String, dynamic>> _buildSampleUsers(Map<String, dynamic>? localProfile) {
    final List<Map<String, dynamic>> users = [
      {
        'nickname': '유나',
        'grade': 'C',
        'level': 8,
        'location': '서울',
        'per_soc': 55,
        'per_iso': 42,
        'per_emo': 63,
        'chat_summary': '오늘은 조금 피곤하지만 견딜 만하다고 말함.',
        'chat_keywords': ['피곤', '무기력'],
        'analysis_reason': '정서 지표가 높아 위로 중심 미션이 필요.',
        'recent_summary': '피곤하지만 괜찮다고 말함',
        'active': true,
        'voice_metrics': {'count': 5, 'avgMs': 4200, 'avgLen': 34, 'nightRatio': 20},
        'voice_samples': [
          {'name': 'voice_1700000001.m4a', 'modified': '2026-02-08 21:10', 'size_kb': 312},
          {'name': 'voice_1700000002.m4a', 'modified': '2026-02-07 22:41', 'size_kb': 198},
        ],
      },
      {
        'nickname': '민준',
        'grade': 'B',
        'level': 15,
        'location': '부산',
        'per_soc': 35,
        'per_iso': 28,
        'per_emo': 40,
        'chat_summary': '최근 외출을 조금 늘리고 싶다고 언급.',
        'chat_keywords': ['외출', '긴장'],
        'analysis_reason': '사회성 노출을 조금씩 늘리는 전략이 적합.',
        'recent_summary': '외출 늘리고 싶음',
        'active': true,
        'voice_metrics': {'count': 2, 'avgMs': 2800, 'avgLen': 18, 'nightRatio': 0},
        'voice_samples': [
          {'name': 'voice_1699999123.m4a', 'modified': '2026-02-06 19:05', 'size_kb': 145},
        ],
      },
      {
        'nickname': '서연',
        'grade': 'D',
        'level': 3,
        'location': '대구',
        'per_soc': 70,
        'per_iso': 66,
        'per_emo': 72,
        'chat_summary': '사람 만나는 게 부담스럽고 집에 있고 싶다고 말함.',
        'chat_keywords': ['불안', '회피'],
        'analysis_reason': 'High 지표가 많아 안정 우선 전략 필요.',
        'recent_summary': '불안과 회피 경향',
        'active': false,
        'voice_metrics': {'count': 1, 'avgMs': 1500, 'avgLen': 8, 'nightRatio': 100},
        'voice_samples': [
          {'name': 'voice_1699980001.m4a', 'modified': '2026-02-03 02:18', 'size_kb': 86},
        ],
      },
    ];

    if (localProfile != null) {
      users.insert(0, {
        ...localProfile,
        'nickname': localProfile['nickname'] ?? '로컬 사용자',
        'recent_summary': (localProfile['chat_summary'] ?? '요약 없음').toString(),
        'active': true,
        'voice_metrics': _buildVoiceMetrics(),
      });
    }
    return users;
  }
}

class _Pill extends StatelessWidget {
  final String label;
  final Color color;
  const _Pill({required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.15),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.5)),
      ),
      child: Text(
        label,
        style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: color),
      ),
    );
  }
}
