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

  String get currentUserId => _uid;

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
        .get();
    final batch = _db.batch();
    final unread = snapshot.docs.where((doc) => doc.data()['isRead'] != true).toList();
    for (final doc in unread) {
      batch.update(doc.reference, {'isRead': true});
    }
    if (unread.isNotEmpty) await batch.commit();
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

  Future<List<Map<String, String>>> getBlockedUsers() async {
    final snapshot = await _db.collection('users').doc(_uid)
        .collection('blockedUsers').get();
    final users = <Map<String, String>>[];
    for (final doc in snapshot.docs) {
      final profile = await _db.collection('publicProfiles').doc(doc.id).get();
      users.add({'id': doc.id, 'name': profile.data()?['fullName'] as String? ?? 'HustleLink member'});
    }
    return users;
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
      final alreadyConfirmed = uid == workerId
          ? data['workerCompletionConfirmed'] == true
          : data['posterCompletionConfirmed'] == true;
      if (alreadyConfirmed) {
        throw StateError('You have already confirmed completion.');
      }
      final workerConfirmed =
          data['workerCompletionConfirmed'] == true || uid == workerId;
      final posterConfirmed =
          data['posterCompletionConfirmed'] == true || uid == posterId;
      final updates = <String, dynamic>{
        if (uid == workerId) 'workerCompletionConfirmed': true,
        if (uid == posterId) 'posterCompletionConfirmed': true,
        'updatedAt': FieldValue.serverTimestamp(),
      };
      if (workerConfirmed && posterConfirmed && data['status'] != 'completed') {
        final applicationId = data['acceptedApplicationId'] as String? ??
            '${gigId}_${workerId}';
        final applicationRef =
            _db.collection('applications').doc(applicationId);
        final applicationSnapshot = await transaction.get(applicationRef);
        if (!applicationSnapshot.exists ||
            applicationSnapshot.data()?['status'] != 'accepted') {
          throw StateError('The accepted application could not be found.');
        }
        updates.addAll({
          'status': 'completed',
          'completedAt': FieldValue.serverTimestamp(),
        });
        transaction.update(applicationRef, {
          'status': 'completed',
          'updatedAt': FieldValue.serverTimestamp(),
        });
      }
      transaction.update(gigRef, updates);

      final otherId = uid == workerId ? posterId : workerId;
      final notificationRef = _notifications.doc('${gigId}_${uid}_completion');
      transaction.set(notificationRef, {
        'recipientId': otherId,
        'actorId': uid,
        'type': 'gig_completion_confirmed',
        'title': 'Completion confirmed',
        'body': 'The other party confirmed completion of $gigTitle.',
        'relatedId': gigId,
        'isRead': false,
        'createdAt': FieldValue.serverTimestamp(),
      });
    });
  }

  Future<void> confirmGigPayment({
    required String gigId,
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
        throw StateError('Only the gig participants can confirm payment.');
      }
      if (data['status'] != 'completed' ||
          data['workerCompletionConfirmed'] != true ||
          data['posterCompletionConfirmed'] != true) {
        throw StateError('Both parties must confirm completion first.');
      }
      if (data['paid'] == true) {
        throw StateError('This gig has already been marked as paid.');
      }
      if (uid == workerId && data['posterPaymentConfirmed'] != true) {
        throw StateError('The poster must mark the gig as paid before you confirm receipt.');
      }
      final posterConfirmed =
          data['posterPaymentConfirmed'] == true || uid == posterId;
      final workerConfirmed =
          data['workerPaymentConfirmed'] == true || uid == workerId;
      transaction.update(gigRef, {
        if (uid == posterId) 'posterPaymentConfirmed': true,
        if (uid == workerId) 'workerPaymentConfirmed': true,
        if (posterConfirmed && workerConfirmed) ...{
          'paid': true,
          'paidAt': FieldValue.serverTimestamp(),
        },
        'updatedAt': FieldValue.serverTimestamp(),
      });
    });
  }

  Future<bool> hasReviewed(String gigId) async {
    final snapshot = await _db.collection('reviews').doc('${gigId}_$_uid').get();
    return snapshot.exists;
  }

  Future<void> submitReview({
    required String gigId,
    required int rating,
    required String comment,
  }) async {
    if (rating < 1 || rating > 5) {
      throw ArgumentError('Choose a rating from 1 to 5 stars.');
    }
    if (comment.trim().length > 500) {
      throw ArgumentError('Reviews must be 500 characters or fewer.');
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
    final id = '${gigId}_$uid';
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
