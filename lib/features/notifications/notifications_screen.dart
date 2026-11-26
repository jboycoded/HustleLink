import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../core/theme/app_tokens.dart';
import '../../data/services/engagement_service.dart';
import '../../data/repositories/user_profile_repository.dart';

class NotificationsScreen extends StatelessWidget {
  const NotificationsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final service = context.read<EngagementService>();
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Scaffold(
      appBar: AppBar(
        title: const Text('NOTIFICATIONS'),
        actions: [
          TextButton(
            onPressed: service.markAllNotificationsRead,
            child: const Text('Mark all read'),
          ),
        ],
      ),
      body: StreamBuilder(
        stream: service.watchNotifications(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return const Center(child: Text('Unable to load notifications.'));
          }
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          final notifications = snapshot.data!;
          if (notifications.isEmpty) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(28),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.notifications_none_rounded,
                        size: 48, color: scheme.onSurfaceVariant),
                    const SizedBox(height: 12),
                    Text('You’re all caught up.',
                        style: theme.textTheme.titleMedium
                            ?.copyWith(fontWeight: FontWeight.w800)),
                    const SizedBox(height: 6),
                    Text('Updates about applications and chats will appear here.',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: scheme.onSurfaceVariant)),
                  ],
                ),
              ),
            );
          }
          return ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: notifications.length,
            separatorBuilder: (_, __) => const SizedBox(height: 10),
            itemBuilder: (context, index) {
              final item = notifications[index];
              return Material(
                color: item.isRead ? scheme.surface : scheme.secondaryContainer,
                borderRadius: BorderRadius.circular(AppTokens.rMd),
                child: InkWell(
                  borderRadius: BorderRadius.circular(AppTokens.rMd),
                  onTap: () async {
                    if (!item.isRead) await service.markNotificationRead(item.id);
                    if (!context.mounted || item.relatedId.isEmpty) return;
                    if (item.type == 'application_received') {
                      try {
                        await context
                            .read<UserProfileRepository>()
                            .updateActiveRole('poster');
                      } catch (_) {
                        // Still open Matches; the screen will show its normal
                        // access or connection error if the role update fails.
                      }
                      if (context.mounted) context.push('/matches');
                    } else if (item.type == 'application_accepted' ||
                        item.type == 'application_rejected') {
                      if (item.type == 'application_accepted') {
                        try {
                          await context
                              .read<UserProfileRepository>()
                              .updateActiveRole('worker');
                        } catch (_) {}
                      }
                      if (context.mounted) {
                        if (item.type == 'application_accepted') {
                          context.push('/chat/${item.relatedId}');
                        } else {
                          context.push('/matches');
                        }
                      }
                    } else if (item.type == 'new_message') {
                      context.push('/chat/${item.relatedId}');
                    } else {
                      context.push('/matches');
                    }
                  },
                  child: Container(
                    padding: const EdgeInsets.all(15),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(AppTokens.rMd),
                      border: Border.all(color: scheme.outline,
                          width: AppTokens.borderWidth),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(_iconFor(item.type), color: scheme.primary),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(item.title,
                                  style: theme.textTheme.titleSmall
                                      ?.copyWith(fontWeight: FontWeight.w800)),
                              const SizedBox(height: 4),
                              Text(item.body),
                            ],
                          ),
                        ),
                        if (!item.isRead)
                          Container(
                            width: 9,
                            height: 9,
                            decoration: BoxDecoration(
                              color: scheme.primary,
                              shape: BoxShape.circle,
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }

  IconData _iconFor(String type) => switch (type) {
        'application_received' => Icons.person_add_alt_1_rounded,
        'application_accepted' => Icons.check_circle_rounded,
        'application_rejected' => Icons.info_outline_rounded,
        'new_message' => Icons.chat_bubble_outline_rounded,
        'gig_completion_confirmed' => Icons.task_alt_rounded,
        'payment_marked' => Icons.payments_outlined,
        'payment_received' => Icons.verified_rounded,
        _ => Icons.notifications_rounded,
      };
}
