// lib/core/network/network_providers.dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive/hive.dart';
import '../utils/logger.dart';
import 'network_info.dart';
import 'offline_queue.dart';
import '../device/device_fingerprint_provider.dart';

import 'dio_client.dart';

final networkInfoProvider = Provider<NetworkInfo>((ref) => NetworkInfoImpl());

final apiCacheBoxProvider = Provider<Box<String>>((ref) {
  throw UnimplementedError('apiCacheBoxProvider has not been overridden in bootstrap');
});

final offlineQueueBoxProvider = Provider<Box<String>>((ref) {
  throw UnimplementedError('offlineQueueBoxProvider has not been overridden in bootstrap');
});

final offlineQueueManagerProvider = Provider<OfflineQueueManager>((ref) {
  final queueBox = ref.watch(offlineQueueBoxProvider);
  final networkInfo = ref.watch(networkInfoProvider);
  final talker = ref.watch(talkerProvider);
  return OfflineQueueManager(queueBox, networkInfo, talker);
});

final dioClientProvider = Provider<DioClient>((ref) {
  final talker = ref.watch(talkerProvider);
  final cacheBox = ref.watch(apiCacheBoxProvider);
  final fingerprint = ref.watch(deviceFingerprintProvider);
  return DioClient(talker: talker, cacheBox: cacheBox, deviceFingerprint: fingerprint);
});
