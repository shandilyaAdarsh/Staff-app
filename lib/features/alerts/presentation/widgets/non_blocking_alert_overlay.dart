// lib/features/alerts/presentation/widgets/non_blocking_alert_overlay.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../manager/presentation/state/manager_providers.dart';
import '../../../manager/domain/entities/operational_alert.dart';
import '../../../../core/theme/app_colors.dart';

class NonBlockingAlertOverlay extends ConsumerStatefulWidget {
  final Widget child;

  const NonBlockingAlertOverlay({super.key, required this.child});

  @override
  ConsumerState<NonBlockingAlertOverlay> createState() => _NonBlockingAlertOverlayState();
}

class _NonBlockingAlertOverlayState extends ConsumerState<NonBlockingAlertOverlay> {
  final List<OperationalAlert> _visibleAlerts = [];
  final Set<String> _seenAlertIds = {};

  @override
  Widget build(BuildContext context) {
    ref.listen<List<OperationalAlert>>(operationalAlertsProvider, (previous, current) {
      final newAlerts = current.where((a) => !_seenAlertIds.contains(a.alertId)).toList();
      for (final alert in newAlerts) {
        _seenAlertIds.add(alert.alertId);
        _showAlert(alert);
      }
    });

    return Stack(
      children: [
        widget.child,
        if (_visibleAlerts.isNotEmpty)
          Positioned(
            top: MediaQuery.of(context).padding.top + 16,
            left: 16,
            right: 16,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: _visibleAlerts.map((alert) => _buildAlertToast(alert)).toList(),
            ),
          ),
      ],
    );
  }

  void _showAlert(OperationalAlert alert) {
    setState(() {
      _visibleAlerts.add(alert);
    });

    // Auto dismiss toast after 4 seconds
    Future.delayed(const Duration(seconds: 4), () {
      if (mounted) {
        setState(() {
          _visibleAlerts.removeWhere((a) => a.alertId == alert.alertId);
        });
      }
    });
  }

  Widget _buildAlertToast(OperationalAlert alert) {
    Color bgColor = AppColors.primary;
    IconData icon = Icons.notifications;

    switch (alert.type) {
      case AlertType.newOrder:
      case AlertType.delayedOrder:
      case AlertType.slaBreached:
        bgColor = AppColors.error;
        icon = Icons.warning_amber_rounded;
        break;
      case AlertType.waiterCall:
        bgColor = AppColors.warning;
        icon = Icons.room_service;
        break;
      case AlertType.orderReady:
        bgColor = AppColors.success;
        icon = Icons.check_circle_outline;
        break;
      default:
        break;
    }

    return Dismissible(
      key: Key(alert.alertId),
      onDismissed: (_) {
        setState(() {
          _visibleAlerts.removeWhere((a) => a.alertId == alert.alertId);
        });
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.2),
              blurRadius: 8,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          children: [
            Icon(icon, color: Colors.white),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    alert.type.name.toUpperCase(),
                    style: const TextStyle(
                      color: Colors.white70,
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Text(
                    alert.entityLabel,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
