/// Local domain model representing individual speech bubbles in a message feed.
class ChatMessage {
  final String id;
  final String text;
  final bool isMe;
  final String timestamp;

  const ChatMessage({
    required this.id,
    required this.text,
    required this.isMe,
    required this.timestamp,
  });
}
