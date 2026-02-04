import 'package:flutter/material.dart';
import '../utils/theme_utils.dart'; 

class UserInfoScreen extends StatefulWidget {
  // 🚀 변경점: 이제 위치(String location)는 안 받고 닉네임만 넘깁니다!
  final Function(String nickname) onCompleted;

  const UserInfoScreen({super.key, required this.onCompleted});

  @override
  State<UserInfoScreen> createState() => _UserInfoScreenState();
}

class _UserInfoScreenState extends State<UserInfoScreen> {
  final TextEditingController _nicknameController = TextEditingController();

  void _submit() {
    final nickname = _nicknameController.text.trim();
    
    if (nickname.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("닉네임을 입력해주세요. 편하게 불러드릴 이름이면 돼요.")),
      );
      return;
    }

    // 부모 위젯으로 닉네임만 전달 (위치는 나중에 GPS가 알아서 함)
    widget.onCompleted(nickname);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: BoxDecoration(gradient: getWeatherGradient(WeatherType.sunny)),
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.favorite_rounded, size: 60, color: Colors.white),
                  const SizedBox(height: 20),
                  const Text(
                    "반가워요!",
                    style: TextStyle(
                      fontSize: 28, 
                      fontWeight: FontWeight.bold, 
                      color: Colors.white
                    ),
                  ),
                  const SizedBox(height: 10),
                  const Text(
                    "당신과 더 가까워지기 위해\n이름 하나만 알려주세요.",
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 16, color: Colors.white70, height: 1.5),
                  ),
                  
                  const SizedBox(height: 40),

                  // 입력 폼 카드
                  Container(
                    padding: const EdgeInsets.all(25),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.95),
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.1),
                          blurRadius: 20,
                          offset: const Offset(0, 10),
                        ),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text("어떻게 불러드릴까요?", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Color(0xFF6BB8B0))),
                        const SizedBox(height: 10),
                        TextField(
                          controller: _nicknameController,
                          decoration: InputDecoration(
                            hintText: "닉네임 (예: 여행자)",
                            hintStyle: TextStyle(color: Colors.grey[400]),
                            filled: true,
                            fillColor: Colors.grey[100],
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide.none,
                            ),
                            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                          ),
                        ),
                        
                        // 🚀 안내 문구 추가 (위치는 자동이라는 점을 살짝 언급)
                        const SizedBox(height: 15),
                        Row(
                          children: [
                            Icon(Icons.location_on_outlined, size: 14, color: Colors.grey[500]),
                            const SizedBox(width: 5),
                            Text(
                              "사는 곳과 날씨는 제가 자동으로 찾아드릴게요.",
                              style: TextStyle(fontSize: 12, color: Colors.grey[500]),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 40),

                  // 시작 버튼
                  SizedBox(
                    width: double.infinity,
                    height: 55,
                    child: ElevatedButton(
                      onPressed: _submit,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.white,
                        foregroundColor: const Color(0xFF6BB8B0),
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(15),
                        ),
                      ),
                      child: const Text(
                        "여행 시작하기",
                        style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}