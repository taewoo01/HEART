import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_sound/flutter_sound.dart';
import 'package:path_provider/path_provider.dart';
import '../services/storage_service.dart';

class LocalDataScreen extends StatefulWidget {
  const LocalDataScreen({super.key});

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

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    await _player.openPlayer();
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
    setState(() {
      _profile = profile;
      _audioFiles = files;
      _voiceSignals = voiceSignals;
      _isLoading = false;
    });
  }

  Future<void> _togglePlay(String path) async {
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
  void dispose() {
    _player.closePlayer();
    super.dispose();
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
    final profile = _profile;
    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: profile == null
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
                  if ((profile['chat_keywords'] as List).isNotEmpty)
                    Text("감정 키워드: ${(profile['chat_keywords'] as List).join(', ')}"),
                ],
              ),
      ),
    );
  }

  Widget _buildVoiceSignalList() {
    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text("음성 신호", style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            if (_voiceSignals.isEmpty)
              const Text("저장된 음성 신호가 없습니다.")
            else
              ..._voiceSignals.take(5).map((e) {
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
    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text("녹음 파일", style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            if (_audioFiles.isEmpty)
              const Text("저장된 녹음 파일이 없습니다.")
            else
              ..._audioFiles.map((f) {
                final stat = f.statSync();
                final sizeKb = (stat.size / 1024).toStringAsFixed(1);
                final name = f.path.split(Platform.pathSeparator).last;
                final isPlaying = _playingPath == f.path;
                return ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(name),
                  subtitle: Text("${stat.modified} · ${sizeKb} KB"),
                  trailing: IconButton(
                    icon: Icon(isPlaying ? Icons.stop : Icons.play_arrow),
                    onPressed: () => _togglePlay(f.path),
                  ),
                );
              }),
          ],
        ),
      ),
    );
  }
}
