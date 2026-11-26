import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../models/app_notification.dart';
import '../models/gig_review.dart';
import 'push_notification_service.dart';

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
    final notification = await _notifications.add({
      'recipientId': recipientId,
      'actorId': _uid,
      'type': type,
      'title': title,
      'body': body,
      'relatedId': relatedId,
      'isRead': false,
      'createdAt': FieldValue.serverTimestamp(),
    });
    await PushNotificationService().sendForNotification(notification.id);
  }

  Stream<List<AppNotification>> watchNotifications() {
    // Keep the notification list independent of related-document lookups.
    // Validating every application/gig/conversation here caused an N+1 read
    // on every snapshot and left the screen blank until all reads completed.
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

  // Notifications are historical records, but only remain visible while
  // their related application, conversation, or gig still exists for this
  // recipient. This prevents taps from opening deleted records.
  Future<bool> isNotificationActionable(AppNotification item) async {
    if (item.relatedId.isEmpty) return false;

    switch (item.type) {
      case 'application_received':
      case 'application_accepted':
      case 'application_rejected':
        final application =
            await _db.collection('applications').doc(item.relatedId).get();
        if (!application.exists) return false;
        final data = application.data()!;
        if (item.type == 'application_received') {
          // A new-application alert is no longer actionable after the poster
          // has accepted or rejected that application.
          return data['posterId'] == _uid && data['status'] == 'pending';
        }
        if (item.type == 'application_accepted') {
          return data['workerId'] == _uid &&
              (data['status'] == 'accepted' || data['status'] == 'completed');
        }
        return data['workerId'] == _uid && data['status'] == 'rejected';

      case 'new_message':
        final conversation =
            await _db.collection('conversations').doc(item.relatedId).get();
        if (!conversation.exists) return false;
        final data = conversation.data()!;
        final participants = data['participants'];
        final hiddenFor = data['hiddenFor'];
        return participants is List &&
            participants.contains(_uid) &&
            !(hiddenFor is List && hiddenFor.contains(_uid));

      case 'gig_completion_confirmed':
      case 'payment_marked':
      case 'payment_received':
        final gig = await _db.collection('gigs').doc(item.relatedId).get();
        if (!gig.exists) return false;
        final data = gig.data()!;
        return data['posterId'] == _uid ||
            data['acceptedWorkerId'] == _uid;

      default:
        return false;
    }
  }

  Future<void> deleteNotification(String id) async {
    await _notifications.doc(id).delete();
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

  Future<void> clearAllNotifications() async {
    final snapshot = await _notifications
        .where('recipientId', isEqualTo: _uid)
        .get();
    for (var start = 0; start < snapshot.docs.length; start += 450) {
      final batch = _db.batch();
      final end = start + 450 < snapshot.docs.length
          ? start + 450
          : snapshot.docs.length;
      for (final doc in snapshot.docs.sublist(start, end)) {
        batch.delete(doc.reference);
      }
      await batch.commit();
    }
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
    final notificationRef = _notifications.doc('${gigId}_${uid}_completion');
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
            '${gigId}_$workerId';
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
    await PushNotificationService().sendForNotification(notificationRef.id);
  }

  Future<void> confirmGigPayment({
    required String gigId,
  }) async {
    final uid = _uid;
    final gigRef = _db.collection('gigs').doc(gigId);
    DocumentReference<Map<String, dynamic>>? notificationRef;
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
      final alreadyConfirmed = uid == posterId
          ? data['posterPaymentConfirmed'] == true
          : data['workerPaymentConfirmed'] == true;
      if (alreadyConfirmed) {
        throw StateError('You have already confirmed this payment step.');
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
      final recipientId = uid == posterId ? workerId : posterId;
      final notificationId = uid == posterId
          ? '${gigId}_payment_marked'
          : '${gigId}_payment_received';
      notificationRef = _notifications.doc(notificationId);
      transaction.set(notificationRef!, {
        'recipientId': recipientId,
        'actorId': uid,
        'type': uid == posterId ? 'payment_marked' : 'payment_received',
        'title': uid == posterId ? 'Payment marked' : 'Payment receipt confirmed',
        'body': uid == posterId
            ? 'The poster marked this gig as paid. Confirm receipt once you receive the payment.'
            : 'The worker confirmed receipt of payment.',
        'relatedId': gigId,
        'isRead': false,
        'createdAt': FieldValue.serverTimestamp(),
      });
    });
    if (notificationRef != null) {
      await PushNotificationService().sendForNotification(notificationRef!.id);
    }
  }

  Future<bool> hasReviewed(String gigId) async {
    final snapshot = await _db.collection('reviews').doc('${gigId}_$_uid').get();
    return snapshot.exists;
  }

  Future<void> submitReview({
    required String gigId,
    required int rating,
    required String comment,
    required Map<String, int> categoryRatings,
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
    final expectedCategories = uid == posterId
        ? const ['quality', 'professionalism', 'communication', 'punctuality']
        : const ['paymentReliability', 'communication', 'fairTreatment', 'requirementClarity'];
    if (categoryRatings.keys.toSet().length != expectedCategories.length ||
        !categoryRatings.keys.toSet().containsAll(expectedCategories) ||
        categoryRatings.values.any((value) => value < 1 || value > 5)) {
      throw ArgumentError('Please rate all four review categories from 1 to 5.');
    }
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
        'revieweeRole': uid == workerId ? 'poster' : 'worker',
        'reviewerName': reviewer.data()?['fullName'] ?? 'HustleLink member',
        'rating': rating,
        'categoryRatings': categoryRatings,
        'comment': comment.trim(),
        'createdAt': FieldValue.serverTimestamp(),
      });
    });
  }

  Stream<List<GigReview>> watchReviewsFor(
    String userId, {
    required String role,
  }) {
    return _db.collection('reviews')
        .where('revieweeId', isEqualTo: userId)
        .snapshots()
        .asyncMap((snapshot) async {
      final reviews = await Future.wait(snapshot.docs.map((doc) async {
        final data = doc.data();
        final savedRole = data['revieweeRole'];
        var revieweeRole =
            savedRole is String ? savedRole.trim().toLowerCase() : null;

        // Legacy reviews did not store the role. Resolve those records in
        // parallel so one slow gig lookup does not hold up the whole list.
        if (revieweeRole == null || revieweeRole.isEmpty) {
          final gigId = data['gigId'] as String? ?? '';
          final reviewerId = data['reviewerId'] as String? ?? '';
          if (gigId.isNotEmpty) {
            try {
              final gigSnapshot =
                  await _db.collection('gigs').doc(gigId).get();
              final gig = gigSnapshot.exists
                  ? gigSnapshot.data()
                  : (await _db.collection('gigHistory').doc(gigId).get()).data();
              if (gig?['posterId'] == reviewerId) {
                revieweeRole = 'worker';
              } else if (gig?['acceptedWorkerId'] == reviewerId) {
                revieweeRole = 'poster';
              } else if (gig?['posterId'] == userId) {
                // Some older accepted gigs did not copy acceptedWorkerId
                // onto the gig. The poster can still read their own
                // applications, so use that record to classify the review.
                final applications = await _db.collection('applications')
                    .where('posterId', isEqualTo: userId)
                    .get();
                final acceptedWorkerExists = applications.docs.any((app) {
                  final application = app.data();
                  return application['gigId'] == gigId &&
                      application['workerId'] == reviewerId &&
                      (application['status'] == 'accepted' ||
                          application['status'] == 'completed');
                });
                if (acceptedWorkerExists) revieweeRole = 'poster';
              }
            } catch (_) {
              // Keep other reviews visible if a legacy gig cannot be read.
            }
          }
        }

        if (revieweeRole != role) return null;
        return GigReview.fromMap(
          doc.id,
          {...data, 'revieweeRole': revieweeRole},
        );
      }));

      final result = reviews.whereType<GigReview>().toList()
        ..sort((a, b) =>
            (b.createdAt ?? DateTime(2000))
                .compareTo(a.createdAt ?? DateTime(2000)));
      return result;
    });
  }
}
