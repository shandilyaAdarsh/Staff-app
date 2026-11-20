// lib/features/orders/presentation/screens/order_details_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../../core/theme/app_colors.dart';
import '../../domain/entities/order.dart';
import '../../domain/entities/order_item.dart';
import '../../providers/orders_providers.dart';
import '../state/active_order_notifier.dart';
import '../state/orders_projection_provider.dart';
import '../../../tables/presentation/state/table_grid_notifier.dart';

class OrderDetailsScreen extends ConsumerWidget {
  final String orderId;
  const OrderDetailsScreen({super.key, required this.orderId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final repository = ref.watch(ordersRepositoryProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return StreamBuilder<Order?>(
      stream: repository.watchOrderById(orderId),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Scaffold(
            backgroundColor: isDark ? AppColors.darkBackground : AppColors.lightBackground,
            body: const Center(child: CircularProgressIndicator(color: AppColors.primary)),
          );
        }

        // Primary source: local cache stream
        // Fallback: in-memory projection (populated from WebSocket events)
        Order? order = snapshot.data;
        if (order == null) {
          final projection = ref.read(ordersProjectionProvider);
          final idx = projection.indexWhere((o) => o.id == orderId);
          if (idx != -1) order = projection[idx];
        }

        if (order == null) {
          return Scaffold(
            backgroundColor: isDark ? AppColors.darkBackground : AppColors.lightBackground,
            appBar: AppBar(
              backgroundColor: isDark ? AppColors.darkSurface : AppColors.lightSurface,
              foregroundColor: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
              elevation: 0,
              title: const Text('Order Details'),
              leading: IconButton(
                icon: const Icon(Icons.arrow_back),
                onPressed: () {
                  if (context.canPop()) {
                    context.pop();
                  } else {
                    context.go('/tables');
                  }
                },
              ),
            ),
            body: Center(
              child: Text(
                'Order not found.',
                style: TextStyle(
                  color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                ),
              ),
            ),
          );
        }

        return Consumer(
          builder: (context, ref, _) {
            // Watch projection so UI updates when WebSocket pushes new data
            final projection = ref.watch(ordersProjectionProvider);
            final projIdx = projection.indexWhere((o) => o.id == orderId);
            final liveOrder = projIdx != -1 ? projection[projIdx] : order!;

            final tablesAsync = ref.watch(tableGridNotifierProvider);
            final tableLabel = tablesAsync.valueOrNull?.tables
                    .where((t) => t.id == liveOrder.tableId)
                    .firstOrNull
                    ?.label ??
                'Table ${liveOrder.tableId.substring(0, 4).toUpperCase()}';

            return _OrderDetailsContent(
              order: liveOrder,
              tableLabel: tableLabel,
            );
          },
        );
      },
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Main content widget
// ─────────────────────────────────────────────────────────────────────────────

class _OrderDetailsContent extends ConsumerWidget {
  final Order order;
  final String tableLabel;
  const _OrderDetailsContent({required this.order, required this.tableLabel});

  // ── Status config ──────────────────────────────────────────────────────────

  Color _statusColor(OrderStatus s) => switch (s) {
        OrderStatus.draft => const Color(0xFF64748B),
        OrderStatus.sent => const Color(0xFF3B82F6),
        OrderStatus.preparing => const Color(0xFFF59E0B),
        OrderStatus.ready => const Color(0xFF10B981),
        OrderStatus.delivered => const Color(0xFF8B5CF6),
        OrderStatus.completed => const Color(0xFF22C55E),
        OrderStatus.cancelled => const Color(0xFFEF4444),
      };

  String _statusLabel(OrderStatus s) => switch (s) {
        OrderStatus.draft => 'Draft',
        OrderStatus.sent => 'Sent to KDS',
        OrderStatus.preparing => 'Preparing',
        OrderStatus.ready => 'Ready',
        OrderStatus.delivered => 'Delivered',
        OrderStatus.completed => 'Completed',
        OrderStatus.cancelled => 'Cancelled',
      };

  IconData _statusIcon(OrderStatus s) => switch (s) {
        OrderStatus.draft => Icons.edit_note_rounded,
        OrderStatus.sent => Icons.send_rounded,
        OrderStatus.preparing => Icons.restaurant_rounded,
        OrderStatus.ready => Icons.done_all_rounded,
        OrderStatus.delivered => Icons.delivery_dining_rounded,
        OrderStatus.completed => Icons.check_circle_rounded,
        OrderStatus.cancelled => Icons.cancel_rounded,
      };

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final orderNumber = order.id.substring(0, 8).toUpperCase();
    final statusColor = _statusColor(order.status);

    final textPrimary = isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary;
    final textSecondary = isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary;

    return Scaffold(
      backgroundColor: isDark ? AppColors.darkBackground : AppColors.lightBackground,
      body: CustomScrollView(
        slivers: [
          // ── Clean Minimal Header ─────────────────────────────────────────
          SliverAppBar(
            pinned: true,
            expandedHeight: 120,
            backgroundColor: isDark ? AppColors.darkSurface : AppColors.lightSurface,
            surfaceTintColor: Colors.transparent,
            elevation: 0,
            leading: IconButton(
              onPressed: () {
                if (context.canPop()) {
                  context.pop();
                } else {
                  context.go('/tables');
                }
              },
              icon: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: isDark ? AppColors.darkSurfaceCard : AppColors.lightSurfaceCard,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: isDark ? AppColors.darkBorder : AppColors.lightBorder),
                ),
                child: Icon(
                  Icons.arrow_back_ios_new_rounded,
                  size: 14,
                  color: textPrimary,
                ),
              ),
            ),
            flexibleSpace: FlexibleSpaceBar(
              background: Container(
                decoration: BoxDecoration(
                  color: isDark ? AppColors.darkSurface : AppColors.lightSurface,
                  border: Border(
                    bottom: BorderSide(
                      color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
                      width: 1,
                    ),
                  ),
                ),
                child: SafeArea(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(60, 10, 16, 12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    tableLabel,
                                    style: GoogleFonts.inter(
                                      color: textPrimary,
                                      fontSize: 22,
                                      fontWeight: FontWeight.w900,
                                    ),
                                  ),
                                  Text(
                                    'ORD-$orderNumber',
                                    style: GoogleFonts.inter(
                                      color: textSecondary,
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600,
                                      letterSpacing: 0.5,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            // Live status badge
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                              decoration: BoxDecoration(
                                color: statusColor.withValues(alpha: 0.12),
                                borderRadius: BorderRadius.circular(20),
                                border: Border.all(color: statusColor.withValues(alpha: 0.3)),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(_statusIcon(order.status), color: statusColor, size: 14),
                                  const SizedBox(width: 5),
                                  Text(
                                    _statusLabel(order.status),
                                    style: GoogleFonts.inter(
                                      color: statusColor,
                                      fontSize: 12,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        // KDS sync indicator
                        Row(
                          children: [
                            Container(
                              width: 7,
                              height: 7,
                              decoration: const BoxDecoration(
                                color: Color(0xFF22C55E),
                                shape: BoxShape.circle,
                              ),
                            ),
                            const SizedBox(width: 5),
                            Text(
                              'KDS Synced',
                              style: GoogleFonts.inter(
                                color: textSecondary,
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),

          // ── Body cards ────────────────────────────────────────────────────
          SliverPadding(
            padding: const EdgeInsets.all(16),
            sliver: SliverList(
              delegate: SliverChildListDelegate([
                _buildStatusTimeline(context, isDark),
                const SizedBox(height: 14),
                _buildOrderSummaryRow(context, isDark),
                const SizedBox(height: 14),
                _buildWaiterCard(context, isDark),
                const SizedBox(height: 14),
                _buildItemsCard(context, ref, isDark),
                const SizedBox(height: 14),
                if (order.cancelLogs.isNotEmpty) ...[
                  const SizedBox(height: 14),
                  _buildCancelLogsCard(context, isDark),
                ],
                if (order.status != OrderStatus.completed && order.status != OrderStatus.cancelled) ...[
                  const SizedBox(height: 14),
                  SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: ElevatedButton.icon(
                      onPressed: () async {
                        await ref.read(activeOrderNotifierProvider(order.tableId).notifier).markOrderServed(order.id);
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Order marked as SERVED & Completed!'),
                              backgroundColor: AppColors.success,
                            ),
                          );
                          Navigator.of(context).pop();
                        }
                      },
                      icon: const Icon(Icons.check_circle_rounded, color: Colors.white, size: 20),
                      label: Text(
                        'Mark Served & Complete Order',
                        style: GoogleFonts.inter(fontSize: 15, fontWeight: FontWeight.w800, color: Colors.white),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.success,
                        foregroundColor: Colors.white,
                        elevation: 0,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      ),
                    ),
                  ),
                ],
                const SizedBox(height: 32),
              ]),
            ),
          ),
        ],
      ),
    );
  }

  // ── Status timeline ────────────────────────────────────────────────────────

  Widget _buildStatusTimeline(BuildContext context, bool isDark) {
    final stages = [
      OrderStatus.draft,
      OrderStatus.sent,
      OrderStatus.preparing,
      OrderStatus.ready,
      OrderStatus.completed,
    ];
    final currentIdx = stages.indexOf(order.status);
    final textPrimary = isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary;
    final textSecondary = isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary;
    final inactiveBorder = isDark ? AppColors.darkBorder : AppColors.lightBorder;
    final inactiveBg = isDark ? AppColors.darkSurfaceCard : AppColors.lightSurfaceCard;

    return _Card(
      isDark: isDark,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _SectionTitle(title: 'Order Flow', icon: Icons.timeline_rounded, isDark: isDark),
          const SizedBox(height: 16),
          Row(
            children: List.generate(stages.length, (i) {
              final isDone = i <= currentIdx;
              final isActive = i == currentIdx;
              final color = _statusColor(stages[i]);
              final label = switch (stages[i]) {
                OrderStatus.draft => 'Draft',
                OrderStatus.sent => 'KDS',
                OrderStatus.preparing => 'Cooking',
                OrderStatus.ready => 'Ready',
                _ => 'Done',
              };

              return Expanded(
                child: Row(
                  children: [
                    if (i > 0)
                      Expanded(
                        child: Container(
                          height: 2,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(2),
                            color: isDone ? color : inactiveBorder,
                          ),
                        ),
                      ),
                    Column(
                      children: [
                        AnimatedContainer(
                          duration: const Duration(milliseconds: 300),
                          width: isActive ? 32 : 26,
                          height: isActive ? 32 : 26,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: isDone ? color : inactiveBg,
                            border: Border.all(
                              color: isActive ? color : (isDone ? color : inactiveBorder),
                              width: isActive ? 2 : 1,
                            ),
                          ),
                          child: Center(
                            child: isDone && !isActive
                                ? const Icon(Icons.check_rounded, size: 14, color: Colors.white)
                                : Icon(
                                    _statusIcon(stages[i]),
                                    size: 13,
                                    color: isDone ? Colors.white : textSecondary,
                                  ),
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          label,
                          style: GoogleFonts.inter(
                            fontSize: 10,
                            fontWeight: isActive ? FontWeight.w800 : FontWeight.w500,
                            color: isActive ? color : (isDone ? textPrimary : textSecondary),
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                    if (i < stages.length - 1) const Expanded(child: SizedBox()),
                  ],
                ),
              );
            }),
          ),
        ],
      ),
    );
  }

  // ── Order summary row: total / items / time ────────────────────────────────

  Widget _buildOrderSummaryRow(BuildContext context, bool isDark) {
    final elapsed = DateTime.now().difference(order.createdAt);
    final elapsedStr = elapsed.inMinutes < 60
        ? '${elapsed.inMinutes}m ago'
        : '${elapsed.inHours}h ${elapsed.inMinutes % 60}m ago';
    final activeItems = order.items.where((i) => i.status != OrderItemStatus.cancelled).length;

    return Row(
      children: [
        Expanded(
          child: _StatCard(
            icon: Icons.receipt_long_rounded,
            label: 'Total',
            value: order.totalPrice.formatted,
            valueColor: AppColors.primary,
            isDark: isDark,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _StatCard(
            icon: Icons.shopping_bag_outlined,
            label: 'Items',
            value: '$activeItems',
            isDark: isDark,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _StatCard(
            icon: Icons.schedule_rounded,
            label: 'Age',
            value: elapsedStr,
            isDark: isDark,
          ),
        ),
      ],
    );
  }

  // ── Waiter card ────────────────────────────────────────────────────────────

  Widget _buildWaiterCard(BuildContext context, bool isDark) {
    final name = order.waiterName.isNotEmpty ? order.waiterName : 'Unassigned';
    final initials = name.trim().split(' ').take(2).map((w) => w.isNotEmpty ? w[0] : '').join().toUpperCase();
    final textPrimary = isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary;
    final textSecondary = isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary;

    return _Card(
      isDark: isDark,
      child: Row(
        children: [
          // Clean avatar with initials
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.primary.withValues(alpha: 0.2)),
            ),
            child: Center(
              child: Text(
                initials.isEmpty ? '?' : initials,
                style: GoogleFonts.inter(
                  color: AppColors.primary,
                  fontWeight: FontWeight.w800,
                  fontSize: 16,
                ),
              ),
            ),
          ),
          const SizedBox(width: 14),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Assigned Waiter',
                style: GoogleFonts.inter(
                  color: textSecondary,
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0.5,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                name,
                style: GoogleFonts.inter(
                  color: textPrimary,
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          const Spacer(),
          // Status badge
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              color: AppColors.success.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: AppColors.success.withValues(alpha: 0.3)),
            ),
            child: Row(
              children: [
                const Icon(Icons.circle, color: AppColors.success, size: 7),
                const SizedBox(width: 5),
                Text(
                  'Active',
                  style: GoogleFonts.inter(
                    color: AppColors.success,
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ── Items list ─────────────────────────────────────────────────────────────

  Widget _buildItemsCard(BuildContext context, WidgetRef ref, bool isDark) {
    final groupedItems = <int, List<OrderItem>>{};
    for (final item in order.items) {
      groupedItems.putIfAbsent(item.seatNumber, () => []).add(item);
    }
    final sortedSeats = groupedItems.keys.toList()..sort();
    final textSecondary = isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary;
    final dividerColor = isDark ? AppColors.darkBorder : AppColors.lightBorder;

    return _Card(
      isDark: isDark,
      padding: EdgeInsets.zero,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 12),
            child: Row(
              children: [
                _SectionTitle(title: 'Order Items', icon: Icons.restaurant_menu_rounded, isDark: isDark),
                const Spacer(),
                Text(
                  order.totalPrice.formatted,
                  style: GoogleFonts.inter(
                    color: AppColors.primary,
                    fontWeight: FontWeight.w900,
                    fontSize: 16,
                  ),
                ),
              ],
            ),
          ),
          Divider(color: dividerColor, height: 1),

          if (order.items.isEmpty)
            Padding(
              padding: const EdgeInsets.all(24),
              child: Center(
                child: Text(
                  'No items in this order.',
                  style: GoogleFonts.inter(color: textSecondary),
                ),
              ),
            )
          else
            ...sortedSeats.map((seat) {
              final seatItems = groupedItems[seat]!;
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Seat header
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
                    child: Row(
                      children: [
                        Icon(Icons.chair_rounded, size: 13, color: textSecondary),
                        const SizedBox(width: 5),
                        Text(
                          'Seat $seat',
                          style: GoogleFonts.inter(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: textSecondary,
                            letterSpacing: 0.8,
                          ),
                        ),
                      ],
                    ),
                  ),
                  ...seatItems.map((item) => _buildItemRow(context, ref, item, isDark)),
                ],
              );
            }),

          const SizedBox(height: 8),
        ],
      ),
    );
  }

  Widget _buildItemRow(BuildContext context, WidgetRef ref, OrderItem item, bool isDark) {
    final isCancelled = item.status == OrderItemStatus.cancelled;
    final textPrimary = isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary;
    final textSecondary = isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary;
    final rowBg = isDark ? AppColors.darkSurfaceCard : AppColors.lightSurfaceCard;
    final rowBorder = isDark ? AppColors.darkBorder : AppColors.lightBorder;

    final itemStatusColor = switch (item.status) {
      OrderItemStatus.queued => const Color(0xFF64748B),
      OrderItemStatus.preparing => AppColors.warning,
      OrderItemStatus.ready => AppColors.statusReady,
      OrderItemStatus.served => const Color(0xFF8B5CF6),
      OrderItemStatus.cancelled => AppColors.error,
    };

    return Container(
      margin: const EdgeInsets.fromLTRB(12, 3, 12, 3),
      decoration: BoxDecoration(
        color: isCancelled ? (isDark ? Colors.black12 : Colors.grey.shade100) : rowBg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: rowBorder),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        child: Row(
          children: [
            // Qty badge
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: isCancelled
                    ? (isDark ? Colors.white10 : Colors.black12)
                    : AppColors.primary.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(8),
              ),
              alignment: Alignment.center,
              child: Text(
                '${item.quantity}',
                style: GoogleFonts.inter(
                  fontSize: 13,
                  fontWeight: FontWeight.w900,
                  color: isCancelled ? textSecondary : AppColors.primary,
                ),
              ),
            ),
            const SizedBox(width: 12),

            // Name + modifiers + status
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    item.product.name,
                    style: GoogleFonts.inter(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: isCancelled ? textSecondary : textPrimary,
                      decoration: isCancelled ? TextDecoration.lineThrough : null,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (item.selectedModifiers.isNotEmpty) ...[
                    const SizedBox(height: 2),
                    Text(
                      item.selectedModifiers.map((m) => m.name).join(', '),
                      style: GoogleFonts.inter(
                        fontSize: 11,
                        color: textSecondary,
                        decoration: isCancelled ? TextDecoration.lineThrough : null,
                      ),
                    ),
                  ],
                  const SizedBox(height: 4),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                    decoration: BoxDecoration(
                      color: itemStatusColor.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(5),
                    ),
                    child: Text(
                      item.status.name.toUpperCase(),
                      style: GoogleFonts.inter(
                        fontSize: 9,
                        fontWeight: FontWeight.w800,
                        color: itemStatusColor,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // Price + cancel button
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  item.totalPrice.formatted,
                  style: GoogleFonts.inter(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: isCancelled ? textSecondary : textPrimary,
                    decoration: isCancelled ? TextDecoration.lineThrough : null,
                  ),
                ),
                if (!isCancelled) ...[
                  const SizedBox(height: 6),
                  GestureDetector(
                    onTap: () => _showCancelItemDialog(context, ref, item),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: AppColors.error.withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(color: AppColors.error.withValues(alpha: 0.3)),
                      ),
                      child: Text(
                        'Cancel',
                        style: GoogleFonts.inter(
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          color: AppColors.error,
                        ),
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _showCancelItemDialog(BuildContext context, WidgetRef ref, OrderItem item) {
    final controller = TextEditingController();
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textPrimary = isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary;
    final textSecondary = isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary;
    final cardBg = isDark ? AppColors.darkSurface : AppColors.lightSurface;
    final borderCol = isDark ? AppColors.darkBorder : AppColors.lightBorder;

    HapticFeedback.lightImpact();
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom),
        child: Container(
          decoration: BoxDecoration(
            color: cardBg,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          ),
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: borderCol,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 20),
              Text(
                'Cancel Item',
                style: GoogleFonts.inter(fontSize: 18, fontWeight: FontWeight.w800, color: textPrimary),
              ),
              const SizedBox(height: 4),
              Text(
                item.product.name,
                style: GoogleFonts.inter(fontSize: 14, color: textSecondary),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: controller,
                autofocus: true,
                style: TextStyle(color: textPrimary),
                decoration: InputDecoration(
                  hintText: 'Reason (e.g. Guest changed mind)',
                  hintStyle: TextStyle(color: textSecondary),
                  filled: true,
                  fillColor: isDark ? AppColors.darkSurfaceCard : AppColors.lightSurfaceCard,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: borderCol),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: AppColors.error),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.pop(ctx),
                      style: OutlinedButton.styleFrom(
                        side: BorderSide(color: borderCol),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                      ),
                      child: Text('Back', style: GoogleFonts.inter(color: textSecondary, fontWeight: FontWeight.w600)),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () {
                        final reason = controller.text.trim();
                        if (reason.isNotEmpty) {
                          ref.read(activeOrderNotifierProvider(order.tableId).notifier).cancelItem(item.id, reason);
                          Navigator.pop(ctx);
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text('${item.product.name} cancelled'),
                              backgroundColor: AppColors.error,
                              behavior: SnackBarBehavior.floating,
                            ),
                          );
                        }
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.error,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        elevation: 0,
                      ),
                      child: Text('Confirm Cancel', style: GoogleFonts.inter(fontWeight: FontWeight.w700)),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ── Cancel logs ────────────────────────────────────────────────────────────

  Widget _buildCancelLogsCard(BuildContext context, bool isDark) {
    final textSecondary = isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary;
    return _Card(
      isDark: isDark,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _SectionTitle(title: 'Cancellation Log', icon: Icons.assignment_late_rounded, isDark: isDark),
          const SizedBox(height: 12),
          ...order.cancelLogs.map(
            (log) => Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 6,
                    height: 6,
                    margin: const EdgeInsets.only(top: 5, right: 10),
                    decoration: const BoxDecoration(color: AppColors.error, shape: BoxShape.circle),
                  ),
                  Expanded(
                    child: Text(
                      log,
                      style: GoogleFonts.inter(fontSize: 13, color: textSecondary, fontWeight: FontWeight.w500),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Reusable sub-widgets
// ─────────────────────────────────────────────────────────────────────────────

class _Card extends StatelessWidget {
  final Widget child;
  final bool isDark;
  final EdgeInsetsGeometry? padding;
  const _Card({required this.child, required this.isDark, this.padding});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkSurface : AppColors.lightSurface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: isDark ? AppColors.darkBorder : AppColors.lightBorder),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.04),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Padding(
        padding: padding ?? const EdgeInsets.all(16),
        child: child,
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  final String title;
  final IconData icon;
  final bool isDark;
  const _SectionTitle({required this.title, required this.icon, required this.isDark});

  @override
  Widget build(BuildContext context) {
    final textPrimary = isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary;
    return Row(
      children: [
        Icon(icon, size: 16, color: AppColors.primary),
        const SizedBox(width: 8),
        Text(
          title,
          style: GoogleFonts.inter(fontSize: 15, fontWeight: FontWeight.w800, color: textPrimary),
        ),
      ],
    );
  }
}

class _StatCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color? valueColor;
  final bool isDark;
  const _StatCard({
    required this.icon,
    required this.label,
    required this.value,
    this.valueColor,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    final textPrimary = isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary;
    final textSecondary = isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary;
    final cardBg = isDark ? AppColors.darkSurface : AppColors.lightSurface;
    final cardBorder = isDark ? AppColors.darkBorder : AppColors.lightBorder;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: cardBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 16, color: valueColor ?? textSecondary),
          const SizedBox(height: 8),
          Text(
            value,
            style: GoogleFonts.inter(
              fontSize: 15,
              fontWeight: FontWeight.w800,
              color: valueColor ?? textPrimary,
            ),
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: GoogleFonts.inter(
              fontSize: 11,
              color: textSecondary,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}
