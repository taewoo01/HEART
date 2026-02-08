import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart'; // 📦 1. 필수 패키지 임포트
import 'services/storage_service.dart'; 
import 'screens/user_info_screen.dart';
import 'screens/onboarding_screen.dart';
import 'screens/main_screen.dart';
import 'screens/natural_chat_screen.dart'; 

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // 🔑 2. .env 파일 로드 (이게 없으면 앱이 멈춥니다!)
  await dotenv.load(fileName: ".env");

  // 세로 모드 고정
  await SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);

  runApp(const HeartApp());
}

class HeartApp extends StatefulWidget {
  const HeartApp({super.key});

  @override
  State<HeartApp> createState() => _HeartAppState();
}

class _HeartAppState extends State<HeartApp> {
  // 🔄 앱 로딩 상태
  bool _isLoading = true;

  // 🔄 현재 단계 (0: 정보입력 -> 1: 설문조사 -> 2: 메인화면)
  int _currentStep = 0;

  // 사용자 데이터 (정보 입력 단계에서 임시 저장용)
  String _nickname = '';
  // ❌ String _location = '';  <-- 삭제됨 (이제 여기서 관리 안 함)

  @override
  void initState() {
    super.initState();
    _checkLoginStatus(); 
  }

  // 1️⃣ 저장된 데이터 확인 (자동 로그인)
  Future<void> _checkLoginStatus() async {
    final userData = await StorageService.getUserProfile();

    if (userData != null) {
      // ✅ 이미 가입된 유저 -> 메인으로 직행
      print("✅ 자동 로그인: ${userData['nickname']} (Grade ${userData['grade']})");
      setState(() {
        _currentStep = 2; 
        _isLoading = false; 
      });
    } else {
      // ❌ 신규 유저 -> 정보 입력부터 시작
      setState(() {
        _currentStep = 0;
        _isLoading = false; 
      });
    }
  }

  // 2️⃣ [Step 0 -> 1] 닉네임 입력 완료
  // 🚨 지역(loc) 파라미터를 삭제하고 닉네임만 받습니다.
  void _completeUserInfo(String name) {
    setState(() {
      _nickname = name;
      _currentStep = 1; // 설문조사 화면으로 이동
    });
    print("📝 정보 입력(이름만): $_nickname");
  }

  // 3️⃣ [Step 1 -> 2] 설문 완료 & 메인 이동
  void _completeOnboarding() {
    print("🚀 설문 완료 및 저장 확인됨 -> 메인 화면 이동");
    setState(() {
      _currentStep = 2; // 메인 화면으로 이동
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const MaterialApp(
        debugShowCheckedModeBanner: false,
        home: Scaffold(
          backgroundColor: Color(0xFFF0F4F8),
          body: Center(child: CircularProgressIndicator(color: Color(0xFF6BB8B0))),
        ),
      );
    }

    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Heal Me',
      theme: ThemeData(
        useMaterial3: true,
        fontFamily: 'Pretendard',
        primaryColor: const Color(0xFF6BB8B0),
        scaffoldBackgroundColor: const Color(0xFFF0F4F8),
        pageTransitionsTheme: const PageTransitionsTheme(
          builders: {
            TargetPlatform.android: FadeUpwardsPageTransitionsBuilder(),
            TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
          },
        ),
      ),
      // 현재 단계에 따른 화면 표시
      home: _buildCurrentScreen(),
      
      // 📌 라우트 설정
      routes: {
        '/chat': (context) => const NaturalChatScreen(),
      },
    );
  }

  Widget _buildCurrentScreen() {
    switch (_currentStep) {
      case 0:
        // 1. 정보 입력 (수정됨: 닉네임만 받아오는 함수 연결)
        return UserInfoScreen(onCompleted: _completeUserInfo);
        
      case 1:
        // 2. 설문조사
        return OnboardingScreen(
          nickname: _nickname,
          // 📍 location은 아직 GPS 잡기 전이므로 임시 값 전달
          // (MainScreen에 진입하면 GPS로 실제 위치를 다시 잡습니다)
          location: "위치 찾는 중...", 
          onComplete: _completeOnboarding, 
        );
        
      case 2:
        // 3. 메인 화면
        return const MainScreen();
        
      default:
        return const Scaffold(body: Center(child: Text("Error")));
    }
  }
}