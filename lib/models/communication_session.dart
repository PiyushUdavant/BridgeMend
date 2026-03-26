class CommunicationSession {
  final String id;
  final DateTime startTime;
  final DateTime? endTime;
  final List<Message> messages;
  final CommunicationScores? scores;
  final String? reflection;
  final List<String> suggestedActivities;
  final Map<String, bool> participantStatus;

  CommunicationSession({
    required this.id,
    required this.startTime,
    this.endTime,
    required this.messages,
    this.scores,
    this.reflection,
    this.suggestedActivities = const [],
    this.participantStatus = const {},
  });

  Duration get duration {
    if (endTime != null) {
      return endTime!.difference(startTime);
    }
    return DateTime.now().difference(startTime);
  }

  bool get isCompleted => endTime != null;
  
  bool get hasPartnerLeft => participantStatus.values.any((active) => !active);

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'startTime': startTime.toIso8601String(),
      'endTime': endTime?.toIso8601String(),
      'messages': messages.map((m) => m.toJson()).toList(),
      'scores': scores?.toJson(),
      'reflection': reflection,
      'suggestedActivities': suggestedActivities,
      'participantStatus': participantStatus,
    };
  }

  factory CommunicationSession.fromJson(Map<String, dynamic> json) {
    return CommunicationSession(
      id: json['id'],
      startTime: DateTime.parse(json['startTime']),
      endTime: json['endTime'] != null ? DateTime.parse(json['endTime']) : null,
      messages: (json['messages'] as List)
          .map((m) => Message.fromJson(m))
          .toList(),
      scores: json['scores'] != null 
          ? CommunicationScores.fromJson(json['scores']) 
          : null,
      reflection: json['reflection'],
      suggestedActivities: List<String>.from(json['suggestedActivities'] ?? []),
      participantStatus: Map<String, bool>.from(json['participantStatus'] ?? {}),
    );
  }
}

class Message {
  final String speakerId;
  final String content;
  final DateTime timestamp;
  final MessageType type;
  final bool wasInterrupted;

  Message({
    required this.speakerId,
    required this.content,
    required this.timestamp,
    required this.type,
    this.wasInterrupted = false,
  });

  Map<String, dynamic> toJson() {
    return {
      'speakerId': speakerId,
      'content': content,
      'timestamp': timestamp.toIso8601String(),
      'type': type.toString(),
      'wasInterrupted': wasInterrupted,
    };
  }

  factory Message.fromJson(Map<String, dynamic> json) {
    return Message(
      speakerId: json['speakerId'],
      content: json['content'],
      timestamp: DateTime.parse(json['timestamp']),
      type: MessageType.values.firstWhere(
        (e) => e.toString() == json['type'],
        orElse: () => MessageType.user,
      ),
      wasInterrupted: json['wasInterrupted'] ?? false,
    );
  }
}

enum MessageType {
  user,
  ai,
  system,
}

class CommunicationScores {
  final Map<String, PartnerScore> partnerScores;
  final String overallFeedback;
  final List<String> improvementSuggestions;

  CommunicationScores({
    required this.partnerScores,
    required this.overallFeedback,
    required this.improvementSuggestions,
  });

  double get averageScore {
    if (partnerScores.isEmpty) return 0.0;
    final scores = partnerScores.values.map((s) => s.averageScore).toList();
    return scores.reduce((a, b) => a + b) / scores.length;
  }

  Map<String, dynamic> toJson() {
    return {
      'partnerScores': partnerScores.map((k, v) => MapEntry(k, v.toJson())),
      'overallFeedback': overallFeedback,
      'improvementSuggestions': improvementSuggestions,
    };
  }

  factory CommunicationScores.fromJson(Map<String, dynamic> json) {
    return CommunicationScores(
      partnerScores: (json['partnerScores'] as Map<String, dynamic>)
          .map((k, v) => MapEntry(k, PartnerScore.fromJson(v))),
      overallFeedback: json['overallFeedback'],
      improvementSuggestions: List<String>.from(json['improvementSuggestions']),
    );
  }
}

class PartnerScore {
  final double empathy;
  final double listening;
  final double reception;
  final double clarity;
  final double respect;
  final double responsiveness;
  final double openMindedness;
  final List<String> strengths;
  final List<String> improvements;

  PartnerScore({
    required this.empathy,
    required this.listening,
    required this.reception,
    required this.clarity,
    required this.respect,
    required this.responsiveness,
    required this.openMindedness,
    required this.strengths,
    required this.improvements,
  });

  double get averageScore {
    return (empathy + listening + reception + clarity + respect + responsiveness + openMindedness) / 7;
  }

  Map<String, dynamic> toJson() {
    return {
      'empathy': empathy,
      'listening': listening,
      'reception': reception,
      'clarity': clarity,
      'respect': respect,
      'responsiveness': responsiveness,
      'openMindedness': openMindedness,
      'strengths': strengths,
      'improvements': improvements,
    };
  }

  factory PartnerScore.fromJson(Map<String, dynamic> json) {
    return PartnerScore(
      empathy: json['empathy'].toDouble(),
      listening: json['listening'].toDouble(),
      reception: json['reception'].toDouble(),
      clarity: json['clarity'].toDouble(),
      respect: json['respect'].toDouble(),
      responsiveness: json['responsiveness'].toDouble(),
      openMindedness: json['openMindedness'].toDouble(),
      strengths: List<String>.from(json['strengths']),
      improvements: List<String>.from(json['improvements']),
    );
  }
}