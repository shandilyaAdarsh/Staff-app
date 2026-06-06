// lib/features/orders/presentation/state/orders_projection_provider.dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../domain/entities/order.dart';

class OrdersProjectionNotifier extends StateNotifier<List<Order>> {
  OrdersProjectionNotifier() : super([]);

  void updateProjection(List<Order> orders) {
    state = List.unmodifiable(orders);
  }

  void clearProjection() {
    state = [];
  }
}

final ordersProjectionProvider =
    StateNotifierProvider<OrdersProjectionNotifier, List<Order>>((ref) {
  return OrdersProjectionNotifier();
});
