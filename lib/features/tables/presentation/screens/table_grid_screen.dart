import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../domain/entities/restaurant_table.dart';
import '../state/table_grid_notifier.dart';
import '../../../orders/domain/entities/order.dart';
import '../../../orders/providers/orders_providers.dart';
import '../../../orders/providers/orders_realtime_provider.dart';
import '../../../orders/presentation/state/orders_projection_provider.dart';
import '../../../auth/presentation/state/auth_notifier.dart';
import '../../../../shared/models/money.dart';

class TableGridScreen extends ConsumerStatefulWidget {
  const TableGridScreen({super.key});

  @override
  ConsumerState<TableGridScreen> createState() => _TableGridScreenState();
}

class _TableGridScreenState extends ConsumerState<TableGridScreen> {
  String _selectedZone = 'My Tables';

  @override
  Widget build(BuildContext context) {
    // Keep alert-side realtime provider alive (popup + sound)
    ref.watch(ordersRealtimeProvider);

    final stateAsync = ref.watch(tableGridNotifierProvider);
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    
    final screenWidth = MediaQuery.of(context).size.width;
    final isDesktop = screenWidth >= 768;

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8F9FA),
      body: Row(
        children: [
          
          Expanded(
            child: Column(
              children: [
                Expanded(
                  child: SingleChildScrollView(
                    padding: EdgeInsets.all(isDesktop ? 40 : 20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Header & Zone Toggle
                        stateAsync.when(
                          loading: () => _buildPageHeader(isDark),
                          error: (_, _) => _buildPageHeader(isDark),
                          data: (state) {
                            // Extract unique floor names from tables
                            final floorNames = <String>{'My Tables', 'All'};
                            for (final t in state.tables) {
                              if (t.floorName != null && t.floorName!.isNotEmpty) {
                                floorNames.add(t.floorName!);
                              }
                            }
                            final zones = floorNames.toList();
                            // Reset selection if current zone no longer exists
                            if (!zones.contains(_selectedZone)) {
                              _selectedZone = 'All';
                            }

                            if (isDesktop) {
                              return Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                crossAxisAlignment: CrossAxisAlignment.center,
                                children: [
                                  _buildPageHeader(isDark),
                                  _buildZoneTabs(isDark, zones),
                                ],
                              );
                            } else {
                              return Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  _buildPageHeader(isDark),
                                  const SizedBox(height: 16),
                                  _buildZoneTabs(isDark, zones),
                                ],
                              );
                            }
                          },
                        ),
                        
                        const SizedBox(height: 32),

                        // Main Grid
                        Consumer(
                          builder: (context, ref, child) {
                            final liveOrders = ref.watch(liveOrdersProvider).valueOrNull ?? [];
                            final projectedOrders = ref.watch(ordersProjectionProvider);
                            // Combine active orders from both live provider and projection store
                            final ordersMap = <String, Order>{};
                            for (final o in liveOrders) { ordersMap[o.id] = o; }
                            for (final o in projectedOrders) { ordersMap[o.id] = o; }

                            // Only show orders belonging to the currently logged-in staff.
                            // Orders with empty waiterName are treated as unscoped (visible to all).
                            final authState = ref.watch(authNotifierProvider);
                            final loggedInStaffName = authState.loggedInStaff?.name ?? '';
                            final loggedInStaffId = authState.loggedInStaff?.id ?? '';

                            final activeOrders = ordersMap.values.where((o) {
                              // Exclude completed and cancelled orders from floor layout
                              if (o.status == OrderStatus.completed || o.status == OrderStatus.cancelled) return false;
                              return true;
                            }).toList();

                            return stateAsync.when(
                              loading: () => const Center(
                                child: Padding(
                                  padding: EdgeInsets.all(32.0),
                                  child: CircularProgressIndicator(color: Color(0xFFE31E24)),
                                ),
                              ),
                              error: (err, stack) => Center(
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    const Icon(Icons.error_outline_rounded, size: 48, color: Color(0xFFBA1A1A)),
                                    const SizedBox(height: 16),
                                    Text('Failed to load layout: $err', style: theme.textTheme.bodyMedium),
                                    const SizedBox(height: 16),
                                    ElevatedButton(
                                      onPressed: () => ref.invalidate(tableGridNotifierProvider),
                                      child: const Text('Retry'),
                                    ),
                                  ],
                                ),
                              ),
                              data: (state) {
                                // Filter tables by selected floor or assignment
                                final tables = _selectedZone == 'All'
                                    ? state.tables
                                    : _selectedZone == 'My Tables'
                                        ? state.tables.where((t) => t.assignedStaffId == loggedInStaffId).toList()
                                        : state.tables.where((t) => t.floorName == _selectedZone).toList();

                                if (tables.isEmpty) {
                                  return Center(
                                    child: Text(
                                      'No tables available',
                                      style: GoogleFonts.plusJakartaSans(
                                        fontSize: 16,
                                        color: isDark ? Colors.white54 : const Color(0xFF64748B),
                                      ),
                                    ),
                                  );
                                }
                                
                                return LayoutBuilder(
                                  builder: (context, constraints) {
                                    int crossAxisCount = 1;
                                    double childAspectRatio = 3.2;

                                    if (constraints.maxWidth >= 900) {
                                      crossAxisCount = 3;
                                      childAspectRatio = 1.6;
                                    } else if (constraints.maxWidth >= 600) {
                                      crossAxisCount = 2;
                                      childAspectRatio = 1.8;
                                    }

                                    return GridView.builder(
                                      shrinkWrap: true,
                                      physics: const NeverScrollableScrollPhysics(),
                                      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                                        crossAxisCount: crossAxisCount,
                                        crossAxisSpacing: 16,
                                        mainAxisSpacing: 16,
                                        childAspectRatio: childAspectRatio,
                                      ),
                                      itemCount: tables.length,
                                      itemBuilder: (context, index) {
                                        final table = tables[index];
                                        return _buildTableCard(table, isDark, activeOrders, loggedInStaffId)
                                          .animate()
                                          .fadeIn(delay: (50 * index).ms)
                                          .slideY(begin: 0.1, delay: (50 * index).ms);
                                      },
                                    );
                                  },
                                );
                              },
                            );
                          },
                        ),
                        
                        const SizedBox(height: 48),
                        _buildStatusLegend(isDark),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }


  Widget _buildPageHeader(bool isDark) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Floor Layout',
          style: GoogleFonts.plusJakartaSans(
            fontSize: 32,
            fontWeight: FontWeight.w700,
            letterSpacing: -0.5,
            color: isDark ? Colors.white : const Color(0xFF0F172A),
          ),
        ),
        const SizedBox(height: 4),
        Text(
          'Real-time table status.',
          style: GoogleFonts.plusJakartaSans(
            fontSize: 14,
            color: isDark ? Colors.white54 : const Color(0xFF5D3F3C), // Using design's on-surface-variant equivalent
          ),
        ),
      ],
    );
  }

  Widget _buildZoneTabs(bool isDark, List<String> zones) {
    return Container(
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : const Color(0xFFF3F4F5),
        borderRadius: BorderRadius.circular(12),
      ),
      padding: const EdgeInsets.all(4),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: zones.map((zone) {
            final isSelected = _selectedZone == zone;
            return InkWell(
              onTap: () => setState(() => _selectedZone = zone),
              borderRadius: BorderRadius.circular(8),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 10),
                decoration: BoxDecoration(
                  color: isSelected 
                      ? (isDark ? const Color(0xFF334155) : Colors.white)
                      : Colors.transparent,
                  borderRadius: BorderRadius.circular(8),
                  boxShadow: isSelected 
                      ? [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 4, offset: const Offset(0, 2))]
                      : [],
                ),
                child: Text(
                  zone,
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 14,
                    fontWeight: isSelected ? FontWeight.w700 : FontWeight.w600,
                    color: isSelected 
                        ? const Color(0xFFE31E24)
                        : (isDark ? Colors.white54 : const Color(0xFF64748B)),
                  ),
                ),
              ),
            );
          }).toList(),
        ),
      ),
    );
  }

  bool _isOrderForTable(Order o, RestaurantTable table) {
    if (o.status == OrderStatus.completed || o.status == OrderStatus.cancelled) {
      return false;
    }
    final tid = o.tableId.trim();
    if (tid.isEmpty && table.activeOrderId != o.id) return false;

    if (tid == table.id || tid == table.label || table.activeOrderId == o.id) return true;

    // Direct label comparison e.g. "Table 4" vs "Table 4" or "4"
    final cleanTableLabel = table.label.toLowerCase().replaceAll('table', '').trim();
    final cleanOrderTable = tid.toLowerCase().replaceAll('table', '').trim();
    if (cleanTableLabel.isNotEmpty && cleanTableLabel == cleanOrderTable) return true;

    return false;
  }

  /// Calculates total monetary amount for active orders at this table.
  String _getTableAmount(RestaurantTable table, List<Order> activeOrders) {
    int totalCents = 0;
    bool hasOrders = false;
    for (final o in activeOrders) {
      if (_isOrderForTable(o, table)) {
        totalCents += o.totalPrice.amountInCents;
        hasOrders = true;
      }
    }
    return hasOrders ? Money(amountInCents: totalCents).formatted : '₹0.00';
  }

  /// Returns elapsed time since the first active order for this table,
  /// e.g. "12m", "1h 05m". Falls back to '-' if no orders.
  String _getTableElapsed(RestaurantTable table, List<Order> activeOrders) {
    DateTime? earliest;
    for (final o in activeOrders) {
      if (_isOrderForTable(o, table)) {
        if (earliest == null || o.createdAt.isBefore(earliest)) {
          earliest = o.createdAt;
        }
      }
    }
    if (earliest == null) return '-';
    final diff = DateTime.now().difference(earliest);
    if (diff.inHours >= 1) {
      return '${diff.inHours}h ${(diff.inMinutes % 60).toString().padLeft(2, '0')}m';
    }
    return '${diff.inMinutes}m';
  }

  Widget _buildTableCard(RestaurantTable table, bool isDark, List<Order> activeOrders, String loggedInStaffId) {
    final hasActiveOrder = activeOrders.any((o) => _isOrderForTable(o, table));
    final isUnassigned = table.assignedStaffId == null;
    final isMine = table.assignedStaffId == loggedInStaffId;

    if (!hasActiveOrder) {
      return _buildAvailableCard(table, isDark);
    }
    
    if (isUnassigned) {
      return _buildOccupiedCard(table, isDark, activeOrders, 'UNASSIGNED\nTAP TO CLAIM', isMine: false, showDetails: false);
    }

    if (isMine) {
      if (table.status == TableStatus.needsAttention) {
        return _buildOccupiedCard(table, isDark, activeOrders, 'CALLING', isMine: true, showDetails: true, isCalling: true);
      } else if (table.isPaymentRequested || table.status == TableStatus.reserved) {
        return _buildOccupiedCard(table, isDark, activeOrders, 'BILL REQ', isMine: true, showDetails: true);
      }
      return _buildOccupiedCard(table, isDark, activeOrders, 'OCCUPIED', isMine: true, showDetails: true);
    }

    // Assigned to someone else
    return _buildOccupiedCard(table, isDark, activeOrders, 'OCCUPIED', isMine: false, showDetails: false);
  }

  Widget _buildAvailableCard(RestaurantTable table, bool isDark) {
    return InkWell(
      onTap: () => context.push('/tables/${table.id}'),
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF064E3B) : const Color(0xFFECFDF5),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFF10B981), width: 1.5),
        ),
        child: Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    table.label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                      color: isDark ? Colors.white : const Color(0xFF064E3B),
                    ),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: const Color(0xFF10B981).withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(100),
                    border: Border.all(color: const Color(0xFF10B981)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.check_circle_outline_rounded, size: 10, color: Color(0xFF064E3B)),
                      const SizedBox(width: 4),
                      Text('AVAILABLE', style: GoogleFonts.plusJakartaSans(fontSize: 12, fontWeight: FontWeight.w700, color: isDark ? Colors.white : const Color(0xFF064E3B))),
                    ],
                  ),
                ),
              ],
            ),
            const Spacer(),
          ],
        ),
      ),
    );
  }

  Widget _buildOccupiedCard(RestaurantTable table, bool isDark, List<Order> activeOrders, String badgeText, {required bool isMine, required bool showDetails, bool isCalling = false}) {
    final amount = _getTableAmount(table, activeOrders);
    final time = _getTableElapsed(table, activeOrders);
    
    final bgColor = isDark ? const Color(0xFF7F1D1D) : const Color(0xFFFEF2F2);
    final borderColor = isCalling ? const Color(0xFFFF0000) : const Color(0xFFEF4444);
    final textColor = isDark ? Colors.white : const Color(0xFF7F1D1D);
    
    return InkWell(
      onTap: () => context.push('/tables/${table.id}'),
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: borderColor, width: 1.5),
          boxShadow: [
            BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 12, offset: const Offset(0, 4)),
          ],
        ),
        child: Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Text(
                    table.label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                      color: textColor,
                    ),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: const Color(0xFFEF4444).withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: const Color(0xFFEF4444)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Text('??', style: TextStyle(fontSize: 10)),
                      const SizedBox(width: 4),
                      Text(
                        badgeText,
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 10,
                          fontWeight: FontWeight.w800,
                          color: textColor,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const Spacer(),
            if (showDetails)
              Container(
                padding: const EdgeInsets.only(top: 16),
                decoration: BoxDecoration(
                  border: Border(top: BorderSide(color: textColor.withValues(alpha: 0.2))),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.group_rounded, size: 16, color: textColor.withValues(alpha: 0.7)),
                        const SizedBox(width: 4),
                        Text('', style: GoogleFonts.plusJakartaSans(fontSize: 12, color: textColor.withValues(alpha: 0.7))),
                      ],
                    ),
                    Row(
                      children: [
                        Icon(Icons.schedule_rounded, size: 16, color: textColor.withValues(alpha: 0.7)),
                        const SizedBox(width: 4),
                        Text(time, style: GoogleFonts.plusJakartaSans(fontSize: 12, color: textColor.withValues(alpha: 0.7))),
                      ],
                    ),
                    Text(
                      amount,
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: textColor,
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

  Widget _buildStatusLegend(bool isDark) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          _buildLegendItem('Available', isDark, color: const Color(0xFF10B981)),
          const SizedBox(width: 16),
          _buildLegendItem('Occupied / Unassigned', isDark, color: const Color(0xFFEF4444)),
        ],
      ),
    );
  }

  Widget _buildLegendItem(String label, bool isDark, {required Color color}) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 12,
          height: 12,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: color,
          ),
        ),
        const SizedBox(width: 8),
        Text(
          label,
          style: GoogleFonts.plusJakartaSans(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: isDark ? Colors.white54 : const Color(0xFF5D3F3C),
          ),
        ),
      ],
    );
  }
}
