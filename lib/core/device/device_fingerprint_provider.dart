import 'dart:math';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

final deviceFingerprintProvider = Provider<String>((ref) {
  throw UnimplementedError('deviceFingerprintProvider must be overridden');
});

class DeviceFingerprintService {
  static const String _key = 'device_fingerprint';

  static Future<String> initFingerprint(SharedPreferences prefs) async {
    String? fingerprint = prefs.getString(_key);
    if (fingerprint == null) {
      fingerprint = _generateFingerprint();
      await prefs.setString(_key, fingerprint);
    }
    return fingerprint;
  }

  static String _generateFingerprint() {
    final random = Random();
    final parts = [
      _hex(random.nextInt(0xFFFFFFFF), 8),
      _hex(random.nextInt(0xFFFF), 4),
      _hex(random.nextInt(0xFFFF), 4),
      _hex(random.nextInt(0xFFFF), 4),
      _hex(random.nextInt(0xFFFFFFFF), 8) + _hex(random.nextInt(0xFFFF), 4),
    ];
    return parts.join('-');
  }

  static String _hex(int value, int length) {
    return value.toRadixString(16).padLeft(length, '0');
  }
}
