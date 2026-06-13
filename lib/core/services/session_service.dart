import 'dart:async';
import 'package:flutter/foundation.dart';

class SessionService {
  static const Duration _inactivityTimeout = Duration(minutes: 5);
  
  Timer? _inactivityTimer;
  final VoidCallback onTimeout;
  bool _isActive = false;

  SessionService({required this.onTimeout});

  void startMonitoring() {
    _isActive = true;
    _resetTimer();
    debugPrint('[Session] Monitoring started — timeout in 5 min');
  }

  void recordActivity() {
    if (!_isActive) return;
    _resetTimer();
  }

  void stopMonitoring() {
    _isActive = false;
    _inactivityTimer?.cancel();
    debugPrint('[Session] Monitoring stopped');
  }

  void _resetTimer() {
    _inactivityTimer?.cancel();
    _inactivityTimer = Timer(_inactivityTimeout, () {
      debugPrint('[Session] Inactivity timeout — auto-locking');
      onTimeout();
    });
  }

  void dispose() {
    _inactivityTimer?.cancel();
  }
}
