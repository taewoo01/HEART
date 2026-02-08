import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;
import 'package:flutter_sound/flutter_sound.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:path_provider/path_provider.dart';
import '../services/ai_service.dart';
import 'local_data_screen.dart';
import '../services/storage_service.dart';

class NaturalChatScreen extends StatefulWidget {
  final bool intakeMode;
  final String? location;
  final String? weather;

  const NaturalChatScreen({super.key})
      : intakeMode = false,
        location = null,
        weather = null;

  const NaturalChatScreen.intake({
    super.key,
    required this.location,
    required this.weather,
  }) : intakeMode = true;

  @override
  State<NaturalChatScreen> createState() => _NaturalChatScreenState();
}

class _NaturalChatScreenState extends State<NaturalChatScreen> with SingleTickerProviderStateMixin {
  // 🛠️ 도구들
  final stt.SpeechToText _speech = stt.SpeechToText();
  final FlutterSoundRecorder _recorder = FlutterSoundRecorder();
  final FlutterTts _flutterTts = FlutterTts();
  
  // 📊 상태 변수
  bool _isListening = false; 
  bool _isThinking = false;   
  bool _isSpeechAvailable = false; 
  String _userText = "";       
  String _aiText = "안녕하세요. 오늘 하루는 어떠셨나요?";
  String? _recordedFilePath;
  bool _isRecording = false;
  DateTime? _recordingStartedAt;
  int _intakeStep = 0;
  final Map<String, String> _intakeAnswers = {};
  static const List<String> _intakeQuestions = [
    "오늘 컨디션은 어떤가요? 예) 좀 지쳤어 / 괜찮은 편이야",
    "지금 어디에 있나요? 예) 방 / 거실 / 침대 위",
    "지금 무엇을 하고 있나요? 예) 누워있어 / 앉아서 쉬는 중",
  ];
  static const List<String> _intakeEmpathy = [
    "말해줘서 고마워요. 지금 느낌을 소중하게 들었어요.",
    "괜찮아요, 편하게 말해줘서 좋아요.",
    "지금 상태를 알려줘서 정말 도움이 됐어요.",
  ];

  // ✨ 애니메이션 관련
  double _buttonSize = 90.0;
  Timer? _animTimer;

  // 📝 대화 기록
  static List<Map<String, String>> _cachedHistory = [];
  List<Map<String, String>> _chatHistory = [];
  final ScrollController _scrollController = ScrollController();

  final AIService _aiService = AIService();

  @override
  void initState() {
    super.initState();
    _chatHistory = List<Map<String, String>>.from(_cachedHistory);
    _initSystem();
  }

  Future<void> _initSystem() async {
    print("--- 시스템 초기화 시작 ---");
    
    // 1. 권한 요청
    await [Permission.microphone, Permission.speech].request();

    // 2. 녹음기 초기화
    await _recorder.openRecorder();

    // 3. STT(음성 인식) 초기화
    _isSpeechAvailable = await _speech.initialize(
      onError: (val) => print('STT 에러: $val'),
      onStatus: (val) {
        print('STT 상태: $val');
        // 말하다가 멈추면 자동으로 버튼 상태 변경 등도 가능
      },
    );
    print("STT 초기화 여부: $_isSpeechAvailable");

    // 4. TTS 설정
    await _flutterTts.setLanguage("ko-KR");
    await _flutterTts.setSpeechRate(0.5);

    // 5. 첫 인사
    if (_chatHistory.isEmpty) {
      if (widget.intakeMode) {
        _aiText = "지금 상태를 천천히 같이 살펴볼게요. 편하게 말해줘요.";
      }
      _addChatMessage("ai", _aiText);
      _flutterTts.speak(_aiText);
      if (widget.intakeMode) {
        _askNextIntakeQuestion();
      }
    }
  }

  // 🎤 버튼 클릭 시 동작
  void _toggleListening() {
    if (_isThinking) return;

    if (_isListening) {
      _stopListening();
    } else {
      _startListening();
    }
  }

  // 👂 듣기 시작 (STT + 로컬 녹음)
  Future<void> _startListening() async {
    print(">>> 1. 듣기 시작 (STT + 녹음) <<<");
    await _flutterTts.stop(); // AI 말 끊기

    setState(() {
      _isListening = true;
      _userText = ""; // 텍스트 초기화
    });
    _startAnimation();

    // 🎙️ 녹음 파일 생성 (앱 내부 저장소)
    try {
      final dir = await getApplicationDocumentsDirectory();
      final fileName = "voice_${DateTime.now().millisecondsSinceEpoch}.m4a";
      _recordedFilePath = "${dir.path}/$fileName";

      await _recorder.startRecorder(
        toFile: _recordedFilePath,
        codec: Codec.aacMP4,
      );
      _isRecording = true;
      _recordingStartedAt = DateTime.now();
      print("녹음 시작: $_recordedFilePath");
    } catch (e) {
      print("녹음 시작 실패: $e");
      _recordedFilePath = null;
      _isRecording = false;
      _recordingStartedAt = null;
    }

    // ⚠️ 녹음과 STT 동시 사용 시 충돌 가능 → 녹음이 켜지면 STT는 건너뜀
    if (_isSpeechAvailable && !_isRecording) {
      _speech.listen(
        onResult: (val) {
          setState(() {
            _userText = val.recognizedWords; // 실시간으로 화면에 글자 표시
          });
          print("인식된 글자: ${val.recognizedWords}");
        },
        localeId: 'ko_KR',
        listenFor: const Duration(seconds: 30),
        pauseFor: const Duration(seconds: 3), // 3초 쉬면 자동 완료
        listenMode: stt.ListenMode.dictation,
        cancelOnError: false,
        partialResults: true, // 말하는 도중에도 글자 띄우기
      );
    } else if (!_isRecording) {
      print("⚠️ STT 초기화 실패 (재시도 필요)");
      _isSpeechAvailable = await _speech.initialize();
    }
  }

  // 🛑 듣기 종료 -> AI 전송
  Future<void> _stopListening() async {
    print(">>> 2. 듣기 종료 <<<");
    
    await _speech.stop();
    if (_isRecording) {
      try {
        await _recorder.stopRecorder();
        _isRecording = false;
        if (_recordedFilePath != null) {
          print("녹음 종료: $_recordedFilePath");
        }
      } catch (e) {
        _isRecording = false;
        print("녹음 종료 실패: $e");
      }
    }
    _stopAnimation();

    setState(() {
      _isListening = false;
      _isThinking = true; 
    });

    // 최종 텍스트 확인
    String finalText = _userText.trim();
    File? audioFile;
    if (_recordedFilePath != null) {
      final candidate = File(_recordedFilePath!);
      if (await candidate.exists()) {
        final size = await candidate.length();
        if (size > 0) {
          audioFile = candidate;
        } else {
          print("⚠️ 녹음 파일 크기 0: $_recordedFilePath");
        }
      } else {
        print("⚠️ 녹음 파일 없음: $_recordedFilePath");
      }
    }

    if (finalText.isEmpty && audioFile == null) {
      if (!mounted) return;
      setState(() => _isThinking = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("음성이 제대로 녹음되지 않았어요. 다시 말씀해 주세요! 🎤")),
      );
      return; 
    }
    
    // ✅ 내 말풍선 추가
    if (finalText.isNotEmpty) {
      _addChatMessage("user", finalText);
    } else {
      _addChatMessage("user", "(음성 메시지)");
    }

    // AI에게 전송 (텍스트 우선, 없으면 오디오 전사)
    final started = _recordingStartedAt;
    final durationMs = started != null ? DateTime.now().difference(started).inMilliseconds : null;
    _recordingStartedAt = null;
    await _processAiResponse(finalText, audioFile: audioFile, durationMs: durationMs);
  }

  // 🤖 AI 응답 처리 (텍스트 기반)
  Future<void> _processAiResponse(String userText, {File? audioFile, int? durationMs}) async {
    try {
      print(">>> 3. AI에게 텍스트 전송: $userText <<<");

      String finalText = userText;
      if (finalText.isEmpty && audioFile != null) {
        try {
          finalText = await _aiService.transcribeAudio(audioFile);
          if (finalText.isNotEmpty) {
            // 방금 추가한 (음성 메시지) 버블을 실제 텍스트로 교체
            if (_chatHistory.isNotEmpty &&
                _chatHistory.last['role'] == 'user' &&
                _chatHistory.last['text'] == '(음성 메시지)') {
              setState(() {
                _chatHistory[_chatHistory.length - 1] = {
                  "role": "user",
                  "text": finalText
                };
                _cachedHistory = List<Map<String, String>>.from(_chatHistory);
              });
              _scrollToBottom();
            }
          }
        } catch (e) {
          print("전사 실패: $e");
        }
      }
      
      if (widget.intakeMode) {
        await _handleIntakeFlow(finalText);
        return;
      }

      final aiResponseText = await _aiService.processVoiceChat(
        userText: finalText,
        audioFile: audioFile,
        chatHistory: _chatHistory,
      );

      // 음성 신호 저장 (길이/빈도 지표)
      if (durationMs != null) {
        await StorageService.addVoiceSignal(
          durationMs: durationMs,
          transcriptLength: finalText.length,
          hasSpeech: finalText.isNotEmpty,
        );
      }

      if (!mounted) return;

      setState(() {
        _aiText = aiResponseText;
        _isThinking = false;
      });
      
      _addChatMessage("ai", aiResponseText);
      await _flutterTts.speak(aiResponseText);

    } catch (e) {
      print("AI Error: $e");
      if (!mounted) return;
      setState(() => _isThinking = false);
      _addChatMessage("ai", "죄송해요, 오류가 생겼어요. 다시 말씀해 주시겠어요?");
    }
  }

  void _addChatMessage(String role, String text) {
    if (!mounted) return;
    setState(() {
      _chatHistory.add({"role": role, "text": text});
      _cachedHistory = List<Map<String, String>>.from(_chatHistory);
    });
    _scrollToBottom();
  }

  void _scrollToBottom() {
    if (!_scrollController.hasClients) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scrollController.hasClients) return;
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeOut,
      );
    });
  }

  void _startAnimation() {
    _animTimer?.cancel();
    _animTimer = Timer.periodic(const Duration(milliseconds: 600), (_) {
      if (mounted) setState(() => _buttonSize = (_buttonSize == 90.0) ? 110.0 : 90.0);
    });
  }
  
  void _stopAnimation() {
    _animTimer?.cancel();
    if (mounted) setState(() => _buttonSize = 90.0);
  }

  @override
  void dispose() {
    _saveChatSummary();
    _animTimer?.cancel();
    _scrollController.dispose();
    _recorder.closeRecorder();
    _speech.cancel();
    _flutterTts.stop();
    super.dispose();
  }

  void _saveChatSummary() {
    if (_chatHistory.isEmpty) return;
    // fire-and-forget
    _aiService.summarizeChat(_chatHistory).then((summary) {
      if (summary == null) return;
      final String text = (summary['summary'] ?? '').toString();
      final List<String> keywords = (summary['keywords'] is List)
          ? (summary['keywords'] as List).map((e) => e.toString()).toList()
          : <String>[];
      StorageService.saveChatSummary(text, keywords);
    });
  }

  Future<void> _handleIntakeFlow(String userText) async {
    if (userText.trim().isEmpty) {
      setState(() => _isThinking = false);
      return;
    }

    // 공감 한마디
    final empathy = _intakeEmpathy[_intakeStep.clamp(0, _intakeEmpathy.length - 1)];
    _addChatMessage("ai", empathy);
    _flutterTts.speak(empathy);

    if (_intakeStep == 0) {
      _intakeAnswers['condition'] = userText.trim();
    } else if (_intakeStep == 1) {
      _intakeAnswers['place'] = userText.trim();
    } else if (_intakeStep == 2) {
      _intakeAnswers['activity'] = userText.trim();
    }

    _intakeStep++;

    if (_intakeStep < _intakeQuestions.length) {
      _askNextIntakeQuestion();
      setState(() => _isThinking = false);
      return;
    }

    if (!mounted) return;
    final selected = await showDialog<String>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        title: const Text("오늘은 어떤 방향으로 할까요?"),
        content: const Text("쉬어가기 / 가볍게 / 보통 중에서 골라주세요."),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, "REST"),
            child: const Text("쉬어갈게요"),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, "LIGHT"),
            child: const Text("가볍게 할래요"),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, "NORMAL"),
            child: const Text("보통으로 해줘"),
          ),
        ],
      ),
    );

    Navigator.pop(context, {
      ..._intakeAnswers,
      "user_choice": selected ?? "NORMAL",
    });
  }

  void _askNextIntakeQuestion() {
    if (_intakeStep >= _intakeQuestions.length) return;
    final q = _intakeQuestions[_intakeStep];
    _addChatMessage("ai", q);
    _flutterTts.speak(q);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF0F4F8),
      appBar: AppBar(
        title: const Text("마음 상담소", style: TextStyle(color: Colors.black87, fontWeight: FontWeight.bold)), 
        centerTitle: true, 
        elevation: 0, 
        backgroundColor: Colors.transparent,
        iconTheme: const IconThemeData(color: Colors.black87),
        actions: [
          IconButton(
            icon: const Icon(Icons.folder_open),
            tooltip: "로컬 데이터 확인",
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const LocalDataScreen()),
              );
            },
          )
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: ListView.builder(
              controller: _scrollController,
              padding: const EdgeInsets.all(20),
              itemCount: _chatHistory.length,
              itemBuilder: (context, index) {
                final chat = _chatHistory[index];
                final isUser = chat['role'] == 'user';
                return Align(
                  alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
                  child: Container(
                    margin: const EdgeInsets.symmetric(vertical: 8), 
                    padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
                    constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.75),
                    decoration: BoxDecoration(
                      color: isUser ? const Color(0xFF6BB8B0) : Colors.white,
                      borderRadius: BorderRadius.only(
                        topLeft: const Radius.circular(20),
                        topRight: const Radius.circular(20),
                        bottomLeft: isUser ? const Radius.circular(20) : const Radius.circular(5),
                        bottomRight: isUser ? const Radius.circular(5) : const Radius.circular(20),
                      ),
                      boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 5, offset: const Offset(0, 2))],
                    ),
                    child: Text(
                      chat['text']!,
                      style: TextStyle(color: isUser ? Colors.white : Colors.black87, fontSize: 16, height: 1.4),
                    ),
                  ),
                );
              },
            ),
          ),
          
          Container(
            padding: const EdgeInsets.only(bottom: 40, top: 25, left: 20, right: 20),
            decoration: const BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.vertical(top: Radius.circular(30)),
              boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 15, offset: Offset(0, -5))]
            ),
            child: Column(
              children: [
                if (_isListening)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 20),
                    child: Text(
                      _userText.isEmpty ? "듣고 있어요... 말씀해 보세요 👂" : _userText,
                      textAlign: TextAlign.center,
                      style: const TextStyle(fontSize: 18, color: Color(0xFF6BB8B0), fontWeight: FontWeight.w600),
                    ),
                  )
                else if (_isThinking) 
                  const Padding(
                    padding: EdgeInsets.only(bottom: 20),
                    child: Text("답변을 생각하고 있어요... 🤔", style: TextStyle(fontSize: 16, color: Colors.grey)),
                  ),
                
                GestureDetector(
                  onTap: _toggleListening,
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 300),
                    width: _buttonSize, height: _buttonSize,
                    decoration: BoxDecoration(
                      color: _isListening ? const Color(0xFFFF6B6B) : const Color(0xFF6BB8B0),
                      shape: BoxShape.circle,
                      boxShadow: [BoxShadow(color: (_isListening ? Colors.red : Colors.teal).withOpacity(0.4), blurRadius: 15, spreadRadius: 5)]
                    ),
                    child: Icon(
                      _isThinking ? Icons.more_horiz : (_isListening ? Icons.stop : Icons.mic),
                      color: Colors.white, size: 40,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
