import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_tokens.dart';
import 'chat_view_model.dart';

class ChatScreen extends StatefulWidget {
  const ChatScreen({super.key});

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final TextEditingController _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<ChatViewModel>();
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final colors = context.appColors;
    final text = theme.textTheme;

    return SafeArea(
      child: Column(
        children: [
          // 1. Client Header Bar Layout
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 12),
            child: Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: colors.peachSoft,
                    border: Border.all(
                      color: scheme.outline,
                      width: AppTokens.borderWidth,
                    ),
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    'AO',
                    style: text.titleSmall?.copyWith(fontWeight: FontWeight.w700),
                  ),
                ),
                const SizedBox(width: 12),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Ada O.',
                      style: text.titleMedium?.copyWith(fontWeight: FontWeight.w700),
                    ),
                    Text(
                      'Wig Install • Active Now',
                      style: text.labelSmall?.copyWith(color: colors.muted),
                    ),
                  ],
                ),
              ],
            ),
          ),

          const Divider(height: 1, thickness: 1),

          // 2. Chat Dialogue Feed
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
              itemCount: vm.messages.length,
              itemBuilder: (context, index) {
                final message = vm.messages[index];
                return Align(
                  alignment: message.isMe ? Alignment.centerRight : Alignment.centerLeft,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 6.0),
                    child: Container(
                      constraints: BoxConstraints(
                        maxWidth: MediaQuery.of(context).size.width * 0.75,
                      ),
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      decoration: BoxDecoration(
                        color: message.isMe ? scheme.primary : scheme.surface,
                        borderRadius: BorderRadius.circular(AppTokens.rLg),
                        border: Border.all(
                          color: scheme.outline,
                          width: AppTokens.borderWidth,
                        ),
                        boxShadow: AppTokens.hardShadow(scheme.outline, 2),
                      ),
                      child: Text(
                        message.text,
                        style: text.bodyMedium?.copyWith(
                          color: message.isMe ? scheme.onPrimary : scheme.onSurface,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),

          // 3. Neo-Brutalist Message Bar Input Field
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
            child: Row(
              children: [
                Expanded(
                  child: Container(
                    decoration: BoxDecoration(
                      color: scheme.surface,
                      borderRadius: BorderRadius.circular(999),
                      border: Border.all(
                        color: scheme.outline,
                        width: AppTokens.borderWidth,
                      ),
                      boxShadow: AppTokens.hardShadow(scheme.outline, 2),
                    ),
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: TextField(
                      controller: _controller,
                      decoration: InputDecoration(
                        hintText: 'Type a message...',
                        hintStyle: TextStyle(color: colors.muted),
                        border: InputBorder.none,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                GestureDetector(
                  onTap: () {
                    if (_controller.text.isNotEmpty) {
                      vm.sendMessage(_controller.text);
                      _controller.clear();
                    }
                  },
                  child: Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      color: colors.peachSoft,
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: scheme.outline,
                        width: AppTokens.borderWidth,
                      ),
                      boxShadow: AppTokens.hardShadow(scheme.outline, 2),
                    ),
                    child: Icon(
                      Icons.send_rounded, 
                      color: scheme.onSurface, 
                      size: 20,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
