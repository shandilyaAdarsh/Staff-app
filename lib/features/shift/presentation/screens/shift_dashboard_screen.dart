// lib/features/shift/presentation/screens/shift_dashboard_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/theme/app_colors.dart';

// ─── Inline entities & providers (self-contained) ────────────────────────────

enum ShiftStatus { idle, starting, active, paused, closing, closed, error }
enum SyncState { fresh, stale, replaying, degraded, unknown }

class ShiftMetrics {
  final int activeTableCount;
  final int completedOrderCount;
  final int activeOrderCount;
  final int pendingCallCount;
  final double slaComplianceRate;
  final String staffId;
  final String staffName;
  final DateTime shiftStartedAt;
  final ShiftStatus status;
  final SyncState syncState;

  const ShiftMetrics({
    required this.activeTableCount,
    required this.completedOrderCount,
    required this.activeOrderCount,
    required this.pendingCallCount,
    required this.slaComplianceRate,
    required this.staffId,
    required this.staffName,
    required this.shiftStartedAt,
    this.status = ShiftStatus.active,
    this.syncState = SyncState.fresh,
  });

  Duration get elapsed => DateTime.now().difference(shiftStartedAt);
}

class WorkloadItem {
  final String tableId;
  final String tableLabel;
  final String orderStatus; // 'preparing' | 'ready' | 'pending_payment'
  final DateTime orderStartedAt;
  final int slaTargetMinutes;

  const WorkloadItem({
    required this.tableId,
    required this.tableLabel,
    required this.orderStatus,
    required this.orderStartedAt,
    this.slaTargetMinutes = 20,
  });

  int get elapsedMinutes => DateTime.now().difference(orderStartedAt).inMinutes;
  double get slaProgress => (elapsedMinutes / slaTargetMinutes).clamp(0.0, 1.0);
  bool get isSlaBreached => elapsedMinutes > slaTargetMinutes;
  Color get slaColor {
    if (slaProgress < 0.6) return AppColors.success;
    if (slaProgress < 0.85) return AppColors.warning;
    return AppColors.error;
  }
}

class ColleagueOverload {
  final String staffId;
  final String name;
  final int activeTableCount;
  ColleagueOverload({required this.staffId, required this.name, required this.activeTableCount});
}

// ─── Providers ───────────────────────────────────────────────────────────────

final shiftMetricsProvider = StateProvider<ShiftMetrics>((ref) {
  return ShiftMetrics(
    staffId: 'waiter_001',
    staffName: 'Alex Johnson',
    shiftStartedAt: DateTime.now().subtract(const Duration(hours: 2, minutes: 14)),
    activeTableCount: 3,
    completedOrderCount: 14,
    activeOrderCount: 3,
    pendingCallCount: 1,
    slaComplianceRate: 0.87,
  );
});

final workloadItemsProvider = Provider<List<WorkloadItem>>((ref) {
  final now = DateTime.now();
  return [
    WorkloadItem(tableId: '5', tableLabel: 'Table 5', orderStatus: 'preparing', orderStartedAt: now.subtract(const Duration(minutes: 12))),
    WorkloadItem(tableId: '9', tableLabel: 'Table 9', orderStatus: 'ready', orderStartedAt: now.subtract(const Duration(minutes: 22)), slaTargetMinutes: 20),
    WorkloadItem(tableId: '12', tableLabel: 'Table 12', orderStatus: 'pending_payment', orderStartedAt: now.subtract(const Duration(minutes: 6))),
  ];
});

final colleagueOverloadsProvider = Provider<List<ColleagueOverload>>((ref) {
  return [
    ColleagueOverload(staffId: 's2', name: 'Maria K.', activeTableCount: 7),
  ];
});

// ─── Screen ──────────────────────────────────────────────────────────────────

class ShiftDashboardScreen extends ConsumerStatefulWidget {
  const ShiftDashboardScreen({super.key});

  @override
  ConsumerState<ShiftDashboardScreen> createState() => _ShiftDashboardScreenState();
}

class _ShiftDashboardScreenState extends ConsumerState<ShiftDashboardScreen>
    with SingleTickerProviderStateMixin {
  late final _ticker = createTicker((_) => setState(() {}));

  @override
  void initState() {
    super.initState();
    _ticker.start();
  }

  @override
  void dispose() {
    _ticker.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final metrics = ref.watch(shiftMetricsProvider);
    final workload = ref.watch(workloadItemsProvider);
    final overloads = ref.watch(colleagueOverloadsProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? AppColors.darkBackground : AppColors.lightBackground,
      body: CustomScrollView(
        slivers: [
          _buildSliverHeader(context, metrics, isDark),
          SliverToBoxAdapter(child: _buildMetricsRow(context, metrics, isDark)),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 20, 16, 8),
              child: Text('My Active Workload',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800)),
            ),
          ),
          workload.isEmpty
              ? SliverToBoxAdapter(child: _buildEmptyWorkload(context))
              : SliverList(
                  delegate: SliverChildBuilderDelegate(
                    (ctx, i) => Padding(
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                      child: _WorkloadCard(item: workload[i]),
                    ),
                    childCount: workload.length,
                  ),
                ),
          SliverToBoxAdapter(child: _buildBranchAwareness(context, overloads, metrics, isDark)),
          SliverToBoxAdapter(child: _buildProgressBar(context, metrics, isDark)),
          const SliverToBoxAdapter(child: SizedBox(height: 24)),
        ],
      ),
    );
  }

  Widget _buildSliverHeader(BuildContext context, ShiftMetrics metrics, bool isDark) {
    final elapsed = metrics.elapsed;
    final h = elapsed.inHours.toString().padLeft(2, '0');
    final m = (elapsed.inMinutes % 60).toString().padLeft(2, '0');
    final s = (elapsed.inSeconds % 60).toString().padLeft(2, '0');

    return SliverAppBar(
      expandedHeight: 140,
      pinned: true,
      backgroundColor: isDark ? AppColors.darkSurface : Colors.white,
      elevation: 0,
      flexibleSpace: FlexibleSpaceBar(
        background: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                AppColors.primary.withValues(alpha: 0.95),
                AppColors.secondary.withValues(alpha: 0.85),
              ],
            ),
          ),
          child: SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Shift Dashboard', style: TextStyle(color: Colors.white70, fontSize: 13, fontWeight: FontWeight.w600)),
                          const SizedBox(height: 2),
                          Text(metrics.staffName, style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w900)),
                        ],
                      ),
                      _ShiftStatusBadge(status: metrics.status),
                    ],
                  ),
                  const Spacer(),
                  Row(
                    children: [
                      const Icon(Icons.timer_rounded, color: Colors.white70, size: 18),
                      const SizedBox(width: 6),
                      Text('$h:$m:$s', style: const TextStyle(color: Colors.white, fontSize: 28, fontWeight: FontWeight.w900, letterSpacing: 1.5, fontFeatures: [FontFeature.tabularFigures()])),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
      actions: [
        Padding(
          padding: const EdgeInsets.only(right: 12),
          child: _SyncIndicator(state: metrics.syncState),
        ),
      ],
    );
  }

  Widget _buildMetricsRow(BuildContext context, ShiftMetrics metrics, bool isDark) {
    return SizedBox(
      height: 120,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
        children: [
          _MetricChip(icon: Icons.table_restaurant_rounded, label: 'Tables', value: '${metrics.activeTableCount}', color: AppColors.primary),
          _MetricChip(icon: Icons.check_circle_rounded, label: 'Completed', value: '${metrics.completedOrderCount}', color: AppColors.success),
          _MetricChip(icon: Icons.receipt_long_rounded, label: 'Active Orders', value: '${metrics.activeOrderCount}', color: AppColors.secondary, pulse: metrics.activeOrderCount > 0),
          _MetricChip(icon: Icons.support_agent_rounded, label: 'Pending Calls', value: '${metrics.pendingCallCount}', color: metrics.pendingCallCount > 0 ? AppColors.error : AppColors.success, pulse: metrics.pendingCallCount > 0),
        ],
      ),
    );
  }

  Widget _buildEmptyWorkload(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      child: Center(
        child: Column(children: [
          Icon(Icons.check_circle_outline_rounded, size: 48, color: AppColors.success.withValues(alpha: 0.7)),
          const SizedBox(height: 12),
          const Text('No active tables assigned', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 15)),
          const SizedBox(height: 4),
          Text('Your workload is clear', style: TextStyle(color: Colors.grey[500], fontSize: 13)),
        ]),
      ),
    );
  }

  Widget _buildBranchAwareness(BuildContext context, List<ColleagueOverload> overloads, ShiftMetrics metrics, bool isDark) {
    if (overloads.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
      child: Container(
        decoration: BoxDecoration(
          color: AppColors.warning.withValues(alpha: isDark ? 0.15 : 0.08),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.warning.withValues(alpha: 0.3)),
        ),
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Row(children: [
              Icon(Icons.groups_rounded, size: 18, color: AppColors.warning),
              SizedBox(width: 8),
              Text('Colleague Overload Alert', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 13, color: AppColors.warning)),
            ]),
            const SizedBox(height: 10),
            ...overloads.map((o) => Row(children: [
              const Icon(Icons.person_rounded, size: 16, color: AppColors.warning),
              const SizedBox(width: 6),
              Text('${o.name} — ${o.activeTableCount} active tables', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
              const Spacer(),
              _buildHelperButton(context, o),
            ])),
          ],
        ),
      ),
    );
  }

  Widget _buildHelperButton(BuildContext context, ColleagueOverload o) {
    return TextButton(
      onPressed: () {
        HapticFeedback.lightImpact();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Offer to assist ${o.name}? Notify supervisor.')),
        );
      },
      child: const Text('Assist', style: TextStyle(color: AppColors.primary, fontWeight: FontWeight.w700)),
    );
  }

  Widget _buildProgressBar(BuildContext context, ShiftMetrics metrics, bool isDark) {
    final sla = metrics.slaComplianceRate;
    final slaColor = sla >= 0.9 ? AppColors.success : sla >= 0.7 ? AppColors.warning : AppColors.error;

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
      child: Container(
        decoration: BoxDecoration(
          color: isDark ? AppColors.darkSurface : Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: isDark ? AppColors.darkBorder : AppColors.lightBorder),
        ),
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Shift SLA Performance', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 14)),
            const SizedBox(height: 12),
            Row(
              children: [
                Text('${(sla * 100).toStringAsFixed(0)}%', style: TextStyle(fontSize: 28, fontWeight: FontWeight.w900, color: slaColor)),
                const SizedBox(width: 8),
                Text('compliance', style: TextStyle(color: Colors.grey[500], fontSize: 13)),
              ],
            ),
            const SizedBox(height: 10),
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: LinearProgressIndicator(
                value: sla,
                minHeight: 10,
                backgroundColor: slaColor.withValues(alpha: 0.15),
                valueColor: AlwaysStoppedAnimation<Color>(slaColor),
              ),
            ),
            const SizedBox(height: 8),
            Text('${metrics.completedOrderCount} orders completed this shift', style: TextStyle(color: Colors.grey[500], fontSize: 12)),
          ],
        ),
      ),
    );
  }
}

// ─── Sub-widgets ──────────────────────────────────────────────────────────────

class _ShiftStatusBadge extends StatelessWidget {
  final ShiftStatus status;
  const _ShiftStatusBadge({required this.status});

  @override
  Widget build(BuildContext context) {
    final label = switch (status) {
      ShiftStatus.active => 'ACTIVE',
      ShiftStatus.paused => 'PAUSED',
      ShiftStatus.closing => 'CLOSING',
      _ => 'IDLE',
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.2),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withValues(alpha: 0.4)),
      ),
      child: Text(label, style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w800, letterSpacing: 1)),
    );
  }
}

class _SyncIndicator extends StatelessWidget {
  final SyncState state;
  const _SyncIndicator({required this.state});

  @override
  Widget build(BuildContext context) {
    if (state == SyncState.fresh) return const SizedBox.shrink();
    final (label, color) = switch (state) {
      SyncState.stale => ('Stale', AppColors.warning),
      SyncState.replaying => ('Syncing', AppColors.primary),
      SyncState.degraded => ('Offline', AppColors.error),
      _ => ('...', Colors.grey),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.2),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.5)),
      ),
      child: Text(label, style: TextStyle(color: color, fontSize: 10, fontWeight: FontWeight.w800)),
    );
  }
}

class _MetricChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color color;
  final bool pulse;
  const _MetricChip({required this.icon, required this.label, required this.value, required this.color, this.pulse = false});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      width: 110,
      margin: const EdgeInsets.only(right: 10),
      decoration: BoxDecoration(
        color: color.withValues(alpha: isDark ? 0.12 : 0.08),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withValues(alpha: 0.25)),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, color: color, size: 18),
          const SizedBox(height: 6),
          Text(value, style: TextStyle(color: color, fontSize: 22, fontWeight: FontWeight.w900)),
          Text(label, style: TextStyle(color: color.withValues(alpha: 0.7), fontSize: 10, fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }
}

class _WorkloadCard extends StatelessWidget {
  final WorkloadItem item;
  const _WorkloadCard({required this.item});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final slaColor = item.slaColor;
    final statusIcon = switch (item.orderStatus) {
      'preparing' => Icons.restaurant_rounded,
      'ready' => Icons.delivery_dining_rounded,
      'pending_payment' => Icons.account_balance_wallet_rounded,
      _ => Icons.table_restaurant_rounded,
    };
    final statusLabel = switch (item.orderStatus) {
      'preparing' => 'Preparing',
      'ready' => 'Ready for pickup',
      'pending_payment' => 'Payment pending',
      _ => item.orderStatus,
    };
    final statusColor = switch (item.orderStatus) {
      'preparing' => AppColors.warning,
      'ready' => AppColors.success,
      'pending_payment' => const Color(0xFF8B5CF6),
      _ => AppColors.primary,
    };

    return Container(
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkSurface : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: item.isSlaBreached ? AppColors.error.withValues(alpha: 0.5) : (isDark ? AppColors.darkBorder : AppColors.lightBorder)),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 8, offset: const Offset(0, 2))],
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(color: AppColors.primary.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(10)),
                child: const Icon(Icons.table_restaurant_rounded, color: AppColors.primary, size: 18),
              ),
              const SizedBox(width: 10),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(item.tableLabel, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15)),
                  const SizedBox(height: 2),
                  Row(children: [
                    Icon(statusIcon, size: 13, color: statusColor),
                    const SizedBox(width: 4),
                    Text(statusLabel, style: TextStyle(fontSize: 12, color: statusColor, fontWeight: FontWeight.w600)),
                  ]),
                ],
              ),
              const Spacer(),
              Text('${item.elapsedMinutes}m', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900, color: slaColor)),
            ],
          ),
          const SizedBox(height: 12),
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: LinearProgressIndicator(
              value: item.slaProgress,
              minHeight: 6,
              backgroundColor: slaColor.withValues(alpha: 0.15),
              valueColor: AlwaysStoppedAnimation<Color>(slaColor),
            ),
          ),
          if (item.isSlaBreached) ...[
            const SizedBox(height: 6),
            Text('SLA breached — ${item.elapsedMinutes - item.slaTargetMinutes}m over target',
                style: const TextStyle(color: AppColors.error, fontSize: 11, fontWeight: FontWeight.w700)),
          ],
        ],
      ),
    );
  }
}
