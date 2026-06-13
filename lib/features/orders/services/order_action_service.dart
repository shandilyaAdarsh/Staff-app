// lib/features/orders/services/order_action_service.dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/network/network_providers.dart';
import '../../../../core/network/offline_queue.dart';
import '../../../../core/network/dio_client.dart';

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
}
