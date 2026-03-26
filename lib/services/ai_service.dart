import 'dart:math';
import '../models/communication_session.dart';

class AIService {
  static const List<String> _conversationStarters = [
    "What is the main concern you'd like to address today?",
    "How are you both feeling about your relationship right now?",
    "What brought you here today? What would you like to work on together?",
    "Can you share what's been on your mind lately regarding your relationship?",
    "What's one thing you'd like your partner to understand better about you?",
    "Let's start with something positive - what's been going well in your relationship lately?",
    "How would you like today's conversation to help strengthen your connection?",
    "What topic would feel most important for you both to discuss right now?",
  ];

  static const List<String> _guidingQuestions = [
    "How do you feel about what your partner just said?",
    "Can you help your partner understand your perspective on this?",
    "What would you need to feel heard in this situation?",
    "How can you both work together to address this challenge?",
    "What's one thing you appreciate about how your partner is communicating right now?",
    "Can you share more about what this means to you?",
    "How would you like to move forward on this topic?",
    "What support do you need from each other?",
    "Let's pause for a moment - what are you both hearing from each other?",
    "How might you express that in a way that shows care for your partner?",
    "What underlying need or feeling is driving this concern?",
    "Can you both take a breath and share what you most want your partner to know?",
  ];

  static const List<String> _gratitudePrompts = [
    "Take a moment to thank your partner for their openness and effort in resolving this.",
    "Share something you appreciated about how your partner communicated during this conversation.",
    "Express gratitude for your partner's willingness to work on this together.",
    "Thank your partner for being vulnerable and honest with you today.",
  ];

  static const List<String> _reflectionQuestions = [
    "What's one thing your partner did during this conversation that you appreciated?",
    "What's one thing you can do to support each other moving forward?",
    "How do you feel about the progress you made today?",
    "What did you learn about your partner or your relationship from this conversation?",
    "What commitment can you both make to continue growing together?",
  ];

  static const List<String> _bondingActivities = [
    "Take a short walk together and talk about something fun you're looking forward to.",
    "Plan a relaxing evening together without distractions.",
    "Schedule your next date night or plan something special to look forward to.",
    "Spend 10 minutes doing something you both enjoy together.",
    "Share a favorite memory you have together.",
    "Cook a meal together or share a favorite snack.",
    "Give each other a hug and take three deep breaths together.",
  ];

  String getConversationStarter() {
    final random = Random();
    return _conversationStarters[random.nextInt(_conversationStarters.length)];
  }

  String getGuidingQuestion() {
    final random = Random();
    return _guidingQuestions[random.nextInt(_guidingQuestions.length)];
  }

  String getGratitudePrompt() {
    final random = Random();
    return _gratitudePrompts[random.nextInt(_gratitudePrompts.length)];
  }

  String getReflectionQuestion() {
    final random = Random();
    return _reflectionQuestions[random.nextInt(_reflectionQuestions.length)];
  }

  List<String> getBondingActivities({int count = 3}) {
    final random = Random();
    final activities = List<String>.from(_bondingActivities);
    activities.shuffle(random);
    return activities.take(count).toList();
  }

  String getInterruptionWarning(String partnerName) {
    final warnings = [
      "Please let $partnerName finish their thought before responding.",
      "Let's give $partnerName space to complete their thoughts.",
      "Hold on - let's make sure $partnerName feels heard before responding.",
      "Take a moment to let $partnerName finish sharing.",
    ];
    final random = Random();
    return warnings[random.nextInt(warnings.length)];
  }

  String getCelebratoryMessage() {
    final messages = [
      "Great work! You've taken an important step toward understanding each other better.",
      "Wonderful progress! Your willingness to communicate openly is strengthening your relationship.",
      "Excellent! You're building stronger communication skills together.",
      "Beautiful work! This kind of honest dialogue brings couples closer together.",
    ];
    final random = Random();
    return messages[random.nextInt(messages.length)];
  }

  // Simulated AI analysis - in a real app, this would call an actual AI service
  Future<CommunicationScores> analyzeCommunication(CommunicationSession session) async {
    try {
      // Simulate API delay
      await Future.delayed(const Duration(seconds: 2));

      // For voice-based sessions, we'll simulate scores based on session duration and participation
      final random = Random();
      final sessionDuration = session.endTime?.difference(session.startTime).inMinutes ?? 0;
      
      // Simulate participation based on session duration (longer sessions = better participation)
      final hasGoodParticipation = sessionDuration >= 5; // At least 5 minutes
      
      // Generate scores for both partners
      final partnerAScore = _generateVoiceBasedScore(hasGoodParticipation, random, true);
      final partnerBScore = _generateVoiceBasedScore(hasGoodParticipation, random, false);

      return CommunicationScores(
        partnerScores: {
          'A': partnerAScore,
          'B': partnerBScore,
        },
        overallFeedback: _generateOverallFeedback(partnerAScore, partnerBScore),
        improvementSuggestions: _generateImprovementSuggestions(),
      );
    } catch (e) {
      // If anything fails, throw a clear error
      throw Exception('Failed to analyze communication: $e');
    }
  }

  PartnerScore _generateVoiceBasedScore(bool hasGoodParticipation, Random random, bool isPartnerA) {
    // Generate realistic scores for voice-based communication
    // Vary scores slightly between partners for realism
    final baseModifier = isPartnerA ? 0.0 : 0.05; // Partner B gets slightly different scores
    
    final empathy = (0.65 + baseModifier) + (random.nextDouble() * 0.25);
    final listening = (0.60 + baseModifier) + (random.nextDouble() * 0.30);
    final reception = (0.70 + baseModifier) + (random.nextDouble() * 0.25);
    final clarity = (0.65 + baseModifier) + (random.nextDouble() * 0.25);
    final respect = (0.75 + baseModifier) + (random.nextDouble() * 0.20);
    final responsiveness = hasGoodParticipation 
        ? (0.70 + baseModifier) + (random.nextDouble() * 0.25)
        : (0.50 + baseModifier) + (random.nextDouble() * 0.30);
    final openMindedness = (0.60 + baseModifier) + (random.nextDouble() * 0.30);

    return PartnerScore(
      empathy: empathy.clamp(0.0, 1.0),
      listening: listening.clamp(0.0, 1.0),
      reception: reception.clamp(0.0, 1.0),
      clarity: clarity.clamp(0.0, 1.0),
      respect: respect.clamp(0.0, 1.0),
      responsiveness: responsiveness.clamp(0.0, 1.0),
      openMindedness: openMindedness.clamp(0.0, 1.0),
      strengths: _generateStrengths(empathy, listening, respect),
      improvements: _generateImprovements(reception, clarity, openMindedness),
    );
  }

  List<String> _generateStrengths(double empathy, double listening, double respect) {
    final strengths = <String>[];
    
    if (empathy > 0.8) strengths.add("Shows strong emotional understanding");
    if (listening > 0.8) strengths.add("Excellent active listening skills");
    if (respect > 0.85) strengths.add("Maintains respectful communication");
    
    if (strengths.isEmpty) {
      strengths.add("Engaged in the conversation willingly");
    }
    
    return strengths;
  }

  List<String> _generateImprovements(double reception, double clarity, double openMindedness) {
    final improvements = <String>[];
    
    if (reception < 0.7) improvements.add("Practice being more receptive to feedback");
    if (clarity < 0.7) improvements.add("Work on expressing thoughts more clearly");
    if (openMindedness < 0.7) improvements.add("Consider alternative perspectives more openly");
    
    if (improvements.isEmpty) {
      improvements.add("Continue building on current communication strengths");
    }
    
    return improvements;
  }

  String _generateOverallFeedback(PartnerScore scoreA, PartnerScore scoreB) {
    final avgA = scoreA.averageScore;
    final avgB = scoreB.averageScore;
    final overall = (avgA + avgB) / 2;

    if (overall > 0.8) {
      return "Excellent communication! You both demonstrated strong listening skills, empathy, and respect for each other. Keep up this positive momentum in your relationship.";
    } else if (overall > 0.7) {
      return "Good progress in your communication. You're showing positive engagement and willingness to understand each other. Focus on the areas for improvement to strengthen your connection further.";
    } else if (overall > 0.6) {
      return "You're making efforts to communicate, but there's room for growth. Practice active listening and expressing yourselves with more clarity and empathy.";
    } else {
      return "This conversation shows you're both committed to working on your relationship. Focus on listening more actively and expressing yourselves with greater respect and openness.";
    }
  }

  List<String> _generateImprovementSuggestions() {
    final suggestions = [
      "Practice 'I' statements to express feelings without blame",
      "Take turns speaking without interrupting each other",
      "Reflect back what you heard before responding",
      "Ask clarifying questions when you don't understand",
      "Express appreciation for your partner's efforts to communicate",
      "Take breaks when emotions get too intense",
      "Focus on one topic at a time during discussions",
    ];
    
    final random = Random();
    suggestions.shuffle(random);
    return suggestions.take(3).toList();
  }

  // Detect potential interruptions based on timing
  bool detectInterruption(List<Message> recentMessages, Duration timeSinceLastMessage) {
    if (recentMessages.length < 2) return false;
    
    final lastMessage = recentMessages.last;
    final secondLastMessage = recentMessages[recentMessages.length - 2];
    
    // If different speakers and very quick succession (less than 2 seconds)
    if (lastMessage.speakerId != secondLastMessage.speakerId &&
        timeSinceLastMessage.inSeconds < 2) {
      return true;
    }
    
    return false;
  }

  // Analyze emotional tone (simplified for MVP)
  String analyzeEmotionalTone(String text) {
    final lowercaseText = text.toLowerCase();
    
    if (lowercaseText.contains(RegExp(r'\b(angry|mad|furious|upset|frustrated)\b'))) {
      return 'tense';
    } else if (lowercaseText.contains(RegExp(r'\b(sad|hurt|disappointed|lonely)\b'))) {
      return 'sad';
    } else if (lowercaseText.contains(RegExp(r'\b(happy|good|great|wonderful|love)\b'))) {
      return 'positive';
    } else if (lowercaseText.contains(RegExp(r'\b(sorry|apologize|my fault|mistake)\b'))) {
      return 'apologetic';
    } else {
      return 'neutral';
    }
  }

  // Generate contextual response based on conversation flow
  String generateContextualResponse(List<Message> messages, String currentTone) {
    if (messages.isEmpty) {
      return getConversationStarter();
    }

    final recentUserMessages = messages
        .where((m) => m.type == MessageType.user)
        .toList()
        .reversed
        .take(3)
        .toList();

    if (currentTone == 'tense' || currentTone == 'sad') {
      return "I can sense some strong emotions here. Let's take a moment to make sure you both feel heard. ${getGuidingQuestion()}";
    }

    if (recentUserMessages.length >= 4) {
      return "You're both sharing openly, which is wonderful. ${getGuidingQuestion()}";
    }

    return getGuidingQuestion();
  }
}