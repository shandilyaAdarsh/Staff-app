// lib/features/orders/providers/orders_realtime_provider.dart
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../auth/presentation/state/auth_notifier.dart';
import '../../alerts/services/order_alert_service.dart';
import '../presentation/state/order_alert_notifier.dart';
import '../services/orders_realtime_service.dart';
import 'orders_providers.dart';
import '../presentation/state/orders_projection_provider.dart';
import '../../tables/presentation/state/table_grid_notifier.dart';

final orderAlertServiceProvider = Provider<OrderAlertService>((ref) {
  final service = OrderAlertService();
  ref.onDispose(() => service.dispose());
  return service;
});

final ordersRealtimeProvider = Provider<void>((ref) {
  final authState = ref.watch(authNotifierProvider);
  final staff = authState.loggedInStaff;
  final branch = authState.selectedBranch;

  // Only subscribe if staff is logged in and branch is selected
  if (staff == null || branch == null) {
    return;
  }

  final supabase = Supabase.instance.client;
  final service = OrdersRealtimeService(supabase, branch.id);
  final alertService = ref.read(orderAlertServiceProvider);
  final orderAlertNotifier = ref.read(orderAlertNotifierProvider.notifier);

  Future<void> fetchAndUpdate() async {
    final repo = ref.read(ordersRepositoryProvider);
    final orders = await repo.fetchActiveOrders();
    ref.read(ordersProjectionProvider.notifier).updateProjection(orders);
    return;
  }


  service.onEvent.listen((event) {
    debugPrint('[ordersRealtimeProvider] EVENT: type=${event.type}, status=${event.payload['status']}');
    if (event.type == RealtimeOrderEventType.insert) {
      // Refresh projection silently when new order is placed (no full-screen alert popup on placement)
      fetchAndUpdate();
    } else if (event.type == RealtimeOrderEventType.update) {
      final status = (event.payload['status'] ?? event.payload['order_status'])?.toString().toLowerCase();
      if (status == 'accepted') {
        alertService.playNewOrderAlert();
        orderAlertNotifier.enqueueAlert(event.payload);
      } else if (status == 'ready' || status == 'ready_for_pickup') {
        final orderId = (event.payload['id'] ?? event.payload['orderId'])?.toString() ?? '';
        final assignedStaffId = (event.payload['assigned_staff_id'] ??
                                 event.payload['assigned_waiter_id'] ??
                                 event.payload['assignedStaffId'] ??
                                 event.payload['acceptedByStaffId'])?.toString();
        final currentStaffId = staff.id;
        final isMyOrder = orderAlertNotifier.isMyAcceptedOrder(orderId) ||
            (assignedStaffId != null && assignedStaffId == currentStaffId) ||
            assignedStaffId == null; // Unassigned table/order: broadcast to all staff

        if (isMyOrder) {
          debugPrint('[ordersRealtimeProvider] Ready alert for order $orderId — showing popup.');
          alertService.playOrderReadyAlert();
          orderAlertNotifier.enqueueReadyAlert(event.payload);
        } else {
          debugPrint('[ordersRealtimeProvider] Ready alert for order $orderId — assigned to other staff ($assignedStaffId), skipping.');
        }
      } else if (status == 'cancelled' || status == 'rejected' || status == 'delivered' || status == 'completed') {
        final orderId = (event.payload['id'] ?? event.payload['orderId'])?.toString() ?? '';
        if (orderId.isNotEmpty) {
          orderAlertNotifier.dismissAlertForOrder(orderId);
        }
      }
      fetchAndUpdate();
      ref.read(tableGridNotifierProvider.notifier).refreshTables();
    }
  });

  // Initial fetch
  fetchAndUpdate();

  service.subscribe();

  ref.onDispose(() {
    service.dispose();
  });
});
