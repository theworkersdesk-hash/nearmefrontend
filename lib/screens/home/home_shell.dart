import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../config/theme.dart';
import '../../providers/discover_provider.dart';
import '../../providers/location_provider.dart';
import '../../providers/providers.dart';
import '../chat/chat_list_screen.dart';
import '../discover/discover_screen.dart';
import '../discover/pending_requests_screen.dart';
import '../events/events_screen.dart';
import '../profile/profile_screen.dart';

/// Authenticated app shell: Discover / Chat / Events / Me. Each tab renders its
/// own header (the design uses large custom headers, not a shared app bar).
class HomeShell extends ConsumerStatefulWidget {
  const HomeShell({super.key});

  @override
  ConsumerState<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends ConsumerState<HomeShell>
    with WidgetsBindingObserver {
  int _index = 0;

  static const _tabs = [
    DiscoverScreen(),
    ChatListScreen(),
    EventsScreen(),
    ProfileScreen(),
  ];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(locationProvider.notifier).sync();
      _initNotifications();
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  /// When the app returns to the foreground, re-capture the device location and
  /// rebuild the nearby-people list so discovery always reflects where the user
  /// currently is.
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      unawaited(_refreshLocationAndPeople());
    }
  }

  Future<void> _refreshLocationAndPeople() async {
    final synced = await ref.read(locationProvider.notifier).sync();
    if (synced && mounted) {
      await ref.read(discoverProvider.notifier).refresh();
    }
  }

  /// Registers for FCM (guarded — no-ops until Firebase is configured) and
  /// routes notification taps to the relevant tab.
  Future<void> _initNotifications() async {
    final notifications = ref.read(notificationServiceProvider);
    try {
      await notifications.init();
    } catch (_) {
      return;
    }
    notifications.onTapPayload.addListener(() {
      final payload = notifications.onTapPayload.value;
      if (payload == null || !mounted) return;
      switch (payload['type']) {
        case 'connection_request':
          Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const PendingRequestsScreen()));
          break;
        case 'connection_accepted':
        case 'chat_message':
          setState(() => _index = 1);
          break;
        case 'event_reminder':
          setState(() => _index = 2);
          break;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.surface,
      body: IndexedStack(index: _index, children: _tabs),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: (i) => setState(() => _index = i),
        backgroundColor: AppColors.background,
        indicatorColor: AppColors.tertiary,
        destinations: const [
          NavigationDestination(
              icon: Icon(Icons.explore_outlined),
              selectedIcon: Icon(Icons.explore),
              label: 'Discover'),
          NavigationDestination(
              icon: Icon(Icons.chat_bubble_outline),
              selectedIcon: Icon(Icons.chat_bubble),
              label: 'Chat'),
          NavigationDestination(
              icon: Icon(Icons.celebration_outlined),
              selectedIcon: Icon(Icons.celebration),
              label: 'Events'),
          NavigationDestination(
              icon: Icon(Icons.person_outline),
              selectedIcon: Icon(Icons.person),
              label: 'Me'),
        ],
      ),
    );
  }
}
