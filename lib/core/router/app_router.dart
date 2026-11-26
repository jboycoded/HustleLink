
import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../data/repositories/gig_repository.dart';
import '../../data/repositories/user_profile_repository.dart';
import '../../data/services/auth_service.dart';
import '../../features/auth/auth_screen.dart';
import '../../features/chat/chat_screen.dart';
import '../../features/chat/chat_conversation_screen.dart';
import '../../features/matches/matches_screen.dart';
import '../../features/matches/matches_view_model.dart';
import '../../features/notifications/notifications_screen.dart';
import '../../features/profile/profile_screen.dart';
import '../../features/profile/public_profile_screen.dart';
import '../../features/profile/profile_view_model.dart';
import '../../features/swipe/swipe_screen.dart';
import '../../features/swipe/swipe_view_model.dart';
import '../widgets/app_shell.dart';

class AuthRefreshNotifier extends ChangeNotifier {
  AuthRefreshNotifier(Stream<User?> authStream) {
    _subscription = authStream.listen((_) {
      notifyListeners();
    });
  }

  late final StreamSubscription<User?> _subscription;

  @override
  void dispose() {
    _subscription.cancel();
    super.dispose();
  }
}

GoRouter createAppRouter({
  required AuthService authService,
  required AuthRefreshNotifier authRefresh,
}) {
  return GoRouter(
    initialLocation: '/swipe',
    refreshListenable: authRefresh,
    redirect: (context, state) {
      final isSignedIn = authService.currentUser != null;
      final isOnAuthPage = state.matchedLocation == '/auth';

      if (!isSignedIn && !isOnAuthPage) {
        return '/auth';
      }

      if (isSignedIn && isOnAuthPage) {
        return '/swipe';
      }

      return null;
    },
    routes: [
      GoRoute(
        path: '/notifications',
        builder: (context, state) => const NotificationsScreen(),
      ),
      GoRoute(
        path: '/auth',
        builder: (context, state) => AuthScreen(
          authService: authService,
        ),
      ),
      StatefulShellRoute.indexedStack(
        builder: (context, state, shell) => AppShell(shell: shell),
        branches: [
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/swipe',
                builder: (context, state) => ChangeNotifierProvider(
                  create: (ctx) => SwipeViewModel(
                    ctx.read<GigRepository>(),
                    ctx.read<UserProfileRepository>(),
                  )..load(),
                  child: const SwipeScreen(),
                ),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/matches',
                builder: (context, state) => ChangeNotifierProvider(
                  create: (ctx) => MatchesViewModel(
  ctx.read<GigRepository>(),
  ctx.read<UserProfileRepository>(),
),
                  child: const MatchesScreen(),
                ),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/chat',
                builder: (context, state) => const ChatScreen(),
                routes: [
                  GoRoute(
                    path: ':conversationId',
                    builder: (context, state) => ChatConversationScreen(
                      conversationId: state.pathParameters['conversationId']!,
                    ),
                  ),
                ],
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/profile',
                builder: (context, state) => ChangeNotifierProvider(
                  create: (ctx) =>
                      ProfileViewModel(ctx.read<UserProfileRepository>())
                        ..load(),
                  child: const ProfileScreen(),
                ),
                routes: [
                  GoRoute(
                    path: ':userId',
                    builder: (context, state) => PublicProfileScreen(
                      userId: state.pathParameters['userId']!,
                    displayRole: state.uri.queryParameters['role'],
                    ),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    ],
  );
}
