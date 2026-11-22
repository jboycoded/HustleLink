import 'package:cloud_firestore/cloud_firestore.dart';

class ChatConversation {
  const ChatConversation({
    required this.id,
    required this.applicationId,
    required this.gigId,
    required this.gigTitle,
    required this.workerId,
    required this.posterId,
    required this.workerName,
    required this.posterName,
    required this.lastMessage,
    required this.lastSenderId,
    required this.lastReadAt,
    this.lastMessageAt,
    this.workerPhotoUrl,
    this.posterPhotoUrl,
    this.hiddenFor = const [],
  });

  final String id;
  final String applicationId;
  final String gigId;
  final String gigTitle;
  final String workerId;
  final String posterId;
  final String workerName;
  final String posterName;
  final String lastMessage;
  final String lastSenderId;
  final Map<String, DateTime?> lastReadAt;
  final DateTime? lastMessageAt;
  final String? workerPhotoUrl;
  final String? posterPhotoUrl;
  final List<String> hiddenFor;

  bool isHiddenFor(String userId) => hiddenFor.contains(userId);

  bool isUnreadFor(String userId) {
    if (lastSenderId.isEmpty || lastSenderId == userId || lastMessageAt == null) {
      return false;
    }
    final readAt = lastReadAt[userId];
    return readAt == null || lastMessageAt!.isAfter(readAt);
  }

  factory ChatConversation.fromMap(String id, Map<String, dynamic> data) {
    final timestamp = data['lastMessageAt'];
    final rawReadAt = data['lastReadAt'] as Map<String, dynamic>? ?? {};
    final readAt = <String, DateTime?>{};
    for (final entry in rawReadAt.entries) {
      readAt[entry.key] = entry.value is Timestamp
          ? (entry.value as Timestamp).toDate()
          : null;
    }
    return ChatConversation(
      id: id,
      applicationId: data['applicationId'] as String? ?? id,
      gigId: data['gigId'] as String? ?? '',
      gigTitle: data['gigTitle'] as String? ?? 'Gig',
      workerId: data['workerId'] as String? ?? '',
      posterId: data['posterId'] as String? ?? '',
      workerName: data['workerName'] as String? ?? 'Worker',
      posterName: data['posterName'] as String? ?? 'Poster',
      lastMessage: data['lastMessage'] as String? ?? 'Conversation started',
      lastSenderId: data['lastSenderId'] as String? ?? '',
      lastReadAt: readAt,
      lastMessageAt: timestamp is Timestamp ? timestamp.toDate() : null,
      workerPhotoUrl: data['workerPhotoUrl'] as String?,
      posterPhotoUrl: data['posterPhotoUrl'] as String?,
      hiddenFor: List<String>.from(data['hiddenFor'] as List? ?? const []),
    );
  }
}
