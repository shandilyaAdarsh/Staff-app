// lib/features/profile/presentation/screens/staff_profile_screen.dart
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../auth/presentation/state/auth_notifier.dart';

// ─── Model ────────────────────────────────────────────────────────────────────

class StaffProfile {
  final String staffId;
  final String name;
  final String role; // 'Waiter' | 'Supervisor' | 'Manager'
  final String branch;
  final String section;
  final String shiftStatus; // 'On Shift' | 'Off Shift'
  final DateTime shiftStartedAt;
  final Set<String> permissions;
  // 'table_view','order_manage','billing_view','analytics_view','manager_override'
  final String syncStateLabel; // 'Fresh' | 'Stale'

  const StaffProfile({
    required this.staffId,
    required this.name,
    required this.role,
    required this.branch,
    required this.section,
    required this.shiftStatus,
    required this.shiftStartedAt,
    required this.permissions,
    required this.syncStateLabel,
  });

  StaffProfile copyWith({
    String? staffId,
    String? name,
    String? role,
    String? branch,
    String? section,
    String? shiftStatus,
    DateTime? shiftStartedAt,
    Set<String>? permissions,
    String? syncStateLabel,
  }) {
    return StaffProfile(
      staffId: staffId ?? this.staffId,
      name: name ?? this.name,
      role: role ?? this.role,
      branch: branch ?? this.branch,
      section: section ?? this.section,
      shiftStatus: shiftStatus ?? this.shiftStatus,
      shiftStartedAt: shiftStartedAt ?? this.shiftStartedAt,
      permissions: permissions ?? this.permissions,
      syncStateLabel: syncStateLabel ?? this.syncStateLabel,
    );
  }
}

// ─── Provider ─────────────────────────────────────────────────────────────────

final staffProfileProvider = StateProvider<StaffProfile>((ref) => StaffProfile(
      staffId: 'waiter_001',
      name: 'Alex Johnson',
      role: 'Waiter',
      branch: 'Downtown Branch',
      section: 'Section A',
      shiftStatus: 'On Shift',
      shiftStartedAt: DateTime.now().subtract(const Duration(hours: 2, minutes: 14)),
      permissions: {'table_view', 'order_manage', 'billing_view'},
      syncStateLabel: 'Fresh',
    ));

// All known permissions in display order
const _allPermissions = <String, String>{
  'table_view': 'Table View',
  'order_manage': 'Order Manage',
  'billing_view': 'Billing View',
  'analytics_view': 'Analytics',
  'manager_override': 'Manager Override',
};

// ─── Screen ───────────────────────────────────────────────────────────────────

class StaffProfileScreen extends ConsumerStatefulWidget {
  const StaffProfileScreen({super.key});

  @override
  ConsumerState<StaffProfileScreen> createState() => _StaffProfileScreenState();
}

class _StaffProfileScreenState extends ConsumerState<StaffProfileScreen> {
  Timer? _shiftTimer;
  Duration _shiftDuration = Duration.zero;

  @override
  void initState() {
    super.initState();
    _updateDuration();
    _shiftTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) _updateDuration();
    });
  }

  void _updateDuration() {
    final profile = ref.read(staffProfileProvider);
    setState(() {
      _shiftDuration = DateTime.now().difference(profile.shiftStartedAt);
    });
  }

  @override
  void dispose() {
    _shiftTimer?.cancel();
    super.dispose();
  }

  String _formatDuration(Duration d) {
    final h = d.inHours;
    final m = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '${h}h ${m}m ${s}s';
  }

  String _initials(String name) {
    final parts = name.trim().split(' ');
    if (parts.length >= 2) return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
    return name.substring(0, name.length.clamp(0, 2)).toUpperCase();
  }

  @override
  Widget build(BuildContext context) {
    final profile = ref.watch(staffProfileProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? AppColors.darkBackground : AppColors.lightBackground,
      appBar: AppBar(
        backgroundColor: isDark ? AppColors.darkSurface : Colors.white,
        elevation: 0,
        title: const Text(
          'My Profile',
          style: TextStyle(fontWeight: FontWeight.w900),
        ),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Divider(
            height: 1,
            color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
          ),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.only(bottom: 32),
        children: [
          _buildProfileHeader(context, profile, isDark),
          const SizedBox(height: 8),
          _buildSectionLabel('PERMISSIONS', isDark),
          _buildPermissionsSection(profile, isDark),
          const SizedBox(height: 8),
          _buildSectionLabel('CURRENT SESSION', isDark),
          _buildSessionSection(profile, isDark),
          const SizedBox(height: 8),
          _buildSectionLabel('ACCOUNT', isDark),
          _buildAccountSection(context, profile, isDark),
          Divider(
            height: 32,
            indent: 16,
            endIndent: 16,
            color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
          ),
          _buildSectionLabel('SESSION ACTIONS', isDark),
          _buildSessionActions(context, isDark),
        ],
      ),
    );
  }

  // ── Profile Header ──────────────────────────────────────────────────────────

  Widget _buildProfileHeader(BuildContext context, StaffProfile profile, bool isDark) {
    final isOnShift = profile.shiftStatus == 'On Shift';
    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkSurface : Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
        ),
      ),
      child: Column(
        children: [
          // Avatar
          Container(
            width: 88,
            height: 88,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: const LinearGradient(
                colors: [AppColors.primary, AppColors.secondary],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              boxShadow: [
                BoxShadow(
                  color: AppColors.primary.withValues(alpha: 0.35),
                  blurRadius: 16,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
            child: Center(
              child: Text(
                _initials(profile.name),
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 30,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 1,
                ),
              ),
            ),
          ),
          const SizedBox(height: 14),
          // Name
          Text(
            profile.name,
            style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 6),
          // Role badge
          _RoleBadge(role: profile.role),
          const SizedBox(height: 12),
          // Branch
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.location_on_rounded, size: 14, color: Colors.grey[500]),
              const SizedBox(width: 4),
              Text(
                profile.branch,
                style: TextStyle(
                  fontSize: 13,
                  color: Colors.grey[500],
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          // Section chip + Shift status badge
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: AppColors.primary.withValues(alpha: 0.3)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.grid_view_rounded, size: 12, color: AppColors.primary),
                    const SizedBox(width: 4),
                    Text(
                      profile.section,
                      style: const TextStyle(
                        color: AppColors.primary,
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              // Live shift status badge
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: isOnShift
                      ? AppColors.success.withValues(alpha: 0.12)
                      : Colors.grey.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: isOnShift
                        ? AppColors.success.withValues(alpha: 0.4)
                        : Colors.grey.withValues(alpha: 0.3),
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (isOnShift)
                      const _PulseDot(color: AppColors.success)
                    else
                      Container(
                        width: 6,
                        height: 6,
                        decoration: const BoxDecoration(
                          color: Colors.grey,
                          shape: BoxShape.circle,
                        ),
                      ),
                    const SizedBox(width: 5),
                    Text(
                      isOnShift
                          ? '${profile.shiftStatus} · ${_formatDuration(_shiftDuration)}'
                          : profile.shiftStatus,
                      style: TextStyle(
                        color: isOnShift ? AppColors.success : Colors.grey,
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ── Permissions ──────────────────────────────────────────────────────────────

  Widget _buildPermissionsSection(StaffProfile profile, bool isDark) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkSurface : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: isDark ? AppColors.darkBorder : AppColors.lightBorder),
      ),
      child: Wrap(
        spacing: 8,
        runSpacing: 8,
        children: _allPermissions.entries.map((entry) {
          final hasPermission = profile.permissions.contains(entry.key);
          return _PermissionChip(
            label: entry.value,
            granted: hasPermission,
          );
        }).toList(),
      ),
    );
  }

  // ── Session Info ─────────────────────────────────────────────────────────────

  Widget _buildSessionSection(StaffProfile profile, bool isDark) {
    final startTime = _formatTime(profile.shiftStartedAt);
    final isFresh = profile.syncStateLabel == 'Fresh';

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkSurface : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: isDark ? AppColors.darkBorder : AppColors.lightBorder),
      ),
      child: Column(
        children: [
          _InfoRow(
            icon: Icons.play_circle_outline_rounded,
            label: 'Shift Started',
            value: startTime,
            isDark: isDark,
            isFirst: true,
          ),
          _divider(isDark),
          _InfoRow(
            icon: Icons.timer_rounded,
            label: 'Shift Duration',
            value: _formatDuration(_shiftDuration),
            isDark: isDark,
            valueColor: AppColors.primary,
          ),
          _divider(isDark),
          _InfoRow(
            icon: Icons.grid_view_rounded,
            label: 'Current Section',
            value: profile.section,
            isDark: isDark,
          ),
          _divider(isDark),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Row(
              children: [
                Icon(
                  Icons.sync_rounded,
                  size: 18,
                  color: Colors.grey[500],
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Sync State',
                    style: TextStyle(fontSize: 14, color: Colors.grey[600]),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: isFresh
                        ? AppColors.success.withValues(alpha: 0.12)
                        : AppColors.warning.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: isFresh
                          ? AppColors.success.withValues(alpha: 0.4)
                          : AppColors.warning.withValues(alpha: 0.4),
                    ),
                  ),
                  child: Text(
                    profile.syncStateLabel,
                    style: TextStyle(
                      color: isFresh ? AppColors.success : AppColors.warning,
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
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

  // ── Account ──────────────────────────────────────────────────────────────────

  Widget _buildAccountSection(BuildContext context, StaffProfile profile, bool isDark) {
    final isManager = profile.role == 'Manager';

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkSurface : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: isDark ? AppColors.darkBorder : AppColors.lightBorder),
      ),
      child: Column(
        children: [
          ListTile(
            leading: const Icon(Icons.badge_rounded, color: AppColors.primary),
            title: const Text('Change Display Name', style: TextStyle(fontWeight: FontWeight.w600)),
            trailing: const Icon(Icons.chevron_right_rounded),
            onTap: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Feature coming soon')),
              );
            },
          ),
          Divider(height: 1, indent: 56, color: isDark ? AppColors.darkBorder : AppColors.lightBorder),
          ListTile(
            leading: const Icon(Icons.pin_rounded, color: AppColors.primary),
            title: const Text('Change PIN', style: TextStyle(fontWeight: FontWeight.w600)),
            trailing: const Icon(Icons.chevron_right_rounded),
            onTap: () => _showChangePinDialog(context, isDark),
          ),
          Divider(height: 1, indent: 56, color: isDark ? AppColors.darkBorder : AppColors.lightBorder),
          ListTile(
            enabled: isManager,
            leading: Icon(
              Icons.store_rounded,
              color: isManager ? AppColors.primary : Colors.grey[400],
            ),
            title: Text(
              'Switch Branch',
              style: TextStyle(
                fontWeight: FontWeight.w600,
                color: isManager ? null : Colors.grey[400],
              ),
            ),
            subtitle: Text(
              isManager ? 'Change active branch' : 'Manager access required',
              style: TextStyle(fontSize: 12, color: Colors.grey[500]),
            ),
            trailing: Icon(
              Icons.chevron_right_rounded,
              color: isManager ? null : Colors.grey[400],
            ),
            onTap: isManager
                ? () {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Feature coming soon')),
                    );
                  }
                : null,
          ),
        ],
      ),
    );
  }

  // ── Session Actions ──────────────────────────────────────────────────────────

  Widget _buildSessionActions(BuildContext context, bool isDark) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        children: [
          SizedBox(
            width: double.infinity,
            height: 56,
            child: OutlinedButton.icon(
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.warning,
                side: const BorderSide(color: AppColors.warning, width: 1.5),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
              icon: const Icon(Icons.lock_outline_rounded),
              label: const Text(
                'Lock Screen',
                style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
              ),
              onPressed: () {
                HapticFeedback.mediumImpact();
                ref.read(authNotifierProvider.notifier).lockSession();
              },
            ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            height: 56,
            child: ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.error,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
              icon: const Icon(Icons.logout_rounded),
              label: const Text(
                'End Shift',
                style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
              ),
              onPressed: () {
                HapticFeedback.heavyImpact();
                context.push('/shift/close');
              },
            ),
          ),
        ],
      ),
    );
  }

  // ── Helpers ──────────────────────────────────────────────────────────────────

  Widget _buildSectionLabel(String label, bool isDark) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 16, 8),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w800,
          letterSpacing: 1.2,
          color: Colors.grey[500],
        ),
      ),
    );
  }

  Widget _divider(bool isDark) => Divider(
        height: 1,
        indent: 16,
        color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
      );

  String _formatTime(DateTime dt) {
    final h = dt.hour > 12 ? dt.hour - 12 : dt.hour == 0 ? 12 : dt.hour;
    final m = dt.minute.toString().padLeft(2, '0');
    final period = dt.hour >= 12 ? 'PM' : 'AM';
    return '$h:$m $period';
  }

  void _showChangePinDialog(BuildContext context, bool isDark) {
    final currentPinCtrl = TextEditingController();
    final newPinCtrl = TextEditingController();
    final confirmPinCtrl = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: isDark ? AppColors.darkSurface : Colors.white,
        title: const Text('Change PIN', style: TextStyle(fontWeight: FontWeight.w800)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: currentPinCtrl,
              obscureText: true,
              keyboardType: TextInputType.number,
              maxLength: 6,
              decoration: const InputDecoration(
                labelText: 'Current PIN',
                prefixIcon: Icon(Icons.lock_outline_rounded),
                counterText: '',
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: newPinCtrl,
              obscureText: true,
              keyboardType: TextInputType.number,
              maxLength: 6,
              decoration: const InputDecoration(
                labelText: 'New PIN',
                prefixIcon: Icon(Icons.pin_rounded),
                counterText: '',
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: confirmPinCtrl,
              obscureText: true,
              keyboardType: TextInputType.number,
              maxLength: 6,
              decoration: const InputDecoration(
                labelText: 'Confirm New PIN',
                prefixIcon: Icon(Icons.pin_rounded),
                counterText: '',
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            onPressed: () {
              Navigator.pop(ctx);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('PIN changed successfully')),
              );
            },
            child: const Text('Change PIN', style: TextStyle(fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );
  }
}

// ─── Sub-Widgets ───────────────────────────────────────────────────────────────

class _RoleBadge extends StatelessWidget {
  final String role;
  const _RoleBadge({required this.role});

  Color get _color => switch (role) {
        'Manager' => AppColors.error,
        'Supervisor' => AppColors.secondary,
        _ => AppColors.primary,
      };

  IconData get _icon => switch (role) {
        'Manager' => Icons.admin_panel_settings_rounded,
        'Supervisor' => Icons.supervisor_account_rounded,
        _ => Icons.person_rounded,
      };

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
      decoration: BoxDecoration(
        color: _color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: _color.withValues(alpha: 0.35)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(_icon, size: 13, color: _color),
          const SizedBox(width: 5),
          Text(
            role,
            style: TextStyle(
              color: _color,
              fontSize: 12,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.3,
            ),
          ),
        ],
      ),
    );
  }
}

class _PermissionChip extends StatelessWidget {
  final String label;
  final bool granted;
  const _PermissionChip({required this.label, required this.granted});

  @override
  Widget build(BuildContext context) {
    final color = granted ? AppColors.success : Colors.grey;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            granted ? Icons.check_circle_rounded : Icons.cancel_rounded,
            size: 13,
            color: color,
          ),
          const SizedBox(width: 5),
          Text(
            label,
            style: TextStyle(
              color: color,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final bool isDark;
  final Color? valueColor;
  final bool isFirst;

  const _InfoRow({
    required this.icon,
    required this.label,
    required this.value,
    required this.isDark,
    this.valueColor,
    this.isFirst = false,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          Icon(icon, size: 18, color: Colors.grey[500]),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              label,
              style: TextStyle(fontSize: 14, color: Colors.grey[600]),
            ),
          ),
          Text(
            value,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: valueColor,
            ),
          ),
        ],
      ),
    );
  }
}

/// Animated pulsing dot for live status
class _PulseDot extends StatefulWidget {
  final Color color;
  const _PulseDot({required this.color});

  @override
  State<_PulseDot> createState() => _PulseDotState();
}

class _PulseDotState extends State<_PulseDot> with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _anim;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..repeat(reverse: true);
    _anim = Tween<double>(begin: 0.4, end: 1.0).animate(_ctrl);
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _anim,
      child: Container(
        width: 6,
        height: 6,
        decoration: BoxDecoration(color: widget.color, shape: BoxShape.circle),
      ),
    );
  }
}
