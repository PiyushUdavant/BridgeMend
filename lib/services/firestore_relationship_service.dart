import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/partner.dart';

class FirestoreRelationshipService {
  final SupabaseClient _db = Supabase.instance.client;
  final GoTrueClient _auth = Supabase.instance.client.auth;

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
        'createdBy': user.id,
        'createdAt': DateTime.now().toIso8601String(),
        'inviteCode': inviteCode,
        'isActive': true,
        'participants': [user.id], // Will have both UIDs when partner B joins
        'updatedAt': DateTime.now().toIso8601String(),
      };

      final inserted = await _db
          .from('relationships')
          .insert(relationshipData)
          .select('id')
          .single();
      return inserted['id'] as String;
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

      final relationship = await _db
          .from('relationships')
          .select('participants')
          .eq('id', relationshipId)
          .maybeSingle();
      if (relationship == null) {
        throw Exception('Relationship not found');
      }
      final participants = List<String>.from(
        relationship['participants'] as List? ?? const [],
      );
      if (!participants.contains(user.id)) {
        participants.add(user.id);
      }

      await _db.from('relationships').update({
        'partnerB': partnerB.toJson(),
        'participants': participants,
        'updatedAt': DateTime.now().toIso8601String(),
      }).eq('id', relationshipId);

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
      debugPrint('🔥 getUserRelationship: current user = ${user?.id}');
      if (user == null) {
        debugPrint('🔥 getUserRelationship: No authenticated user');
        return null;
      }

      debugPrint('🔥 getUserRelationship: Querying relationships for user ${user.id}');
      final rows = await _db
          .from('relationships')
          .select()
          .contains('participants', [user.id]).eq('isActive', true).limit(1);

      debugPrint('🔥 getUserRelationship: Query returned ${rows.length} documents');

      if (rows.isNotEmpty) {
        final data = Map<String, dynamic>.from(rows.first);
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
      final row = await _db
          .from('relationships')
          .select()
          .eq('id', relationshipId)
          .maybeSingle();
      return row == null ? null : Map<String, dynamic>.from(row);
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

      await _db.from('relationships').update({
        ...updates,
        'updatedAt': DateTime.now().toIso8601String(),
      }).eq('id', relationshipId);
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
      await _db.from('relationships').update({
        field: partner.toJson(),
        'updatedAt': DateTime.now().toIso8601String(),
      }).eq('id', relationshipId);
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
      final data = await _db
          .from('relationships')
          .select('participants')
          .eq('id', relationshipId)
          .maybeSingle();
      if (data != null) {
        final participants = List<String>.from(data['participants'] ?? []);
        if (participants.contains(user.id)) {
          await _db.from('relationships').update({
            'isActive': false,
            'deletedAt': DateTime.now().toIso8601String(),
            'updatedAt': DateTime.now().toIso8601String(),
          }).eq('id', relationshipId);
        }
      }
    } catch (e) {
      debugPrint('Error deleting relationship: $e');
    }
  }

  // Get relationship stream for real-time updates
  Stream<Map<String, dynamic>?> getRelationshipStream(String relationshipId) {
    return _db
        .from('relationships')
        .stream(primaryKey: ['id'])
        .eq('id', relationshipId)
        .map((rows) {
          if (rows.isNotEmpty) {
            return Map<String, dynamic>.from(rows.first);
          }
          return null;
        });
  }

  // Get user's relationship stream
  Stream<Map<String, dynamic>?> getUserRelationshipStream() {
    final user = _auth.currentUser;
    if (user == null) return Stream.value(null);

    return _db
        .from('relationships')
        .stream(primaryKey: ['id'])
        .map((rows) {
          final filtered = rows.where((row) {
            final participants = List<String>.from(
              row['participants'] as List? ?? const [],
            );
            return row['isActive'] == true && participants.contains(user.id);
          }).toList();
          if (filtered.isNotEmpty) {
            return Map<String, dynamic>.from(filtered.first);
          }
          return null;
        });
  }

  // Find relationship by invite code
  Future<Map<String, dynamic>?> findRelationshipByInviteCode(String inviteCode) async {
    try {
      final rows = await _db
          .from('relationships')
          .select()
          .eq('inviteCode', inviteCode)
          .eq('isActive', true)
          .limit(1);

      if (rows.isNotEmpty) {
        return Map<String, dynamic>.from(rows.first);
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