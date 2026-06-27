import 'dart:convert';
import '../models/communication_session.dart';
import 'hive_service.dart';

class LocalSessionService {
  static Future<void> saveSession(CommunicationSession session) async {
    try {
      await HiveService.sessionsBox.put(
        session.id,
        jsonEncode(session.toJson()),
      );
    } catch (_) {}
  }

  static Future<void> saveSessions(List<CommunicationSession> sessions) async {
    final batch = <String, String>{};
    for (final s in sessions) {
      try {
        batch[s.id] = jsonEncode(s.toJson());
      } catch (_) {}
    }
    if (batch.isNotEmpty) {
      await HiveService.sessionsBox.putAll(batch);
    }
  }

  static List<CommunicationSession> getSessions() {
    final result = <CommunicationSession>[];
    for (final key in HiveService.sessionsBox.keys) {
      try {
        final raw = HiveService.sessionsBox.get(key as String);
        if (raw != null) {
          result.add(
            CommunicationSession.fromJson(
              jsonDecode(raw) as Map<String, dynamic>,
            ),
          );
        }
      } catch (_) {}
    }
    result.sort((a, b) => b.startTime.compareTo(a.startTime));
    return result;
  }

  static List<CommunicationSession> getCompletedSessions() =>
      getSessions().where((s) => s.isCompleted).toList();

  static Future<void> deleteSession(String id) async {
    await HiveService.sessionsBox.delete(id);
  }

  static Future<void> clearAll() async {
    await HiveService.sessionsBox.clear();
  }

  static int get sessionCount => HiveService.sessionsBox.length;
}