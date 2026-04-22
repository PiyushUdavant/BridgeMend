import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/communication_session.dart';

class FirestoreSessionsService {
  final SupabaseClient _db = Supabase.instance.client;
  final GoTrueClient _auth = Supabase.instance.client.auth;

  // Create a new communication session
  Future<String> createSession(String relationshipId, CommunicationSession session) async {
    try {
      final user = _auth.currentUser;
      if (user == null) {
        throw Exception('User not authenticated');
      }

      final sessionData = {
        ...session.toJson(),
        'relationshipId': relationshipId,
        'createdBy': user.id,
        'createdAt': DateTime.now().toIso8601String(),
        'updatedAt': DateTime.now().toIso8601String(),
        'status': session.status ?? 'active',
      };

      final inserted = await _db
          .from('sessions')
          .insert(sessionData)
          .select('id')
          .single();
      return inserted['id'] as String;
    } catch (e) {
      debugPrint('Error creating session: $e');
      throw Exception('Failed to create session: $e');
    }
  }

  // Save individual user rating for their partner
  Future<void> saveUserRating({
    required String sessionId,
    required String raterId,
    required String ratedPartnerId,
    required PartnerScore score,
  }) async {
    try {
      final user = _auth.currentUser;
      if (user == null) {
        throw Exception('User not authenticated');
      }

      // Save the rating in a subcollection
      await _db.from('session_ratings').upsert({
        'sessionId': sessionId,
        'raterId': raterId,
        'ratedPartnerId': ratedPartnerId,
        'score': score.toJson(),
        'submittedAt': DateTime.now().toIso8601String(),
      });

      debugPrint('Rating saved successfully for session $sessionId');
    } catch (e) {
      debugPrint('Error saving user rating: $e');
      throw Exception('Failed to save rating: $e');
    }
  }

  // Check if a user has already rated their partner
  Future<bool> hasUserRatedPartner(String sessionId, String userId) async {
    try {
      final row = await _db
          .from('session_ratings')
          .select('sessionId')
          .eq('sessionId', sessionId)
          .eq('raterId', userId)
          .maybeSingle();
      return row != null;
    } catch (e) {
      debugPrint('Error checking rating status: $e');
      return false;
    }
  }

  // Check if both partners have rated each other
  Future<bool> haveBothPartnersRated(String sessionId) async {
    try {
      final ratings = await _db
          .from('session_ratings')
          .select('raterId')
          .eq('sessionId', sessionId);
      return ratings.length >= 2;
    } catch (e) {
      debugPrint('Error checking both partners rating status: $e');
      return false;
    }
  }

  // Get all ratings for a session
  Future<List<Map<String, dynamic>>> getSessionRatings(String sessionId) async {
    try {
      final ratings = await _db
          .from('session_ratings')
          .select()
          .eq('sessionId', sessionId);

      return ratings.map((row) => {
        'raterId': row['raterId'],
        'ratedPartnerId': row['ratedPartnerId'],
        'score': row['score'],
        'submittedAt': row['submittedAt'],
      }).toList();
    } catch (e) {
      debugPrint('Error getting session ratings: $e');
      throw Exception('Failed to get ratings: $e');
    }
  }

  // Update an existing session
  Future<void> updateSession(String sessionId, CommunicationSession session) async {
    try {
      final user = _auth.currentUser;
      if (user == null) return;

      // Preserve waiting-room fields (participants, per-user presence, status from DB)
      final existingData = await _db
              .from('sessions')
              .select('participants,createdAt,participantStatus,status')
              .eq('id', sessionId)
              .maybeSingle() ??
          {};

      final payload = Map<String, dynamic>.from(session.toJson());
      // Do not overwrite user-id participantStatus from the in-memory template (A/B legacy).
      payload.remove('participantStatus');
      payload['participants'] = existingData['participants'];
      payload['createdAt'] = existingData['createdAt'];
      payload['participantStatus'] =
          existingData['participantStatus'] ?? session.participantStatus;
      payload['status'] = 'active';
      payload['updatedAt'] = DateTime.now().toIso8601String();

      await _db.from('sessions').update(payload).eq('id', sessionId);
    } catch (e) {
      debugPrint('Error updating session: $e');
    }
  }

  /// Participant user ids on the waiting-room session row (for voice start without `partnerB` json).
  Future<List<String>> getSessionParticipantIds(String sessionId) async {
    try {
      final row = await _db
          .from('sessions')
          .select('participants')
          .eq('id', sessionId)
          .maybeSingle();
      if (row == null) return [];
      final raw = row['participants'];
      if (raw is! List) return [];
      final out = <String>[];
      for (final e in raw) {
        if (e == null) continue;
        final t = (e is String ? e : e.toString()).trim();
        if (t.isNotEmpty) out.add(t);
      }
      return out;
    } catch (e) {
      debugPrint('getSessionParticipantIds: $e');
      return [];
    }
  }

  // Get session by ID
  Future<CommunicationSession?> getSessionById(String sessionId) async {
    try {
      final row = await _db
          .from('sessions')
          .select()
          .eq('id', sessionId)
          .maybeSingle();
      return row == null ? null : CommunicationSession.fromJson(row);
    } catch (e) {
      debugPrint('Error getting session by ID: $e');
      return null;
    }
  }

  // Get all sessions for a relationship
  Future<List<CommunicationSession>> getRelationshipSessions(String relationshipId, {int limit = 50}) async {
    try {
      final rows = await _db
          .from('sessions')
          .select()
          .eq('relationshipId', relationshipId)
          .order('startTime', ascending: false)
          .limit(limit);

      return rows
          .map((row) => CommunicationSession.fromJson(Map<String, dynamic>.from(row)))
          .toList();
    } catch (e) {
      debugPrint('Error getting relationship sessions: $e');
      return [];
    }
  }

  // Get completed sessions for a relationship
  Future<List<CommunicationSession>> getCompletedSessions(String relationshipId, {int limit = 20}) async {
    try {
      final rows = await _db
          .from('sessions')
          .select()
          .eq('relationshipId', relationshipId)
          .not('endTime', 'is', null)
          .order('endTime', ascending: false)
          .limit(limit);

      return rows
          .map((row) => CommunicationSession.fromJson(Map<String, dynamic>.from(row)))
          .toList();
    } catch (e) {
      debugPrint('Error getting completed sessions: $e');
      return [];
    }
  }

  // Get active (ongoing) session for a relationship
  Future<CommunicationSession?> getActiveSession(String relationshipId) async {
    try {
      final rows = await _db
          .from('sessions')
          .select()
          .eq('relationshipId', relationshipId)
          .isFilter('endTime', null)
          .order('startTime', ascending: false)
          .limit(1);

      if (rows.isNotEmpty) {
        return CommunicationSession.fromJson(rows.first);
      }
      return null;
    } catch (e) {
      debugPrint('Error getting active session: $e');
      return null;
    }
  }

  // Add a message to a session
  Future<void> addMessage(String sessionId, Message message) async {
    try {
      final user = _auth.currentUser;
      if (user == null) return;

      final existing = await _db
          .from('sessions')
          .select('messages')
          .eq('id', sessionId)
          .maybeSingle();
      if (existing == null) return;
      final messages = List<Map<String, dynamic>>.from(
        (existing['messages'] as List? ?? const []).map(
          (e) => Map<String, dynamic>.from(e as Map),
        ),
      );
      messages.add(message.toJson());

      await _db.from('sessions').update({
        'messages': messages,
        'updatedAt': DateTime.now().toIso8601String(),
      }).eq('id', sessionId);
    } catch (e) {
      debugPrint('Error adding message: $e');
    }
  }

  // Mark participant as left
  Future<void> markParticipantLeft(String sessionId, String participantId) async {
    try {
      final user = _auth.currentUser;
      if (user == null) return;

      debugPrint('Marking participant $participantId as left from session $sessionId');
      await _db.from('sessions').update({
        'participantStatus.$participantId': false,
        'updatedAt': DateTime.now().toIso8601String(),
      }).eq('id', sessionId);
      debugPrint('Successfully marked participant $participantId as left');
    } catch (e) {
      debugPrint('Error marking participant as left: $e');
    }
  }

  // End a session
  Future<void> endSession(String sessionId, {
    CommunicationScores? scores,
    String? reflection,
    List<String>? suggestedActivities,
  }) async {
    try {
      final user = _auth.currentUser;
      if (user == null) return;

      final updates = <String, dynamic>{
        'endTime': DateTime.now().toIso8601String(),
        'updatedAt': DateTime.now().toIso8601String(),
        'status': 'ended',
      };

      if (scores != null) {
        updates['scores'] = scores.toJson();
      }

      if (reflection != null) {
        updates['reflection'] = reflection;
      }

      if (suggestedActivities != null) {
        updates['suggestedActivities'] = suggestedActivities;
      }

      await _db.from('sessions').update(updates).eq('id', sessionId);
    } catch (e) {
      debugPrint('Error ending session: $e');
    }
  }

  // Get session stream for real-time updates
  Stream<CommunicationSession?> getSessionStream(String sessionId) {
    return _db
        .from('sessions')
        .stream(primaryKey: ['id'])
        .eq('id', sessionId)
        .map((rows) {
          if (rows.isNotEmpty) {
            return CommunicationSession.fromJson(rows.first);
          }
          return null;
        });
  }

  // Get active session stream for a relationship
  Stream<CommunicationSession?> getActiveSessionStream(String relationshipId) {
    return _db
        .from('sessions')
        .stream(primaryKey: ['id'])
        .eq('relationshipId', relationshipId)
        .map((rows) {
          final active = rows.where((r) => r['endTime'] == null).toList();
          if (active.isNotEmpty) {
            active.sort(
              (a, b) => (b['startTime'] as String).compareTo(a['startTime'] as String),
            );
            return CommunicationSession.fromJson(active.first);
          }
          return null;
        });
  }

  // Get relationship sessions stream
  Stream<List<CommunicationSession>> getRelationshipSessionsStream(String relationshipId, {int limit = 20}) {
    return _db
        .from('sessions')
        .stream(primaryKey: ['id'])
        .eq('relationshipId', relationshipId)
        .map((rows) {
          final mapped = rows
              .map((row) => CommunicationSession.fromJson(row))
              .toList();
          mapped.sort((a, b) => b.startTime.compareTo(a.startTime));
          return mapped.take(limit).toList();
        });
  }

  // Delete a session
  Future<void> deleteSession(String sessionId) async {
    try {
      final user = _auth.currentUser;
      if (user == null) return;

      // Check if user has permission to delete this session
      final data = await _db
          .from('sessions')
          .select('relationshipId')
          .eq('id', sessionId)
          .maybeSingle();
      if (data != null) {
        final relationshipData = await _db
            .from('relationships')
            .select('participants')
            .eq('id', data['relationshipId'])
            .maybeSingle();

        if (relationshipData != null) {
          final participants = List<String>.from(
            relationshipData['participants'] ?? const [],
          );

          if (participants.contains(user.id)) {
            await _db.from('sessions').delete().eq('id', sessionId);
          }
        }
      }
    } catch (e) {
      debugPrint('Error deleting session: $e');
    }
  }

  // Get session statistics for a relationship
  Future<Map<String, dynamic>> getSessionStatistics(String relationshipId) async {
    try {
      final sessions = await getCompletedSessions(relationshipId, limit: 100);
      
      if (sessions.isEmpty) {
        return {
          'totalSessions': 0,
          'averageDuration': 0,
          'averageScore': 0.0,
          'totalMessages': 0,
          'averageMessagesPerSession': 0,
        };
      }

      final totalSessions = sessions.length;
      final totalDuration = sessions
          .where((s) => s.endTime != null)
          .map((s) => s.endTime!.difference(s.startTime).inMinutes)
          .fold(0, (total, duration) => total + duration);
      
      final averageDuration = totalDuration / totalSessions;
      
      final scoresWithData = sessions
          .where((s) => s.scores != null)
          .map((s) => s.scores!.averageScore)
          .toList();
      
      final averageScore = scoresWithData.isNotEmpty
          ? scoresWithData.reduce((a, b) => a + b) / scoresWithData.length
          : 0.0;

      final totalMessages = sessions
          .map((s) => s.messages.length)
          .fold(0, (total, messageCount) => total + messageCount);

      return {
        'totalSessions': totalSessions,
        'averageDuration': averageDuration.round(),
        'averageScore': averageScore,
        'totalMessages': totalMessages,
        'averageMessagesPerSession': (totalMessages / totalSessions).round(),
      };
    } catch (e) {
      debugPrint('Error getting session statistics: $e');
      return {
        'totalSessions': 0,
        'averageDuration': 0,
        'averageScore': 0.0,
        'totalMessages': 0,
        'averageMessagesPerSession': 0,
      };
    }
  }
}