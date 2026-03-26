class Partner {
  final String id;
  final String name;
  final String gender;
  final List<String> relationshipGoals;
  final List<String> currentChallenges;
  final String? customGoal;
  final String? customChallenge;

  Partner({
    required this.id,
    required this.name,
    required this.gender,
    required this.relationshipGoals,
    required this.currentChallenges,
    this.customGoal,
    this.customChallenge,
  });

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'gender': gender,
      'relationshipGoals': relationshipGoals,
      'currentChallenges': currentChallenges,
      'customGoal': customGoal,
      'customChallenge': customChallenge,
    };
  }

  factory Partner.fromJson(Map<String, dynamic> json) {
    return Partner(
      id: json['id'],
      name: json['name'],
      gender: json['gender'],
      relationshipGoals: List<String>.from(json['relationshipGoals']),
      currentChallenges: List<String>.from(json['currentChallenges']),
      customGoal: json['customGoal'],
      customChallenge: json['customChallenge'],
    );
  }
}

class RelationshipData {
  final Partner partnerA;
  final Partner partnerB;
  final DateTime createdAt;
  final String inviteCode;

  RelationshipData({
    required this.partnerA,
    required this.partnerB,
    required this.createdAt,
    required this.inviteCode,
  });

  Map<String, dynamic> toJson() {
    return {
      'partnerA': partnerA.toJson(),
      'partnerB': partnerB.toJson(),
      'createdAt': createdAt.toIso8601String(),
      'inviteCode': inviteCode,
    };
  }

  factory RelationshipData.fromJson(Map<String, dynamic> json) {
    return RelationshipData(
      partnerA: Partner.fromJson(json['partnerA']),
      partnerB: Partner.fromJson(json['partnerB']),
      createdAt: DateTime.parse(json['createdAt']),
      inviteCode: json['inviteCode'],
    );
  }
}