/// Mend backend (ZEGO tokens, call analysis, etc.)
class ApiConfig {
  static const String baseUrl = 'https://bridgemend.onrender.com';

  /// Local dev: `flutter run --dart-define=API_BASE_URL=http://10.0.2.2:3000`
  static String get serverBaseUrl {
    const override = String.fromEnvironment('API_BASE_URL');
    if (override.isNotEmpty) return override;
    return baseUrl;
  }
}
