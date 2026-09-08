// lib/core/network/network_info_io.dart
import 'dart:io';

import '../config/app_config.dart';

Future<bool> checkConnection() async {
  try {
    final result = await InternetAddress.lookup('google.com');
    if (result.isNotEmpty && result[0].rawAddress.isNotEmpty) return true;
  } on SocketException catch (_) {}

  // LAN backend fallback — check if machine's WiFi IP is reachable
  // This allows the app to detect connectivity even without WAN access.
  try {
    final uri = Uri.parse(AppConfig.instance.apiBaseUrl);
    final socket = await Socket.connect(uri.host, uri.port, timeout: const Duration(milliseconds: 1500));
    socket.destroy();
    return true;
  } catch (_) {
    return false;
  }
}
