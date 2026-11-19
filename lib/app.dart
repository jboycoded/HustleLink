import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import 'core/router/app_router.dart';
import 'core/theme/app_theme.dart';
import 'data/repositories/gig_repository.dart';
import 'data/repositories/user_profile_repository.dart';
import 'data/services/auth_service.dart';
import 'data/services/chat_service.dart';
import 'data/services/gig_service.dart';

class HustleLinkApp extends StatefulWidget {
  const HustleLinkApp({super.key});

  @override
  State<HustleLinkApp> createState() => _HustleLinkAppState();
}

class _HustleLinkAppState extends State<HustleLinkApp> {
  late final AuthService _authService;
  late final AuthRefreshNotifier _authRefresh;
  late final GoRouter _router;

  @override
  void initState() {
    super.initState();

    _authService = AuthService();
    _authRefresh = AuthRefreshNotifier(_authService.authStateChanges);
    _router = createAppRouter(
      authService: _authService,
      authRefresh: _authRefresh,
    );
  }

  @override
  void dispose() {
    _router.dispose();
    _authRefresh.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Provider<AuthService>.value(
      value: _authService,
      child: Provider<UserProfileRepository>(
        create: (_) => UserProfileRepository(),
        child: Provider<ChatService>(
          create: (_) => ChatService(),
          child: Provider<GigRepository>(
            create: (_) => GigRepository(GigService()),
            child: MaterialApp.router(
              title: 'HUSTLELINK',
              debugShowCheckedModeBanner: false,
              theme: AppTheme.light(),
              darkTheme: AppTheme.dark(),
              themeMode: ThemeMode.system,
              routerConfig: _router,
            ),
          ),
        ),
      ),
    );
  }
}
