import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import '../models/partner.dart';

class FirestoreRelationshipService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  // Create a new relationship
  Future<String> createRelationship(Partner partnerA, String inviteCode) async {
    try {
      final user = _auth.currentUser;
      if (user == null) {
        throw Exception('User not authenticated');
      }

      final relationshipData = {
        'partnerA': partnerA.toJson(),
        'partnerB': null, // Will be filled when partner B joins
        'createdBy': user.uid,
        'createdAt': FieldValue.serverTimestamp(),
        'inviteCode': inviteCode,
        'isActive': true,
        'participants': [user.uid], // Will have both UIDs when partner B joins
        'updatedAt': FieldValue.serverTimestamp(),
      };

      final docRef = await _firestore.collection('relationships').add(relationshipData);
      return docRef.id;
    } catch (e) {
      debugPrint('Error creating relationship: $e');
      throw Exception('Failed to create relationship: $e');
    }
  }

  // Join an existing relationship
  Future<String> joinRelationship(String relationshipId, Partner partnerB) async {
    try {
      final user = _auth.currentUser;
      if (user == null) {
        throw Exception('User not authenticated');
      }

      await _firestore.collection('relationships').doc(relationshipId).update({
        'partnerB': partnerB.toJson(),
        'participants': FieldValue.arrayUnion([user.uid]),
        'updatedAt': FieldValue.serverTimestamp(),
      });

      return relationshipId;
    } catch (e) {
      debugPrint('Error joining relationship: $e');
      throw Exception('Failed to join relationship: $e');
    }
  }

  // Get current user's relationship
  Future<Map<String, dynamic>?> getUserRelationship() async {
    try {
      final user = _auth.currentUser;
      debugPrint('🔥 getUserRelationship: current user = ${user?.uid}');
      if (user == null) {
        debugPrint('🔥 getUserRelationship: No authenticated user');
        return null;
      }

      debugPrint('🔥 getUserRelationship: Querying relationships for user ${user.uid}');
      final querySnapshot = await _firestore
          .collection('relationships')
          .where('participants', arrayContains: user.uid)
          .where('isActive', isEqualTo: true)
          .limit(1)
          .get();

      debugPrint('🔥 getUserRelationship: Query returned ${querySnapshot.docs.length} documents');
      
      if (querySnapshot.docs.isNotEmpty) {
        final doc = querySnapshot.docs.first;
        final data = {
          'id': doc.id,
          ...doc.data(),
        };
        debugPrint('🔥 getUserRelationship: Found relationship: ${data['id']}');
        return data;
      }
      
      debugPrint('🔥 getUserRelationship: No relationship found');
      return null;
    } catch (e) {
      debugPrint('🔥 ERROR getUserRelationship: $e');
      return null;
    }
  }

  // Get relationship by ID
  Future<Map<String, dynamic>?> getRelationshipById(String relationshipId) async {
    try {
      final doc = await _firestore.collection('relationships').doc(relationshipId).get();
      if (doc.exists) {
        return {
          'id': doc.id,
          ...doc.data()!,
        };
      }
      return null;
    } catch (e) {
      debugPrint('Error getting relationship by ID: $e');
      return null;
    }
  }

  // Update relationship data
  Future<void> updateRelationship(String relationshipId, Map<String, dynamic> updates) async {
    try {
      final user = _auth.currentUser;
      if (user == null) return;

      await _firestore.collection('relationships').doc(relationshipId).update({
        ...updates,
        'updatedAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      debugPrint('Error updating relationship: $e');
    }
  }

  // Update partner information
  Future<void> updatePartner(String relationshipId, String partnerId, Partner partner) async {
    try {
      final user = _auth.currentUser;
      if (user == null) return;

      final field = partnerId == 'A' ? 'partnerA' : 'partnerB';
      await _firestore.collection('relationships').doc(relationshipId).update({
        field: partner.toJson(),
        'updatedAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      debugPrint('Error updating partner: $e');
    }
  }

  // Delete relationship
  Future<void> deleteRelationship(String relationshipId) async {
    try {
      final user = _auth.currentUser;
      if (user == null) return;

      // Check if user is part of the relationship
      final doc = await _firestore.collection('relationships').doc(relationshipId).get();
      if (doc.exists) {
        final data = doc.data()!;
        final participants = List<String>.from(data['participants'] ?? []);
        
        if (participants.contains(user.uid)) {
          await _firestore.collection('relationships').doc(relationshipId).update({
            'isActive': false,
            'deletedAt': FieldValue.serverTimestamp(),
            'updatedAt': FieldValue.serverTimestamp(),
          });
        }
      }
    } catch (e) {
      debugPrint('Error deleting relationship: $e');
    }
  }

  // Get relationship stream for real-time updates
  Stream<Map<String, dynamic>?> getRelationshipStream(String relationshipId) {
    return _firestore
        .collection('relationships')
        .doc(relationshipId)
        .snapshots()
        .map((doc) {
          if (doc.exists) {
            return {
              'id': doc.id,
              ...doc.data()!,
            };
          }
          return null;
        });
  }

  // Get user's relationship stream
  Stream<Map<String, dynamic>?> getUserRelationshipStream() {
    final user = _auth.currentUser;
    if (user == null) return Stream.value(null);

    return _firestore
        .collection('relationships')
        .where('participants', arrayContains: user.uid)
        .where('isActive', isEqualTo: true)
        .limit(1)
        .snapshots()
        .map((querySnapshot) {
          if (querySnapshot.docs.isNotEmpty) {
            final doc = querySnapshot.docs.first;
            return {
              'id': doc.id,
              ...doc.data(),
            };
          }
          return null;
        });
  }

  // Find relationship by invite code
  Future<Map<String, dynamic>?> findRelationshipByInviteCode(String inviteCode) async {
    try {
      final querySnapshot = await _firestore
          .collection('relationships')
          .where('inviteCode', isEqualTo: inviteCode)
          .where('isActive', isEqualTo: true)
          .limit(1)
          .get();

      if (querySnapshot.docs.isNotEmpty) {
        final doc = querySnapshot.docs.first;
        return {
          'id': doc.id,
          ...doc.data(),
        };
      }
      return null;
    } catch (e) {
      debugPrint('Error finding relationship by invite code: $e');
      return null;
    }
  }

  // Check if user has an active relationship
  Future<bool> hasActiveRelationship() async {
    final relationship = await getUserRelationship();
    return relationship != null;
  }
}