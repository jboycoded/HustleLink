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
    this.lastMessageAt,
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
  final DateTime? lastMessageAt;

  factory ChatConversation.fromMap(String id, Map<String, dynamic> data) {
    final timestamp = data['lastMessageAt'];
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
      lastMessageAt: timestamp is Timestamp ? timestamp.toDate() : null,
    );
  }
}
