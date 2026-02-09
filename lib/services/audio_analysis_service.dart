import 'dart:convert';
import 'dart:io';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;

class AudioAnalysisService {
  static final String _baseUrl =
      dotenv.env['AUDIO_ANALYSIS_BASE_URL'] ?? "http://127.0.0.1:8000";

  Future<Map<String, dynamic>?> analyzeAudio({
    required File audioFile,
    required String userId,
    String? sessionId,
  }) async {
    try {
      final uri = Uri.parse("$_baseUrl/v1/audio/analyze");
      final request = http.MultipartRequest("POST", uri)
        ..fields["user_id"] = userId
        ..fields["session_id"] = sessionId ?? ""
        ..files.add(await http.MultipartFile.fromPath("file", audioFile.path));

      final streamed = await request.send();
      final response = await http.Response.fromStream(streamed);

      if (response.statusCode < 200 || response.statusCode >= 300) {
        print("❌ [AudioAnalysis] ${response.statusCode}: ${response.body}");
        return null;
      }
      return jsonDecode(response.body) as Map<String, dynamic>;
    } catch (e) {
      print("❌ [AudioAnalysis] 요청 실패: $e");
      return null;
    }
  }
}
