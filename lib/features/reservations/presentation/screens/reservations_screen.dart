// lib/features/reservations/presentation/screens/reservations_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../tables/presentation/state/table_grid_notifier.dart';
import '../../../tables/domain/entities/restaurant_table.dart';
import '../state/reservations_notifier.dart';
import '../../domain/entities/reservation.dart';

class ReservationsScreen extends ConsumerStatefulWidget {
  const ReservationsScreen({super.key});

  @override
  ConsumerState<ReservationsScreen> createState() => _ReservationsScreenState();
}

class _ReservationsScreenState extends ConsumerState<ReservationsScreen> {
  final _nameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _partySizeController = TextEditingController();
  bool _isVip = false;

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _partySizeController.dispose();
    super.dispose();
  }

  void _showAddWalkInDialog() {
    _nameController.clear();
    _phoneController.clear();
    _partySizeController.clear();
    _isVip = false;

    showDialog<void>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Add to Waitlist'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: _nameController,
                  decoration: const InputDecoration(labelText: 'Guest Name'),
                ),
                TextField(
                  controller: _phoneController,
                  decoration: const InputDecoration(labelText: 'Phone Number'),
                  keyboardType: TextInputType.phone,
                ),
                TextField(
                  controller: _partySizeController,
                  decoration: const InputDecoration(labelText: 'Party Size (Guests)'),
                  keyboardType: TextInputType.number,
                ),
                CheckboxListTile(
                  title: const Text('VIP Guest'),
                  value: _isVip,
                  activeColor: AppColors.primary,
                  onChanged: (val) {
                    if (val != null) {
                      setDialogState(() {
                        _isVip = val;
                      });
                    }
                  },
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () {
                final name = _nameController.text.trim();
                final phone = _phoneController.text.trim();
                final partySize = int.tryParse(_partySizeController.text) ?? 2;
                if (name.isNotEmpty && phone.isNotEmpty) {
                  ref.read(reservationsNotifierProvider.notifier).checkInWalkIn(name, phone, partySize, _isVip);
                  Navigator.pop(context);
                }
              },
              style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary, foregroundColor: Colors.white),
              child: const Text('Add'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _showSeatAllocationDialog(String id, int guestCount, bool isWalkIn) async {
    final tablesState = await ref.read(tableGridNotifierProvider.future);
    if (!mounted) return;

    // Filter compatible tables (capacity >= guestCount and status available/cleaning)
    final compatibleTables = tablesState.tables
        .where((t) => t.capacity >= guestCount && (t.status == TableStatus.available || t.status == TableStatus.cleaning))
        .toList();

    await showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text('Seat Allocation (Party of $guestCount)'),
        content: compatibleTables.isEmpty
            ? const Text('No compatible tables available right now. Please clean or free up a table.')
            : SizedBox(
                width: double.maxFinite,
                child: ListView.builder(
                  shrinkWrap: true,
                  itemCount: compatibleTables.length,
                  itemBuilder: (itemContext, index) {
                    final table = compatibleTables[index];
                    return Card(
                      child: ListTile(
                        leading: const Icon(Icons.table_restaurant_rounded, color: AppColors.primary),
                        title: Text('Table ${table.label}'),
                        subtitle: Text('Capacity: ${table.capacity} • Status: ${table.status.name}'),
                        trailing: ElevatedButton(
                          onPressed: () async {
                            if (isWalkIn) {
                              await ref.read(reservationsNotifierProvider.notifier).seatWalkIn(id, table.id);
                            } else {
                              await ref.read(reservationsNotifierProvider.notifier).seatReservation(id, table.id);
                            }
                            // Also update table status on the grid optimistically
                            await ref.read(tableGridNotifierProvider.notifier).updateStatus(table.id, TableStatus.occupied);
                            if (dialogContext.mounted) {
                              Navigator.pop(dialogContext);
                            }
                          },
                          style: ElevatedButton.styleFrom(backgroundColor: AppColors.success, foregroundColor: Colors.white),
                          child: const Text('Seat Here'),
                        ),
                      ),
                    );
                  },
                ),
              ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  Color _getSlaColor(String sla) {
    switch (sla) {
      case 'critical':
        return AppColors.error;
      case 'warning':
        return AppColors.warning;
      case 'safe':
        return AppColors.success;
      default:
        return Colors.grey;
    }
  }

  @override
  Widget build(BuildContext context) {
    final resStateAsync = ref.watch(reservationsNotifierProvider);
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Reservations & Waitlist'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            onPressed: () => ref.invalidate(reservationsNotifierProvider),
          ),
        ],
      ),
      body: resStateAsync.when(
        loading: () => const Center(child: CircularProgressIndicator(color: AppColors.primary)),
        error: (err, stack) => Center(child: Text('Error: $err')),
        data: (state) {
          final upcomingReservations = state.reservations
              .where((r) => r.status == ReservationStatus.booked || r.status == ReservationStatus.checkedIn)
              .toList();

          return LayoutBuilder(
            builder: (context, constraints) {
              final mainContent = Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Section: Horizontal Reservations Timeline
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
                    key: const ValueKey('timeline-header'),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Upcoming Reservations',
                          style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                        ),
                        Text(
                          '${upcomingReservations.length} Active',
                          style: theme.textTheme.bodySmall?.copyWith(color: AppColors.primary),
                        ),
                      ],
                    ),
                  ),
                  SizedBox(
                    height: 180,
                    child: upcomingReservations.isEmpty
                        ? Center(
                            child: Text(
                              'No upcoming reservations booked today.',
                              style: theme.textTheme.bodyMedium?.copyWith(color: Colors.grey),
                            ),
                          )
                        : ListView.builder(
                            scrollDirection: Axis.horizontal,
                            padding: const EdgeInsets.symmetric(horizontal: 16.0),
                            itemCount: upcomingReservations.length,
                            itemBuilder: (context, index) {
                              final res = upcomingReservations[index];
                              final formattedTime = DateFormat('hh:mm a').format(res.reservationTime);
                              final slaColor = _getSlaColor(res.slaStatus);

                              return Container(
                                width: 260,
                                margin: const EdgeInsets.only(right: 12.0, bottom: 8.0),
                                child: Card(
                                  color: isDark ? AppColors.darkSurface : Colors.white,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(16),
                                    side: BorderSide(
                                      color: slaColor,
                                      width: res.slaStatus == 'critical' ? 2.0 : 1.0,
                                    ),
                                  ),
                                  child: Padding(
                                    padding: const EdgeInsets.all(16.0),
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Row(
                                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                          children: [
                                            Text(
                                              formattedTime,
                                              style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16),
                                            ),
                                            Container(
                                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                              decoration: BoxDecoration(
                                                color: slaColor.withValues(alpha: 0.1),
                                                borderRadius: BorderRadius.circular(8),
                                              ),
                                              child: Text(
                                                res.status.name.toUpperCase(),
                                                style: TextStyle(color: slaColor, fontWeight: FontWeight.bold, fontSize: 10),
                                              ),
                                            ),
                                          ],
                                        ),
                                        const SizedBox(height: 8),
                                        Text(
                                          res.guestName,
                                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                        Text(
                                          'Party of ${res.guestCount} • ${res.guestPhone}',
                                          style: theme.textTheme.bodySmall,
                                        ),
                                        const Spacer(),
                                        Row(
                                          mainAxisAlignment: MainAxisAlignment.end,
                                          children: [
                                            if (res.status == ReservationStatus.booked)
                                              TextButton.icon(
                                                icon: const Icon(Icons.check, size: 16),
                                                label: const Text('Check In'),
                                                style: TextButton.styleFrom(foregroundColor: AppColors.primary),
                                                onPressed: () => ref
                                                    .read(reservationsNotifierProvider.notifier)
                                                    .checkInReservation(res.id),
                                              )
                                            else if (res.status == ReservationStatus.checkedIn)
                                              ElevatedButton.icon(
                                                icon: const Icon(Icons.table_restaurant_rounded, size: 16),
                                                label: const Text('Allocate Table'),
                                                style: ElevatedButton.styleFrom(
                                                  backgroundColor: AppColors.success,
                                                  foregroundColor: Colors.white,
                                                  minimumSize: const Size(0, 36),
                                                ),
                                                onPressed: () => _showSeatAllocationDialog(res.id, res.guestCount, false),
                                              ),
                                          ],
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              );
                            },
                          ),
                  ),
                  const Divider(),
                  // Section: Waitlist Queue
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Waitlist Queue',
                          style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                        ),
                        ElevatedButton.icon(
                          icon: const Icon(Icons.add, size: 16),
                          label: const Text('Walk-in Entry'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.primary,
                            foregroundColor: Colors.white,
                            minimumSize: const Size(0, 36),
                          ),
                          onPressed: _showAddWalkInDialog,
                        ),
                      ],
                    ),
                  ),
                  Expanded(
                    child: state.waitlist.isEmpty
                        ? Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.group_off_rounded, size: 48, color: Colors.grey[400]),
                                const SizedBox(height: 8),
                                const Text('No guests currently waiting on the waitlist.'),
                              ],
                            ),
                          )
                        : ListView.builder(
                            padding: const EdgeInsets.symmetric(horizontal: 16.0),
                            itemCount: state.waitlist.length,
                            itemBuilder: (context, index) {
                              final entry = state.waitlist[index];
                              return Card(
                                color: isDark ? AppColors.darkSurface : Colors.white,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(16),
                                  side: BorderSide(
                                    color: entry.isVip ? AppColors.warning : (isDark ? AppColors.darkBorder : AppColors.lightBorder),
                                    width: entry.isVip ? 1.5 : 1.0,
                                  ),
                                ),
                                margin: const EdgeInsets.only(bottom: 8),
                                child: ListTile(
                                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                                  leading: CircleAvatar(
                                    backgroundColor: entry.isVip
                                        ? AppColors.warning.withValues(alpha: 0.15)
                                        : AppColors.primary.withValues(alpha: 0.1),
                                    child: Text(
                                      '${entry.guestCount}',
                                      style: TextStyle(
                                        color: entry.isVip ? AppColors.warning : AppColors.primary,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                  title: Row(
                                    children: [
                                      Text(
                                        entry.guestName,
                                        style: const TextStyle(fontWeight: FontWeight.bold),
                                      ),
                                      if (entry.isVip) ...[
                                        const SizedBox(width: 8),
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                          decoration: BoxDecoration(
                                            color: AppColors.warning.withValues(alpha: 0.2),
                                            borderRadius: BorderRadius.circular(8),
                                          ),
                                          child: const Text(
                                            'VIP',
                                            style: TextStyle(color: Colors.orange, fontWeight: FontWeight.bold, fontSize: 10),
                                          ),
                                        ),
                                      ],
                                    ],
                                  ),
                                  subtitle: Text(
                                    'Waiting: ${entry.waitDurationMinutes} mins • Score: ${entry.priorityScore.toStringAsFixed(1)}',
                                  ),
                                  trailing: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      IconButton(
                                        icon: const Icon(Icons.cancel_outlined, color: AppColors.error),
                                        onPressed: () => ref
                                            .read(reservationsNotifierProvider.notifier)
                                            .removeWaitlist(entry.id),
                                      ),
                                      ElevatedButton(
                                        onPressed: () => _showSeatAllocationDialog(entry.id, entry.guestCount, true),
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor: AppColors.success,
                                          foregroundColor: Colors.white,
                                        ),
                                        child: const Text('Seat'),
                                      ),
                                    ],
                                  ),
                                ),
                              );
                            },
                          ),
                  ),
                ],
              );

              return mainContent;
            },
          );
        },
      ),
    );
  }
}
