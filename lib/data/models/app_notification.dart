import 'package:cloud_firestore/cloud_firestore.dart';

class AppNotification {
  const AppNotification({
    required this.id,
    required this.type,
    required this.title,
    required this.body,
    required this.relatedId,
    required this.isRead,
    this.createdAt,
  });

  final String id;
  final String type;
  final String title;
  final String body;
  final String relatedId;
  final bool isRead;
  final DateTime? createdAt;

  factory AppNotification.fromMap(String id, Map<String, dynamic> data) {
    final timestamp = data['createdAt'];
    return AppNotification(
      id: id,
      type: data['type'] as String? ?? 'general',
      title: data['title'] as String? ?? 'HustleLink',
      body: data['body'] as String? ?? '',
      relatedId: data['relatedId'] as String? ?? '',
      isRead: data['isRead'] as bool? ?? false,
      createdAt: timestamp is Timestamp ? timestamp.toDate() : null,
    );
  }
}
