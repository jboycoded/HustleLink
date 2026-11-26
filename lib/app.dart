import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import 'core/router/app_router.dart';
import 'core/theme/app_theme.dart';
import 'data/repositories/gig_repository.dart';
import 'data/repositories/user_profile_repository.dart';
import 'data/services/auth_service.dart';
import 'data/services/chat_service.dart';
import 'data/services/engagement_service.dart';
import 'data/services/gig_service.dart';
import 'data/services/profile_photo_service.dart';
import 'data/services/proof_video_service.dart';
import 'data/services/push_notification_service.dart';

class HustleLinkApp extends StatefulWidget {
  const HustleLinkApp({super.key});

  @override
  State<HustleLinkApp> createState() => _HustleLinkAppState();
}

class _HustleLinkAppState extends State<HustleLinkApp> {
  late final AuthService _authService;
  late final AuthRefreshNotifier _authRefresh;
  late final GoRouter _router;
  late final PushNotificationService _pushNotifications;

  @override
  void initState() {
    super.initState();
    _authService = AuthService();
    _authRefresh = AuthRefreshNotifier(_authService.authStateChanges);
    _router = createAppRouter(
      authService: _authService,
      authRefresh: _authRefresh,
    );
    _pushNotifications = PushNotificationService();
    _pushNotifications.initialize(onNotificationTap: _handleNotificationTap);
  }

  Future<void> _handleNotificationTap(Map<String, dynamic> data) async {
    if (!mounted) return;
    final type = data['type'] as String? ?? '';
    final relatedId = data['relatedId'] as String? ?? '';
    if ((type == 'new_message' || type == 'application_accepted') &&
        relatedId.isNotEmpty) {
      _router.go('/chat/$relatedId');
    } else {
      _router.go('/notifications');
    }
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
          child: Provider<ProofVideoService>(
            create: (_) => ProofVideoService(),
            child: Provider<ProfilePhotoService>(
              create: (_) => ProfilePhotoService(),
              child: Provider<EngagementService>(
                create: (_) => EngagementService(),
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
          ),
        ),
      ),
    );
  }
}
