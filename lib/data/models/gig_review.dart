import 'package:cloud_firestore/cloud_firestore.dart';

class GigReview {
  const GigReview({
    required this.id,
    required this.gigId,
    required this.reviewerId,
    required this.revieweeId,
    required this.reviewerName,
    required this.rating,
    required this.comment,
    this.revieweeRole,
    this.createdAt,
  });

  final String id;
  final String gigId;
  final String reviewerId;
  final String revieweeId;
  final String reviewerName;
  final int rating;
  final String comment;
  final String? revieweeRole;
  final DateTime? createdAt;

  factory GigReview.fromMap(String id, Map<String, dynamic> data) {
    final timestamp = data['createdAt'];
    return GigReview(
      id: id,
      gigId: data['gigId'] as String? ?? '',
      reviewerId: data['reviewerId'] as String? ?? '',
      revieweeId: data['revieweeId'] as String? ?? '',
      reviewerName: data['reviewerName'] as String? ?? 'HustleLink member',
      rating: (data['rating'] as num?)?.toInt() ?? 0,
      comment: data['comment'] as String? ?? '',
      revieweeRole: data['revieweeRole'] as String?,
      createdAt: timestamp is Timestamp ? timestamp.toDate() : null,
    );
  }
}
