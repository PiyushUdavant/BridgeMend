import 'communication_session.dart';

class CallPartnerInfo {
  final String id;
  final String name;
  /// Male, Female, Non-Binary, etc. — used for voice diarization labels.
  final String gender;

  const CallPartnerInfo({
    required this.id,
    required this.name,
    required this.gender,
  });

  Map<String, String> toJson() => {
        'id': id,
        'name': name,
        'gender': gender,
      };
}

class CallAnalysisResult {
  final String sessionId;
  final Map<String, dynamic> transcript;
  final Map<String, dynamic> analysis;
  final CommunicationScores appScores;
  final int? processingTimeMs;

  CallAnalysisResult({
    required this.sessionId,
    required this.transcript,
    required this.analysis,
    required this.appScores,
    this.processingTimeMs,
  });

  factory CallAnalysisResult.fromJson(Map<String, dynamic> json) {
    final appScoresRaw = Map<String, dynamic>.from(
      json['appScores'] as Map,
    );
    return CallAnalysisResult(
      sessionId: json['sessionId'] as String,
      transcript: Map<String, dynamic>.from(json['transcript'] as Map),
      analysis: Map<String, dynamic>.from(json['analysis'] as Map),
      appScores: CommunicationScores.fromJson(appScoresRaw),
      processingTimeMs: (json['meta'] as Map?)?['processingTimeMs'] as int?,
    );
  }

  List<String> get suggestedBondingActivities {
    final items = analysis['suggestedBondingActivities'];
    if (items is List) {
      return items.map((e) => e.toString()).toList();
    }
    return const [];
  }

  String? get sessionSummary => analysis['sessionSummary'] as String?;
}
