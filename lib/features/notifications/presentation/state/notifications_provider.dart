// lib/features/notifications/presentation/state/notifications_provider.dart
import 'dart:async';
import 'dart:math';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../domain/entities/app_notification.dart';

class NotificationsNotifier extends StateNotifier<List<AppNotification>> {
  NotificationsNotifier() : super([]) {
    _populateInitialMockNotifications();
  }

  void _populateInitialMockNotifications() {
    // Start with an empty list instead of mock data.
    state = [];
  }

  // Deduplication logic using temporary buffers
  final Map<String, Timer> _dedupTimers = {};

  void triggerNotification({
    required String title,
    required String message,
    required NotificationSeverity severity,
    required NotificationCategory category,
    Map<String, String>? metadata,
  }) {
    // If a notification with the same title and category is triggered within 500ms, deduplicate
    final dedupKey = '${category.name}_$title';
    if (_dedupTimers.containsKey(dedupKey)) {
      _dedupTimers[dedupKey]?.cancel();
    }

    _dedupTimers[dedupKey] = Timer(const Duration(milliseconds: 500), () {
      final notif = AppNotification(
        id: 'notif_${Random().nextInt(1000000)}',
        title: title,
        message: message,
        severity: severity,
        category: category,
        timestamp: DateTime.now(),
        metadata: metadata,
      );

      state = [notif, ...state];
      _dedupTimers.remove(dedupKey);

      // Perform haptic escalations based on severity
      _executeHapticsForSeverity(severity);
    });
  }

  void _executeHapticsForSeverity(NotificationSeverity severity) {
    switch (severity) {
      case NotificationSeverity.info:
        HapticFeedback.lightImpact();
        break;
      case NotificationSeverity.warning:
        HapticFeedback.mediumImpact();
        break;
      case NotificationSeverity.urgent:
        HapticFeedback.vibrate();
        break;
      case NotificationSeverity.critical:
        // Double heavy pulse pattern
        HapticFeedback.heavyImpact().then((_) {
          Future.delayed(const Duration(milliseconds: 100), () {
            HapticFeedback.heavyImpact();
          });
        });
        break;
    }
  }

  void markAsRead(String id) {
    state = state.map((n) {
      if (n.id == id) {
        return n.copyWith(isRead: true);
      }
      return n;
    }).toList();
  }

  void markAllAsRead() {
    state = state.map((n) => n.copyWith(isRead: true)).toList();
  }

  void clearNotification(String id) {
    state = state.where((n) => n.id != id).toList();
  }

  void clearAll() {
    state = [];
  }
}

final notificationsProvider = StateNotifierProvider<NotificationsNotifier, List<AppNotification>>((ref) {
  return NotificationsNotifier();
});

// Derived provider for unread notifications count
final unreadNotificationsCountProvider = Provider<int>((ref) {
  final list = ref.watch(notificationsProvider);
  return list.where((n) => !n.isRead).length;
});
