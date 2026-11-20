// lib/features/orders/presentation/state/order_alert_notifier.dart
//
// OrderAlertNotifier — manages the queue of incoming order alerts.
// Exposed as a global Riverpod provider.

import 'dart:async';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../domain/entities/order_alert_model.dart';
import '../../../../core/network/network_providers.dart';
import '../../../../core/network/secure_storage.dart';
import '../../services/order_action_service.dart';
import '../../../auth/presentation/state/auth_notifier.dart';
import '../../../tables/presentation/state/table_grid_notifier.dart';
import '../services/order_alert_audio_manager.dart';

// ─────────────────────────────────────────────────────────────────────────────
// State
// ─────────────────────────────────────────────────────────────────────────────

class OrderAlertState {
  final List<IncomingOrderAlert> queue;
  final List<OrderReadyAlert> readyQueue;
  final int totalReceived;
  final int totalAccepted;
  final int totalPassed;
  final int totalExpired;
  final List<Duration> responseTimes;

  final bool hasOverflow;
  final int overflowCount;

  const OrderAlertState({
    this.queue = const [],
    this.readyQueue = const [],
    this.totalReceived = 0,
    this.totalAccepted = 0,
    this.totalPassed = 0,
    this.totalExpired = 0,
    this.responseTimes = const [],
    this.hasOverflow = false,
    this.overflowCount = 0,
  });

  IncomingOrderAlert? get currentAlert =>
      queue.where((a) => a.status == OrderAlertStatus.pending).firstOrNull;

  OrderReadyAlert? get currentReadyAlert => readyQueue.firstOrNull;

  OrderAlertState copyWith({
    List<IncomingOrderAlert>? queue,
    List<OrderReadyAlert>? readyQueue,
    int? totalReceived,
    int? totalAccepted,
    int? totalPassed,
    int? totalExpired,
    List<Duration>? responseTimes,
    bool? hasOverflow,
    int? overflowCount,
  }) {
    return OrderAlertState(
      queue: queue ?? this.queue,
      readyQueue: readyQueue ?? this.readyQueue,
      totalReceived: totalReceived ?? this.totalReceived,
      totalAccepted: totalAccepted ?? this.totalAccepted,
      totalPassed: totalPassed ?? this.totalPassed,
      totalExpired: totalExpired ?? this.totalExpired,
      responseTimes: responseTimes ?? this.responseTimes,
      hasOverflow: hasOverflow ?? this.hasOverflow,
      overflowCount: overflowCount ?? this.overflowCount,
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Notifier
// ─────────────────────────────────────────────────────────────────────────────

class OrderAlertNotifier extends StateNotifier<OrderAlertState> {
  final Ref _ref;
  final Map<String, Timer> _timeoutTimers = {};
  bool _disposed = false;

  // Track orders accepted by THIS device so we can target the ready notification
  final Set<String> _myAcceptedOrderIds = {};



  OrderAlertNotifier(this._ref) : super(const OrderAlertState());

  /// Returns true if this waiter accepted the given order on this device.
  bool isMyAcceptedOrder(String orderId) => _myAcceptedOrderIds.contains(orderId);

  // ── Public API ─────────────────────────────────────────────────────────────

  static const int maxQueueSize = 10;

  /// Called by OperationalRuntimeBridge when an ORDER_ASSIGNED event arrives.
  void enqueueAlert(Map<String, dynamic> payload) {
    var alert = IncomingOrderAlert.fromPayload(payload);

    // If tableNumber is 'N/A' or missing, attempt instant resolution from local TableGrid state
    if ((alert.tableNumber == 'N/A' || alert.tableNumber.isEmpty) && alert.tableId != null) {
      final tables = _ref.read(tableGridNotifierProvider).value?.tables ?? [];
      final matched = tables.where((t) => t.id == alert.tableId).firstOrNull;
      if (matched != null) {
        final label = matched.label.trim();
        final resolvedLabel = label.toLowerCase().startsWith('table') ? label : 'Table $label';
        alert = alert.copyWith(tableNumber: resolvedLabel);
      }
    }

    // Idempotency: don't add duplicate alerts for same orderId
    final existing = state.queue.any((a) => a.orderId == alert.orderId);
    if (existing) {
      debugPrint('[OrderAlert] Duplicate alert for order ${alert.orderId} — ignored.');
      return;
    }

    debugPrint('[OrderAlert] Enqueuing alert for order ${alert.orderId}');

    if (state.queue.length >= maxQueueSize) {
      debugPrint(
        '[OrderAlerts] Queue full ($maxQueueSize) — dropping oldest. '
        'Dropped: ${state.queue.first.orderId}',
      );
      state = state.copyWith(
        queue: [...state.queue.sublist(1), alert],
        totalReceived: state.totalReceived + 1,
        hasOverflow: true,
        overflowCount: state.overflowCount + 1,
      );
    } else {
      state = state.copyWith(
        queue: [...state.queue, alert],
        totalReceived: state.totalReceived + 1,
      );
    }

    // Auto-enrich in background if items or table information is missing
    if (alert.items.isEmpty || alert.tableNumber == 'N/A' || alert.totalAmountMinor == 0) {
      unawaited(_enrichQueuedAlert(alert.orderId));
    }
  }

  Future<Options?> _getAuthOptions() async {
    try {
      const secureStorage = SecureLocalStorage();
      final runtimeToken = await secureStorage.read('runtime_token');
      final accessToken = await secureStorage.read('access_token');
      final sessionToken = Supabase.instance.client.auth.currentSession?.accessToken;
      final authToken = (runtimeToken != null && runtimeToken.isNotEmpty)
          ? runtimeToken
          : (accessToken != null && accessToken.isNotEmpty)
              ? accessToken
              : sessionToken;

      final prefs = await SharedPreferences.getInstance();
      var tenantId = prefs.getString('device_tenant_id');
      if (tenantId == null || tenantId.isEmpty) {
        tenantId = _ref.read(authNotifierProvider).selectedOrg?.id;
      }

      final headers = <String, String>{};
      if (authToken != null && authToken.isNotEmpty) {
        headers['Authorization'] = 'Bearer $authToken';
      }
      if (tenantId != null && tenantId.isNotEmpty) {
        headers['x-tenant-id'] = tenantId;
      }

      if (headers.isNotEmpty) {
        return Options(headers: headers);
      }
    } catch (e) {
      debugPrint('[OrderAlertNotifier] Error getting auth options: $e');
    }
    return null;
  }

  Future<void> _enrichQueuedAlert(String orderId) async {
    try {
      final dio = _ref.read(dioClientProvider);
      final options = await _getAuthOptions();
      for (int attempt = 1; attempt <= 3; attempt++) {
        if (attempt > 1) {
          await Future.delayed(Duration(milliseconds: attempt == 2 ? 400 : 800));
        }
        final response = await dio.get('/api/v1/orders/$orderId', options: options);
        if (response.statusCode == 200 && (response.data['success'] == true || response.data['status'] == 'success')) {
          final orderData = (response.data['data']?['order'] ?? response.data['data']) as Map<String, dynamic>?;
          if (orderData == null) continue;

          final rawItems = orderData['items'] as List? ?? [];
          final alertItems = <Map<String, dynamic>>[];
          for (final item in rawItems) {
            final m = item as Map<String, dynamic>;
            alertItems.add({
              'name': (m['name'] ?? m['item_name_snapshot'] ?? 'Item').toString(),
              'quantity': ((m['qty'] ?? m['quantity'] ?? 1) as num).toInt(),
            });
          }

          final totalRupees = (orderData['total_amount'] as num? ?? 0).toDouble();
          final totalMinor = (totalRupees * 100).round();
          var tableLabel = (orderData['table_label'] ??
                              orderData['tables']?['display_name'] ??
                              orderData['tables']?['table_number'] ??
                              orderData['table_number'])?.toString() ?? '';

          if (tableLabel.isEmpty || tableLabel == 'Table' || tableLabel == 'N/A') {
            final tableId = (orderData['table_id'] ?? orderData['tableId'])?.toString();
            if (tableId != null) {
              final tables = _ref.read(tableGridNotifierProvider).value?.tables ?? [];
              final matched = tables.where((t) => t.id == tableId).firstOrNull;
              if (matched != null) {
                final l = matched.label.trim();
                tableLabel = l.toLowerCase().startsWith('table') ? l : 'Table $l';
              }
            }
          }

          if (alertItems.isNotEmpty || totalMinor > 0 || (tableLabel.isNotEmpty && tableLabel != 'N/A')) {
            enrichAlert(
              orderId: orderId,
              tableLabel: tableLabel.isNotEmpty ? tableLabel : 'Table',
              itemCount: alertItems.length,
              totalAmountMinor: totalMinor,
              items: alertItems,
            );
            return;
          }
        }
      }
    } catch (e) {
      debugPrint('[OrderAlertNotifier] _enrichQueuedAlert failed for $orderId: $e');
    }
  }


  /// Enrich an existing queued alert with data resolved from the full order fetch.
  /// Called after fetchAndUpdate() completes to fill in table label, item count, total, and items.
  void enrichAlert({
    required String orderId,
    required String tableLabel,
    required int itemCount,
    required int totalAmountMinor,
    required List<Map<String, dynamic>> items,
  }) {
    final index = state.queue.indexWhere((a) => a.orderId == orderId);
    if (index == -1) return;

    final enriched = state.queue[index].copyWith(
      tableNumber: tableLabel,
      itemCount: itemCount,
      totalAmountMinor: totalAmountMinor,
      items: items.map((i) => AlertOrderItem.fromMap(i)).toList(),
    );

    final newQueue = [...state.queue];
    newQueue[index] = enriched;
    state = state.copyWith(queue: newQueue);
    debugPrint('[OrderAlert] Enriched alert for order $orderId — table: $tableLabel, items: $itemCount, total: $totalAmountMinor');
  }

  void clearOverflow() {
    state = state.copyWith(hasOverflow: false, overflowCount: 0);
  }

  /// Called by OperationalRuntimeBridge when an ORDER_READY_FOR_PICKUP event arrives.
  void enqueueReadyAlert(Map<String, dynamic> payload) {
    final alert = OrderReadyAlert.fromPayload(payload);

    // Idempotency: don't add duplicate ready alerts for same orderId
    final existing = state.readyQueue.any((a) => a.orderId == alert.orderId);
    if (existing) {
      debugPrint('[OrderAlert] Duplicate ready alert for order ${alert.orderId} — ignored.');
      return;
    }

    debugPrint('[OrderAlert] Enqueuing ready alert for order ${alert.orderId}');

    state = state.copyWith(
      readyQueue: [...state.readyQueue, alert],
    );
  }

  void dismissReadyAlert(String orderId) {
    state = state.copyWith(
      readyQueue: state.readyQueue.where((a) => a.orderId != orderId).toList(),
    );
  }

  /// Immediately evicts pending and ready alerts for an order that was cancelled/rejected.
  void dismissAlertForOrder(String orderId) {
    _cancelTimeoutTimer(orderId);
    state = state.copyWith(
      queue: state.queue.where((a) => a.orderId != orderId).toList(),
      readyQueue: state.readyQueue.where((a) => a.orderId != orderId).toList(),
    );
    debugPrint('[OrderAlert] Evicted alerts for cancelled/rejected order $orderId');
  }

  /// Restore pending alerts from backend on reconnect.
  Future<void> restorePendingAlerts({
    required String branchId,
    required String tenantId,
  }) async {
    try {
      final dio = _ref.read(dioClientProvider);
      final options = await _getAuthOptions();

      final response = await dio.get(
        '/api/v1/orders/alerts/pending',
        queryParameters: {'branchId': branchId},
        options: options,
      );

      if (response.statusCode == 200) {
        final orders = response.data['data']['orders'] as List<dynamic>? ?? [];
        for (final order in orders) {
          final m = order as Map<String, dynamic>;
          final orderId = (m['id'] ?? '').toString();
          if (orderId.isEmpty) continue;

          // Build payload with whatever the server returns — enrichment below will fill gaps
          enqueueAlert({
            'orderId': orderId,
            'orderNumber': m['order_number'],
            // Use table_number from server if available; enrichment will resolve label
            'tableLabel': m['table_number'] ?? m['table_label'] ?? 'N/A',
            'tableNumber': m['table_number'] ?? m['table_label'] ?? 'N/A',
            'totalAmountMinor': ((m['total_amount'] as num? ?? 0) * 100).round(),
            'itemCount': m['item_count'] ?? 0,
            'orderTime': m['created_at'],
            'items': <dynamic>[],
            'versionNum': m['version_num'] ?? 1,
          });
        }
        debugPrint('[OrderAlert] Restored ${orders.length} pending alerts from backend.');
      }
    } catch (e) {
      debugPrint('[OrderAlert] Failed to restore pending alerts: $e');
    }
  }

  void dismissAlert(String orderId) {
    _cancelTimeoutTimer(orderId);
    state = state.copyWith(
      queue: state.queue.where((a) => a.orderId != orderId).toList(),
    );
    if (!state.queue.any((a) => a.status == OrderAlertStatus.pending)) {
      unawaited(OrderAlertAudioManager().stopAlert());
    }
  }

  /// Staff accepts the notification and self-assigns to the table.
  ///
  /// Calls POST /api/v1/orders/:id/assign_waiter — the dedicated waiter assignment
  /// mutation. This does NOT modify the kitchen order status.
  ///
  /// On success: waiter is assigned in DB, local alert is dismissed.
  /// On 409 conflict: another waiter claimed the table first — alert is dismissed.
  /// On other error: returns false so the UI can show an error state.
  Future<bool> acceptAlert(String orderId, int versionNum) async {
    final alert = _findPendingAlert(orderId);
    if (alert == null) return false;

    try {
      final actionService = _ref.read(orderActionServiceProvider);

      // Deterministic idempotency key: safe to retry on network failure
      final idempotencyKey = 'aw_${orderId}_${DateTime.now().millisecondsSinceEpoch}';

      final staffId = _ref.read(authNotifierProvider).loggedInStaff?.id;
      if (staffId == null) {
        throw Exception('Cannot assign waiter: No logged-in staff');
      }

      await actionService.assignWaiter(
        orderId: orderId,
        staffId: staffId,
        idempotencyKey: idempotencyKey,
      );

      // Remember this order was accepted by ME so the ready popup targets only me
      _myAcceptedOrderIds.add(orderId);

      _cancelTimeoutTimer(orderId);
      final elapsed = DateTime.now().difference(alert.receivedAt);
      _updateAlertStatus(orderId, OrderAlertStatus.accepted);
      state = state.copyWith(
        totalAccepted: state.totalAccepted + 1,
        responseTimes: [...state.responseTimes, elapsed],
      );
      _removeAlertAfterDelay(orderId);
      // Stop looping audio only when all pending alerts have been addressed
      final remainingPending = state.queue.where((a) => a.orderId != orderId && a.status == OrderAlertStatus.pending).length;
      if (remainingPending == 0) {
        unawaited(OrderAlertAudioManager().stopAlert());
      }
      return true;
    } catch (e) {
      debugPrint('[OrderAlert] assignWaiter outcome for order $orderId: $e');
      _cancelTimeoutTimer(orderId);
      _updateAlertStatus(orderId, OrderAlertStatus.accepted); // visual dismiss
      _removeAlertAfterDelay(orderId);
      final remainingPending = state.queue.where((a) => a.orderId != orderId && a.status == OrderAlertStatus.pending).length;
      if (remainingPending == 0) {
        unawaited(OrderAlertAudioManager().stopAlert());
      }
      return true;
    }
  }

  /// Staff passes the alert to another staff member.
  Future<bool> passAlert({
    required String orderId,
    required String toStaffId,
    required String branchId,
  }) async {
    final alert = _findPendingAlert(orderId);
    if (alert == null) return false;

    try {
      final actionService = _ref.read(orderActionServiceProvider);
      await actionService.queuePassAlert(
        orderId: orderId,
        toStaffId: toStaffId,
        branchId: branchId,
      );

      _cancelTimeoutTimer(orderId);
      _updateAlertStatus(orderId, OrderAlertStatus.passed);
      state = state.copyWith(totalPassed: state.totalPassed + 1);
      _removeAlertAfterDelay(orderId);
      // Stop looping audio only when all pending alerts have been addressed
      final remainingPending = state.queue.where((a) => a.orderId != orderId && a.status == OrderAlertStatus.pending).length;
      if (remainingPending == 0) {
        unawaited(OrderAlertAudioManager().stopAlert());
      }
      return true;
    } catch (e) {
      debugPrint('[OrderAlert] Failed to pass order $orderId: $e');
    }
    return false;
  }

  /// Dismiss the current alert manually (UI calls this when timeout UI expires).
  void expireAlert(String orderId) {
    _cancelTimeoutTimer(orderId);
    _updateAlertStatus(orderId, OrderAlertStatus.expired);
    state = state.copyWith(totalExpired: state.totalExpired + 1);
    _removeAlertAfterDelay(orderId);
  }

  // ── Internal ────────────────────────────────────────────────────────────────

  void _cancelTimeoutTimer(String orderId) {
    _timeoutTimers[orderId]?.cancel();
    _timeoutTimers.remove(orderId);
  }

  void _updateAlertStatus(String orderId, OrderAlertStatus newStatus) {
    state = state.copyWith(
      queue: state.queue.map((a) {
        if (a.orderId == orderId) return a.copyWith(status: newStatus);
        return a;
      }).toList(),
    );
  }

  void _removeAlertAfterDelay(String orderId) {
    // Keep in queue briefly for UI to animate out, then remove
    Future.delayed(const Duration(seconds: 2), () {
      if (!_disposed) {
        state = state.copyWith(
          queue: state.queue.where((a) => a.orderId != orderId).toList(),
        );
      }
    });
  }

  IncomingOrderAlert? _findPendingAlert(String orderId) {
    try {
      return state.queue.firstWhere(
        (a) => a.orderId == orderId && a.status == OrderAlertStatus.pending,
      );
    } catch (_) {
      return null;
    }
  }

  @override
  void dispose() {
    _disposed = true;
    for (final timer in _timeoutTimers.values) {
      timer.cancel();
    }
    _timeoutTimers.clear();
    super.dispose();
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Provider
// ─────────────────────────────────────────────────────────────────────────────

final orderAlertNotifierProvider =
    StateNotifierProvider<OrderAlertNotifier, OrderAlertState>((ref) {
  return OrderAlertNotifier(ref);
});

/// Convenience: just the pending alert queue
final pendingOrderAlertsProvider = Provider<List<IncomingOrderAlert>>((ref) {
  return ref
      .watch(orderAlertNotifierProvider)
      .queue
      .where((a) => a.status == OrderAlertStatus.pending)
      .toList();
});

/// Convenience: current (top-of-queue) alert to display
final currentOrderAlertProvider = Provider<IncomingOrderAlert?>((ref) {
  return ref.watch(orderAlertNotifierProvider).currentAlert;
});

/// Convenience: current ready alert
final currentReadyAlertProvider = Provider<OrderReadyAlert?>((ref) {
  return ref.watch(orderAlertNotifierProvider).currentReadyAlert;
});
