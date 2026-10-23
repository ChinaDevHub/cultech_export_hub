import 'package:flutter/foundation.dart';

/// Where the backend lives.
///
/// Override at build time:
///   flutter run --dart-define=API_BASE=http://192.168.1.20:3000
/// Defaults: Android emulator → 10.0.2.2, everything else → localhost.
abstract final class AppConfig {
  static const _override = String.fromEnvironment('API_BASE');

  /// Public web front-end (used for certificate QR links). Falls back to the
  /// API host, which also serves the web build.
  static const _webOverride = String.fromEnvironment('WEB_BASE');

  static String get baseUrl {
    if (_override.isNotEmpty) return _trim(_override);
    if (!kIsWeb && defaultTargetPlatform == TargetPlatform.android) {
      return 'http://10.0.2.2:3000';
    }
    return 'http://localhost:3000';
  }

  static String get webBase => _webOverride.isNotEmpty ? _trim(_webOverride) : baseUrl;

  static String get apiBase => '$baseUrl/api';

  /// Run fully offline against the in-app mock backend (default: on, so the
  /// app works without any server — ideal for demos). Use the real API with
  /// `--dart-define=USE_MOCK=false`.
  static const useMock = bool.fromEnvironment('USE_MOCK', defaultValue: true);

  /// Demo shortcuts on login screens: debug builds, and always in offline
  /// demo mode (so a jury can sign in with the sample accounts).
  static bool get showDemoAccounts => kDebugMode || useMock;

  static String _trim(String s) => s.endsWith('/') ? s.substring(0, s.length - 1) : s;
}
