import 'dart:developer' as developer;
import 'dart:io';

import '../models/call_analysis_result.dart';
import '../models/partner.dart';
import '../providers/firebase_app_state.dart';
import 'call_analysis_service.dart';
import 'firestore_sessions_service.dart';

/// Loads or runs Gemini call analysis for a session.
class SessionAnalysisLoader {
  final CallAnalysisService _callAnalysisService = CallAnalysisService();
  final FirestoreSessionsService _sessionsService = FirestoreSessionsService();

  Partner _partnerFromOverrides({
    required String id,
    required String name,
    required String gender,
  }) {
    return Partner(
      id: id,
      name: name.isEmpty ? 'Partner' : name,
      gender: gender,
      relationshipGoals: const [],
      currentChallenges: const [],
    );
  }

  Future<CallAnalysisResult> loadOrAnalyze({
    required FirebaseAppState appState,
    required String sessionId,
    void Function(String statusLabel)? onStatus,
    String? routeRatedPartnerId,
    String? routeRatedPartnerName,
    String? routeRatedPartnerGender,
    String? routeSelfDisplayName,
    String? routeSelfGender,
  }) async {
    await appState.refreshRelationshipFromServer();

    final cached = _fromAppState(appState, sessionId);
    if (cached != null) {
      onStatus?.call('Using saved analysis');
      return cached;
    }

    onStatus?.call('Checking cloud records…');
    final fromDb = await _sessionsService.getSessionAiAnalysis(sessionId);
    if (fromDb != null) {
      _applyToAppState(appState, fromDb);
      return fromDb;
    }

    onStatus?.call('Transcribing your conversation…');
    final audioPath = appState.pendingCallAudioPath;
    if (audioPath == null) {
      throw Exception(
        'No recording found for this session. End a voice call before viewing AI insights.',
      );
    }

    final audioFile = File(audioPath);
    if (!await audioFile.exists()) {
      throw Exception(
        'Call recording file is missing. Please complete a new voice session.',
      );
    }

    final temp = appState.getTemporarySessionData();

    Partner? other = appState.getOtherPartner();
    Partner? self = appState.getCurrentPartner();

    final routedOtherId = routeRatedPartnerId ?? temp?['partnerId']?.toString();
    final routedOtherName =
        routeRatedPartnerName ?? temp?['partnerName']?.toString();
    final routedOtherGender =
        routeRatedPartnerGender ?? temp?['partnerGender']?.toString() ?? '';

    if (routedOtherId != null && routedOtherId.isNotEmpty) {
      other = _partnerFromOverrides(
        id: routedOtherId,
        name: routedOtherName ?? other?.name ?? 'Partner',
        gender: routedOtherGender.isNotEmpty ? routedOtherGender : (other?.gender ?? ''),
      );
    }

    if (other == null || other.id.isEmpty) {
      throw Exception(
        'Partner information is unavailable. Open the app while logged in with your partner linked, or complete the voice session again.',
      );
    }

    final selfName = routeSelfDisplayName ??
        temp?['selfDisplayName']?.toString() ??
        self?.name ??
        'You';
    final selfGender = routeSelfGender ??
        temp?['selfGender']?.toString() ??
        self?.gender ??
        '';

    final myRaterId = appState.getRaterId() ??
        temp?['currentUserId']?.toString() ??
        self?.id ??
        'A';

    if (myRaterId == other.id) {
      throw Exception(
        'Could not tell which partner you are (duplicate ids). Try refreshing or completing onboarding.',
      );
    }

    onStatus?.call('Analyzing communication patterns…');
    final result = await _callAnalysisService.analyzeCall(
      sessionId: sessionId,
      partners: [
        CallPartnerInfo(
          id: myRaterId,
          name: selfName,
          gender: selfGender,
        ),
        CallPartnerInfo(
          id: other.id,
          name: other.name,
          gender: other.gender,
        ),
      ],
      audioFile: audioFile,
      durationSeconds: appState.pendingCallDurationSeconds,
      conflictTopic: appState.pendingConflictTopic,
    );

    onStatus?.call('Saving insights…');
    await _sessionsService.saveCallAnalysis(
      sessionId,
      transcript: result.transcript,
      analysis: result.analysis,
      appScores: result.appScores.toJson(),
    );

    _applyToAppState(appState, result);
    await appState.clearPendingCallAudio(deleteFile: true);

    developer.log('Session analysis complete for $sessionId');
    return result;
  }

  CallAnalysisResult? _fromAppState(FirebaseAppState appState, String sessionId) {
    final analysis = appState.sessionAiAnalysis;
    final scores = appState.sessionAiScores;
    final transcript = appState.sessionAiTranscript;
    if (analysis == null || scores == null || transcript == null) {
      return null;
    }
    return CallAnalysisResult(
      sessionId: sessionId,
      transcript: transcript,
      analysis: analysis,
      appScores: scores,
    );
  }

  void _applyToAppState(FirebaseAppState appState, CallAnalysisResult result) {
    appState.setSessionAiAnalysis(
      scores: result.appScores,
      analysis: result.analysis,
      transcript: result.transcript,
      transcriptSummary: result.sessionSummary,
    );
  }
}
