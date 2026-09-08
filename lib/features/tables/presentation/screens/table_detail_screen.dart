import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../auth/presentation/state/auth_notifier.dart';
import '../../../orders/services/order_action_service.dart';
import '../../../orders/presentation/state/active_order_notifier.dart';
import '../../../orders/presentation/state/orders_projection_provider.dart';
import '../../../orders/providers/orders_providers.dart';
import '../../../orders/domain/entities/order.dart';
import '../../../orders/domain/entities/order_item.dart';
import '../../../../shared/models/money.dart';
import '../../domain/entities/restaurant_table.dart';
import '../state/table_grid_notifier.dart';

class TableDetailScreen extends ConsumerWidget {
  final String tableId;

  const TableDetailScreen({
    super.key,
    required this.tableId,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Watch real-time providers to react immediately when payment completion or orders update
    final projectedOrders = ref.watch(ordersProjectionProvider);
    final liveOrders = ref.watch(liveOrdersProvider).valueOrNull ?? [];

    final activeOrderAsync = ref.watch(activeOrderNotifierProvider(tableId));
    final tableGridStateAsync = ref.watch(tableGridNotifierProvider);
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8F9FA),
      appBar: AppBar(
        backgroundColor: isDark ? const Color(0xFF1E293B) : Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_rounded, color: isDark ? Colors.white54 : const Color(0xFF5D3F3C)),
          onPressed: () => context.pop(),
        ),
        title: tableGridStateAsync.when(
          data: (gridState) {
            final table = gridState.tables.firstWhere(
              (t) => t.id == tableId,
              orElse: () => RestaurantTable(id: tableId, label: tableId, capacity: 4, status: TableStatus.unknown),
            );
            return Text(
              'Table ${table.label}',
              style: GoogleFonts.plusJakartaSans(
                fontSize: 24,
                fontWeight: FontWeight.w700,
                color: const Color(0xFFE31E24),
              ),
            );
          },
          loading: () => const SizedBox(),
          error: (err, stack) => const SizedBox(),
        ),
        actions: const [
          SizedBox(width: 48), // Balancing trailing space
        ],
      ),
      body: tableGridStateAsync.when(
        loading: () => const Center(child: CircularProgressIndicator(color: Color(0xFFE31E24))),
        error: (err, stack) => Center(child: Text('Error loading layout: $err')),
        data: (gridState) {
          final tableIndex = gridState.tables.indexWhere((t) => t.id == tableId);
          if (tableIndex == -1) {
            return Center(child: Text('Table $tableId not found.'));
          }
          final table = gridState.tables[tableIndex];

          // Collect all distinct active orders for this table
          final activeOrdersMap = <String, Order>{};
          for (final o in projectedOrders) {
            if ((o.tableId == tableId || o.tableId.trim() == tableId.trim()) &&
                o.status != OrderStatus.completed &&
                o.status != OrderStatus.cancelled) {
              activeOrdersMap[o.id] = o;
            }
          }
          for (final o in liveOrders) {
            if ((o.tableId == tableId || o.tableId.trim() == tableId.trim()) &&
                o.status != OrderStatus.completed &&
                o.status != OrderStatus.cancelled) {
              activeOrdersMap[o.id] = o;
            }
          }
          final activeTableOrders = activeOrdersMap.values.toList();

          return activeOrderAsync.when(
            loading: () => const Center(child: CircularProgressIndicator(color: Color(0xFFE31E24))),
            error: (err, stack) => Center(child: Text('Error loading active session: $err')),
            data: (order) {
              if (activeTableOrders.isEmpty) {
                return _buildEmptyState(context, ref, table, theme, isDark);
              }
              return _buildActiveSession(context, ref, table, activeTableOrders, isDark);
            },
          );
        },
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context, WidgetRef ref, RestaurantTable table, ThemeData theme, bool isDark) {
    String message = 'Table is available for seating.';
    IconData icon = Icons.table_restaurant_rounded;
    Color iconColor = isDark ? Colors.white24 : const Color(0xFFBFC8D0);

    if (table.status == TableStatus.cleaning) {
      message = 'Table is currently being cleaned.';
      icon = Icons.cleaning_services_rounded;
    } else if (table.status == TableStatus.occupied) {
      message = 'Table is occupied. Waiting for order details...';
      icon = Icons.sensor_occupied_rounded;
      iconColor = const Color(0xFFE31E24).withValues(alpha: 0.5);
    }

    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            icon,
            size: 72,
            color: iconColor,
          ),
          const SizedBox(height: 16),
          Text(
            message,
            style: GoogleFonts.plusJakartaSans(
              fontSize: 16,
              color: isDark ? Colors.white70 : const Color(0xFF5D3F3C),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActiveSession(BuildContext context, WidgetRef ref, RestaurantTable table, List<Order> activeTableOrders, bool isDark) {
    final loggedInStaffId = ref.watch(authNotifierProvider).loggedInStaff?.id;
    final isUnassigned = table.assignedStaffId == null;
    final isAssignedToOther = !isUnassigned && table.assignedStaffId != loggedInStaffId;

    if (isAssignedToOther) {
      return Center(
        child: Text(
          'This table is assigned to another staff member.\nOrder details are hidden.',
          textAlign: TextAlign.center,
          style: GoogleFonts.plusJakartaSans(
            fontSize: 16,
            color: isDark ? Colors.white54 : const Color(0xFF64748B),
          ),
        ),
      );
    }
    // If no active orders exist for this table, show vacant state
    if (activeTableOrders.isEmpty) {
      final theme = Theme.of(context);
      return _buildEmptyState(context, ref, table, theme, isDark);
    }

    return Stack(
      children: [
        Positioned.fill(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24.0),
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 800),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Table Stats Row
                    _buildStatsRow(table, activeTableOrders, isDark),
                    
                    if (isUnassigned)
                      Padding(
                        padding: const EdgeInsets.only(top: 24.0),
                        child: _ClaimTableButton(orderId: activeTableOrders.first.id),
                      ),
                    const SizedBox(height: 32),


                    // Render each order as a bill/receipt
                    ...activeTableOrders.map((order) {
                      final orderIndex = activeTableOrders.indexOf(order) + 1;
                      return _buildOrderBill(ref, order, orderIndex, activeTableOrders, isDark);
                    }),


                    const SizedBox(height: 120), // Bottom padding for actions footer
                  ],
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildStatsRow(RestaurantTable table, List<Order> activeTableOrders, bool isDark) {
    int totalCents = 0;
    for (final o in activeTableOrders) {
      for (final item in o.items) {
        if (item.status != OrderItemStatus.cancelled) {
          totalCents += item.totalPrice.amountInCents;
        }
      }
    }
    final formattedTotal = Money(amountInCents: totalCents).formatted;

    // Elapsed time since first order
    DateTime? earliest;
    for (final o in activeTableOrders) {
      if (earliest == null || o.createdAt.isBefore(earliest)) earliest = o.createdAt;
    }
    String elapsedStr = '-';
    if (earliest != null) {
      final diff = DateTime.now().difference(earliest);
      elapsedStr = diff.inHours >= 1
          ? '${diff.inHours}h ${(diff.inMinutes % 60).toString().padLeft(2, '0')}m'
          : '${diff.inMinutes}m';
    }

    return Row(
      children: [
        Expanded(
          child: _buildStatCard(Icons.timer_rounded, 'Time', elapsedStr, isDark),
        ),
        const SizedBox(width: 12),
        Expanded(
          flex: 2,
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 20),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF1E293B) : Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFFFFDAD6)),
              boxShadow: [
                BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 12, offset: const Offset(0, 4)),
              ],
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.payments_rounded, color: Color(0xFFBA0013), size: 22),
                const SizedBox(width: 10),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'TOTAL',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: const Color(0xFFBA0013),
                        letterSpacing: 1,
                      ),
                    ),
                    Text(
                      formattedTotal,
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 22,
                        fontWeight: FontWeight.w800,
                        color: const Color(0xFFBA0013),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildStatCard(IconData icon, String label, String value, bool isDark) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 12, offset: const Offset(0, 4)),
        ],
      ),
      child: Column(
        children: [
          Icon(icon, color: isDark ? Colors.white54 : const Color(0xFF5D5E61), size: 24),
          const SizedBox(height: 4),
          Text(
            label.toUpperCase(),
            style: GoogleFonts.plusJakartaSans(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: isDark ? Colors.white54 : const Color(0xFF5D5E61),
            ),
          ),
          Text(
            value,
            style: GoogleFonts.plusJakartaSans(
              fontSize: 20,
              fontWeight: FontWeight.w700,
              color: isDark ? Colors.white : const Color(0xFF0F172A),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildOrderBill(WidgetRef ref, Order order, int orderIndex, List<Order> allOrders, bool isDark) {
    final activeItems = order.items.where((i) => i.status != OrderItemStatus.cancelled).toList();
    
    // Calculate totals
    int subtotalCents = 0;
    for (final item in activeItems) {
      subtotalCents += item.totalPrice.amountInCents;
    }
    // GST 5% on food (typical India restaurant)
    final taxCents = (subtotalCents * 0.05).round();
    final grandTotalCents = subtotalCents + taxCents;

    // Status color
    Color statusBg;
    Color statusFg;
    switch (order.status) {
      case OrderStatus.delivered:
        statusBg = const Color(0xFFDCFCE7); statusFg = const Color(0xFF166534);
      case OrderStatus.preparing:
        statusBg = const Color(0xFFFEF3C7); statusFg = const Color(0xFF92400E);
      case OrderStatus.ready:
        statusBg = const Color(0xFFD1FAE5); statusFg = const Color(0xFF065F46);
      case OrderStatus.sent:
        statusBg = const Color(0xFFEFF6FF); statusFg = const Color(0xFF1E40AF);
      default:
        statusBg = const Color(0xFFFFDAD6); statusFg = const Color(0xFF93000A);
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 20),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: isDark ? Colors.white10 : const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Bill Header ──
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8F9FA),
              borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
              border: Border(bottom: BorderSide(color: isDark ? Colors.white10 : const Color(0xFFE2E8F0))),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: const Color(0xFFE31E24).withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    'Order #$orderIndex',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 13,
                      fontWeight: FontWeight.w800,
                      color: const Color(0xFFE31E24),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    order.id.length > 8 ? order.id.substring(0, 8).toUpperCase() : order.id.toUpperCase(),
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 11,
                      color: isDark ? Colors.white38 : const Color(0xFF94A3B8),
                      fontWeight: FontWeight.w600,
                      letterSpacing: 1,
                    ),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: statusBg,
                    borderRadius: BorderRadius.circular(100),
                  ),
                  child: Text(
                    order.status.name.toUpperCase(),
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 10,
                      fontWeight: FontWeight.w800,
                      color: statusFg,
                    ),
                  ),
                ),
              ],
            ),
          ),

          // ── Items ──
          if (activeItems.isEmpty)
            Padding(
              padding: const EdgeInsets.all(20),
              child: Text(
                'No item details available.',
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 13,
                  color: isDark ? Colors.white38 : const Color(0xFF94A3B8),
                ),
              ),
            )
          else ...[
            // Column header
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 6),
              child: Row(
                children: [
                  Expanded(
                    flex: 5,
                    child: Text('ITEM', style: GoogleFonts.plusJakartaSans(fontSize: 10, fontWeight: FontWeight.w700, color: const Color(0xFF94A3B8), letterSpacing: 1)),
                  ),
                  SizedBox(
                    width: 36,
                    child: Text('QTY', style: GoogleFonts.plusJakartaSans(fontSize: 10, fontWeight: FontWeight.w700, color: const Color(0xFF94A3B8), letterSpacing: 1), textAlign: TextAlign.center),
                  ),
                  SizedBox(
                    width: 72,
                    child: Text('PRICE', style: GoogleFonts.plusJakartaSans(fontSize: 10, fontWeight: FontWeight.w700, color: const Color(0xFF94A3B8), letterSpacing: 1), textAlign: TextAlign.right),
                  ),
                  SizedBox(
                    width: 80,
                    child: Text('AMOUNT', style: GoogleFonts.plusJakartaSans(fontSize: 10, fontWeight: FontWeight.w700, color: const Color(0xFF94A3B8), letterSpacing: 1), textAlign: TextAlign.right),
                  ),
                ],
              ),
            ),
            Divider(color: isDark ? Colors.white10 : const Color(0xFFE2E8F0), height: 1),

            // Item rows
            ...activeItems.map((item) => _buildBillItemRow(item, isDark)),

            Divider(color: isDark ? Colors.white10 : const Color(0xFFE2E8F0), height: 1),

            // ── Totals ──
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('Subtotal', style: GoogleFonts.plusJakartaSans(fontSize: 13, color: isDark ? Colors.white70 : const Color(0xFF64748B))),
                  Text(
                    Money(amountInCents: subtotalCents).formatted,
                    style: GoogleFonts.plusJakartaSans(fontSize: 13, fontWeight: FontWeight.w600, color: isDark ? Colors.white : const Color(0xFF0F172A)),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 4),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('GST (5%)', style: GoogleFonts.plusJakartaSans(fontSize: 13, color: isDark ? Colors.white70 : const Color(0xFF64748B))),
                  Text(
                    Money(amountInCents: taxCents).formatted,
                    style: GoogleFonts.plusJakartaSans(fontSize: 13, fontWeight: FontWeight.w600, color: isDark ? Colors.white : const Color(0xFF0F172A)),
                  ),
                ],
              ),
            ),
            Container(
              margin: const EdgeInsets.fromLTRB(16, 8, 16, 16),
              padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 14),
              decoration: BoxDecoration(
                color: const Color(0xFFFEF2F2),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'GRAND TOTAL',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 14,
                      fontWeight: FontWeight.w800,
                      color: const Color(0xFFE31E24),
                      letterSpacing: 0.5,
                    ),
                  ),
                  Text(
                    Money(amountInCents: grandTotalCents).formatted,
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                      color: const Color(0xFFE31E24),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildBillItemRow(OrderItem item, bool isDark) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                flex: 5,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item.product.name,
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: isDark ? Colors.white : const Color(0xFF0F172A),
                      ),
                    ),
                    if (item.selectedModifiers.isNotEmpty)
                      ...item.selectedModifiers.map((m) => Text(
                        '+ ${m.name}',
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 11,
                          color: isDark ? Colors.white38 : const Color(0xFF94A3B8),
                        ),
                      )),
                  ],
                ),
              ),
              SizedBox(
                width: 36,
                child: Text(
                  '${item.quantity}',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: isDark ? Colors.white70 : const Color(0xFF334155),
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
              SizedBox(
                width: 72,
                child: Text(
                  item.unitPrice.formatted,
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 13,
                    color: isDark ? Colors.white54 : const Color(0xFF64748B),
                  ),
                  textAlign: TextAlign.right,
                ),
              ),
              SizedBox(
                width: 80,
                child: Text(
                  item.totalPrice.formatted,
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: isDark ? Colors.white : const Color(0xFF0F172A),
                  ),
                  textAlign: TextAlign.right,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

}


class _ClaimTableButton extends ConsumerStatefulWidget {
  final String orderId;
  const _ClaimTableButton({required this.orderId});
  @override
  ConsumerState<_ClaimTableButton> createState() => _ClaimTableButtonState();
}

class _ClaimTableButtonState extends ConsumerState<_ClaimTableButton> {
  bool _isLoading = false;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton(
        onPressed: _isLoading
            ? null
            : () async {
                final authState = ref.read(authNotifierProvider);
                final staffId = authState.loggedInStaff?.id;
                if (staffId == null) {
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Authentication error: No staff logged in')));
                  return;
                }

                setState(() => _isLoading = true);
                final actionService = ref.read(orderActionServiceProvider);
                try {
                  await actionService.assignWaiter(
                    orderId: widget.orderId,
                    staffId: staffId,
                    idempotencyKey: DateTime.now().millisecondsSinceEpoch.toString(),
                  );
                  if (!context.mounted) return;
                  
                  ref.invalidate(tableGridNotifierProvider);
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Table claimed successfully')));
                  context.go('/tables');
                } catch (e) {
                  if (!context.mounted) return;
                  setState(() => _isLoading = false);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Failed to claim table: $e'),
                      backgroundColor: Colors.red.shade700,
                    ),
                  );
                }
              },
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFFE31E24),
          padding: const EdgeInsets.symmetric(vertical: 16),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          disabledBackgroundColor: const Color(0xFFE31E24).withValues(alpha: 0.5),
        ),
        child: _isLoading
            ? const SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5),
              )
            : Text(
                'CLAIM TABLE',
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: Colors.white,
                ),
              ),
      ),
    );
  }
}
