// lib/features/auth/presentation/screens/session_lock_screen.dart
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../../../core/theme/app_colors.dart';
import '../state/auth_notifier.dart';

class SessionLockScreen extends ConsumerStatefulWidget {
  const SessionLockScreen({super.key});

  @override
  ConsumerState<SessionLockScreen> createState() => _SessionLockScreenState();
}

class _SessionLockScreenState extends ConsumerState<SessionLockScreen> {
  String _pinCode = '';
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _onKeyPress(String val) {
    if (_pinCode.length >= 4) return;
    setState(() {
      _pinCode += val;
    });

    if (_pinCode.length == 4) {
      _triggerUnlock();
    }
  }

  void _onDelete() {
    if (_pinCode.isEmpty) return;
    setState(() {
      _pinCode = _pinCode.substring(0, _pinCode.length - 1);
    });
  }

  void _triggerUnlock() {
    final success = ref.read(authNotifierProvider.notifier).unlockSession(_pinCode);
    if (success) {
      context.go('/tables');
    } else {
      setState(() {
        _pinCode = '';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authNotifierProvider);
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final staff = authState.loggedInStaff;
    if (staff == null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (context.mounted) context.go('/login');
      });
      return const SizedBox.shrink();
    }

    final duration = authState.shiftStartTime != null
        ? DateTime.now().difference(authState.shiftStartTime!)
        : Duration.zero;

    final hours = duration.inHours.toString().padLeft(2, '0');
    final minutes = (duration.inMinutes % 60).toString().padLeft(2, '0');
    final seconds = (duration.inSeconds % 60).toString().padLeft(2, '0');

    return Scaffold(
      backgroundColor: isDark ? AppColors.darkBackground : Colors.grey[100],
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // Lock Icon and Header
                const Icon(Icons.lock_rounded, size: 56, color: AppColors.error)
                    .animate(onPlay: (c) => c.repeat(reverse: true))
                    .scaleXY(begin: 0.95, end: 1.05, duration: 1500.ms, curve: Curves.easeInOut),
                const SizedBox(height: 16),
                Text(
                  'Terminal Locked',
                  style: theme.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold),
                ),
                Text(
                  'Enter PIN to resume shift for ${staff.name}',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                  ),
                ),
                const SizedBox(height: 24),
                
                // Shift Telemetry / Status Box
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: isDark ? AppColors.darkSurface : Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: isDark ? AppColors.darkBorder : AppColors.lightBorder),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      _buildShiftStat('Shift Time', '$hours:$minutes:$seconds', Icons.timer_outlined, theme),
                      _buildShiftStat('Active Role', staff.role.name.toUpperCase(), Icons.assignment_ind_outlined, theme),
                    ],
                  ),
                ),
                const SizedBox(height: 24),
                
                // PIN indicators
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: List.generate(4, (index) {
                    final isActive = index < _pinCode.length;
                    return Container(
                      margin: const EdgeInsets.symmetric(horizontal: 10),
                      width: 16,
                      height: 16,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: isActive ? AppColors.error : Colors.transparent,
                        border: Border.all(
                          color: isDark ? Colors.white30 : Colors.black26,
                          width: 2,
                        ),
                      ),
                    );
                  }),
                ),
                const SizedBox(height: 16),
                
                if (authState.errorMessage != null)
                  Text(
                    authState.errorMessage!,
                    style: const TextStyle(color: AppColors.error, fontWeight: FontWeight.bold),
                  ),
                
                const SizedBox(height: 24),
                
                // Numeric Keypad
                GridView.count(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  crossAxisCount: 3,
                  mainAxisSpacing: 12,
                  crossAxisSpacing: 12,
                  childAspectRatio: 1.4,
                  children: [
                    ...['1', '2', '3', '4', '5', '6', '7', '8', '9'].map((digit) {
                      return OutlinedButton(
                        style: OutlinedButton.styleFrom(
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                        ),
                        onPressed: () => _onKeyPress(digit),
                        child: Text(
                          digit,
                          style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                        ),
                      );
                    }),
                    IconButton(
                      icon: const Icon(Icons.fingerprint_rounded, size: 28, color: AppColors.error),
                      onPressed: () {
                        // Bypass simulation
                        ref.read(authNotifierProvider.notifier).unlockSession(staff.pin);
                        context.go('/tables');
                      },
                    ),
                    OutlinedButton(
                      style: OutlinedButton.styleFrom(
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      ),
                      onPressed: () => _onKeyPress('0'),
                      child: Text(
                        '0',
                        style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.backspace_outlined, size: 20),
                      onPressed: _onDelete,
                    ),
                  ],
                ),
                
                const SizedBox(height: 24),
                
                // Exit options
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    TextButton.icon(
                      icon: const Icon(Icons.exit_to_app_rounded, size: 18),
                      label: const Text('End Shift'),
                      onPressed: () {
                        ref.read(authNotifierProvider.notifier).endShift();
                        context.go('/login');
                      },
                    ),
                    TextButton.icon(
                      icon: const Icon(Icons.report_problem_outlined, size: 18),
                      label: const Text('Incident Report'),
                      onPressed: () {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Incident flagged. Notifying shift manager.')),
                        );
                      },
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildShiftStat(String label, String value, IconData icon, ThemeData theme) {
    return Column(
      children: [
        Icon(icon, size: 20, color: AppColors.primary),
        const SizedBox(height: 4),
        Text(
          value,
          style: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.bold),
        ),
        Text(
          label,
          style: theme.textTheme.bodySmall,
        ),
      ],
    );
  }
}
