// test/new_features_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:orderlyy_app/features/waiter_calls/domain/entities/waiter_call.dart';
import 'package:orderlyy_app/features/notifications/presentation/state/notifications_provider.dart';

void main() {
  group('WaiterCall Priority & Urgency Logic', () {
    test('standard call urgency based on elapsed time', () {
      final now = DateTime.now();
      
      final freshCall = WaiterCall(
        id: '1',
        tableId: 'T1',
        tableLabel: 'Table 1',
        type: CallType.service,
        status: CallStatus.pending,
        timestamp: now,
      );

      final agedCall = WaiterCall(
        id: '2',
        tableId: 'T2',
        tableLabel: 'Table 2',
        type: CallType.service,
        status: CallStatus.pending,
        timestamp: now.subtract(const Duration(seconds: 125)),
      );

      expect(freshCall.isUrgent, isFalse);
      expect(agedCall.isUrgent, isTrue);
    });

    test('VIP call urgency escalates faster (45 seconds)', () {
      final now = DateTime.now();

      final freshVipCall = WaiterCall(
        id: '3',
        tableId: 'T3',
        tableLabel: 'Table 3',
        type: CallType.service,
        status: CallStatus.pending,
        timestamp: now.subtract(const Duration(seconds: 30)),
        isVip: true,
      );

      final agedVipCall = WaiterCall(
        id: '4',
        tableId: 'T4',
        tableLabel: 'Table 4',
        type: CallType.service,
        status: CallStatus.pending,
        timestamp: now.subtract(const Duration(seconds: 50)),
        isVip: true,
      );

      expect(freshVipCall.isUrgent, isFalse);
      expect(agedVipCall.isUrgent, isTrue);
    });

    test('Issue reports are always urgent', () {
      final now = DateTime.now();

      final issueCall = WaiterCall(
        id: '5',
        tableId: 'T5',
        tableLabel: 'Table 5',
        type: CallType.issueReport,
        status: CallStatus.pending,
        timestamp: now,
      );

      expect(issueCall.isUrgent, isTrue);
    });

    test('Priority score calculation maps correctly', () {
      final now = DateTime.now();
      final call = WaiterCall(
        id: '6',
        tableId: 'T6',
        tableLabel: 'Table 6',
        type: CallType.issueReport,
        status: CallStatus.pending,
        timestamp: now.subtract(const Duration(seconds: 10)),
        isVip: true,
      );

      // (10 seconds * 1.0 time weight) + 30.0 severity + 25.0 VIP = 65.0
      expect(call.calculatePriorityScore(false), 65.0);

      // (10 seconds * 1.5 time weight) + 30.0 severity + 25.0 VIP = 70.0
      expect(call.calculatePriorityScore(true), 70.0);
    });
  });

  group('AppNotification & NotificationsNotifier Logic', () {
    test('Initial notifications are populated with correct read/unread states', () {
      final notifier = NotificationsNotifier();
      final list = notifier.state;

      expect(list.length, 4);
      expect(list.where((n) => !n.isRead).length, 3);
      expect(list.where((n) => n.isRead).length, 1);
    });

    test('Mark notification as read updates state correctly', () {
      final notifier = NotificationsNotifier();
      expect(notifier.state.firstWhere((n) => n.id == 'notif_1').isRead, isFalse);

      notifier.markAsRead('notif_1');
      expect(notifier.state.firstWhere((n) => n.id == 'notif_1').isRead, isTrue);
    });

    test('Mark all notifications as read updates all states', () {
      final notifier = NotificationsNotifier();
      notifier.markAllAsRead();

      expect(notifier.state.any((n) => !n.isRead), isFalse);
    });

    test('Clear notification removes it from list', () {
      final notifier = NotificationsNotifier();
      final originalLength = notifier.state.length;

      notifier.clearNotification('notif_1');
      expect(notifier.state.length, originalLength - 1);
      expect(notifier.state.any((n) => n.id == 'notif_1'), isFalse);
    });

    test('Clear all empties the notification feed list', () {
      final notifier = NotificationsNotifier();
      notifier.clearAll();

      expect(notifier.state, isEmpty);
    });
  });
}
