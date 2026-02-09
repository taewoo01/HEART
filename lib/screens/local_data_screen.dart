import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_sound/flutter_sound.dart';
import 'package:path_provider/path_provider.dart';
import '../services/storage_service.dart';

class LocalDataScreen extends StatefulWidget {
  final bool enablePlayback;
  final bool multiUser;
  const LocalDataScreen({super.key, this.enablePlayback = false, this.multiUser = false});

  @override
  State<LocalDataScreen> createState() => _LocalDataScreenState();
}

class _LocalDataScreenState extends State<LocalDataScreen> {
  Map<String, dynamic>? _profile;
  List<FileSystemEntity> _audioFiles = [];
  List<Map<String, dynamic>> _voiceSignals = [];
  bool _isLoading = true;
  String? _playingPath;
  final FlutterSoundPlayer _player = FlutterSoundPlayer();
  List<Map<String, dynamic>> _users = [];
  int _selectedUserIndex = 0;

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    if (widget.enablePlayback) {
      await _player.openPlayer();
    }
    await _loadData();
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
    final users = widget.multiUser ? _buildSampleUsers(profile, voiceSignals, files) : <Map<String, dynamic>>[];
    setState(() {
      _profile = profile;
      _audioFiles = files;
      _voiceSignals = voiceSignals;
      _users = users;
      _selectedUserIndex = _selectedUserIndex.clamp(0, users.isEmpty ? 0 : users.length - 1);
      _isLoading = false;
    });
  }

  @override
  void dispose() {
    if (widget.enablePlayback) {
      _player.closePlayer();
    }
    super.dispose();
  }

  Future<void> _togglePlay(String path) async {
    if (!widget.enablePlayback) return;
    if (_playingPath == path) {
      await _player.stopPlayer();
      setState(() => _playingPath = null);
      return;
    }

    if (_playingPath != null) {
      await _player.stopPlayer();
    }

    await _player.startPlayer(
      fromURI: path,
      codec: Codec.aacMP4,
      whenFinished: () {
        if (mounted) setState(() => _playingPath = null);
      },
    );
    setState(() => _playingPath = path);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("로컬 데이터 확인"),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadData,
          )
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                if (widget.multiUser) _buildUserSelector(),
                if (widget.multiUser) const SizedBox(height: 12),
                _buildProfileCard(),
                const SizedBox(height: 16),
                _buildVoiceSignalList(),
                const SizedBox(height: 16),
                _buildAudioList(),
              ],
            ),
    );
  }

  Widget _buildProfileCard() {
    final profile = _selectedProfile();
    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: profile == null || profile.isEmpty
            ? const Text("저장된 사용자 데이터가 없습니다.")
            : Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text("닉네임: ${profile['nickname']}"),
                  Text("위치: ${profile['location']}"),
                  Text("등급: ${profile['grade']}"),
                  Text("레벨: ${profile['level']}"),
                  Text("HQ-25 대인기피: ${profile['per_soc']}%"),
                  Text("HQ-25 고립: ${profile['per_iso']}%"),
                  Text("HQ-25 정서: ${profile['per_emo']}%"),
                  if ((profile['analysis_reason'] ?? '').toString().isNotEmpty)
                    Text("분석 근거: ${profile['analysis_reason']}"),
                  if ((profile['chat_summary'] ?? '').toString().isNotEmpty)
                    Text("대화 요약: ${profile['chat_summary']}"),
                  if ((profile['chat_keywords'] as List?)?.isNotEmpty == true)
                    Text("감정 키워드: ${(profile['chat_keywords'] as List).join(', ')}"),
                ],
              ),
      ),
    );
  }

  Widget _buildVoiceSignalList() {
    final voiceSignals = _selectedVoiceSignals();
    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text("음성 신호", style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            if (voiceSignals.isEmpty)
              const Text("저장된 음성 신호가 없습니다.")
            else
              ...voiceSignals.take(5).map((e) {
                final ts = (e['ts'] ?? 0) as int;
                final dt = DateTime.fromMillisecondsSinceEpoch(ts);
                final duration = (e['duration_ms'] ?? 0) as int;
                final len = (e['transcript_len'] ?? 0) as int;
                final hasSpeech = (e['has_speech'] ?? false) as bool;
                return ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text("${dt.month}/${dt.day} ${dt.hour}:${dt.minute.toString().padLeft(2, '0')}"),
                  subtitle: Text("길이: ${duration}ms · 글자수: $len · 말함: $hasSpeech"),
                );
              }),
          ],
        ),
      ),
    );
  }

  Widget _buildAudioList() {
    final audioSamples = _selectedAudioSamples();
    final canPlay = widget.enablePlayback && _isSelectedLocal();
    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text("녹음 파일", style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            if (audioSamples.isEmpty)
              const Text("저장된 녹음 파일이 없습니다.")
            else
              ...audioSamples.map((s) {
                final path = (s['path'] ?? '').toString();
                final isPlaying = _playingPath == path;
                return ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: GestureDetector(
                    onTap: canPlay && path.isNotEmpty ? () => _togglePlay(path) : null,
                    child: Text(s['name'] as String),
                  ),
                  subtitle: Text("${s['modified']} · ${s['size']}"),
                  trailing: canPlay
                      ? IconButton(
                          icon: Icon(isPlaying ? Icons.stop : Icons.play_arrow),
                          onPressed: path.isNotEmpty ? () => _togglePlay(path) : null,
                        )
                      : null,
                );
              }),
          ],
        ),
      ),
    );
  }

  Widget _buildUserSelector() {
    if (_users.isEmpty) return const SizedBox.shrink();
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
            onTap: () => setState(() => _selectedUserIndex = index),
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

  Map<String, dynamic> _selectedProfile() {
    if (!widget.multiUser || _users.isEmpty) return _profile ?? {};
    return _users[_selectedUserIndex]['profile'] as Map<String, dynamic>;
  }

  List<Map<String, dynamic>> _selectedVoiceSignals() {
    if (!widget.multiUser || _users.isEmpty) return _voiceSignals;
    return List<Map<String, dynamic>>.from(_users[_selectedUserIndex]['voice_signals'] as List);
  }

  List<Map<String, dynamic>> _selectedAudioSamples() {
    if (!widget.multiUser || _users.isEmpty) {
      return _audioFiles.map((f) {
        final stat = f.statSync();
        final sizeKb = (stat.size / 1024).toStringAsFixed(1);
        final name = f.path.split(Platform.pathSeparator).last;
        return {
          'name': name,
          'modified': stat.modified,
          'size': "$sizeKb KB",
          'path': f.path,
        };
      }).toList();
    }
    return List<Map<String, dynamic>>.from(_users[_selectedUserIndex]['audio_samples'] as List);
  }

  bool _isSelectedLocal() {
    if (!widget.multiUser || _users.isEmpty) return true;
    return (_users[_selectedUserIndex]['is_local'] ?? false) == true;
  }

  List<Map<String, dynamic>> _buildSampleUsers(
    Map<String, dynamic>? localProfile,
    List<Map<String, dynamic>> localSignals,
    List<FileSystemEntity> localAudio,
  ) {
    final localAudioSamples = localAudio.map((f) {
      final stat = f.statSync();
      final sizeKb = (stat.size / 1024).toStringAsFixed(1);
      final name = f.path.split(Platform.pathSeparator).last;
      return {
        'name': name,
        'modified': stat.modified,
        'size': "$sizeKb KB",
        'path': f.path,
      };
    }).toList();

    return [
      {
        'nickname': localProfile?['nickname'] ?? '로컬 사용자',
        'grade': localProfile?['grade'] ?? 'C',
        'recent': (localProfile?['chat_summary'] ?? '요약 없음').toString(),
        'is_local': true,
        'profile': localProfile ?? {},
        'voice_signals': localSignals,
        'audio_samples': localAudioSamples,
      },
      {
        'nickname': '유나',
        'grade': 'C',
        'recent': '피곤하지만 괜찮았던 하루',
        'is_local': false,
        'profile': {'nickname': '유나', 'location': '서울', 'grade': 'C', 'level': 8, 'per_soc': 55, 'per_iso': 42, 'per_emo': 63},
        'voice_signals': [
          {'ts': DateTime.now().millisecondsSinceEpoch - 86400000, 'duration_ms': 4200, 'transcript_len': 34, 'has_speech': true},
        ],
        'audio_samples': [
          {'name': 'voice_1700000001.m4a', 'modified': '2026-02-08 21:10', 'size': '312 KB', 'path': ''},
        ],
      },
      {
        'nickname': '민준',
        'grade': 'B',
        'recent': '외출을 조금 늘리고 싶음',
        'is_local': false,
        'profile': {'nickname': '민준', 'location': '부산', 'grade': 'B', 'level': 15, 'per_soc': 35, 'per_iso': 28, 'per_emo': 40},
        'voice_signals': [
          {'ts': DateTime.now().millisecondsSinceEpoch - 172800000, 'duration_ms': 2800, 'transcript_len': 18, 'has_speech': true},
        ],
        'audio_samples': [
          {'name': 'voice_1699999123.m4a', 'modified': '2026-02-06 19:05', 'size': '145 KB', 'path': ''},
        ],
      },
      {
        'nickname': '서연',
        'grade': 'D',
        'recent': '불안하지만 견딤',
        'is_local': false,
        'profile': {'nickname': '서연', 'location': '대구', 'grade': 'D', 'level': 3, 'per_soc': 70, 'per_iso': 66, 'per_emo': 72},
        'voice_signals': [
          {'ts': DateTime.now().millisecondsSinceEpoch - 259200000, 'duration_ms': 1500, 'transcript_len': 8, 'has_speech': true},
        ],
        'audio_samples': [
          {'name': 'voice_1699980001.m4a', 'modified': '2026-02-03 02:18', 'size': '86 KB', 'path': ''},
        ],
      },
    ];
  }
}
