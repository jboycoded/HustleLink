import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../data/models/app_notification.dart';
import '../../data/services/engagement_service.dart';

class NotificationBell extends StatelessWidget {
  const NotificationBell({super.key});

  @override
  Widget build(BuildContext context) {
    final service = context.read<EngagementService>();
    final scheme = Theme.of(context).colorScheme;
    return StreamBuilder<List<AppNotification>>(
      stream: service.watchNotifications(),
      builder: (context, snapshot) {
        final unread = (snapshot.data ?? const <AppNotification>[])
            .where((item) => !item.isRead).length;
        return IconButton(
          tooltip: unread == 0 ? 'Notifications' : '$unread unread notifications',
          onPressed: () => context.push('/notifications'),
          icon: Stack(
            clipBehavior: Clip.none,
            children: [
              const Icon(Icons.notifications_none_rounded),
              if (unread > 0)
                Positioned(
                  right: -5,
                  top: -5,
                  child: Container(
                    constraints: const BoxConstraints(minWidth: 16, minHeight: 16),
                    padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                    decoration: BoxDecoration(
                      color: scheme.error,
                      borderRadius: BorderRadius.circular(99),
                    ),
                    child: Text(
                      unread > 99 ? '99+' : '$unread',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: scheme.onError, fontSize: 9, fontWeight: FontWeight.w800),
                    ),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }
}
