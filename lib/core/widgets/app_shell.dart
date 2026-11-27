
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../data/repositories/user_profile_repository.dart';
import '../../features/profile/models/user_profile.dart';

/// The bottom navigation wrapper around the four main screens.
class AppShell extends StatefulWidget {
  const AppShell({super.key, required this.shell});

  final StatefulNavigationShell shell;

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  late final Stream<UserProfile?> _profileStream;

  @override
  void initState() {
    super.initState();
    _profileStream = context.read<UserProfileRepository>().watchMyProfile();
  }

  @override
  Widget build(BuildContext context) {
    final shell = widget.shell;
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return StreamBuilder<UserProfile?>(
      stream: _profileStream,
      builder: (context, snapshot) {
        final isPoster = snapshot.data?.activeRole == 'poster';
        return Scaffold(
          backgroundColor: scheme.surface,
          body: shell,
          bottomNavigationBar: NavigationBar(
            backgroundColor: scheme.surface,
            selectedIndex: shell.currentIndex,
            onDestinationSelected: (i) {
              // Always open the Chat list root when the Chat tab is selected.
              if (i == 2) {
                context.go('/chat');
                return;
              }
              shell.goBranch(i, initialLocation: i == shell.currentIndex);
            },
            destinations: [
              NavigationDestination(
                icon: const Icon(Icons.explore_outlined),
                selectedIcon: const Icon(Icons.explore),
                label: isPoster ? 'My Gigs' : 'Discover',
              ),
              NavigationDestination(
                icon: const Icon(Icons.assignment_outlined),
                selectedIcon: const Icon(Icons.assignment),
                label: isPoster ? 'Applications' : 'My Applications',
              ),
              const NavigationDestination(
                icon: Icon(Icons.chat_bubble_outline),
                selectedIcon: Icon(Icons.chat_bubble),
                label: 'Chat',
              ),
              const NavigationDestination(
                icon: Icon(Icons.person_outline),
                selectedIcon: Icon(Icons.person),
                label: 'Profile',
              ),
            ],
          ),
        );
      },
    );
  }
}
