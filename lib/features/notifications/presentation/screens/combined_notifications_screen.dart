import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'notification_center_screen.dart';
import '../../../waiter_calls/presentation/screens/waiter_call_feed_screen.dart';

class CombinedNotificationsScreen extends ConsumerWidget {
  const CombinedNotificationsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Notifications', style: TextStyle(fontWeight: FontWeight.w900)),
          bottom: const TabBar(
            tabs: [
              Tab(text: 'Requests'),
              Tab(text: 'Alerts'),
            ],
          ),
        ),
        body: TabBarView(
          children: [
            WaiterCallFeedScreen(),
            NotificationCenterScreen(),
          ],
        ),
      ),
    );
  }
}
