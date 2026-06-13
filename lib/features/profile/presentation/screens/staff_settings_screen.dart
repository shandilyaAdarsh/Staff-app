// lib/features/profile/presentation/screens/staff_settings_screen.dart
//
// Staff Settings — alert volume, session timeout, and preferences.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../orders/presentation/services/order_alert_audio_manager.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Volume persistence keys
// ─────────────────────────────────────────────────────────────────────────────

const _kAlertVolume = 'pref_alert_volume';

// ─────────────────────────────────────────────────────────────────────────────
// Riverpod provider — loads/saves volume from SharedPreferences
// ─────────────────────────────────────────────────────────────────────────────

final alertVolumeProvider =
    StateNotifierProvider<AlertVolumeNotifier, double>((ref) {
  return AlertVolumeNotifier();
});

class AlertVolumeNotifier extends StateNotifier<double> {
  AlertVolumeNotifier() : super(OrderAlertAudioManager().volume) {
    _loadFromPrefs();
  }

  Future<void> _loadFromPrefs() async {
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getDouble(_kAlertVolume);
    if (saved != null) {
      state = saved;
      OrderAlertAudioManager().setVolume(saved);
    }
  }

  Future<void> setVolume(double value) async {
    state = value;
    OrderAlertAudioManager().setVolume(value);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble(_kAlertVolume, value);
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Screen
// ─────────────────────────────────────────────────────────────────────────────

class StaffSettingsScreen extends ConsumerWidget {
  const StaffSettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final volume = ref.watch(alertVolumeProvider);

    return Scaffold(
      backgroundColor:
          isDark ? AppColors.darkBackground : AppColors.lightBackground,
      appBar: AppBar(
        title: Text(
          'Settings',
          style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w700),
        ),
        elevation: 0,
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _SectionHeader(label: 'Alert Sound', isDark: isDark),
          const SizedBox(height: 8),
          _SettingsCard(
            isDark: isDark,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(
                      _volumeIcon(volume),
                      color: AppColors.primary,
                      size: 22,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'Alert Volume',
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          color: isDark ? Colors.white : const Color(0xFF1A1C1E),
                        ),
                      ),
                    ),
                    Text(
                      '${(volume * 100).round()}%',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: AppColors.primary,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                SliderTheme(
                  data: SliderTheme.of(context).copyWith(
                    activeTrackColor: AppColors.primary,
                    inactiveTrackColor:
                        isDark ? Colors.white12 : const Color(0xFFE2E8F0),
                    thumbColor: AppColors.primary,
                    overlayColor: AppColors.primary.withValues(alpha: 0.12),
                    trackHeight: 4,
                  ),
                  child: Slider(
                    value: volume,
                    min: 0.0,
                    max: 1.0,
                    divisions: 10,
                    onChanged: (v) {
                      ref.read(alertVolumeProvider.notifier).setVolume(v);
                    },
                  ),
                ),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Off',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 11,
                        color: isDark ? Colors.white38 : Colors.black38,
                      ),
                    ),
                    Text(
                      'Max',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 11,
                        color: isDark ? Colors.white38 : Colors.black38,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  'Controls the volume of incoming order and ready alerts.',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 12,
                    color: isDark ? Colors.white38 : Colors.black38,
                  ),
                ),
                const SizedBox(height: 12),
                OutlinedButton.icon(
                  icon: const Icon(Icons.play_arrow_rounded, size: 18),
                  label: Text(
                    'Test Alert Sound',
                    style: GoogleFonts.plusJakartaSans(
                      fontWeight: FontWeight.w600,
                      fontSize: 13,
                    ),
                  ),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.primary,
                    side: BorderSide(
                        color: AppColors.primary.withValues(alpha: 0.5)),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  onPressed: () async {
                    await OrderAlertAudioManager().playOrderReadySound();
                  },
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  IconData _volumeIcon(double volume) {
    if (volume == 0) return Icons.volume_off_rounded;
    if (volume < 0.5) return Icons.volume_down_rounded;
    return Icons.volume_up_rounded;
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Shared UI helpers
// ─────────────────────────────────────────────────────────────────────────────

class _SectionHeader extends StatelessWidget {
  final String label;
  final bool isDark;
  const _SectionHeader({required this.label, required this.isDark});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: 4, bottom: 4),
      child: Text(
        label.toUpperCase(),
        style: GoogleFonts.plusJakartaSans(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          letterSpacing: 1.2,
          color: isDark ? Colors.white38 : Colors.black38,
        ),
      ),
    );
  }
}

class _SettingsCard extends StatelessWidget {
  final Widget child;
  final bool isDark;
  const _SettingsCard({required this.child, required this.isDark});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkSurface : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
        ),
        boxShadow: [
          if (!isDark)
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.04),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
        ],
      ),
      child: child,
    );
  }
}
