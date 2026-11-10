//import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../data/repositories/gig_repository.dart';
import '../../features/chat/chat_screen.dart';
import '../../features/chat/chat_view_model.dart';
import '../../features/matches/matches_screen.dart';
import '../../features/matches/matches_view_model.dart';
import '../../features/profile/profile_screen.dart';
import '../../features/swipe/swipe_screen.dart';
import '../../features/swipe/swipe_view_model.dart';
import '../widgets/app_shell.dart';

final appRouter = GoRouter(
  initialLocation: '/swipe',
  routes: [
    StatefulShellRoute.indexedStack(
      builder: (context, state, shell) => AppShell(shell: shell),
      branches: [
        StatefulShellBranch(routes: [
          GoRoute(
            path: '/swipe',
            builder: (context, state) => ChangeNotifierProvider(
              create: (ctx) => SwipeViewModel(ctx.read<GigRepository>())..load(),
              child: const SwipeScreen(),
            ),
          ),
        ]),
        StatefulShellBranch(routes: [
          GoRoute(
            path: '/matches',
            builder: (context, state) => ChangeNotifierProvider(
              create: (ctx) => MatchesViewModel(ctx.read<GigRepository>()), // loaded automatically via initState in your MatchesScreen
              child: const MatchesScreen(),
            ),
          ),
        ]),
        StatefulShellBranch(routes: [
          GoRoute(
            path: '/chat',
            builder: (context, state) => ChangeNotifierProvider(
              //create: (ctx) => ChatViewModel(ctx.read<GigRepository>())..load(),
              create: (ctx) => ChatViewModel()..load(),
              child: const ChatScreen(),
            ),
          ),
        ]),
        StatefulShellBranch(routes: [
          GoRoute(
            path: '/profile',
            builder: (context, state) => const ProfileScreen(),
          ),
        ]),
      ],
    ),
  ],
);
