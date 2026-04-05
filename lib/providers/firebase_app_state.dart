import 'package:flutter/foundation.dart';
import 'dart:developer' as developer;
import 'dart:async';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/partner.dart';
import '../models/communication_session.dart';
import '../services/firebase_auth_service.dart';
import '../services/firestore_invite_service.dart';
import '../services/firestore_relationship_service.dart';
import '../services/firestore_sessions_service.dart';

class InviteJoinResult {
  final bool isSuccess;
  final String? errorMessage;

  const InviteJoinResult._({required this.isSuccess, this.errorMessage});

  factory InviteJoinResult.success() {
    return const InviteJoinResult._(isSuccess: true);
  }

  factory InviteJoinResult.failure(String message) {
    return InviteJoinResult._(isSuccess: false, errorMessage: message);
  }
}

class FirebaseAppState extends ChangeNotifier {
  // Services
  final FirebaseAuthService _authService = FirebaseAuthService();
  final FirestoreInviteService _inviteService = FirestoreInviteService();
  final FirestoreRelationshipService _relationshipService =
      FirestoreRelationshipService();
  final FirestoreSessionsService _sessionsService = FirestoreSessionsService();

  // State
  User? _user;
  Map<String, dynamic>? _relationshipData;
  List<CommunicationSession> _sessions = [];
  CommunicationSession? _currentSession;
  String? _currentSessionId;
  bool _isOnboardingComplete = false;
  String? _currentUserId;
  bool _isLoading = true;

  // Temporary storage for session data during navigation
  Map<String, dynamic>? _temporarySessionData;

  // Getters
  User? get user => _user;
  Map<String, dynamic>? get relationshipData => _relationshipData;
  List<CommunicationSession> get sessions => _sessions;
  CommunicationSession? get currentSession => _currentSession;
  bool get isOnboardingComplete => _isOnboardingComplete;
  String? get currentUserId => _currentUserId;
  bool get hasPartner => _relationshipData?['partnerB'] != null;
  bool get isAuthenticated => _user != null;
  bool get isLoading => _isLoading;

  // Temporary session data methods
  void setTemporarySessionData({
    required String? sessionId,
    required String? currentUserId,
    required String? partnerId,
    required String? partnerName,
  }) {
    _temporarySessionData = {
      'sessionId': sessionId,
      'currentUserId': currentUserId,
      'partnerId': partnerId,
      'partnerName': partnerName,
    };
    notifyListeners();
  }

  Map<String, dynamic>? getTemporarySessionData() {
    return _temporarySessionData;
  }

  void clearTemporarySessionData() {
    _temporarySessionData = null;
    notifyListeners();
  }

  // Initialize the app state
  Future<void> initialize() async {
    // Listen to auth state changes
    _authService.authStateChanges.listen((user) async {
      developer.log('🔥 Auth state changed: $user');
      _user = user;
      if (user != null) {
        debugPrint('🔥 User signed in, loading data...');
        await _loadUserData();
      } else {
        debugPrint(
          '🔥 User signed out, clearing data and should navigate to login...',
        );
        _clearUserData();
      }
      _isLoading = false;
      debugPrint(
        '🔥 Calling notifyListeners() - AuthWrapper should rebuild now',
      );
      notifyListeners();
    });

    // Get initial auth state
    _user = _authService.currentUser;
    if (_user != null) {
      await _loadUserData();
    }
    _isLoading = false;
    notifyListeners();
  }

  // Load user data from Firestore
  Future<void> _loadUserData() async {
    debugPrint('🔥 Loading user data for user: ${_user?.id}');
    try {
      // Load relationship data
      debugPrint('🔥 Calling getUserRelationship()...');
      _relationshipData = await _relationshipService.getUserRelationship();
      debugPrint('🔥 Relationship data result: $_relationshipData');

      if (_relationshipData != null) {
        debugPrint(
          '🔥 Found relationship data - setting onboarding complete to true',
        );
        _isOnboardingComplete = true;
        // Determine current user ID based on relationship data
        if (_relationshipData!['createdBy'] == _user!.id) {
          _currentUserId = 'A';
          debugPrint('🔥 User is Partner A');
        } else {
          _currentUserId = 'B';
          debugPrint('🔥 User is Partner B');
        }
        // Load sessions
        debugPrint('🔥 Loading sessions...');
        _sessions = await _sessionsService.getRelationshipSessions(
          _relationshipData!['id'],
        );
        // Load active session
        debugPrint('🔥 Loading active session...');
        _currentSession = await _sessionsService.getActiveSession(
          _relationshipData!['id'],
        );
        debugPrint('🔥 Sessions loaded successfully');
      } else {
        debugPrint('🔥 No relationship data found - onboarding incomplete');
        _isOnboardingComplete = false;
      }
      debugPrint(
        '🔥 Finished loading user data. Onboarding complete: $_isOnboardingComplete',
      );
    } catch (e) {
      debugPrint('🔥 ERROR loading user data: $e');
      _isOnboardingComplete = false;
    }
  }

  // Clear user data
  void _clearUserData() {
    debugPrint('🔥 Clearing user data and setting user to null');
    _user = null; // This is crucial for navigation
    _relationshipData = null;
    _sessions = [];
    _currentSession = null;
    _currentSessionId = null;
    _isOnboardingComplete = false;
    _currentUserId = null;
  }

  // Sign in with Google
  Future<String?> signInWithGoogle() async {
    final result = await _authService.signInWithGoogle();
    if (result.user != null) {
      return null; // Success, no error
    } else {
      return result.errorMessage ?? 'Unknown error occurred during sign-in.';
    }
  }

  // Sign in with email and password
  Future<String?> signInWithEmail(String email, String password) async {
    final result = await _authService.signInWithEmail(email, password);
    if (result.user != null) {
      return null; // Success, no error
    } else {
      return result.errorMessage ?? 'Unknown error occurred during sign-in.';
    }
  }

  // Sign up with email and password
  Future<String?> signUpWithEmail(String email, String password) async {
    final result = await _authService.signUpWithEmail(email, password);
    if (result.user != null) {
      return null; // Success, no error
    } else {
      return result.errorMessage ?? 'Unknown error occurred during sign-up.';
    }
  }

  // Send password reset email
  Future<String?> sendPasswordResetEmail(String email) async {
    final result = await _authService.sendPasswordResetEmail(email);
    if (result.errorMessage == null) {
      return null; // Success, no error
    } else {
      return result.errorMessage ?? 'Unknown error occurred.';
    }
  }

  // Send email verification
  Future<String?> sendEmailVerification() async {
    final result = await _authService.sendEmailVerification();
    if (result.errorMessage == null) {
      return null; // Success, no error
    } else {
      return result.errorMessage ?? 'Unknown error occurred.';
    }
  }

  // Reload user to check verification status
  Future<void> reloadUser() async {
    await _authService.reloadUser();
    notifyListeners();
  }

  // Delete current user account (for unverified accounts)
  Future<String?> deleteCurrentUser() async {
    final result = await _authService.deleteCurrentUser();
    if (result.errorMessage == null) {
      return null; // Success, no error
    } else {
      return result.errorMessage ?? 'Unknown error occurred.';
    }
  }

  // Check if user needs email verification
  bool get needsEmailVerification => _authService.needsEmailVerification;

  // Get user creation time
  DateTime? get userCreationTime => _authService.userCreationTime;

  // Sign out
  Future<void> signOut() async {
    try {
      debugPrint('🔥 Starting sign out process...');
      await _authService.signOut();
      debugPrint('🔥 Sign out completed successfully');
    } catch (e) {
      debugPrint('🔥 ERROR: Sign out failed: $e');
      rethrow;
    }
  }

  // Delete account
  Future<String?> deleteAccount() async {
    try {
      debugPrint('🔥 Starting account deletion process...');

      // Delete the authenticated account FIRST (before signing out)
      debugPrint('🔥 Step 1: Deleting authenticated account...');
      var result = await _authService.deleteCurrentUser().timeout(
        const Duration(seconds: 30),
        onTimeout: () {
          debugPrint('🔥 Step 1: Auth deletion timed out');
          return AuthResult(
            errorMessage: 'Account deletion timed out. Please try again.',
          );
        },
      );

      if (result.errorMessage != null) {
        debugPrint('🔥 Step 1: Auth deletion failed: ${result.errorMessage}');
        // If recent-login required and user is Google signed-in, attempt reauth once
        if (result.errorMessage!.contains('sign in again') &&
            _authService.userHasProvider('google.com')) {
          debugPrint(
            '🔥 Attempting Google reauthentication for account deletion...',
          );
          final reauth = await _authService.reauthenticateWithGoogle();
          if (reauth.errorMessage != null) {
            debugPrint('🔥 Reauthentication failed: ${reauth.errorMessage}');
            return result.errorMessage; // original error
          }
          debugPrint('🔥 Reauthentication succeeded. Retrying deletion...');
          result = await _authService.deleteCurrentUser();
          if (result.errorMessage != null) {
            debugPrint(
              '🔥 Deletion still failed after reauth: ${result.errorMessage}',
            );
            return result.errorMessage;
          }
        } else {
          return result.errorMessage;
        }
      }
      debugPrint('🔥 Step 1: Auth account deletion API succeeded');

      // Then clear all user data (relationships, sessions, etc.)
      debugPrint('🔥 Step 2: Clearing all user data...');
      if (_relationshipData != null &&
          _relationshipData!['createdBy'] == _user?.id) {
        await _relationshipService
            .deleteRelationship(_relationshipData!['id'])
            .timeout(
              const Duration(seconds: 15),
              onTimeout: () {
                debugPrint(
                  '🔥 Step 2: Relationship deletion timed out (non-critical)',
                );
              },
            );
      }
      debugPrint('🔥 Step 2: User data cleared successfully');

      // Clear local state
      debugPrint('🔥 Step 3: Clearing local state...');
      _clearUserData();
      notifyListeners();
      debugPrint('🔥 Step 3: Local state cleared successfully');

      debugPrint('🔥 Account deletion completed successfully');
      return null; // Success
    } catch (e) {
      debugPrint('🔥 ERROR: Account deletion failed: $e');
      debugPrint('🔥 Stack trace: ${StackTrace.current}');
      return 'Failed to delete account. Please try again or contact support.';
    }
  }

  // Complete onboarding for Partner A
  Future<void> completeOnboarding(Partner partner) async {
    try {
      if (_user == null) {
        throw Exception('User not authenticated');
      }

      _currentUserId = partner.id;

      if (partner.id == 'A') {
        // Create relationship (no invite code)
        final relationshipId = await _relationshipService.createRelationship(
          partner,
          '', // Pass empty string for invite code
        );

        // Load the created relationship
        _relationshipData = await _relationshipService.getRelationshipById(
          relationshipId,
        );
        _isOnboardingComplete = true;

        notifyListeners();
      } else {
        throw Exception('Partner B should use joinWithInviteCode method');
      }
    } catch (e) {
      debugPrint('Error completing onboarding: $e');
      rethrow;
    }
  }

  // Join with invite code for Partner B
  Future<InviteJoinResult> joinWithInviteCode(
    String code,
    Partner partner,
  ) async {
    try {
      if (_user == null) {
        return InviteJoinResult.failure('User not authenticated');
      }

      _currentUserId = partner.id;

      // Validate the invite code
      final result = await _inviteService.validateAndUseInvite(code, partner);

      if (result.isValid && result.partner != null) {
        // Find the relationship by invite code
        final relationshipData = await _relationshipService
            .findRelationshipByInviteCode(code);

        if (relationshipData != null) {
          // Join the relationship
          await _relationshipService.joinRelationship(
            relationshipData['id'],
            partner,
          );

          // Load the updated relationship
          _relationshipData = await _relationshipService.getRelationshipById(
            relationshipData['id'],
          );
          _isOnboardingComplete = true;

          notifyListeners();
          return InviteJoinResult.success();
        } else {
          return InviteJoinResult.failure('Relationship not found');
        }
      } else {
        return InviteJoinResult.failure(
          result.errorMessage ?? 'Invalid invite code',
        );
      }
    } catch (e) {
      debugPrint('Error joining with invite code: $e');
      return InviteJoinResult.failure(
        'An error occurred while joining. Please try again.',
      );
    }
  }

  // Start a communication session
  Future<void> startCommunicationSession({String? sessionCode}) async {
    try {
      if (_relationshipData == null || !hasPartner || _user == null) return;

      final session = CommunicationSession(
        id: sessionCode ?? DateTime.now().millisecondsSinceEpoch.toString(),
        startTime: DateTime.now(),
        messages: [],
        participantStatus: {'A': true, 'B': true},
      );

      if (sessionCode != null) {
        // Use the existing session document from waiting room
        _currentSessionId = sessionCode;
        await _sessionsService.updateSession(sessionCode, session);
      } else {
        // Create a new session
        _currentSessionId = await _sessionsService.createSession(
          _relationshipData!['id'],
          session,
        );
      }

      _currentSession = session;

      notifyListeners();
    } catch (e) {
      debugPrint('Error starting communication session: $e');
    }
  }

  // Add a message to the current session
  Future<void> addMessage(
    String speakerId,
    String content,
    MessageType type, {
    bool wasInterrupted = false,
  }) async {
    try {
      if (_currentSession == null || _currentSessionId == null) return;

      final message = Message(
        speakerId: speakerId,
        content: content,
        timestamp: DateTime.now(),
        type: type,
        wasInterrupted: wasInterrupted,
      );

      _currentSession!.messages.add(message);
      await _sessionsService.addMessage(_currentSessionId!, message);

      notifyListeners();
    } catch (e) {
      debugPrint('Error adding message: $e');
    }
  }

  // Mark current user as left from session
  Future<void> leaveCurrentSession() async {
    try {
      if (_currentSession == null ||
          _currentSessionId == null ||
          _currentUserId == null) {
        debugPrint(
          'Cannot leave session - missing session info: session=$_currentSession, sessionId=$_currentSessionId, userId=$_currentUserId',
        );
        return;
      }

      debugPrint(
        'Leaving session: sessionId=$_currentSessionId, userId=$_currentUserId',
      );
      await _sessionsService.markParticipantLeft(
        _currentSessionId!,
        _currentUserId!,
      );

      notifyListeners();
    } catch (e) {
      debugPrint('Error leaving communication session: $e');
    }
  }

  // End the current communication session
  Future<void> endCommunicationSession({
    CommunicationScores? scores,
    String? reflection,
    List<String>? suggestedActivities,
  }) async {
    try {
      if (_currentSession == null || _currentSessionId == null) return;

      // End the session in Firestore
      await _sessionsService.endSession(
        _currentSessionId!,
        scores: scores,
        reflection: reflection,
        suggestedActivities: suggestedActivities,
      );

      // Update local state
      final completedSession = CommunicationSession(
        id: _currentSession!.id,
        startTime: _currentSession!.startTime,
        endTime: DateTime.now(),
        messages: _currentSession!.messages,
        scores: scores,
        reflection: reflection,
        suggestedActivities: suggestedActivities ?? [],
        participantStatus: _currentSession!.participantStatus,
      );

      _sessions.insert(0, completedSession);
      _currentSession = null;
      _currentSessionId = null;

      // Reload sessions to refresh insights data
      await _reloadSessions();

      notifyListeners();
    } catch (e) {
      debugPrint('Error ending communication session: $e');
    }
  }

  // Reload sessions from Firestore
  Future<void> _reloadSessions() async {
    if (_relationshipData != null) {
      try {
        _sessions = await _sessionsService.getRelationshipSessions(
          _relationshipData!['id'],
        );
      } catch (e) {
        debugPrint('Error reloading sessions: $e');
      }
    }
  }

  // Get current partner
  Partner? getCurrentPartner() {
    if (_relationshipData == null || _currentUserId == null) return null;

    if (_currentUserId == 'A') {
      return _relationshipData!['partnerA'] != null
          ? Partner.fromJson(_relationshipData!['partnerA'])
          : null;
    } else if (_currentUserId == 'B') {
      return _relationshipData!['partnerB'] != null
          ? Partner.fromJson(_relationshipData!['partnerB'])
          : null;
    }
    return null;
  }

  // Get other partner
  Partner? getOtherPartner() {
    if (_relationshipData == null || _currentUserId == null) return null;

    if (_currentUserId == 'A') {
      return _relationshipData!['partnerB'] != null
          ? Partner.fromJson(_relationshipData!['partnerB'])
          : null;
    } else if (_currentUserId == 'B') {
      return _relationshipData!['partnerA'] != null
          ? Partner.fromJson(_relationshipData!['partnerA'])
          : null;
    }
    return null;
  }

  // Get recent sessions
  List<CommunicationSession> getRecentSessions({int limit = 10}) {
    final completedSessions = _sessions.where((s) => s.isCompleted).toList();
    completedSessions.sort((a, b) => b.startTime.compareTo(a.startTime));
    return completedSessions.take(limit).toList();
  }

  // Get average score for a partner
  double getAverageScore(String partnerId) {
    final recentSessions = getRecentSessions();
    if (recentSessions.isEmpty) return 0.0;

    final scoresWithData = recentSessions
        .where((s) => s.scores?.partnerScores[partnerId] != null)
        .map((s) => s.scores!.partnerScores[partnerId]!.averageScore)
        .toList();

    if (scoresWithData.isEmpty) return 0.0;

    return scoresWithData.reduce((a, b) => a + b) / scoresWithData.length;
  }

  // Clear all data (for testing or user deletion)
  Future<void> clearAllData() async {
    try {
      // Delete relationship if user created it
      if (_relationshipData != null &&
          _relationshipData!['createdBy'] == _user?.id) {
        await _relationshipService.deleteRelationship(_relationshipData!['id']);
      }

      // Sign out
      await signOut();

      // Clear local state
      _clearUserData();
      notifyListeners();
    } catch (e) {
      debugPrint('Error clearing all data: $e');
    }
  }

  // Get session statistics
  Future<Map<String, dynamic>> getSessionStatistics() async {
    try {
      if (_relationshipData == null) return {};
      return await _sessionsService.getSessionStatistics(
        _relationshipData!['id'],
      );
    } catch (e) {
      debugPrint('Error getting session statistics: $e');
      return {};
    }
  }

  // Listen to relationship updates
  Stream<Map<String, dynamic>?> getRelationshipStream() {
    if (_relationshipData == null) return Stream.value(null);
    return _relationshipService.getRelationshipStream(_relationshipData!['id']);
  }

  // Listen to session updates
  Stream<List<CommunicationSession>> getSessionsStream() {
    if (_relationshipData == null) return Stream.value([]);
    return _sessionsService.getRelationshipSessionsStream(
      _relationshipData!['id'],
    );
  }

  // Listen to active session updates
  Stream<CommunicationSession?> getActiveSessionStream() {
    if (_relationshipData == null) return Stream.value(null);
    return _sessionsService.getActiveSessionStream(_relationshipData!['id']);
  }
}
