import 'dart:math';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import '../models/partner.dart';

class InviteValidationResult {
  final bool isValid;
  final String? errorMessage;
  final Partner? partner;

  const InviteValidationResult._({
    required this.isValid,
    this.errorMessage,
    this.partner,
  });

  factory InviteValidationResult.success(Partner partner) {
    return InviteValidationResult._(
      isValid: true,
      partner: partner,
    );
  }

  factory InviteValidationResult.invalid(String message) {
    return InviteValidationResult._(
      isValid: false,
      errorMessage: message,
    );
  }
}

class FirestoreInviteService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  // Generate a unique 6-character invite code
  String generateInviteCode() {
    const chars = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789';
    final random = Random();
    return String.fromCharCodes(
      Iterable.generate(6, (_) => chars.codeUnitAt(random.nextInt(chars.length)))
    );
  }

  // Create an invite code for Partner A
  Future<String> createInvite(Partner partnerA) async {
    try {
      final user = _auth.currentUser;
      if (user == null) {
        throw Exception('User not authenticated');
      }

      String inviteCode;
      bool isUnique = false;
      
      // Generate a unique invite code
      do {
        inviteCode = generateInviteCode();
        final doc = await _firestore.collection('invites').doc(inviteCode).get();
        isUnique = !doc.exists;
      } while (!isUnique);

      // Create invite document
      await _firestore.collection('invites').doc(inviteCode).set({
        'code': inviteCode,
        'createdBy': user.uid,
        'partnerA': partnerA.toJson(),
        'createdAt': FieldValue.serverTimestamp(),
        'expiresAt': DateTime.now().add(const Duration(hours: 24)),
        'isUsed': false,
        'usedBy': null,
        'usedAt': null,
        'partnerB': null,
      });

      return inviteCode;
    } catch (e) {
      debugPrint('Error creating invite: $e');
      throw Exception('Failed to create invite code: $e');
    }
  }

  // Validate and use an invite code for Partner B
  Future<InviteValidationResult> validateAndUseInvite(String inviteCode, Partner partnerB) async {
    try {
      final user = _auth.currentUser;
      if (user == null) {
        return InviteValidationResult.invalid('User not authenticated');
      }

      final docRef = _firestore.collection('invites').doc(inviteCode.toUpperCase());
      
      return await _firestore.runTransaction((transaction) async {
        final doc = await transaction.get(docRef);
        
        if (!doc.exists) {
          return InviteValidationResult.invalid('Code does not exist. Please check the code and try again.');
        }

        final data = doc.data()!;
        
        // Check if code is already used
        if (data['isUsed'] == true) {
          return InviteValidationResult.invalid('This code has already been used. Please request a new code.');
        }

        // Check if code is expired
        final expiresAt = (data['expiresAt'] as Timestamp).toDate();
        if (DateTime.now().isAfter(expiresAt)) {
          return InviteValidationResult.invalid('This code has expired. Please request a new code.');
        }

        // Check if the same user is trying to use their own invite
        if (data['createdBy'] == user.uid) {
          return InviteValidationResult.invalid('You cannot use your own invite code.');
        }

        // Mark as used
        transaction.update(docRef, {
          'isUsed': true,
          'usedBy': user.uid,
          'usedAt': FieldValue.serverTimestamp(),
          'partnerB': partnerB.toJson(),
        });

        // Return Partner A data
        return InviteValidationResult.success(Partner.fromJson(data['partnerA']));
      });
    } catch (e) {
      debugPrint('Error validating invite: $e');
      return InviteValidationResult.invalid('An error occurred while validating the code. Please try again.');
    }
  }

  // Get invite status (for Partner A to check)
  Future<Map<String, dynamic>?> getInviteStatus(String inviteCode) async {
    try {
      final doc = await _firestore.collection('invites').doc(inviteCode.toUpperCase()).get();
      if (doc.exists) {
        final data = doc.data()!;
        return {
          'code': data['code'],
          'isUsed': data['isUsed'],
          'createdAt': data['createdAt'],
          'expiresAt': data['expiresAt'],
          'usedAt': data['usedAt'],
          'partnerB': data['partnerB'],
        };
      }
      return null;
    } catch (e) {
      debugPrint('Error getting invite status: $e');
      return null;
    }
  }

  // Get all invites created by current user
  Future<List<Map<String, dynamic>>> getUserInvites() async {
    try {
      final user = _auth.currentUser;
      if (user == null) return [];

      final querySnapshot = await _firestore
          .collection('invites')
          .where('createdBy', isEqualTo: user.uid)
          .orderBy('createdAt', descending: true)
          .get();

      return querySnapshot.docs.map((doc) => doc.data()).toList();
    } catch (e) {
      debugPrint('Error getting user invites: $e');
      return [];
    }
  }

  // Clean up expired invites (can be called periodically)
  Future<void> cleanupExpiredInvites() async {
    try {
      final now = DateTime.now();
      final querySnapshot = await _firestore
          .collection('invites')
          .where('expiresAt', isLessThan: now)
          .get();

      final batch = _firestore.batch();
      for (final doc in querySnapshot.docs) {
        batch.delete(doc.reference);
      }
      
      await batch.commit();
      debugPrint('Cleaned up ${querySnapshot.docs.length} expired invites');
    } catch (e) {
      debugPrint('Error cleaning up expired invites: $e');
    }
  }

  // Delete a specific invite
  Future<void> deleteInvite(String inviteCode) async {
    try {
      final user = _auth.currentUser;
      if (user == null) return;

      final docRef = _firestore.collection('invites').doc(inviteCode.toUpperCase());
      final doc = await docRef.get();
      
      if (doc.exists && doc.data()!['createdBy'] == user.uid) {
        await docRef.delete();
      }
    } catch (e) {
      debugPrint('Error deleting invite: $e');
    }
  }
}