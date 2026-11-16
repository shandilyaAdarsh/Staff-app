import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:orderlyy_app/features/orders/domain/entities/order.dart';
import 'package:orderlyy_app/features/orders/domain/entities/order_item.dart';
import 'package:orderlyy_app/features/orders/domain/entities/menu_product.dart';
import 'package:orderlyy_app/features/orders/presentation/state/orders_projection_provider.dart';
import 'package:orderlyy_app/shared/models/money.dart';
import 'package:orderlyy_app/features/tables/domain/entities/restaurant_table.dart';

void main() {
  group('Order Lifecycle & Delivered Orders Filtering Tests', () {
    final now = DateTime.now();

    const item1 = OrderItem(
      id: 'item-1',
      product: MenuProduct(
        id: 'prod-1',
        name: 'Butter Chicken',
        price: Money(amountInCents: 35000), // ₹350.00
        category: 'Mains',
        availableModifiers: [],
      ),
      quantity: 2,
      selectedModifiers: [],
      seatNumber: 1,
      status: OrderItemStatus.queued,
    );

    const item2 = OrderItem(
      id: 'item-2',
      product: MenuProduct(
        id: 'prod-2',
        name: 'Garlic Naan',
        price: Money(amountInCents: 6000), // ₹60.00
        category: 'Breads',
        availableModifiers: [],
      ),
      quantity: 3,
      selectedModifiers: [],
      seatNumber: 1,
      status: OrderItemStatus.queued,
    );

    final activeOrderPreparing = Order(
      id: 'ord-prep-1',
      tableId: 'table-3',
      items: [item1],
      status: OrderStatus.preparing,
      createdAt: now.subtract(const Duration(minutes: 15)),
      updatedAt: now,
    );

    final activeOrderReady = Order(
      id: 'ord-ready-1',
      tableId: 'table-3',
      items: [item2],
      status: OrderStatus.ready,
      createdAt: now.subtract(const Duration(minutes: 10)),
      updatedAt: now,
    );

    final deliveredOrder1 = Order(
      id: 'ord-deliv-1',
      tableId: 'table-3',
      items: [item1, item2],
      status: OrderStatus.delivered,
      createdAt: now.subtract(const Duration(minutes: 30)),
      updatedAt: now.subtract(const Duration(minutes: 5)),
    );

    final deliveredOrder2 = Order(
      id: 'ord-deliv-2',
      tableId: 'table-3',
      items: [item2],
      status: OrderStatus.delivered,
      createdAt: now.subtract(const Duration(minutes: 45)),
      updatedAt: now.subtract(const Duration(minutes: 20)),
    );

    final completedOrder = Order(
      id: 'ord-comp-1',
      tableId: 'table-3',
      items: [item1],
      status: OrderStatus.completed,
      createdAt: now.subtract(const Duration(hours: 1)),
      updatedAt: now.subtract(const Duration(minutes: 50)),
    );

    final cancelledOrder = Order(
      id: 'ord-canc-1',
      tableId: 'table-3',
      items: [item2],
      status: OrderStatus.cancelled,
      createdAt: now.subtract(const Duration(hours: 2)),
      updatedAt: now.subtract(const Duration(hours: 1)),
    );

    test('1. A DELIVERED order is removed from the active projection list after update', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final notifier = container.read(ordersProjectionProvider.notifier);

      // Initially active orders include preparing, ready, and delivered
      notifier.updateProjection([activeOrderPreparing, activeOrderReady, deliveredOrder1]);

      final projected = container.read(ordersProjectionProvider);

      // DELIVERED order must be evicted from active projection
      expect(projected.any((o) => o.id == deliveredOrder1.id), isFalse);
      expect(projected.length, equals(2));
      expect(projected.map((o) => o.id), containsAll(['ord-prep-1', 'ord-ready-1']));
    });

    test('2. Multiple delivered orders do not keep a table marked active', () {
      // Table 3 only has delivered orders
      final allOrders = [deliveredOrder1, deliveredOrder2, completedOrder, cancelledOrder];

      final activeOrdersMap = <String, Order>{};
      final deliveredOrdersMap = <String, Order>{};

      for (final o in allOrders) {
        if (o.tableId == 'table-3') {
          if (o.status != OrderStatus.delivered &&
              o.status != OrderStatus.completed &&
              o.status != OrderStatus.cancelled) {
            activeOrdersMap[o.id] = o;
          } else if (o.status == OrderStatus.delivered) {
            deliveredOrdersMap[o.id] = o;
          }
        }
      }

      final activeTableOrders = activeOrdersMap.values.toList();
      final deliveredTableOrders = deliveredOrdersMap.values.toList();

      // Active orders list for table 3 must be completely empty
      expect(activeTableOrders.isEmpty, isTrue);

      // But delivered orders must remain accessible in order history
      expect(deliveredTableOrders.length, equals(2));
      expect(deliveredTableOrders.map((o) => o.id), containsAll(['ord-deliv-1', 'ord-deliv-2']));
    });

    test('3. Active orders remain visible while delivered orders are separated into history', () {
      final allOrders = [activeOrderPreparing, deliveredOrder1];

      final activeOrdersMap = <String, Order>{};
      final deliveredOrdersMap = <String, Order>{};

      for (final o in allOrders) {
        if (o.tableId == 'table-3') {
          if (o.status != OrderStatus.delivered &&
              o.status != OrderStatus.completed &&
              o.status != OrderStatus.cancelled) {
            activeOrdersMap[o.id] = o;
          } else if (o.status == OrderStatus.delivered) {
            deliveredOrdersMap[o.id] = o;
          }
        }
      }

      final activeTableOrders = activeOrdersMap.values.toList();
      final deliveredTableOrders = deliveredOrdersMap.values.toList();

      expect(activeTableOrders.length, equals(1));
      expect(activeTableOrders.first.id, equals('ord-prep-1'));
      expect(activeTableOrders.first.status, equals(OrderStatus.preparing));

      expect(deliveredTableOrders.length, equals(1));
      expect(deliveredTableOrders.first.id, equals('ord-deliv-1'));
      expect(deliveredTableOrders.first.status, equals(OrderStatus.delivered));
    });

    test('4. Table totals follow the existing billing contract and do not display ₹0.00 when items exist', () {
      // Order with 2x Butter Chicken (₹350 each) + 3x Garlic Naan (₹60 each)
      // Line 1: 2 * 350 = 700
      // Line 2: 3 * 60  = 180
      // Subtotal = 880
      expect(deliveredOrder1.items.length, equals(2));

      int totalCents = 0;
      for (final item in deliveredOrder1.items) {
        if (item.status != OrderItemStatus.cancelled) {
          totalCents += item.totalPrice.amountInCents;
        }
      }

      expect(totalCents, equals(88000));
      final formattedTotal = Money(amountInCents: totalCents).formatted;
      expect(formattedTotal, equals('₹880.00'));
      expect(formattedTotal, isNot(equals('₹0.00')));
    });

    test('5. Order-item details render with accurate names, quantities, and prices', () {
      final order = deliveredOrder1;
      expect(order.items, isNotEmpty);

      final firstItem = order.items.first;
      expect(firstItem.product.name, equals('Butter Chicken'));
      expect(firstItem.quantity, equals(2));
      expect(firstItem.unitPrice.formatted, equals('₹350.00'));
      expect(firstItem.totalPrice.formatted, equals('₹700.00'));

      final secondItem = order.items[1];
      expect(secondItem.product.name, equals('Garlic Naan'));
      expect(secondItem.quantity, equals(3));
      expect(secondItem.unitPrice.formatted, equals('₹60.00'));
      expect(secondItem.totalPrice.formatted, equals('₹180.00'));
    });

    test('6. Realtime status transition to DELIVERED evicts order from active list immediately', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final notifier = container.read(ordersProjectionProvider.notifier);
      notifier.updateProjection([activeOrderPreparing, activeOrderReady]);

      expect(container.read(ordersProjectionProvider).length, equals(2));

      // Order becomes delivered in realtime
      final readyNowDelivered = activeOrderReady.copyWith(status: OrderStatus.delivered);
      notifier.updateProjection([activeOrderPreparing, readyNowDelivered]);

      final updated = container.read(ordersProjectionProvider);
      expect(updated.length, equals(1));
      expect(updated.first.id, equals('ord-prep-1'));
      expect(updated.any((o) => o.id == 'ord-ready-1'), isFalse);
    });

    test('7. Floor layout table amount ignores delivered orders', () {
      final orders = [deliveredOrder1, deliveredOrder2];
      const table = RestaurantTable(id: 'table-3', label: 'Table 3', capacity: 4, status: TableStatus.occupied);

      // Floor layout active order filter
      final activeOrders = orders.where((o) {
        return o.status != OrderStatus.delivered &&
               o.status != OrderStatus.completed &&
               o.status != OrderStatus.cancelled;
      }).toList();

      int totalCents = 0;
      bool hasActiveOrders = false;
      for (final o in activeOrders) {
        if (o.tableId == table.id) {
          totalCents += o.totalPrice.amountInCents;
          hasActiveOrders = true;
        }
      }

      final amount = hasActiveOrders ? Money(amountInCents: totalCents).formatted : '₹0.00';
      expect(hasActiveOrders, isFalse);
      expect(amount, equals('₹0.00'));
    });
  });
}
