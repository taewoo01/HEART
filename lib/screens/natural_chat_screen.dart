import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;
import 'package:flutter_sound/flutter_sound.dart'; // 껍데기만 유지 (에러 방지)
import 'package:flutter_tts/flutter_tts.dart';
import 'package:permission_handler/permission_handler.dart';
import '../services/ai_service.dart';

class NaturalChatScreen extends StatefulWidget {
  const NaturalChatScreen({super.key});

  @override
  State<NaturalChatScreen> createState() => _NaturalChatScreenState();
}

class _NaturalChatScreenState extends State<NaturalChatScreen> with SingleTickerProviderStateMixin {
  // 🛠️ 도구들
  final stt.SpeechToText _speech = stt.SpeechToText();
  final FlutterTts _flutterTts = FlutterTts();
  
  // 📊 상태 변수
  bool _isListening = false; 
  bool _isThinking = false;   
  bool _isSpeechAvailable = false; 
  String _userText = "";       
  String _aiText = "안녕하세요. 오늘 하루는 어떠셨나요?";

  // ✨ 애니메이션 관련
  double _buttonSize = 90.0;
  Timer? _animTimer;

  // 📝 대화 기록
  List<Map<String, String>> _chatHistory = [];

  final AIService _aiService = AIService();

  @override
  void initState() {
    super.initState();
    _initSystem();
  }

  Future<void> _initSystem() async {
    print("--- 시스템 초기화 시작 ---");
    
    // 1. 권한 요청
    await [Permission.microphone, Permission.speech].request();

    // 2. STT(음성 인식) 초기화
    _isSpeechAvailable = await _speech.initialize(
      onError: (val) => print('STT 에러: $val'),
      onStatus: (val) {
        print('STT 상태: $val');
        // 말하다가 멈추면 자동으로 버튼 상태 변경 등도 가능
      },
    );
    print("STT 초기화 여부: $_isSpeechAvailable");

    // 3. TTS 설정
    await _flutterTts.setLanguage("ko-KR");
    await _flutterTts.setSpeechRate(0.5);

    // 4. 첫 인사
    if (_chatHistory.isEmpty) {
      _addChatMessage("ai", _aiText);
      _flutterTts.speak(_aiText);
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

  // 👂 듣기 시작 (녹음 파일 생성 안 함 -> 마이크 충돌 해결)
  Future<void> _startListening() async {
    print(">>> 1. 듣기 시작 (STT 전용) <<<");
    await _flutterTts.stop(); // AI 말 끊기

    setState(() {
      _isListening = true;
      _userText = ""; // 텍스트 초기화
    });
    _startAnimation();

    if (_isSpeechAvailable) {
      // 🚨 중요: startRecorder를 쓰지 않습니다! (마이크를 STT에 양보)
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
    } else {
      print("⚠️ STT 초기화 실패 (재시도 필요)");
      _isSpeechAvailable = await _speech.initialize();
    }
  }

  // 🛑 듣기 종료 -> AI 전송
  Future<void> _stopListening() async {
    print(">>> 2. 듣기 종료 <<<");
    
    await _speech.stop(); 
    _stopAnimation();

    setState(() {
      _isListening = false;
      _isThinking = true; 
    });

    // 최종 텍스트 확인
    String finalText = _userText.trim();
    
    // 혹시라도 인식이 안 됐을 경우
    if (finalText.isEmpty) {
      if (!mounted) return;
      setState(() => _isThinking = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("음성을 인식하지 못했어요. 다시 말씀해 주세요! 🎤")),
      );
      return; 
    }
    
    // ✅ 내 말풍선 추가 (이제 "(음성메시지)"가 아니라 진짜 글자가 뜹니다!)
    _addChatMessage("user", finalText);

    // AI에게 전송 (텍스트만 보냄)
    await _processAiResponse(finalText);
  }

  // 🤖 AI 응답 처리 (텍스트 기반)
  Future<void> _processAiResponse(String userText) async {
    try {
      print(">>> 3. AI에게 텍스트 전송: $userText <<<");
      
      // 💡 핵심 변경 사항:
      // 녹음 파일(audioFile)을 보내지 않고, 텍스트(userText)를 보냅니다.
      // 하지만 기존 AI Service가 파일을 요구할 수 있으므로 '빈 파일'을 넣어 에러를 막습니다.
      
      final aiResponseText = await _aiService.processVoiceChat(
        audioFile: File(""), // 👈 빈 파일 (AI Service에서 텍스트가 있으면 파일을 무시하도록 되어있어야 함)
        userText: userText   // 👈 진짜 데이터는 이것!
      );

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
    _animTimer?.cancel();
    _speech.cancel();
    _flutterTts.stop();
    super.dispose();
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
      ),
      body: Column(
        children: [
          Expanded(
            child: ListView.builder(
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