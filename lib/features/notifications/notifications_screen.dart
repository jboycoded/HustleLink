import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../core/theme/app_tokens.dart';
import '../../data/services/engagement_service.dart';
import '../../data/repositories/user_profile_repository.dart';
import '../../data/services/chat_service.dart';

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
            onPressed: () => _confirmClearAllNotifications(context, service),
            child: const Text('Clear all'),
          ),
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
                    Text('Updates about matching gigs, applications and chats will appear here.',
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
                    // Resolve providers before the first await so no
                    // BuildContext lookup is performed across an async gap.
                    final profiles = context.read<UserProfileRepository>();
                    final chats = context.read<ChatService>();
                    String? resolvedRole;
                    final actionable = item.type == 'new_message'
                        ? (resolvedRole = await chats
                                .getCurrentUserRoleForConversation(item.relatedId)) !=
                            null
                        : (item.type == 'gig_completion_confirmed' ||
                                item.type == 'payment_marked' ||
                                item.type == 'payment_received')
                            ? (resolvedRole = await chats.getCurrentUserRoleForGig(
                                  item.relatedId,
                                  allowConversationFallback: false,
                                )) !=
                                null
                            : await service.isNotificationActionable(item);
                    if (!context.mounted) return;
                    if (!actionable) {
                      try {
                        await service.deleteNotification(item.id);
                      } catch (_) {}
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('This notification is no longer relevant and has been removed.'),
                          ),
                        );
                      }
                      return;
                    }
                    if (!item.isRead) {
                      service.markNotificationRead(item.id).catchError((_) {});
                    }
                    if (!context.mounted || item.relatedId.isEmpty) return;
                    if (item.type == 'application_received') {
                      try {
                        await profiles.updateActiveRole('poster');
                      } catch (_) {
                        // Still open Matches; the screen will show its normal
                        // access or connection error if the role update fails.
                      }
                      if (context.mounted) context.push('/matches');
                    } else if (item.type == 'application_accepted' ||
                        item.type == 'application_rejected') {
                      try {
                        await profiles.updateActiveRole('worker');
                      } catch (_) {}
                      if (context.mounted) {
                        if (item.type == 'application_accepted') {
                          context.push('/chat/${item.relatedId}');
                        } else {
                          context.push('/matches');
                        }
                      }
                    } else if (item.type == 'new_message') {
                      if (resolvedRole != null) {
                        try {
                          await profiles.updateActiveRole(resolvedRole);
                        } catch (_) {}
                      }
                      if (context.mounted) {
                        context.push('/chat/${item.relatedId}');
                      }
                    } else if (item.type == 'new_matching_gig') {
                      try {
                        await profiles.updateActiveRole('worker');
                      } catch (_) {}
                      if (context.mounted) {
                        context.push('/swipe?gigId=${item.relatedId}');
                      }
                    } else {
                      if (item.type == 'gig_completion_confirmed' ||
                          item.type == 'payment_marked' ||
                          item.type == 'payment_received') {
                        if (resolvedRole != null) {
                          try {
                            await profiles.updateActiveRole(resolvedRole);
                          } catch (_) {}
                        }
                      }
                      if (context.mounted) context.push('/matches');
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

  Future<void> _confirmClearAllNotifications(
    BuildContext context,
    EngagementService service,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Clear all notifications?'),
        content: const Text(
          'This will remove all notifications from your notification screen. '
          'It will not delete your applications, gigs, conversations, or messages.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Clear all'),
          ),
        ],
      ),
    );
    if (confirmed != true || !context.mounted) return;
    try {
      await service.clearAllNotifications();
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Notifications cleared.')),
        );
      }
    } catch (_) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not clear notifications. Please try again.')),
        );
      }
    }
  }

  IconData _iconFor(String type) => switch (type) {
        'application_received' => Icons.person_add_alt_1_rounded,
        'application_accepted' => Icons.check_circle_rounded,
        'application_rejected' => Icons.info_outline_rounded,
        'new_message' => Icons.chat_bubble_outline_rounded,
        'new_matching_gig' => Icons.work_outline_rounded,
        'gig_completion_confirmed' => Icons.task_alt_rounded,
        'payment_marked' => Icons.payments_outlined,
        'payment_received' => Icons.verified_rounded,
        _ => Icons.notifications_rounded,
      };
}
