// lib/routing/app_router.dart
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../app/observers/routing_observer.dart';
import 'package:google_fonts/google_fonts.dart';
import '../core/theme/app_colors.dart';
import '../features/tables/presentation/screens/table_grid_screen.dart';
import '../features/tables/presentation/screens/table_detail_screen.dart';
import '../features/auth/presentation/state/auth_notifier.dart';
import '../features/auth/presentation/state/auth_state.dart';
import '../features/auth/presentation/screens/splash_screen.dart';
import '../features/auth/presentation/screens/welcome_screen.dart';
import '../features/auth/presentation/screens/device_registration_screen.dart';
import '../features/auth/presentation/screens/staff_login_screen.dart';

import '../features/auth/presentation/screens/session_lock_screen.dart';
import '../core/storage/device_context_store.dart';

import '../features/waiter_calls/presentation/screens/waiter_call_feed_screen.dart';
import '../features/waiter_calls/presentation/screens/waiter_call_details_screen.dart';
import '../features/notifications/presentation/screens/notification_center_screen.dart';
import '../features/notifications/presentation/state/notifications_provider.dart';
import '../features/waiter_calls/presentation/state/waiter_calls_providers.dart';
// Volume II — Screen imports
import '../features/profile/presentation/screens/staff_profile_screen.dart';
import '../features/notifications/presentation/screens/combined_notifications_screen.dart';
import '../features/realtime/presentation/state/realtime_providers.dart';
import '../features/realtime/domain/entities/realtime_state_model.dart';
import '../core/widgets/realtime_banner.dart';
import '../core/network/realtime_sync_manager.dart';
import '../features/orders/presentation/widgets/incoming_order_alert_overlay.dart';

// Derived provider: count of active (unresolved) waiter calls for badge display
final activeWaiterCallsCountProvider = Provider<int>((ref) {
  final calls = ref.watch(activeWaiterCallsProvider);
  return calls.length;
});

// RouterNotifier acts as a bridge between Riverpod and GoRouter.
// It listens to auth state changes and notifies GoRouter to trigger a redirect.
class RouterNotifier extends ChangeNotifier {
  final Ref _ref;

  RouterNotifier(this._ref) {
    _ref.listen<AuthState>(
      authNotifierProvider,
      (_, next) => notifyListeners(),
    );
    _ref.listen<RealtimeStateModel>(
      realtimeStateProvider,
      (_, next) => notifyListeners(),
    );
  }
}

final routerNotifierProvider = Provider<RouterNotifier>((ref) {
  return RouterNotifier(ref);
});

final routerProvider = Provider<GoRouter>((ref) {
  final notifier = ref.read(routerNotifierProvider);

  return GoRouter(
    initialLocation: '/splash',
    debugLogDiagnostics: true,
    refreshListenable: notifier,
    observers: [AppRoutingObserver()],
    redirect: (context, state) {
      final authState = ref.read(authNotifierProvider);
      final loc = state.uri.path;

      debugPrint(
        '[ROUTER] redirect evaluation: location=$loc, isLocked=${authState.isLocked}, isShiftStarted=${authState.isShiftStarted}, org=${authState.selectedOrg?.name}, branch=${authState.selectedBranch?.name}',
      );

      // Handle the default platform route
      if (loc == '/') {
        return '/splash';
      }

      // If we are on the splash screen, do NOT redirect. Let it perform its bootloader diagnostics.
      if (loc == '/splash') {
        return null;
      }

      // Check for critical realtime connection failure
      final realtimeState = ref.read(realtimeStateProvider);
      if (realtimeState.connectionState == RealtimeConnectionState.critical) {
        if (loc != '/realtime/recovery') {
          return '/realtime/recovery';
        }
        return null;
      }

      // If we recovered and are still on the recovery screen, go back to main screen
      if (loc == '/realtime/recovery') {
        return '/tables';
      }

      // If locked, staff must go to/stay on session lock screen
      if (authState.isLocked) {
        if (loc != '/lock') {
          return '/lock';
        }
        return null;
      }

      // Ensure locked screen is not bypassed when not locked
      if (loc == '/lock' && !authState.isLocked) {
        return '/tables';
      }

      // Main authentication routing state machine
      final deviceStore = ref.read(deviceContextStoreProvider);

      if (!deviceStore.hasContext) {
        if (loc != '/welcome' && loc != '/device-registration') {
          return '/welcome';
        }
        return null;
      }

      if (authState.loggedInStaff == null) {
        if (loc != '/login') {
          return '/login';
        }
        return null;
      }

      // Removed the shift-start redirect since the screen is removed
      // and login auto-starts the shift.

      // If logged in, shift started, operational, and not locked...

      // Profile setup / onboarding wizard bypassed for this phase.

      // Block access to auth configuration screens
      final isAuthScreen =
          loc == '/device-registration' ||
          loc == '/login';

      if (isAuthScreen) {
        return '/notifications';
      }

      // Allow access to the target route
      return null;
    },
    routes: [
      GoRoute(
        path: '/splash',
        name: 'splash',
        builder: (context, state) => const SplashScreen(),
      ),
      GoRoute(
        path: '/welcome',
        name: 'welcome',
        builder: (context, state) => const WelcomeScreen(),
      ),
      GoRoute(
        path: '/device-registration',
        name: 'device-registration',
        builder: (context, state) => const DeviceRegistrationScreen(),
      ),
      GoRoute(
        path: '/login',
        name: 'login',
        builder: (context, state) => const StaffLoginScreen(),
      ),
      // Shift Start Route Removed
      GoRoute(
        path: '/lock',
        name: 'lock',
        builder: (context, state) => const SessionLockScreen(),
      ),
      // Profile Setup Route Removed
      ShellRoute(
        builder: (context, state, child) {
          return NavigationShellLayout(child: child);
        },
        routes: [
          GoRoute(
            path: '/notifications',
            name: 'notifications',
            builder: (context, state) => const CombinedNotificationsScreen(),
          ),
          GoRoute(
            path: '/tables',
            name: 'tables',
            builder: (context, state) => const TableGridScreen(),
          ),
          GoRoute(
            path: '/profile',
            name: 'profile',
            builder: (context, state) => const StaffProfileScreen(),
          ),
        ],
      ),
      GoRoute(
        path: '/tables/:id',
        name: 'table-detail',
        builder: (context, state) {
          final id = state.pathParameters['id']!;
          return TableDetailScreen(tableId: id);
        },
      ),
      // Profile is now inside ShellRoute
      GoRoute(
        path: '/waiter-calls/:id',
        name: 'waiter-call-details',
        builder: (context, state) {
          final id = state.pathParameters['id']!;
          return WaiterCallDetailsScreen(callId: id);
        },
      ),
    ],
  );
});

// NavigationShellLayout is a ConsumerWidget so it can watch live badge counts.
class NavigationShellLayout extends ConsumerWidget {
  final Widget child;

  const NavigationShellLayout({super.key, required this.child});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final location = GoRouterState.of(context).uri.path;

    // Live badge providers
    final unreadNotifCount = ref.watch(unreadNotificationsCountProvider);
    final activeCallCount = ref.watch(activeWaiterCallsCountProvider);
    final realtimeState = ref.watch(realtimeStateProvider);
    final authState = ref.watch(authNotifierProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    int selectedIndex = 0;
    if (location.startsWith('/tables')) {
      selectedIndex = 1;
    } else if (location.startsWith('/profile')) {
      selectedIndex = 2;
    }

    RealtimeState mapState(RealtimeConnectionState s) {
      switch (s) {
        case RealtimeConnectionState.connected:
          return RealtimeState.connected;
        case RealtimeConnectionState.reconnecting:
          return RealtimeState.reconnecting;
        case RealtimeConnectionState.replaying:
          return RealtimeState.replaying;
        case RealtimeConnectionState.degraded:
          return RealtimeState.degraded;
        case RealtimeConnectionState.critical:
          return RealtimeState.critical;
      }
    }

    // Removed unused route checks

    return LayoutBuilder(
      builder: (context, constraints) {
        final isDesktop = constraints.maxWidth >= 800;

        final bodyContent = OrderAlertListener(
          child: Stack(
            children: [
              child,
              RealtimeBanner(
                state: mapState(realtimeState.connectionState),
                reconnectAttempt: realtimeState.reconnectAttempts,
                onRetry: () {
                  ref.read(realtimeSyncManagerProvider).connectLocal();
                },
              ),
            ],
          ),
        );

        final scaffold = Scaffold(
          appBar: PreferredSize(
            preferredSize: const Size.fromHeight(60),
            child: _buildTopActionBar(
              context,
              unreadNotifCount,
              activeCallCount,
              authState.selectedBranch?.name ?? 'Main Kitchen',
              isDark,
              isDesktop,
            ),
          ),
          body: isDesktop
              ? Row(
                  children: [
                    _buildNavigationRail(
                      context,
                      selectedIndex,
                      activeCallCount,
                      unreadNotifCount,
                      isDark,
                    ),
                    VerticalDivider(
                      thickness: 1,
                      width: 1,
                      color: isDark ? Colors.white10 : const Color(0xFFE2E8F0),
                    ),
                    Expanded(child: bodyContent),
                  ],
                )
              : bodyContent,
          bottomNavigationBar: isDesktop
              ? null
              : _buildBottomNavigationBar(
                  context,
                  selectedIndex,
                  activeCallCount,
                  unreadNotifCount,
                  isDark,
                ),
        );

        return scaffold;
      },
    );
  }

  Widget _buildNavigationRail(
    BuildContext context,
    int selectedIndex,
    int activeCallCount,
    int unreadNotifCount,
    bool isDark,
  ) {
    return Container(
      width: 80,
      color: isDark ? const Color(0xFF1E293B) : Colors.white,
      child: SafeArea(
        child: Column(
          children: [
            const SizedBox(height: 16),
            _buildNavItem(context, Icons.notifications_rounded, 'Notifications', selectedIndex == 0, isDark, () => context.go('/notifications'), badgeCount: activeCallCount + unreadNotifCount, isRail: true),
            _buildNavItem(context, Icons.table_restaurant_rounded, 'My Tables', selectedIndex == 1, isDark, () => context.go('/tables'), isRail: true),
            _buildNavItem(context, Icons.person_rounded, 'Profile', selectedIndex == 2, isDark, () => context.go('/profile'), isRail: true),
            const Spacer(),
          ],
        ),
      ),
    );
  }

  Widget _buildBottomNavigationBar(
    BuildContext context,
    int selectedIndex,
    int activeCallCount,
    int unreadNotifCount,
    bool isDark,
  ) {
    return Container(
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 12,
            offset: const Offset(0, -4),
          ),
        ],
        border: Border(
          top: BorderSide(
            color: isDark ? Colors.white10 : const Color(0xFFE2E8F0),
          ),
        ),
      ),
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: SafeArea(
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            _buildNavItem(
              context,
              Icons.notifications_rounded,
              'Notifications',
              selectedIndex == 0,
              isDark,
              () => context.go('/notifications'),
              badgeCount: activeCallCount + unreadNotifCount,
            ),
            _buildNavItem(
              context,
              Icons.table_restaurant_rounded,
              'My Tables',
              selectedIndex == 1,
              isDark,
              () => context.go('/tables'),
            ),
            _buildNavItem(
              context,
              Icons.person_rounded,
              'Profile',
              selectedIndex == 2,
              isDark,
              () => context.go('/profile'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNavItem(
    BuildContext context,
    IconData icon,
    String label,
    bool isActive,
    bool isDark,
    VoidCallback onTap, {
    int badgeCount = 0,
    bool isRail = false,
  }) {
    const activeColor = Color(0xFFE31E24);
    final activeBg = activeColor.withValues(alpha: 0.1);
    final inactiveColor = isDark ? Colors.white54 : const Color(0xFF64748B);

    Widget iconWidget = Icon(
      icon,
      color: isActive ? activeColor : inactiveColor,
      size: 24,
    );
    if (badgeCount > 0) {
      iconWidget = Badge(
        label: Text('$badgeCount'),
        backgroundColor: AppColors.error,
        child: iconWidget,
      );
    }

    final item = Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: isActive ? activeBg : Colors.transparent,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: iconWidget,
              ),
              const SizedBox(height: 4),
              Text(
                label,
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 11,
                  fontWeight: isActive ? FontWeight.w700 : FontWeight.w600,
                  color: isActive ? activeColor : inactiveColor,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ),
    );

    return isRail
        ? Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: item,
          )
        : Expanded(child: item);
  }

  Widget _buildTopActionBar(
    BuildContext context,
    int unreadNotifCount,
    int activeCallCount,
    String branchName,
    bool isDark,
    bool isDesktop,
  ) {
    return Container(
      decoration: BoxDecoration(
        color:
            Theme.of(context).appBarTheme.backgroundColor ??
            Theme.of(context).scaffoldBackgroundColor,
        border: Border(
          bottom: BorderSide(
            color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
            width: 0.5,
          ),
        ),
      ),
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              // Store Title
              Row(
                children: [
                  Icon(
                    Icons.storefront_rounded,
                    color: isDark
                        ? const Color(0xFFffb4ab)
                        : const Color(0xFFE31E24),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    branchName,
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 20,
                      fontWeight: FontWeight.w700,
                      color: isDark
                          ? const Color(0xFFffb4ab)
                          : const Color(0xFFE31E24),
                    ),
                  ),
                ],
              ),
              // Action Icons
              Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.account_circle_rounded),
                    iconSize: 28,
                    tooltip: 'Profile',
                    onPressed: () => context.push('/profile'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
