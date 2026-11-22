import 'package:cloud_firestore/cloud_firestore.dart';

class GigApplication {
  const GigApplication({
    required this.id,
    required this.gigId,
    required this.workerId,
    required this.posterId,
    required this.workerName,
    required this.gigTitle,
    required this.gigCategory,
    required this.gigPay,
    required this.gigLocation,
    required this.status,
    this.createdAt,
    this.workerPhotoUrl,
  });

  final String id;
  final String gigId;
  final String workerId;
  final String posterId;
  final String workerName;
  final String gigTitle;
  final String gigCategory;
  final int gigPay;
  final String gigLocation;
  final String status;
  final DateTime? createdAt;
  final String? workerPhotoUrl;

  factory GigApplication.fromMap(
    String id,
    Map<String, dynamic> data,
  ) {
    final timestamp = data['createdAt'];

    return GigApplication(
      id: id,
      gigId: data['gigId'] as String? ?? '',
      workerId: data['workerId'] as String? ?? '',
      posterId: data['posterId'] as String? ?? '',
      workerName: data['workerName'] as String? ?? 'Worker',
      gigTitle: data['gigTitle'] as String? ?? 'Gig',
      gigCategory: data['gigCategory'] as String? ?? '',
      gigPay: (data['gigPay'] as num?)?.toInt() ?? 0,
      gigLocation: data['gigLocation'] as String? ?? '',
      status: data['status'] as String? ?? 'pending',
      createdAt: timestamp is Timestamp ? timestamp.toDate() : null,
      workerPhotoUrl: data['workerPhotoUrl'] as String?,
    );
  }
}
