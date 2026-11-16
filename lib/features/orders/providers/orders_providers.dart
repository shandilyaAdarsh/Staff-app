// lib/features/orders/providers/orders_providers.dart
import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../../bootstrap/bootstrap.dart';
import '../data/datasources/local/orders_local_datasource.dart';
import '../data/datasources/remote/orders_remote_datasource.dart';
import '../data/repositories/orders_repository_impl.dart';
import '../domain/entities/menu_product.dart';
import '../domain/entities/order.dart';
import '../domain/repositories/orders_repository.dart';
import '../../menu/presentation/state/menu_providers.dart';
import '../../../../core/network/network_providers.dart';
import '../presentation/state/orders_projection_provider.dart';
import '../../auth/presentation/state/auth_notifier.dart';

final ordersLocalDatasourceProvider = Provider<OrdersLocalDatasource>((ref) {
  final prefs = ref.watch(sharedPreferencesProvider);
  return OrdersLocalDatasourceImpl(prefs);
});

final ordersRemoteDatasourceProvider = Provider<OrdersRemoteDatasource>((ref) {
  final dio = ref.watch(dioClientProvider);
  return OrdersRemoteDatasourceImpl(dio);
});

final ordersRepositoryProvider = Provider<OrdersRepository>((ref) {
  final local = ref.watch(ordersLocalDatasourceProvider);
  final remote = ref.watch(ordersRemoteDatasourceProvider);
  final offlineQueue = ref.watch(offlineQueueManagerProvider);
  return OrdersRepositoryImpl(
    local: local,
    remote: remote,
    offlineQueue: offlineQueue,
    ref: ref,
  );
});

final menuProductsProvider = Provider<List<MenuProduct>>((ref) {
  return ref.watch(publicMenuProductsProvider);
});

final activeOrdersProvider = FutureProvider.autoDispose<void>((ref) async {
  final repo = ref.watch(ordersRepositoryProvider);
  final orders = await repo.fetchActiveOrders();
  ref.read(ordersProjectionProvider.notifier).updateProjection(orders);
});

// ─────────────────────────────────────────────────────────────────────────────
// Live orders notifier — polls Supabase every 5 seconds AND re-fetches on
// realtime INSERT/UPDATE events. This dual approach guarantees the table cards
// always reflect the current DB state, regardless of subscription timing.
// ─────────────────────────────────────────────────────────────────────────────

class LiveOrdersNotifier extends StateNotifier<AsyncValue<List<Order>>> {
  final Ref _ref;
  Timer? _pollTimer;
  RealtimeChannel? _channel;
  bool _disposed = false;

  LiveOrdersNotifier(this._ref) : super(const AsyncValue.loading()) {
    _init();
  }

  Future<void> _refresh() async {
    if (_disposed) return;
    final authState = _ref.read(authNotifierProvider);
    final branch = authState.selectedBranch;
    if (branch == null) {
      if (!_disposed) state = const AsyncValue.data([]);
      return;
    }
    try {
      final orders = await _ref.read(ordersRepositoryProvider).fetchActiveOrders();
      if (!_disposed) {
        state = AsyncValue.data(orders);
        _ref.read(ordersProjectionProvider.notifier).updateProjection(orders);
        debugPrint('[LiveOrdersNotifier] refreshed — ${orders.length} active orders');
      }
    } catch (e, st) {
      debugPrint('[LiveOrdersNotifier] refresh error: $e');
      if (!_disposed) state = AsyncValue.error(e, st);
    }
  }

  void _init() {
    final authState = _ref.read(authNotifierProvider);
    final branch = authState.selectedBranch;
    if (branch == null) {
      state = const AsyncValue.data([]);
      return;
    }

    // Initial fetch
    _refresh();

    // Poll every 5 seconds as a safety net
    _pollTimer = Timer.periodic(const Duration(seconds: 5), (_) => _refresh());

    // Also subscribe to realtime for instant updates
    final supabase = Supabase.instance.client;
    final branchId = branch.id;

    try {
      _channel = supabase
          .channel('live_orders_notifier_$branchId')
          .onPostgresChanges(
            event: PostgresChangeEvent.insert,
            schema: 'public',
            table: 'orders',
            filter: PostgresChangeFilter(
              type: PostgresChangeFilterType.eq,
              column: 'branch_id',
              value: branchId,
            ),
            callback: (_) {
              debugPrint('[LiveOrdersNotifier] INSERT event — refreshing');
              _refresh();
            },
          )
          .onPostgresChanges(
            event: PostgresChangeEvent.update,
            schema: 'public',
            table: 'orders',
            filter: PostgresChangeFilter(
              type: PostgresChangeFilterType.eq,
              column: 'branch_id',
              value: branchId,
            ),
            callback: (_) {
              debugPrint('[LiveOrdersNotifier] UPDATE event — refreshing');
              _refresh();
            },
          )
          .subscribe((status, [err]) {
            debugPrint('[LiveOrdersNotifier] channel status: $status err: $err');
          });
    } catch (e) {
      debugPrint('[LiveOrdersNotifier] Realtime setup error: $e');
    }
  }

  @override
  void dispose() {
    _disposed = true;
    _pollTimer?.cancel();
    _channel?.unsubscribe();
    super.dispose();
  }
}

final liveOrdersProvider =
    StateNotifierProvider<LiveOrdersNotifier, AsyncValue<List<Order>>>((ref) {
  return LiveOrdersNotifier(ref);
});
