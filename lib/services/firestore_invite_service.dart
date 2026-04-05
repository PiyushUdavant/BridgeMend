import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
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
  final SupabaseClient _db = Supabase.instance.client;
  final GoTrueClient _auth = Supabase.instance.client.auth;

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
        final existing = await _db
            .from('invites')
            .select('code')
            .eq('code', inviteCode)
            .maybeSingle();
        isUnique = existing == null;
      } while (!isUnique);

      // Create invite document
      await _db.from('invites').insert({
        'code': inviteCode,
        'createdBy': user.id,
        'partnerA': partnerA.toJson(),
        'createdAt': DateTime.now().toIso8601String(),
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

      final code = inviteCode.toUpperCase();
      final data = await _db.from('invites').select().eq('code', code).maybeSingle();
      if (data == null) {
          return InviteValidationResult.invalid('Code does not exist. Please check the code and try again.');
      }
        
        // Check if code is already used
        if (data['isUsed'] == true) {
          return InviteValidationResult.invalid('This code has already been used. Please request a new code.');
        }

        // Check if code is expired
        final expiresAt = DateTime.parse(data['expiresAt'] as String);
        if (DateTime.now().isAfter(expiresAt)) {
          return InviteValidationResult.invalid('This code has expired. Please request a new code.');
        }

        // Check if the same user is trying to use their own invite
        if (data['createdBy'] == user.id) {
          return InviteValidationResult.invalid('You cannot use your own invite code.');
        }

        // Mark as used
      await _db
          .from('invites')
          .update({
            'isUsed': true,
            'usedBy': user.id,
            'usedAt': DateTime.now().toIso8601String(),
            'partnerB': partnerB.toJson(),
          })
          .eq('code', code)
          .eq('isUsed', false);

      // Return Partner A data
      return InviteValidationResult.success(Partner.fromJson(data['partnerA']));
    } catch (e) {
      debugPrint('Error validating invite: $e');
      return InviteValidationResult.invalid('An error occurred while validating the code. Please try again.');
    }
  }

  // Get invite status (for Partner A to check)
  Future<Map<String, dynamic>?> getInviteStatus(String inviteCode) async {
    try {
      final data = await _db
          .from('invites')
          .select()
          .eq('code', inviteCode.toUpperCase())
          .maybeSingle();
      if (data != null) {
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

      final rows = await _db
          .from('invites')
          .select()
          .eq('createdBy', user.id)
          .order('createdAt', ascending: false);
      return rows.map((row) => Map<String, dynamic>.from(row)).toList();
    } catch (e) {
      debugPrint('Error getting user invites: $e');
      return [];
    }
  }

  // Clean up expired invites (can be called periodically)
  Future<void> cleanupExpiredInvites() async {
    try {
      final now = DateTime.now();
      final rows = await _db
          .from('invites')
          .select('code')
          .lt('expiresAt', now.toIso8601String());
      if (rows.isNotEmpty) {
        final codes = rows.map((e) => e['code']).toList();
        await _db.from('invites').delete().inFilter('code', codes);
      }
      debugPrint('Cleaned up ${rows.length} expired invites');
    } catch (e) {
      debugPrint('Error cleaning up expired invites: $e');
    }
  }

  // Delete a specific invite
  Future<void> deleteInvite(String inviteCode) async {
    try {
      final user = _auth.currentUser;
      if (user == null) return;

      final code = inviteCode.toUpperCase();
      final row = await _db
          .from('invites')
          .select('createdBy')
          .eq('code', code)
          .maybeSingle();

      if (row != null && row['createdBy'] == user.id) {
        await _db.from('invites').delete().eq('code', code);
      }
    } catch (e) {
      debugPrint('Error deleting invite: $e');
    }
  }
}