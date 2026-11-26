import 'package:cloud_firestore/cloud_firestore.dart';

class Gig {
  const Gig({
    required this.id,
    required this.title,
    required this.description,
    required this.category,
    required this.pay,
    required this.posterId,
    required this.posterName,
    required this.location,
    required this.when,
    required this.status,
    required this.proofVideoRequired,
    this.createdAt,
    this.updatedAt,
    this.distanceKm,
    this.workerCompletionConfirmed = false,
    this.posterCompletionConfirmed = false,
    this.posterPaymentConfirmed = false,
    this.workerPaymentConfirmed = false,
    this.paid = false,
    this.paidAt,
    this.completedAt,
    this.posterPhotoUrl,
    this.acceptedApplicationId,
    this.acceptedWorkerId,
  });

  final String id;
  final String title;
  final String description;
  final String category;
  final int pay;
  final String posterId;
  final String posterName;
  final String location;
  final String when;
  final String status;
  final bool proofVideoRequired;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  // Reserved for a future real distance calculation.
  final double? distanceKm;
  final bool workerCompletionConfirmed;
  final bool posterCompletionConfirmed;
  final bool posterPaymentConfirmed;
  final bool workerPaymentConfirmed;
  final bool paid;
  final DateTime? paidAt;
  final DateTime? completedAt;
  final String? posterPhotoUrl;
  final String? acceptedApplicationId;
  final String? acceptedWorkerId;

  bool get isOpen => status == 'open';
  bool get hasAcceptedParticipant =>
      acceptedWorkerId != null && acceptedWorkerId!.isNotEmpty;

  factory Gig.fromMap(String id, Map<String, dynamic> data) {
    DateTime? readDate(dynamic value) {
      if (value is Timestamp) return value.toDate();
      if (value is DateTime) return value;
      return null;
    }

    return Gig(
      id: id,
      title: data['title'] as String? ?? '',
      description: data['description'] as String? ?? '',
      category: data['category'] as String? ?? '',
      pay: (data['pay'] as num?)?.toInt() ?? 0,
      posterId: data['posterId'] as String? ?? '',
      posterName: data['posterName'] as String? ?? '',
      location: data['location'] as String? ?? '',
      when: data['when'] as String? ?? '',
      status: data['status'] as String? ?? 'open',
      proofVideoRequired:
          data['proofVideoRequired'] as bool? ?? true,
      createdAt: readDate(data['createdAt']),
      updatedAt: readDate(data['updatedAt']),
      workerCompletionConfirmed: data['workerCompletionConfirmed'] as bool? ?? false,
      posterCompletionConfirmed: data['posterCompletionConfirmed'] as bool? ?? false,
      posterPaymentConfirmed: data['posterPaymentConfirmed'] as bool? ?? false,
      workerPaymentConfirmed: data['workerPaymentConfirmed'] as bool? ?? false,
      paid: data['paid'] as bool? ?? false,
      paidAt: readDate(data['paidAt']),
      completedAt: readDate(data['completedAt']),
      posterPhotoUrl: data['posterPhotoUrl'] as String?,
      acceptedApplicationId: data['acceptedApplicationId'] as String?,
      acceptedWorkerId: data['acceptedWorkerId'] as String?,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'title': title,
      'description': description,
      'category': category,
      'pay': pay,
      'posterId': posterId,
      'posterName': posterName,
      'location': location,
      'when': when,
      'status': status,
      'proofVideoRequired': proofVideoRequired,
      'createdAt': createdAt == null
          ? FieldValue.serverTimestamp()
          : Timestamp.fromDate(createdAt!),
      'updatedAt': FieldValue.serverTimestamp(),
      if (acceptedApplicationId != null) 'acceptedApplicationId': acceptedApplicationId,
      if (acceptedWorkerId != null) 'acceptedWorkerId': acceptedWorkerId,
    };
  }
}
