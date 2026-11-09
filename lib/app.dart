import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'core/router/app_router.dart';
import 'core/theme/app_theme.dart';
import 'data/repositories/gig_repository.dart';
import 'data/services/gig_service.dart';

class HustleLinkApp extends StatelessWidget {
  const HustleLinkApp({super.key});

  @override
  Widget build(BuildContext context) {
    return Provider<GigRepository>(
      // Swap GigService for a real backend service later; nothing else changes.
      create: (_) => GigRepository(const GigService()),
      child: MaterialApp.router(
        title: 'HUSTLELINK',
        debugShowCheckedModeBanner: false,
        theme: AppTheme.light(),
        routerConfig: appRouter,
      ),
    );
  }
}
