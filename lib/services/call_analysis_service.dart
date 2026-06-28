import 'dart:convert';
import 'dart:developer' as developer;
import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';
import '../config/api_config.dart';
import '../models/call_analysis_result.dart';

class CallAnalysisService {
  static const Duration _timeout = Duration(seconds: 500);

  static String get _analyzeUrl =>
      '${ApiConfig.serverBaseUrl}/api/call/analyze';

  static String get _analyzeTextUrl =>
      '${ApiConfig.serverBaseUrl}/api/call/analyze-text';

  /// Upload call audio for STT + Gemini analysis.
  Future<CallAnalysisResult> analyzeCall({
    required String sessionId,
    required List<CallPartnerInfo> partners,
    required File audioFile,
    int? durationSeconds,
    String? conflictTopic,
  }) async {
    final request = http.MultipartRequest('POST', Uri.parse(_analyzeUrl));

    request.fields['sessionId'] = sessionId;
    request.fields['partners'] = jsonEncode(
      partners.map((p) => p.toJson()).toList(),
    );

    if (durationSeconds != null) {
      request.fields['durationSeconds'] = durationSeconds.toString();
    }
    if (conflictTopic != null && conflictTopic.isNotEmpty) {
      request.fields['conflictTopic'] = conflictTopic;
    }

    final ext = audioFile.path.split('.').last.toLowerCase();

    MediaType contentType;

    switch(ext){
      case 'm4a':
        contentType = MediaType('audio', 'mp4');
        break;

      case 'aac':
        contentType = MediaType('audio', 'aac');
        break;

      case 'mp3': 
        contentType = MediaType('audio', 'mpeg');
        break;

      case 'wav':
        contentType = MediaType('audio', 'wav');
        break;

      case 'webm':
        contentType = MediaType('audio', 'webm');
        break;

      default:
        contentType = MediaType('application', 'octet-stream');
    }

    request.files.add(
      await http.MultipartFile.fromPath(
        'audio',
        audioFile.path,
        filename: 'call.$ext',
        contentType: contentType,
      ),
    );

    developer.log(
      'CallAnalysisService: uploading audio (${await audioFile.length()} bytes), ext=$ext, type=$contentType',
    );

    final streamed = await request.send().timeout(_timeout);
    final response = await http.Response.fromStream(streamed);

    return _parseResponse(response);
  }

  /// Analyze an existing transcript (no audio upload).
  Future<CallAnalysisResult> analyzeTranscript({
    required String sessionId,
    required List<CallPartnerInfo> partners,
    required String transcript,
    int? durationSeconds,
    String? conflictTopic,
  }) async {
    final body = <String, dynamic>{
      'sessionId': sessionId,
      'partners': partners.map((p) => p.toJson()).toList(),
      'transcript': transcript,
      if (durationSeconds != null) 'durationSeconds': durationSeconds,
      if (conflictTopic != null && conflictTopic.isNotEmpty)
        'conflictTopic': conflictTopic,
    };

    final response = await http
        .post(
          Uri.parse(_analyzeTextUrl),
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode(body),
        )
        .timeout(_timeout);

    return _parseResponse(response);
  }

  CallAnalysisResult _parseResponse(http.Response response) {
    if (response.statusCode == 200) {
      final json = jsonDecode(response.body) as Map<String, dynamic>;
      if (json['success'] == true) {
        return CallAnalysisResult.fromJson(json);
      }
      throw CallAnalysisException(
        json['message']?.toString() ?? 'Analysis failed',
        statusCode: response.statusCode,
      );
    }

    String message = 'Server error (${response.statusCode})';
    try {
      final json = jsonDecode(response.body) as Map<String, dynamic>;
      message = json['message']?.toString() ?? json['error']?.toString() ?? message;
    } catch (_) {
      if (response.body.isNotEmpty) {
        message = response.body.length > 200
            ? '${response.body.substring(0, 200)}…'
            : response.body;
      }
    }

    throw CallAnalysisException(message, statusCode: response.statusCode);
  }
}

class CallAnalysisException implements Exception {
  final String message;
  final int? statusCode;

  CallAnalysisException(this.message, {this.statusCode});

  @override
  String toString() => message;
}
