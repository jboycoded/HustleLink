import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../core/theme/app_tokens.dart';
import '../../data/services/chat_service.dart';

class ChatConversationScreen extends StatefulWidget {
  const ChatConversationScreen({super.key, required this.conversationId});

  final String conversationId;

  @override
  State<ChatConversationScreen> createState() => _ChatConversationScreenState();
}

class _ChatConversationScreenState extends State<ChatConversationScreen> {
  final TextEditingController _controller = TextEditingController();
  bool _sending = false;
  bool _markingRead = false;
  StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? _readSubscription;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final service = context.read<ChatService>();
      _readSubscription = service.watchMessages(widget.conversationId).listen(
        (snapshot) {
          if (snapshot.docs.isEmpty || _markingRead || !mounted) return;
          final latest = snapshot.docs.last.data();
          if (latest['senderId'] == service.currentUserId) return;
          _markingRead = true;
          service.markAsRead(widget.conversationId).whenComplete(() {
            _markingRead = false;
          }).catchError((_) {
            _markingRead = false;
          });
        },
        onError: (_) {},
      );
    });
  }

  @override
  void dispose() {
    _readSubscription?.cancel();
    _controller.dispose();
    super.dispose();
  }

  String _initials(String name) => name
      .trim()
      .split(RegExp(r'\s+'))
      .where((part) => part.isNotEmpty)
      .take(2)
      .map((part) => part[0].toUpperCase())
      .join();

  Future<void> _send(ChatService service) async {
    final text = _controller.text.trim();
    if (text.isEmpty || _sending) return;
    setState(() => _sending = true);
    try {
      await service.sendMessage(
        conversationId: widget.conversationId,
        text: text,
      );
      _controller.clear();
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Message could not be sent. Try again.')),
        );
      }
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final service = context.read<ChatService>();
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return Scaffold(
      backgroundColor: scheme.surface,
      body: SafeArea(
        child: StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
          stream: service.watchConversation(widget.conversationId),
          builder: (context, conversationSnapshot) {
            if (conversationSnapshot.hasError) {
              return const Center(child: Text('Unable to open this conversation.'));
            }
            if (!conversationSnapshot.hasData) {
              return const Center(child: CircularProgressIndicator());
            }
            final data = conversationSnapshot.data!.data();
            if (data == null) {
              return const Center(child: Text('Conversation not found.'));
            }

            final workerId = data['workerId'] as String? ?? '';
            final isWorker = workerId == service.currentUserId;
            final recipientId = isWorker
                ? (data['posterId'] as String? ?? '')
                : (data['workerId'] as String? ?? '');
            final recipientName = isWorker
                ? (data['posterName'] as String? ?? 'Poster')
                : (data['workerName'] as String? ?? 'Worker');
            final gigTitle = data['gigTitle'] as String? ?? 'Gig';
            final recipientPhoto = isWorker ? data['posterPhotoUrl'] as String? : data['workerPhotoUrl'] as String?;

            return Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(12, 10, 18, 12),
                  child: Row(
                    children: [
                      IconButton(
                        onPressed: () => Navigator.of(context).pop(),
                        icon: const Icon(Icons.arrow_back_rounded),
                      ),
                      InkWell(
                        borderRadius: BorderRadius.circular(30),
                        onTap: recipientId.isEmpty
                            ? null
                            : () => context.push('/profile/$recipientId'),
                        child: CircleAvatar(
                          backgroundColor: scheme.secondary,
                          foregroundColor: scheme.onSecondary,
                          backgroundImage: recipientPhoto != null && recipientPhoto.isNotEmpty ? NetworkImage(recipientPhoto) : null,
                          child: recipientPhoto == null || recipientPhoto.isEmpty ? Text(_initials(recipientName)) : null,
                        ),
                      ),
                      const SizedBox(width: 11),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              recipientName,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: theme.textTheme.titleMedium
                                  ?.copyWith(fontWeight: FontWeight.w800),
                            ),
                            Text(
                              gigTitle,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: theme.textTheme.labelSmall
                                  ?.copyWith(color: scheme.onSurfaceVariant),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                Divider(height: 1, color: scheme.outline),
                Expanded(
                  child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                    stream: service.watchMessages(widget.conversationId),
                    builder: (context, messageSnapshot) {
                      if (messageSnapshot.hasError) {
                        return const Center(child: Text('Unable to load messages.'));
                      }
                      if (!messageSnapshot.hasData) {
                        return const Center(child: CircularProgressIndicator());
                      }
                      final messages = messageSnapshot.data!.docs;
                      if (messages.isEmpty) {
                        return Center(
                          child: Text(
                            'You can now chat about $gigTitle.',
                            style: theme.textTheme.bodyMedium
                                ?.copyWith(color: scheme.onSurfaceVariant),
                          ),
                        );
                      }
                      return ListView.builder(
                        reverse: false,
                        padding: const EdgeInsets.fromLTRB(18, 18, 18, 24),
                        itemCount: messages.length,
                        itemBuilder: (context, index) {
                          final message = messages[index].data();
                          final isMe = message['senderId'] == service.currentUserId;
                          final timestamp = message['createdAt'];
                          final time = timestamp is Timestamp
                              ? TimeOfDay.fromDateTime(timestamp.toDate()).format(context)
                              : '';
                          return Align(
                            alignment: isMe
                                ? Alignment.centerRight
                                : Alignment.centerLeft,
                            child: Container(
                              constraints: BoxConstraints(
                                maxWidth: MediaQuery.of(context).size.width * .78,
                              ),
                              margin: const EdgeInsets.only(bottom: 12),
                              padding: const EdgeInsets.symmetric(
                                horizontal: 15,
                                vertical: 11,
                              ),
                              decoration: BoxDecoration(
                                color: isMe ? scheme.secondary : scheme.surfaceContainerHighest,
                                borderRadius: BorderRadius.circular(AppTokens.rLg),
                                border: Border.all(color: scheme.outline),
                                boxShadow: AppTokens.hardShadow(scheme.outline, 2),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.end,
                                children: [
                                  Text(
                                    message['text'] as String? ?? '',
                                    style: theme.textTheme.bodyMedium?.copyWith(
                                      color: isMe ? scheme.onSecondary : scheme.onSurface,
                                    ),
                                  ),
                                  if (time.isNotEmpty) ...[
                                    const SizedBox(height: 4),
                                    Text(
                                      time,
                                      style: theme.textTheme.labelSmall?.copyWith(
                                        color: isMe
                                            ? scheme.onSecondary.withValues(alpha: .75)
                                            : scheme.onSurfaceVariant,
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                            ),
                          );
                        },
                      );
                    },
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                  child: Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _controller,
                          minLines: 1,
                          maxLines: 4,
                          maxLength: 4000,
                          textCapitalization: TextCapitalization.sentences,
                          decoration: InputDecoration(
                            hintText: 'Type a message...',
                            filled: true,
                            fillColor: scheme.surfaceContainerHighest,
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 17,
                              vertical: 12,
                            ),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(24),
                              borderSide: BorderSide(color: scheme.outline),
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(24),
                              borderSide: BorderSide(color: scheme.outline),
                            ),
                          ),
                          onSubmitted: (_) => _send(service),
                        ),
                      ),
                      const SizedBox(width: 10),
                      IconButton.filled(
                        onPressed: _sending ? null : () => _send(service),
                        icon: _sending
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(strokeWidth: 2),
                              )
                            : const Icon(Icons.send_rounded),
                      ),
                    ],
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}
