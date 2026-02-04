import 'package:geolocator/geolocator.dart';

class LocationService {
  Future<Position?> getCurrentLocation() async {
    bool serviceEnabled;
    LocationPermission permission;

    // 1. GPS 켜져 있나 확인
    serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      print('❌ 위치 서비스(GPS)가 꺼져 있습니다.');
      return null;
    }

    // 2. 권한 확인
    permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      // 권한 없으면 물어보기
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        print('❌ 위치 권한 거부됨');
        return null;
      }
    }

    if (permission == LocationPermission.deniedForever) {
      print('❌ 위치 권한 영구 거부됨 (설정에서 켜야 함)');
      return null;
    }

    // 3. 위도/경도 가져오기 성공!
    return await Geolocator.getCurrentPosition(
      desiredAccuracy: LocationAccuracy.high,
    );
  }
}