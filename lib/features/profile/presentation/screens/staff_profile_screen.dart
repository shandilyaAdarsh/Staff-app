import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../auth/presentation/state/auth_notifier.dart';

class StaffProfileScreen extends ConsumerStatefulWidget {
  const StaffProfileScreen({super.key});

  @override
  ConsumerState<StaffProfileScreen> createState() => _StaffProfileScreenState();
}

class _StaffProfileScreenState extends ConsumerState<StaffProfileScreen> {
  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bgColor = isDark ? AppColors.darkBackground : AppColors.lightBackground;
    final surfaceColor = isDark ? AppColors.darkSurface : Colors.white;
    final borderColor = isDark ? AppColors.darkBorder : AppColors.lightBorder;
    final textPrimary = isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary;
    final textSecondary = isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary;

    final authState = ref.watch(authNotifierProvider);
    final staff = authState.loggedInStaff;

    return Scaffold(
      backgroundColor: bgColor,
      appBar: AppBar(
        title: Text(
          'My Profile',
          style: AppTextStyles.h3.copyWith(
            color: textPrimary,
            fontWeight: FontWeight.bold,
          ),
        ),
        backgroundColor: surfaceColor,
        elevation: 0,
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Divider(height: 1, color: borderColor),
        ),
      ),
      body: staff == null && authState.selectedBranch == null
          ? const Center(child: CircularProgressIndicator())
          : staff == null
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24.0),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.account_circle_outlined, size: 64, color: textSecondary),
                        const SizedBox(height: 16),
                        Text(
                          'Staff Profile Unavailable',
                          style: AppTextStyles.h3.copyWith(color: textPrimary),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Could not load staff information. Please log in or refresh your shift.',
                          textAlign: TextAlign.center,
                          style: AppTextStyles.bodyMedium.copyWith(color: textSecondary),
                        ),
                        const SizedBox(height: 24),
                        ElevatedButton.icon(
                          onPressed: () {
                            ref.read(authNotifierProvider.notifier).loadStaffForBranch();
                          },
                          icon: const Icon(Icons.refresh_rounded),
                          label: const Text('Retry Loading'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.primary,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                        ),
                      ],
                    ),
                  ),
                )
              : ListView(
                  padding: const EdgeInsets.all(16),
                  children: [
                    _buildHeaderCard(staff, authState, surfaceColor, borderColor, textPrimary, textSecondary),
                    const SizedBox(height: 24),

                    _buildSafeSection(
                      'CONTACT INFORMATION',
                      surfaceColor,
                      borderColor,
                      textSecondary,
                      [
                        _buildRow('Mobile Number', textPrimary, rawValue: staff.mobileNumber),
                        _buildRow('Email', textPrimary, rawValue: staff.email),
                      ],
                    ),
                    _buildSafeSection(
                      'EMPLOYMENT INFORMATION',
                      surfaceColor,
                      borderColor,
                      textSecondary,
                      [
                        _buildRow('Employee ID', textPrimary, rawValue: staff.employeeId),
                        _buildRow('Role', textPrimary, rawValue: _formatRole(staff.role)),
                        _buildRow('Branch', textPrimary, rawValue: staff.branch ?? authState.selectedBranch?.name),
                        _buildRow('Status', textPrimary,
                            rawValue: staff.employmentStatus ?? 'Active', valueColor: AppColors.success),
                      ],
                    ),
                    const SizedBox(height: 16),

                    // ── Session Actions ──────────────────────────────────
                    _buildSectionHeader('SESSION', textSecondary),
                    _buildCard(
                      surfaceColor,
                      borderColor,
                      [
                        InkWell(
                          borderRadius: BorderRadius.circular(16),
                          onTap: () {
                            ref.read(authNotifierProvider.notifier).lockSession();
                            context.go('/login');
                          },
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                            child: Row(
                              children: [
                                const Icon(Icons.lock_rounded, color: AppColors.primary, size: 20),
                                const SizedBox(width: 12),
                                Text(
                                  'Lock Session',
                                  style: AppTextStyles.bodyMedium.copyWith(
                                    color: AppColors.primary,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                const Spacer(),
                                const Icon(Icons.chevron_right_rounded, color: AppColors.primary, size: 20),
                              ],
                            ),
                          ),
                        ),
                        _divider(borderColor),
                        InkWell(
                          borderRadius: BorderRadius.circular(16),
                          onTap: () => _confirmLogout(context),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                            child: Row(
                              children: [
                                const Icon(Icons.logout_rounded, color: AppColors.error, size: 20),
                                const SizedBox(width: 12),
                                Text(
                                  'Log Out',
                                  style: AppTextStyles.bodyMedium.copyWith(
                                    color: AppColors.error,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                const Spacer(),
                                const Icon(Icons.chevron_right_rounded, color: AppColors.error, size: 20),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 32),
                  ],
                ),
    );
  }

  Future<void> _confirmLogout(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        title: const Text('Log Out'),
        content: const Text(
          'Are you sure you want to log out? Your session will be ended.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            style: TextButton.styleFrom(foregroundColor: AppColors.error),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Log Out'),
          ),
        ],
      ),
    );

    if (confirmed == true && context.mounted) {
      await ref.read(authNotifierProvider.notifier).logout();
      if (context.mounted) context.go('/login');
    }
  }

  Widget _buildSectionHeader(String title, Color color) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 4, 4, 8),
      child: Text(
        title,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w800,
          color: color,
          letterSpacing: 1.2,
        ),
      ),
    );
  }

  Widget _buildCard(Color surfaceColor, Color borderColor, List<Widget> children) {
    return Container(
      decoration: BoxDecoration(
        color: surfaceColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: borderColor),
      ),
      child: Column(children: children),
    );
  }

  bool _hasValue(dynamic value) {
    if (value == null) return false;
    final str = value.toString().trim();
    if (str.isEmpty ||
        str.toLowerCase() == 'n/a' ||
        str.toLowerCase() == 'na' ||
        str.toLowerCase() == 'null' ||
        str.toLowerCase() == 'undefined') {
      return false;
    }
    return true;
  }

  Widget? _buildRow(String label, Color textPrimary, {dynamic rawValue, Color? valueColor}) {
    if (!_hasValue(rawValue)) return null;
    final value = rawValue.toString().trim();
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: AppTextStyles.bodyMedium.copyWith(
              color: textPrimary,
              fontWeight: FontWeight.w500,
            ),
          ),
          Text(
            value,
            style: AppTextStyles.bodyMedium.copyWith(
              fontWeight: FontWeight.bold,
              color: valueColor ?? textPrimary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSafeSection(
    String title,
    Color surfaceColor,
    Color borderColor,
    Color textSecondary,
    List<Widget?> rows,
  ) {
    final validRows = rows.whereType<Widget>().toList();
    if (validRows.isEmpty) return const SizedBox.shrink();

    final children = <Widget>[];
    for (int i = 0; i < validRows.length; i++) {
      children.add(validRows[i]);
      if (i < validRows.length - 1) {
        children.add(_divider(borderColor));
      }
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _buildSectionHeader(title, textSecondary),
        _buildCard(surfaceColor, borderColor, children),
        const SizedBox(height: 24),
      ],
    );
  }

  Widget _divider(Color color) => Divider(height: 1, indent: 16, color: color);

  Widget _buildHeaderCard(
    dynamic staff,
    dynamic authState,
    Color surfaceColor,
    Color borderColor,
    Color textPrimary,
    Color textSecondary,
  ) {
    final fullName = _getFullName(staff);
    final roleStr = _formatRole(staff.role);
    final branchStr = staff.branch ?? authState.selectedBranch?.name ?? 'Main Branch';
    final orgStr = authState.selectedOrg?.name ?? 'Orderlyy';

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: surfaceColor,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: borderColor),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 32,
            backgroundColor: AppColors.primary.withValues(alpha: 0.15),
            backgroundImage: staff.profilePhoto != null && staff.profilePhoto!.isNotEmpty
                ? NetworkImage(staff.profilePhoto!)
                : null,
            child: staff.profilePhoto == null || staff.profilePhoto!.isEmpty
                ? Text(
                    fullName.isNotEmpty ? fullName[0].toUpperCase() : 'S',
                    style: const TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: AppColors.primary,
                    ),
                  )
                : null,
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  fullName,
                  style: AppTextStyles.h3.copyWith(
                    color: textPrimary,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '$roleStr • $branchStr',
                  style: AppTextStyles.bodyMedium.copyWith(
                    color: AppColors.primary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  orgStr,
                  style: AppTextStyles.bodySmall.copyWith(
                    color: textSecondary,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _getFullName(dynamic staff) {
    final firstLast = '${staff.firstName} ${staff.lastName}'.trim();
    if (firstLast.isNotEmpty) return firstLast;
    if (staff.name != null && staff.name.isNotEmpty) return staff.name;
    return 'Staff Member';
  }

  String _formatRole(dynamic role) {
    if (role == null) return 'Staff';
    final roleName = role.toString().split('.').last;
    switch (roleName.toLowerCase()) {
      case 'waiter':
        return 'Waiter / Server';
      case 'runner':
        return 'Food Runner';
      case 'host':
        return 'Host / Greeter';
      case 'kdsoperator':
      case 'kds_operator':
        return 'KDS Operator';
      case 'manager':
        return 'Restaurant Manager';
      default:
        return roleName[0].toUpperCase() + roleName.substring(1);
    }
  }
}
