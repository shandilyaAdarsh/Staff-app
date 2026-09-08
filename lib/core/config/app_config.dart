// lib/core/config/app_config.dart
import 'package:flutter/foundation.dart';
import 'environment.dart';

class AppConfig {
  final Environment environment;
  final String apiBaseUrl;
  final String websocketUrl;
  final bool enableSentry;

  static late AppConfig _instance;
  static AppConfig get instance => _instance;

  AppConfig._({
    required this.environment,
    required this.apiBaseUrl,
    required this.websocketUrl,
    required this.enableSentry,
  });

  static void initialize({
    Environment? environment,
    bool? enableSentry,
  }) {
    const envApiBaseUrl = String.fromEnvironment('API_BASE_URL', defaultValue: '');
    
    String resolvedApiBaseUrl = envApiBaseUrl;

    if (resolvedApiBaseUrl.isEmpty) {
      if (kIsWeb) {
        // Fallback for local web development to avoid needing --dart-define
        resolvedApiBaseUrl = '${Uri.base.scheme}://${Uri.base.host}:3001';
      } else {
        throw Exception(
          'API_BASE_URL is missing! You must run the app with '
          '--dart-define=API_BASE_URL=http://<YOUR_LAN_IP>:3001 '
          'when running on a physical device. Do not use localhost.',
        );
      }
    }

    if (resolvedApiBaseUrl.contains('localhost') || resolvedApiBaseUrl.contains('127.0.0.1') || resolvedApiBaseUrl.contains('30.30.11.1')) {
      if (!kIsWeb && defaultTargetPlatform != TargetPlatform.windows && defaultTargetPlatform != TargetPlatform.macOS) {
        throw Exception(
          "Invalid API_BASE_URL: $resolvedApiBaseUrl. "
          "You cannot use localhost, 127.0.0.1, or stale IPs (like 30.30.11.1) on a physical mobile device. "
          "Please use your development machine's actual LAN IP (e.g. 192.168.x.x)."
        );
      }
    }

    // Derive websocket URL from api base URL
    final uri = Uri.parse(resolvedApiBaseUrl);
    final wsScheme = uri.scheme == 'https' ? 'wss' : 'ws';
    final resolvedWsUrl = '$wsScheme://${uri.host}:${uri.port}/api/v1/realtime';

    _instance = AppConfig._(
      environment: environment ?? Environment.dev,
      apiBaseUrl: resolvedApiBaseUrl,
      websocketUrl: resolvedWsUrl,
      enableSentry: enableSentry ?? false,
    );
  }
}
