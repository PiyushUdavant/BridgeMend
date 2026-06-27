import 'package:hive_flutter/hive_flutter.dart';

class HiveBoxes {
  static const String sessions = 'sessions_v1';
}

class HiveService {
  static Future<void> init() async {
    await Hive.initFlutter();
    await Hive.openBox<String>(HiveBoxes.sessions);
  }

  static Box<String> get sessionsBox => Hive.box<String>(HiveBoxes.sessions);

  static Future<void> closeAll() async => Hive.close();
}