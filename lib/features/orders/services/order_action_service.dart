// lib/features/orders/services/order_action_service.dart
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../../core/network/network_providers.dart';
import '../../../../core/network/offline_queue.dart';
import '../../../../core/network/dio_client.dart';
import '../../../../core/network/secure_storage.dart';

final orderActionServiceProvider = Provider<OrderActionService>((ref) {
  final offlineQueue = ref.watch(offlineQueueManagerProvider);
  final dio = ref.watch(dioClientProvider);
  return OrderActionService(offlineQueue, dio);
});

class OrderActionService {
  final OfflineQueueManager _offlineQueue;
  final DioClient _dio;

  OrderActionService(this._offlineQueue, this._dio) {
    _registerHandlers();
  }

  void _registerHandlers() {
    _offlineQueue.registerHandler('order_accept', (payload) async {
      final orderId = payload['orderId'] as String;
      final versionNum = payload['versionNum'] as int;
      await _dio.patch(
        '/api/v1/orders/$orderId/accept',
        data: {'versionNum': versionNum},
      );
    });

    _offlineQueue.registerHandler('order_pass', (payload) async {
      final orderId = payload['orderId'] as String;
      final toStaffId = payload['toStaffId'] as String;
      final branchId = payload['branchId'] as String;
      await _dio.patch(
        '/api/v1/orders/$orderId/reassign',
        data: {'toStaffId': toStaffId, 'branchId': branchId},
      );
    });
  }

  Future<void> queueAcceptAlert(String orderId, int versionNum) async {
    await _offlineQueue.queueWrite(
      action: 'order_accept',
      payload: {
        'orderId': orderId,
        'versionNum': versionNum,
      },
    );
  }

  Future<void> queuePassAlert({
    required String orderId,
    required String toStaffId,
    required String branchId,
  }) async {
    await _offlineQueue.queueWrite(
      action: 'order_pass',
      payload: {
        'orderId': orderId,
        'toStaffId': toStaffId,
        'branchId': branchId,
      },
    );
  }

  /// Assigns the currently authenticated waiter to the table/order.
  ///
  /// This is the Staff App''s "ACCEPT" mutation calling POST /assign_waiter,
  /// strictly separated from the kitchen order status transition.
  ///
  /// The [idempotencyKey] must be deterministic per (orderId, staffSession)
  /// so retries on network failure are safe and idempotent.
  Future<Map<String, dynamic>> assignWaiter({
    required String orderId,
    required String staffId,
    required String idempotencyKey,
  }) async {
    final options = await _getAuthOptions();
    if (options == null) {
      throw Exception('[AssignWaiter] Cannot assign waiter — no valid auth token available.');
    }

    final response = await _dio.post(
      '/api/v1/orders/$orderId/assign_waiter',
      data: {
        'idempotency_key': idempotencyKey,
        'staff_id': staffId,
      },
      options: options,
    );

    if (response.statusCode == 200) {
      final data = response.data as Map<String, dynamic>;
      return data['data'] as Map<String, dynamic>? ?? {};
    }

    throw Exception('[AssignWaiter] Unexpected response: ${response.statusCode}');
  }

  /// Resolves the runtime auth token (runtime_token preferred, Supabase session fallback).
  Future<Options?> _getAuthOptions() async {
    try {
      const secureStorage = SecureLocalStorage();
      final runtimeToken = await secureStorage.read('runtime_token');
      final sessionToken = Supabase.instance.client.auth.currentSession?.accessToken;
      final authToken = (runtimeToken != null && runtimeToken.isNotEmpty)
          ? runtimeToken
          : sessionToken;
      if (authToken != null && authToken.isNotEmpty) {
        return Options(headers: {'Authorization': 'Bearer $authToken'});
      }
    } catch (e) {
      debugPrint('[OrderActionService] Failed to resolve auth token: $e');
    }
    return null;
  }
}
