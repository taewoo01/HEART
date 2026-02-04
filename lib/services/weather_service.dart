import 'dart:convert';
import 'package:http/http.dart' as http;
import '../utils/theme_utils.dart'; 

// 📦 날씨랑 지역명을 같이 담을 그릇
class WeatherInfo {
  final WeatherType type;
  final String cityName; 
  final double temp;    

  WeatherInfo({required this.type, required this.cityName, required this.temp});
}

class WeatherService {
  // ⚠️ [확인 필수] 여기에 OpenWeatherMap API 키가 잘 들어있는지 확인하세요!
  // 예: 'a1b2c3d4e5f6...'
  final String _apiKey = 'd35ca65ce8d90fa1d3d50c2c2ffb2bde'; 

  Future<WeatherInfo> getCurrentWeather(double lat, double lon) async {
    try {
      print("🚀 [WeatherService] 날씨 요청 시작: 위도($lat), 경도($lon)");

      // 1. API 키 확인
      if (_apiKey == '여기에_OPENWEATHERMAP_KEY_입력') {
        print("❌ [WeatherService] 오류: API 키가 설정되지 않았습니다!");
        return WeatherInfo(type: WeatherType.sunny, cityName: "키 설정 필요", temp: 0.0);
      }

      final url = Uri.parse(
          'https://api.openweathermap.org/data/2.5/weather?lat=$lat&lon=$lon&appid=$_apiKey&units=metric');
      
      // 2. 인터넷으로 요청 보내기
      final response = await http.get(url);

      print("📡 [WeatherService] 응답 코드: ${response.statusCode}");

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        
        String mainCondition = data['weather'][0]['main']; 
        String cityName = data['name']; 
        double temp = (data['main']['temp'] as num).toDouble();

        // 밤낮 계산
        int dt = data['dt'];
        int sunrise = data['sys']['sunrise'];
        int sunset = data['sys']['sunset'];
        bool isNight = (dt >= sunset) || (dt < sunrise);

        print("✅ [WeatherService] 성공! 지역: $cityName, 날씨: $mainCondition, 온도: $temp°C");

        return WeatherInfo(
          type: _mapToWeatherType(mainCondition, isNight),
          cityName: cityName,
          temp: temp,
        );
      } else {
        print("❌ [WeatherService] API 실패: ${response.body}"); // 에러 메시지 자세히 출력
        return WeatherInfo(type: WeatherType.sunny, cityName: "통신 실패", temp: 0.0);
      }
    } catch (e) {
      print("🚨 [WeatherService] 시스템 에러: $e");
      return WeatherInfo(type: WeatherType.sunny, cityName: "에러 발생", temp: 0.0);
    }
  }

  WeatherType _mapToWeatherType(String condition, bool isNight) {
    switch (condition) {
      case 'Thunderstorm': case 'Drizzle': case 'Rain':
        return WeatherType.rainy;
      case 'Snow':
        return WeatherType.snowy;
      case 'Clouds': case 'Mist': case 'Fog': case 'Haze': case 'Dust': case 'Sand':
        return WeatherType.cloudy;
    }
    if (condition == 'Clear') {
      return isNight ? WeatherType.night : WeatherType.sunny;
    }
    return isNight ? WeatherType.night : WeatherType.sunny;
  }
}