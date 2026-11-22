import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../models/app_notification.dart';
import '../models/gig_review.dart';

class EngagementService {
  EngagementService({FirebaseFirestore? firestore, FirebaseAuth? auth})
      : _db = firestore ?? FirebaseFirestore.instance,
        _auth = auth ?? FirebaseAuth.instance;

  final FirebaseFirestore _db;
  final FirebaseAuth _auth;

  String get _uid {
    final value = _auth.currentUser?.uid;
    if (value == null) throw StateError('You must be signed in.');
    return value;
  }

  CollectionReference<Map<String, dynamic>> get _notifications =>
      _db.collection('notifications');

  Future<void> notifyUser({
    required String recipientId,
    required String type,
    required String title,
    required String body,
    String relatedId = '',
  }) async {
    if (recipientId.isEmpty || recipientId == _uid) return;
    await _notifications.add({
      'recipientId': recipientId,
      'actorId': _uid,
      'type': type,
      'title': title,
      'body': body,
      'relatedId': relatedId,
      'isRead': false,
      'createdAt': FieldValue.serverTimestamp(),
    });
  }

  Stream<List<AppNotification>> watchNotifications() {
    return _notifications
        .where('recipientId', isEqualTo: _uid)
        .snapshots()
        .map((snapshot) {
      final items = snapshot.docs
          .map((doc) => AppNotification.fromMap(doc.id, doc.data()))
          .toList();
      items.sort((a, b) => (b.createdAt ?? DateTime(2000))
          .compareTo(a.createdAt ?? DateTime(2000)));
      return items;
    });
  }

  Future<void> markNotificationRead(String id) async {
    await _notifications.doc(id).update({'isRead': true});
  }

  Future<void> markAllNotificationsRead() async {
    final snapshot = await _notifications
        .where('recipientId', isEqualTo: _uid)
        .where('isRead', isEqualTo: false)
        .get();
    final batch = _db.batch();
    for (final doc in snapshot.docs) {
      batch.update(doc.reference, {'isRead': true});
    }
    if (snapshot.docs.isNotEmpty) await batch.commit();
  }

  Future<void> blockUser(String targetId) async {
    if (targetId.isEmpty || targetId == _uid) {
      throw ArgumentError('You cannot block this account.');
    }
    await _db.collection('users').doc(_uid)
        .collection('blockedUsers').doc(targetId).set({
      'userId': targetId,
      'createdAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> unblockUser(String targetId) async {
    await _db.collection('users').doc(_uid)
        .collection('blockedUsers').doc(targetId).delete();
  }

  Future<Set<String>> getBlockedUserIds() async {
    final snapshot = await _db.collection('users').doc(_uid)
        .collection('blockedUsers').get();
    return snapshot.docs.map((doc) => doc.id).toSet();
  }

  Future<void> report({
    required String targetType,
    required String targetId,
    required String reason,
    String details = '',
  }) async {
    const reasons = {
      'spam', 'fraud', 'harassment', 'unsafe', 'inappropriate', 'other'
    };
    if (!reasons.contains(reason) || targetId.isEmpty) {
      throw ArgumentError('Choose a valid report reason.');
    }
    await _db.collection('reports').add({
      'reporterId': _uid,
      'targetType': targetType,
      'targetId': targetId,
      'reason': reason,
      'details': details.trim(),
      'status': 'open',
      'createdAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> confirmGigCompletion({
    required String gigId,
    required String gigTitle,
  }) async {
    final uid = _uid;
    final gigRef = _db.collection('gigs').doc(gigId);
    await _db.runTransaction((transaction) async {
      final snapshot = await transaction.get(gigRef);
      if (!snapshot.exists) throw StateError('Gig not found.');
      final data = snapshot.data()!;
      final workerId = data['acceptedWorkerId'] as String? ?? '';
      final posterId = data['posterId'] as String? ?? '';
      if (uid != workerId && uid != posterId) {
        throw StateError('Only the gig participants can confirm completion.');
      }
      if (data['status'] != 'filled' && data['status'] != 'completed') {
        throw StateError('This gig is not awaiting completion.');
      }
      final workerConfirmed = data['workerCompletionConfirmed'] == true || uid == workerId;
      final posterConfirmed = data['posterCompletionConfirmed'] == true || uid == posterId;
      transaction.update(gigRef, {
        if (uid == workerId) 'workerCompletionConfirmed': true,
        if (uid == posterId) 'posterCompletionConfirmed': true,
        if (workerConfirmed && posterConfirmed) ...{
          'status': 'completed',
          'completedAt': FieldValue.serverTimestamp(),
        },
        'updatedAt': FieldValue.serverTimestamp(),
      });
    });
  }

  Future<void> submitReview({
    required String gigId,
    required int rating,
    required String comment,
  }) async {
    if (rating < 1 || rating > 5) {
      throw ArgumentError('Choose a rating from 1 to 5 stars.');
    }
    final uid = _uid;
    final gigRef = _db.collection('gigs').doc(gigId);
    final gigSnapshot = await gigRef.get();
    if (!gigSnapshot.exists) throw StateError('Gig not found.');
    final gig = gigSnapshot.data()!;
    if (gig['status'] != 'completed' ||
        gig['workerCompletionConfirmed'] != true ||
        gig['posterCompletionConfirmed'] != true) {
      throw StateError('Both parties must confirm completion before reviewing.');
    }
    final workerId = gig['acceptedWorkerId'] as String? ?? '';
    final posterId = gig['posterId'] as String? ?? '';
    if (uid != workerId && uid != posterId) {
      throw StateError('Only the gig participants can leave a review.');
    }
    final revieweeId = uid == workerId ? posterId : workerId;
    final id = '${gigId}_${uid}';
    final ref = _db.collection('reviews').doc(id);
    final reviewer = await _db.collection('users').doc(uid).get();
    await _db.runTransaction((transaction) async {
      final existing = await transaction.get(ref);
      if (existing.exists) throw StateError('You have already reviewed this gig.');
      transaction.set(ref, {
        'gigId': gigId,
        'reviewerId': uid,
        'revieweeId': revieweeId,
        'reviewerName': reviewer.data()?['fullName'] ?? 'HustleLink member',
        'rating': rating,
        'comment': comment.trim(),
        'createdAt': FieldValue.serverTimestamp(),
      });
    });
  }

  Stream<List<GigReview>> watchReviewsFor(String userId) {
    return _db.collection('reviews')
        .where('revieweeId', isEqualTo: userId)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => GigReview.fromMap(doc.id, doc.data()))
            .toList());
  }
}
