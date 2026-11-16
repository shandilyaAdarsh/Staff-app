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
    const envWsUrl = String.fromEnvironment('WS_URL', defaultValue: '');

    String resolvedApiBaseUrl = envApiBaseUrl.trim();

    if (resolvedApiBaseUrl.isEmpty) {
      if (kReleaseMode) {
        resolvedApiBaseUrl = 'https://table-os.onrender.com';
      } else if (kIsWeb) {
        // Fallback for local web development to avoid needing --dart-define
        resolvedApiBaseUrl = '${Uri.base.scheme}://${Uri.base.host}:3001';
      } else {
        throw Exception(
          'API_BASE_URL is missing! You must run the app with '
          '--dart-define=API_BASE_URL=https://table-os.onrender.com (or LAN IP for local dev).',
        );
      }
    }

    // Strip trailing slashes and redundant /api/v1 prefix
    resolvedApiBaseUrl = resolvedApiBaseUrl.replaceAll(RegExp(r'/+$'), '');
    if (resolvedApiBaseUrl.endsWith('/api/v1')) {
      resolvedApiBaseUrl = resolvedApiBaseUrl.substring(0, resolvedApiBaseUrl.length - 7);
    }

    if (resolvedApiBaseUrl.contains('localhost') || resolvedApiBaseUrl.contains('127.0.0.1') || resolvedApiBaseUrl.contains('30.30.11.1')) {
      if (!kIsWeb && defaultTargetPlatform != TargetPlatform.windows && defaultTargetPlatform != TargetPlatform.macOS) {
        throw Exception(
          'Invalid API_BASE_URL: $resolvedApiBaseUrl. '
          'You cannot use localhost, 127.0.0.1, or stale IPs (like 30.30.11.1) on a physical mobile device. '
          'Please use your development machine\'s actual LAN IP or the production URL https://table-os.onrender.com.'
        );
      }
    }

    // Derive or use configured WebSocket URL
    String resolvedWsUrl = envWsUrl.trim();
    if (resolvedWsUrl.isEmpty) {
      final uri = Uri.parse(resolvedApiBaseUrl);
      final wsScheme = uri.scheme == 'https' ? 'wss' : 'ws';
      final portPart = (uri.hasPort && uri.port != 80 && uri.port != 443) ? ':${uri.port}' : '';
      resolvedWsUrl = '$wsScheme://${uri.host}$portPart/api/v1/realtime';
    }

    _instance = AppConfig._(
      environment: environment ?? (kReleaseMode ? Environment.prod : Environment.dev),
      apiBaseUrl: resolvedApiBaseUrl,
      websocketUrl: resolvedWsUrl,
      enableSentry: enableSentry ?? false,
    );
  }
}
