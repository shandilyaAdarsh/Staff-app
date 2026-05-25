// lib/features/realtime/presentation/screens/realtime_status_screen.dart

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';

import '../state/realtime_providers.dart';
import '../../../../core/network/realtime_sync_manager.dart';

// ---------------------------------------------------------------------------
// Model for timeline events
// ---------------------------------------------------------------------------

class _TimelineEvent {
  final String label;
  final String timeAgo;
  final IconData icon;
  final Color color;

  const _TimelineEvent({
    required this.label,
    required this.timeAgo,
    required this.icon,
    required this.color,
  });
}

// ---------------------------------------------------------------------------
// RealtimeStatusScreen
// ---------------------------------------------------------------------------

class RealtimeStatusScreen extends ConsumerWidget {
  const RealtimeStatusScreen({super.key});

  static const _timeline = [
    _TimelineEvent(
      label: 'Connected to server',
      timeAgo: '2 h ago',
      icon: Icons.check_circle_rounded,
      color: AppColors.success,
    ),
    _TimelineEvent(
      label: 'Connection lost (network drop)',
      timeAgo: '8 min ago',
      icon: Icons.cancel_rounded,
      color: AppColors.error,
    ),
    _TimelineEvent(
      label: 'Reconnected successfully',
      timeAgo: '7 min ago',
      icon: Icons.refresh_rounded,
      color: AppColors.success,
    ),
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final realtimeState = ref.watch(realtimeStateProvider);
    final connectionState = realtimeState.connectionState.name;
    final replayProgress = realtimeState.replayProgress ?? 0.0;
    final pendingOps = ref.watch(pendingOpsCountProvider);
    final failedOps = ref.watch(failedOpsCountProvider);

    final isDark = Theme.of(context).brightness == Brightness.dark;
    final surfaceColor =
        isDark ? AppColors.darkSurface : AppColors.lightSurface;
    final borderColor =
        isDark ? AppColors.darkBorder : AppColors.lightBorder;
    final textPrimary =
        isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary;
    final textSecondary =
        isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary;

    return Scaffold(
      backgroundColor:
          isDark ? AppColors.darkBackground : AppColors.lightBackground,
      appBar: AppBar(
        title: Text(
          'Realtime Status',
          style: AppTextStyles.h3.copyWith(color: textPrimary),
        ),
        centerTitle: false,
        backgroundColor:
            isDark ? AppColors.darkSurface : AppColors.lightSurface,
        elevation: 0,
        scrolledUnderElevation: 0,
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Divider(height: 1, color: borderColor),
        ),
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios_new_rounded, color: textPrimary),
          onPressed: () => context.pop(),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
        children: [
          // ── Status Card ─────────────────────────────────────────────────
          _StatusCard(
            connectionState: connectionState,
            surfaceColor: surfaceColor,
            borderColor: borderColor,
            textPrimary: textPrimary,
            textSecondary: textSecondary,
          ),

          // ── Replay progress bar ──────────────────────────────────────────
          if (connectionState == 'replaying') ...[
            const SizedBox(height: 8),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Replay progress',
                    style: AppTextStyles.bodySmall
                        .copyWith(color: textSecondary),
                  ),
                  const SizedBox(height: 6),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(
                      value: replayProgress,
                      minHeight: 6,
                      backgroundColor: borderColor,
                      valueColor: const AlwaysStoppedAnimation<Color>(
                          Color(0xFF3D8EF0)),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${(replayProgress * 100).toStringAsFixed(0)}% complete',
                    style: AppTextStyles.caption
                        .copyWith(color: textSecondary),
                  ),
                ],
              ),
            ),
          ],

          const SizedBox(height: 24),

          // ── Connection Timeline ──────────────────────────────────────────
          _SectionHeader(
            title: 'Connection Timeline',
            textPrimary: textPrimary,
          ),
          const SizedBox(height: 12),
          _TimelineSection(
            events: _timeline,
            surfaceColor: surfaceColor,
            borderColor: borderColor,
            textPrimary: textPrimary,
            textSecondary: textSecondary,
          ),

          const SizedBox(height: 24),

          // ── Sync Queue KPIs ──────────────────────────────────────────────
          _SectionHeader(
            title: 'Sync Queue',
            textPrimary: textPrimary,
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _KpiChip(
                  label: 'Pending Ops',
                  value: '$pendingOps',
                  color: AppColors.warning,
                  icon: Icons.pending_rounded,
                  surfaceColor: surfaceColor,
                  borderColor: borderColor,
                  textPrimary: textPrimary,
                  textSecondary: textSecondary,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _KpiChip(
                  label: 'Failed Ops',
                  value: '$failedOps',
                  color: AppColors.error,
                  icon: Icons.error_rounded,
                  surfaceColor: surfaceColor,
                  borderColor: borderColor,
                  textPrimary: textPrimary,
                  textSecondary: textSecondary,
                ),
              ),
            ],
          ),

          const SizedBox(height: 24),

          // ── Quick Actions ────────────────────────────────────────────────
          _SectionHeader(
            title: 'Quick Actions',
            textPrimary: textPrimary,
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _ActionButton(
                  label: 'Force Reconnect',
                  icon: Icons.refresh_rounded,
                  color: AppColors.primary,
                  onPressed: () {
                    HapticFeedback.mediumImpact();
                    ref.read(realtimeSyncManagerProvider).connectLocal();
                    ref.read(realtimeStateProvider.notifier).simulateReconnect();
                  },
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _ActionButton(
                  label: 'View Sync Queue',
                  icon: Icons.sync_alt_rounded,
                  color: AppColors.secondary,
                  onPressed: () {
                    HapticFeedback.selectionClick();
                    context.push('/realtime/sync-queue');
                  },
                ),
              ),
            ],
          ),

          const SizedBox(height: 32),

          // ── Simulation Panel ─────────────────────────────────────────────
          _SimulationPanel(
            surfaceColor: surfaceColor,
            borderColor: borderColor,
            textPrimary: textPrimary,
            textSecondary: textSecondary,
          ),

          const SizedBox(height: 32),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Status Card
// ---------------------------------------------------------------------------

class _StatusCard extends StatelessWidget {
  final String connectionState;
  final Color surfaceColor;
  final Color borderColor;
  final Color textPrimary;
  final Color textSecondary;

  const _StatusCard({
    required this.connectionState,
    required this.surfaceColor,
    required this.borderColor,
    required this.textPrimary,
    required this.textSecondary,
  });

  _StatusConfig get config {
    switch (connectionState) {
      case 'connected':
        return const _StatusConfig(
          icon: Icons.check_circle_rounded,
          label: 'Fully Operational',
          color: AppColors.success,
          subtitle: 'All systems nominal. Real-time updates active.',
          showSpinner: false,
        );
      case 'reconnecting':
        return const _StatusConfig(
          icon: Icons.sync_rounded,
          label: 'Reconnecting...',
          color: Color(0xFFF59E0B),
          subtitle: 'Attempting to re-establish connection.',
          showSpinner: true,
        );
      case 'replaying':
        return const _StatusConfig(
          icon: Icons.history_rounded,
          label: 'Syncing missed events',
          color: Color(0xFF3D8EF0),
          subtitle: 'Replaying missed events to restore floor state.',
          showSpinner: true,
        );
      case 'degraded':
        return const _StatusConfig(
          icon: Icons.warning_rounded,
          label: 'Offline Mode',
          color: AppColors.warning,
          subtitle: 'Connection degraded. Some updates may be delayed.',
          showSpinner: false,
        );
      case 'critical':
        return const _StatusConfig(
          icon: Icons.dangerous_rounded,
          label: 'Recovery Required',
          color: AppColors.error,
          subtitle: 'Unable to reach server. Manual intervention needed.',
          showSpinner: false,
        );
      default:
        return const _StatusConfig(
          icon: Icons.help_outline_rounded,
          label: 'Unknown',
          color: AppColors.darkTextSecondary,
          subtitle: 'Connection state unknown.',
          showSpinner: false,
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    final cfg = config;
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: surfaceColor,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: cfg.color.withValues(alpha: 0.4), width: 1.5),
        boxShadow: [
          BoxShadow(
            color: cfg.color.withValues(alpha: 0.08),
            blurRadius: 24,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        children: [
          // Icon / spinner
          if (cfg.showSpinner)
            SizedBox(
              width: 64,
              height: 64,
              child: CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(cfg.color),
                strokeWidth: 3.5,
              ),
            )
          else
            Icon(cfg.icon, color: cfg.color, size: 64),
          const SizedBox(height: 16),
          Text(
            cfg.label,
            style: AppTextStyles.h2.copyWith(
              color: cfg.color,
              fontWeight: FontWeight.w800,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          Text(
            cfg.subtitle,
            style: AppTextStyles.bodyMedium.copyWith(color: textSecondary),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 12),
          // Status pill
          Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
            decoration: BoxDecoration(
              color: cfg.color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(100),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(
                    color: cfg.color,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  connectionState.toUpperCase(),
                  style: AppTextStyles.caption.copyWith(
                    color: cfg.color,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 1.2,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _StatusConfig {
  final IconData icon;
  final String label;
  final Color color;
  final String subtitle;
  final bool showSpinner;

  const _StatusConfig({
    required this.icon,
    required this.label,
    required this.color,
    required this.subtitle,
    required this.showSpinner,
  });
}

// ---------------------------------------------------------------------------
// Timeline Section
// ---------------------------------------------------------------------------

class _TimelineSection extends StatelessWidget {
  final List<_TimelineEvent> events;
  final Color surfaceColor;
  final Color borderColor;
  final Color textPrimary;
  final Color textSecondary;

  const _TimelineSection({
    required this.events,
    required this.surfaceColor,
    required this.borderColor,
    required this.textPrimary,
    required this.textSecondary,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: surfaceColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: borderColor),
      ),
      child: Column(
        children: List.generate(events.length, (i) {
          final event = events[i];
          final isLast = i == events.length - 1;
          return _TimelineItem(
            event: event,
            isLast: isLast,
            borderColor: borderColor,
            textPrimary: textPrimary,
            textSecondary: textSecondary,
          );
        }),
      ),
    );
  }
}

class _TimelineItem extends StatelessWidget {
  final _TimelineEvent event;
  final bool isLast;
  final Color borderColor;
  final Color textPrimary;
  final Color textSecondary;

  const _TimelineItem({
    required this.event,
    required this.isLast,
    required this.borderColor,
    required this.textPrimary,
    required this.textSecondary,
  });

  @override
  Widget build(BuildContext context) {
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Icon + connector line
          Column(
            children: [
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: event.color.withValues(alpha: 0.15),
                  shape: BoxShape.circle,
                ),
                child: Icon(event.icon, color: event.color, size: 18),
              ),
              if (!isLast)
                Expanded(
                  child: Container(
                    width: 2,
                    color: borderColor,
                    margin: const EdgeInsets.symmetric(vertical: 4),
                  ),
                ),
            ],
          ),
          const SizedBox(width: 12),
          // Event text
          Expanded(
            child: Padding(
              padding: EdgeInsets.only(bottom: isLast ? 0 : 16, top: 4),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    event.label,
                    style: AppTextStyles.bodyMedium.copyWith(
                      color: textPrimary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    event.timeAgo,
                    style:
                        AppTextStyles.bodySmall.copyWith(color: textSecondary),
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

// ---------------------------------------------------------------------------
// KPI Chip
// ---------------------------------------------------------------------------

class _KpiChip extends StatelessWidget {
  final String label;
  final String value;
  final Color color;
  final IconData icon;
  final Color surfaceColor;
  final Color borderColor;
  final Color textPrimary;
  final Color textSecondary;

  const _KpiChip({
    required this.label,
    required this.value,
    required this.color,
    required this.icon,
    required this.surfaceColor,
    required this.borderColor,
    required this.textPrimary,
    required this.textSecondary,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      decoration: BoxDecoration(
        color: surfaceColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: borderColor),
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: color, size: 22),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  value,
                  style: AppTextStyles.h3.copyWith(
                    color: color,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                Text(
                  label,
                  style: AppTextStyles.bodySmall
                      .copyWith(color: textSecondary),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Action Button
// ---------------------------------------------------------------------------

class _ActionButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final Color color;
  final VoidCallback onPressed;

  const _ActionButton({
    required this.label,
    required this.icon,
    required this.color,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 56,
      child: ElevatedButton.icon(
        onPressed: onPressed,
        icon: Icon(icon, size: 20),
        label: Text(
          label,
          style: AppTextStyles.button.copyWith(fontSize: 13),
        ),
        style: ElevatedButton.styleFrom(
          backgroundColor: color,
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
          elevation: 0,
          padding: const EdgeInsets.symmetric(horizontal: 12),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Section Header
// ---------------------------------------------------------------------------

class _SectionHeader extends StatelessWidget {
  final String title;
  final Color textPrimary;

  const _SectionHeader({required this.title, required this.textPrimary});

  @override
  Widget build(BuildContext context) {
    return Text(
      title,
      style: AppTextStyles.h3.copyWith(
        color: textPrimary,
        fontWeight: FontWeight.w700,
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Simulation Panel
// ---------------------------------------------------------------------------

class _SimulationPanel extends ConsumerWidget {
  final Color surfaceColor;
  final Color borderColor;
  final Color textPrimary;
  final Color textSecondary;

  const _SimulationPanel({
    required this.surfaceColor,
    required this.borderColor,
    required this.textPrimary,
    required this.textSecondary,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final states = [
      ('connected', AppColors.success, Icons.check_circle_rounded),
      ('reconnecting', const Color(0xFFF59E0B), Icons.sync_rounded),
      ('replaying', const Color(0xFF3D8EF0), Icons.history_rounded),
      ('degraded', AppColors.warning, Icons.warning_rounded),
      ('critical', AppColors.error, Icons.dangerous_rounded),
    ];

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: surfaceColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: borderColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.science_rounded,
                  color: textSecondary, size: 18),
              const SizedBox(width: 8),
              Text(
                'Simulate State',
                style: AppTextStyles.bodyMedium.copyWith(
                  color: textSecondary,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: states.map((s) {
              final (label, color, icon) = s;
              final current =
                  ref.watch(realtimeStateProvider).connectionState.name;
              final isActive = current == label;
              return GestureDetector(
                onTap: () {
                  HapticFeedback.selectionClick();
                  final notifier = ref.read(realtimeStateProvider.notifier);
                  switch (label) {
                    case 'connected':
                      notifier.simulateReconnect();
                      break;
                    case 'reconnecting':
                      notifier.simulateDisconnect();
                      break;
                    case 'replaying':
                      notifier.simulateReplay();
                      break;
                    case 'degraded':
                      notifier.simulateDegraded();
                      break;
                    case 'critical':
                      notifier.simulateCritical();
                      break;
                  }
                },
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  padding: const EdgeInsets.symmetric(
                      horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: isActive
                        ? color.withValues(alpha: 0.18)
                        : Colors.transparent,
                    borderRadius: BorderRadius.circular(100),
                    border: Border.all(
                      color: isActive
                          ? color
                          : borderColor,
                      width: isActive ? 1.5 : 1,
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(icon,
                          color: isActive ? color : textSecondary,
                          size: 16),
                      const SizedBox(width: 6),
                      Text(
                        label,
                        style: AppTextStyles.bodySmall.copyWith(
                          color: isActive ? color : textSecondary,
                          fontWeight: isActive
                              ? FontWeight.w700
                              : FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }
}
