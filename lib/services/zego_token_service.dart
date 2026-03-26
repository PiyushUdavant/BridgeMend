import 'dart:convert';
import 'dart:developer' as developer;
import 'package:http/http.dart' as http;

class ZegoTokenService {
  // Replace with your EC2 instance URL
  static const String baseUrl = 'http://13.223.2.148:3000';

  /// Generate ZEGOCLOUD token from your backend
  static Future<String?> generateToken(String userId, String roomId) async {
    try {
      developer.log('Requesting ZEGO token for user: $userId, room: $roomId');

      final response = await http.post(
        Uri.parse('$baseUrl/zego-token'),
        headers: {
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'userId': userId,
          'roomId': roomId,
        }),
      ).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final token = data['token'] as String?;
        
        if (token != null) {
          developer.log('ZEGO token generated successfully');
          return token;
        } else {
          developer.log('ERROR: Token is null in response');
          return null;
        }
      } else {
        developer.log('ERROR: Failed to generate token - Status: ${response.statusCode}');
        developer.log('Response: ${response.body}');
        return null;
      }
    } catch (e) {
      developer.log('ERROR: Exception while generating token: $e');
      return null;
    }
  }

  /// Validate ZEGOCLOUD token
  static Future<bool> validateToken(String token) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/zego-token/validate'),
        headers: {
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'token': token,
        }),
      ).timeout(const Duration(seconds: 5));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return data['valid'] == true;
      }
      
      return false;
    } catch (e) {
      developer.log('Error validating token: $e');
      return false;
    }
  }

  /// Check if backend server is reachable
  static Future<bool> checkServerHealth() async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/health'),
      ).timeout(const Duration(seconds: 5));

      return response.statusCode == 200;
    } catch (e) {
      developer.log('Server health check failed: $e');
      return false;
    }
  }
}