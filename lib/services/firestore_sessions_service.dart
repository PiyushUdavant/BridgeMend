import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import '../models/communication_session.dart';

class FirestoreSessionsService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

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
        'createdBy': user.uid,
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      };

      final docRef = await _firestore.collection('sessions').add(sessionData);
      return docRef.id;
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
      await _firestore
          .collection('sessions')
          .doc(sessionId)
          .collection('ratings')
          .doc(raterId)
          .set({
        'raterId': raterId,
        'ratedPartnerId': ratedPartnerId,
        'score': score.toJson(),
        'submittedAt': FieldValue.serverTimestamp(),
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
      final doc = await _firestore
          .collection('sessions')
          .doc(sessionId)
          .collection('ratings')
          .doc(userId)
          .get();
      
      return doc.exists;
    } catch (e) {
      debugPrint('Error checking rating status: $e');
      return false;
    }
  }

  // Check if both partners have rated each other
  Future<bool> haveBothPartnersRated(String sessionId) async {
    try {
      final ratings = await _firestore
          .collection('sessions')
          .doc(sessionId)
          .collection('ratings')
          .get();
      
      return ratings.docs.length >= 2;
    } catch (e) {
      debugPrint('Error checking both partners rating status: $e');
      return false;
    }
  }

  // Get all ratings for a session
  Future<List<Map<String, dynamic>>> getSessionRatings(String sessionId) async {
    try {
      final ratings = await _firestore
          .collection('sessions')
          .doc(sessionId)
          .collection('ratings')
          .get();
      
      return ratings.docs.map((doc) => {
        'raterId': doc.data()['raterId'],
        'ratedPartnerId': doc.data()['ratedPartnerId'],
        'score': doc.data()['score'],
        'submittedAt': doc.data()['submittedAt'],
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

      // Get the existing document to preserve waiting room data
      final existingDoc = await _firestore.collection('sessions').doc(sessionId).get();
      final existingData = existingDoc.data() ?? {};

      await _firestore.collection('sessions').doc(sessionId).update({
        ...session.toJson(),
        'updatedAt': FieldValue.serverTimestamp(),
        // Preserve participants from waiting room
        'participants': existingData['participants'],
        'createdAt': existingData['createdAt'],
      });
    } catch (e) {
      debugPrint('Error updating session: $e');
    }
  }

  // Get session by ID
  Future<CommunicationSession?> getSessionById(String sessionId) async {
    try {
      final doc = await _firestore.collection('sessions').doc(sessionId).get();
      if (doc.exists) {
        return CommunicationSession.fromJson(doc.data()!);
      }
      return null;
    } catch (e) {
      debugPrint('Error getting session by ID: $e');
      return null;
    }
  }

  // Get all sessions for a relationship
  Future<List<CommunicationSession>> getRelationshipSessions(String relationshipId, {int limit = 50}) async {
    try {
      final querySnapshot = await _firestore
          .collection('sessions')
          .where('relationshipId', isEqualTo: relationshipId)
          .orderBy('startTime', descending: true)
          .limit(limit)
          .get();

      return querySnapshot.docs
          .map((doc) => CommunicationSession.fromJson(doc.data()))
          .toList();
    } catch (e) {
      debugPrint('Error getting relationship sessions: $e');
      return [];
    }
  }

  // Get completed sessions for a relationship
  Future<List<CommunicationSession>> getCompletedSessions(String relationshipId, {int limit = 20}) async {
    try {
      final querySnapshot = await _firestore
          .collection('sessions')
          .where('relationshipId', isEqualTo: relationshipId)
          .where('endTime', isNotEqualTo: null)
          .orderBy('endTime', descending: true)
          .limit(limit)
          .get();

      return querySnapshot.docs
          .map((doc) => CommunicationSession.fromJson(doc.data()))
          .toList();
    } catch (e) {
      debugPrint('Error getting completed sessions: $e');
      return [];
    }
  }

  // Get active (ongoing) session for a relationship
  Future<CommunicationSession?> getActiveSession(String relationshipId) async {
    try {
      final querySnapshot = await _firestore
          .collection('sessions')
          .where('relationshipId', isEqualTo: relationshipId)
          .where('endTime', isNull: true)
          .orderBy('startTime', descending: true)
          .limit(1)
          .get();

      if (querySnapshot.docs.isNotEmpty) {
        return CommunicationSession.fromJson(querySnapshot.docs.first.data());
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

      await _firestore.collection('sessions').doc(sessionId).update({
        'messages': FieldValue.arrayUnion([message.toJson()]),
        'updatedAt': FieldValue.serverTimestamp(),
      });
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
      await _firestore.collection('sessions').doc(sessionId).update({
        'participantStatus.$participantId': false,
        'updatedAt': FieldValue.serverTimestamp(),
      });
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
        'endTime': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
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

      await _firestore.collection('sessions').doc(sessionId).update(updates);
    } catch (e) {
      debugPrint('Error ending session: $e');
    }
  }

  // Get session stream for real-time updates
  Stream<CommunicationSession?> getSessionStream(String sessionId) {
    return _firestore
        .collection('sessions')
        .doc(sessionId)
        .snapshots()
        .map((doc) {
          if (doc.exists) {
            return CommunicationSession.fromJson(doc.data()!);
          }
          return null;
        });
  }

  // Get active session stream for a relationship
  Stream<CommunicationSession?> getActiveSessionStream(String relationshipId) {
    return _firestore
        .collection('sessions')
        .where('relationshipId', isEqualTo: relationshipId)
        .where('endTime', isNull: true)
        .orderBy('startTime', descending: true)
        .limit(1)
        .snapshots()
        .map((querySnapshot) {
          if (querySnapshot.docs.isNotEmpty) {
            return CommunicationSession.fromJson(querySnapshot.docs.first.data());
          }
          return null;
        });
  }

  // Get relationship sessions stream
  Stream<List<CommunicationSession>> getRelationshipSessionsStream(String relationshipId, {int limit = 20}) {
    return _firestore
        .collection('sessions')
        .where('relationshipId', isEqualTo: relationshipId)
        .orderBy('startTime', descending: true)
        .limit(limit)
        .snapshots()
        .map((querySnapshot) {
          return querySnapshot.docs
              .map((doc) => CommunicationSession.fromJson(doc.data()))
              .toList();
        });
  }

  // Delete a session
  Future<void> deleteSession(String sessionId) async {
    try {
      final user = _auth.currentUser;
      if (user == null) return;

      // Check if user has permission to delete this session
      final doc = await _firestore.collection('sessions').doc(sessionId).get();
      if (doc.exists) {
        final data = doc.data()!;
        // Get the relationship to check if user is a participant
        final relationshipDoc = await _firestore
            .collection('relationships')
            .doc(data['relationshipId'])
            .get();
        
        if (relationshipDoc.exists) {
          final relationshipData = relationshipDoc.data()!;
          final participants = List<String>.from(relationshipData['participants'] ?? []);
          
          if (participants.contains(user.uid)) {
            await _firestore.collection('sessions').doc(sessionId).delete();
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