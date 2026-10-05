import 'dart:convert';
import 'package:http/http.dart' as http;

class ApiService {
  // Android Emulator → computer running FastAPI
  static const String baseUrl = 'http://10.0.2.2:8000';

  static Future<String> testBackend() async {
    final response = await http.get(
      Uri.parse('$baseUrl/test'),
    );

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);

      return data['message'];
    } else {
      throw Exception(
        'Backend request failed: ${response.statusCode}',
      );
    }
  }
}