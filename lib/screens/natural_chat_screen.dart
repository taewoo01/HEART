import 'dart:async';
import 'package:flutter/material.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;
import 'package:flutter_sound/flutter_sound.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:google_generative_ai/google_generative_ai.dart';

// ❌ main() 함수 삭제됨 (이제 이 파일은 화면 부품으로만 동작합니다)

class NaturalChatScreen extends StatefulWidget {
  const NaturalChatScreen({super.key});

  @override
  State<NaturalChatScreen> createState() => _NaturalChatScreenState();
}

class _NaturalChatScreenState extends State<NaturalChatScreen> with SingleTickerProviderStateMixin {
  // 🛠️ 도구들
  final stt.SpeechToText _speech = stt.SpeechToText();
  final FlutterSoundRecorder _recorder = FlutterSoundRecorder();
  final FlutterTts _flutterTts = FlutterTts();
  
  // ✨ 제미나이 모델 & 채팅 세션
  late final GenerativeModel _geminiModel;
  late final ChatSession _chatSession;
  
  // 🔑 API KEY (주의: 실제 배포 시에는 숨겨야 합니다)
  final String _apiKey = 'AIzaSyB3w8463q2SnEnb2S5bgNRl8FA5s-2nfao'; 

  // 📊 상태 변수
  bool _isListening = false; 
  bool _isThinking = false;   
  String _userText = "";      
  String _aiText = "안녕하세요. 오늘 하루는 어떠셨나요?";

  // ✨ 애니메이션 관련
  double _buttonSize = 90.0;
  Timer? _animTimer;

  // 📝 대화 기록
  List<Map<String, String>> _chatHistory = [];

  @override
  void initState() {
    super.initState();
    _initSystem();
  }

  Future<void> _initSystem() async {
    print("--- 시스템 초기화 시작 ---");
    // 1. 권한 요청
    await [Permission.microphone, Permission.speech].request();
    
    // 2. 하드웨어 초기화 (녹음기는 초기화만 하고 실제 사용은 안 함)
    await _recorder.openRecorder();
    
    // TTS 설정
    await _flutterTts.setLanguage("ko-KR");
    await _flutterTts.setSpeechRate(0.5);
    await _flutterTts.setPitch(1.0);

    // 3. 🧠 제미나이 초기화
    _geminiModel = GenerativeModel(
      model: 'gemini-flash-latest', // 최신 모델명으로 약간 수정해두었습니다
      apiKey: _apiKey,
    );

    _chatSession = _geminiModel.startChat(history: [
      Content.text('''
        당신은 '마음 치유 상담사'입니다. 
        사용자는 은둔형 외톨이 성향을 가진 사람입니다.
        규칙:
        1. 따뜻하고 부드러운 "해요체" 사용.
        2. 해결책 강요 금지, 공감 우선.
        3. 답변은 2~3문장 이내로 짧게.
      '''),
      Content.model([TextPart("네, 알겠습니다. 편안하게 말씀해 주세요.")])
    ]);

    // 첫 인사
    _addChatMessage("ai", _aiText);
    _flutterTts.speak(_aiText);
    print("--- 시스템 초기화 완료 ---");
  }

  // 🎤 버튼 클릭 시 (토글)
  void _toggleListening() {
    if (_isThinking) return; // 생각 중일 땐 클릭 방지

    if (_isListening) {
      _stopListening(); // 듣고 있었다면 -> 멈추기
    } else {
      _startListening(); // 멈춰 있었다면 -> 듣기 시작
    }
  }

  // 👂 듣기 시작 (수정됨: 녹음기 끄고 STT만 집중!)
  Future<void> _startListening() async {
    print(">>> 1. 듣기 버튼 눌림 <<<");
    _flutterTts.stop(); // 말하고 있었다면 끊기

    setState(() {
      _isListening = true;
      _userText = ""; 
    });
    _startAnimation();

    bool available = await _speech.initialize(
      onError: (val) => print('STT 에러: $val'),
      onStatus: (val) => print('STT 상태: $val'),
    );

    if (available) {
      print(">>> 2. STT 엔진 사용 가능 <<<");
      
      // 녹음기(Recorder)는 비활성화됨 (STT 전용 모드)
      print(">>> 3. 녹음기(Recorder)는 비활성화됨 (STT 전용 모드) <<<");

      // ✅ STT 리스닝 설정 강화
      await _speech.listen(
        onResult: (val) {
          print("인식된 말: ${val.recognizedWords}");
          setState(() {
            _userText = val.recognizedWords;
          });
        },
        localeId: 'ko_KR',
        listenFor: const Duration(seconds: 60), // 30초 -> 60초로 연장
        pauseFor: const Duration(seconds: 10),   // 5초 -> 10초로 연장 (생각할 시간 줌)
        cancelOnError: false,                   // 에러 나도 바로 안 꺼지게
        listenMode: stt.ListenMode.dictation,
      );
    } else {
      print("❌ STT 초기화 실패");
      setState(() => _isListening = false);
      _stopAnimation();
    }
  }

  // 🛑 듣기 종료 -> AI 전송
  Future<void> _stopListening() async {
    print(">>> 4. 듣기 종료 버튼 눌림 <<<");
    
    await _speech.stop(); // 음성 인식만 깔끔하게 종료
    _stopAnimation();

    // 텍스트가 비어있으면 그냥 종료
    if (_userText.trim().isEmpty) {
      print("--- 인식된 텍스트 없음 ---");
      setState(() => _isListening = false);
      return;
    }

    // UI 상태 변경: 듣기 끝 -> 생각 중
    setState(() {
      _isListening = false;
      _isThinking = true; 
    });

    _addChatMessage("user", _userText);

    try {
      print(">>> 5. Gemini에게 전송 중: $_userText <<<");
      final response = await _chatSession.sendMessage(Content.text(_userText));
      final aiResponseText = response.text ?? "죄송해요, 다시 말씀해 주시겠어요?";

      // AI 응답 처리
      setState(() {
        _aiText = aiResponseText;
        _isThinking = false;
      });
      
      _addChatMessage("ai", aiResponseText);
      await _flutterTts.speak(aiResponseText);
      print(">>> 6. 답변 완료 <<<");

    } catch (e) {
      print("Gemini Error: $e");
      setState(() => _isThinking = false);
      _addChatMessage("ai", "인터넷 연결이 불안정한 것 같아요.");
    }
  }

  void _addChatMessage(String role, String text) {
    setState(() {
      _chatHistory.add({"role": role, "text": text});
    });
  }

  void _startAnimation() {
    _animTimer?.cancel();
    _animTimer = Timer.periodic(const Duration(milliseconds: 600), (_) {
      setState(() => _buttonSize = (_buttonSize == 90.0) ? 110.0 : 90.0);
    });
  }
  
  void _stopAnimation() {
    _animTimer?.cancel();
    setState(() => _buttonSize = 90.0);
  }

  @override
  void dispose() {
    _animTimer?.cancel();
    _recorder.closeRecorder();
    _speech.cancel();
    _flutterTts.stop();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF0F4F8),
      appBar: AppBar(
        title: const Text("마음 상담소"), 
        centerTitle: true, 
        elevation: 0, 
        backgroundColor: Colors.transparent
      ),
      body: Column(
        children: [
          // 📜 채팅 리스트
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
                    margin: const EdgeInsets.symmetric(vertical: 5),
                    padding: const EdgeInsets.all(15),
                    constraints: const BoxConstraints(maxWidth: 260),
                    decoration: BoxDecoration(
                      color: isUser ? const Color(0xFF6BB8B0) : Colors.white,
                      borderRadius: BorderRadius.only(
                        topLeft: const Radius.circular(20),
                        topRight: const Radius.circular(20),
                        bottomLeft: isUser ? const Radius.circular(20) : Radius.zero,
                        bottomRight: isUser ? Radius.zero : const Radius.circular(20),
                      ),
                      boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 4)],
                    ),
                    child: Text(
                      chat['text']!,
                      style: TextStyle(
                        color: isUser ? Colors.white : Colors.black87, 
                        fontSize: 16,
                        height: 1.4,
                      ),
                    ),
                  ),
                );
              },
            ),
          ),

          // 🎛️ 하단 컨트롤러 구역
          Container(
            padding: const EdgeInsets.only(bottom: 40, top: 20),
            decoration: const BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.vertical(top: Radius.circular(30)),
              boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 10, offset: Offset(0, -5))]
            ),
            child: Column(
              children: [
                // 실시간 인식 텍스트 표시
                if (_isListening)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: Text(
                      _userText.isEmpty ? "듣고 있어요..." : _userText,
                      style: const TextStyle(color: Colors.black54, fontSize: 16),
                      textAlign: TextAlign.center,
                    ),
                  )
                else if (_isThinking) 
                  const Text("AI가 생각하고 있어요... 🤔", style: TextStyle(color: Colors.grey, fontSize: 14)),
                
                const SizedBox(height: 10),

                // 🔴 왕 버튼 (마이크)
                GestureDetector(
                  onTap: _toggleListening,
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 600),
                    width: _buttonSize,
                    height: _buttonSize,
                    decoration: BoxDecoration(
                      color: _isListening ? Colors.redAccent : const Color(0xFF6BB8B0),
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: (_isListening ? Colors.redAccent : const Color(0xFF6BB8B0)).withOpacity(0.4),
                          blurRadius: 20,
                          spreadRadius: 5,
                        )
                      ],
                    ),
                    child: Icon(
                      _isThinking ? Icons.more_horiz : (_isListening ? Icons.stop : Icons.mic),
                      color: Colors.white,
                      size: 40,
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