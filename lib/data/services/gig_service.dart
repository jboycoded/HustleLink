import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../../core/constants/hustlelink_categories.dart';

import '../models/gig.dart';
import '../models/gig_application.dart';
import 'push_notification_service.dart';

class GigService {
  GigService({
    FirebaseFirestore? firestore,
    FirebaseAuth? auth,
  })  : _firestore = firestore ?? FirebaseFirestore.instance,
        _auth = auth ?? FirebaseAuth.instance;

  final FirebaseFirestore _firestore;
  final FirebaseAuth _auth;

  CollectionReference<Map<String, dynamic>> get _gigs =>
      _firestore.collection('gigs');

  CollectionReference<Map<String, dynamic>> get _applications =>
      _firestore.collection('applications');

  String get _uid {
    final user = _auth.currentUser;

    if (user == null) {
      throw StateError('You must be signed in to manage gigs.');
    }

    return user.uid;
  }


  Future<String> createGig({
    required String title,
    required String description,
    required String category,
    required int pay,
    required String location,
    required String when,
    bool proofVideoRequired = true,
  }) async {
    final uid = _uid;

    final profile = await _firestore.collection('users').doc(uid).get();
    final profileData = profile.data();

    final posterName =
        (profileData?['fullName'] as String?)?.trim().isNotEmpty == true
            ? (profileData!['fullName'] as String).trim()
            : (_auth.currentUser?.email ?? 'Poster');

    final document = _gigs.doc();

    await document.set({
      'title': title.trim(),
      'description': description.trim(),
      'category': HustleLinkCategories.canonicalize(category),
      'pay': pay,
      'posterId': uid,
      'posterName': posterName,
      'location': location.trim(),
      'when': when.trim(),
      'status': 'open',
      'proofVideoRequired': proofVideoRequired,
      'posterPhotoUrl': profileData?['photoUrl'],
      'createdAt': Timestamp.now(),
      'updatedAt': FieldValue.serverTimestamp(),
    });

    // Notify available Worker-mode profiles whose saved skills include
    // this category. Delivery is best-effort and cannot undo a posted gig.
    try {
      await _notifyMatchingWorkers(
        gigId: document.id,
        title: title.trim(),
        category: HustleLinkCategories.canonicalize(category),
        pay: pay,
      );
    } catch (_) {
      // The gig is already live; a notification failure must not fail posting.
    }

    return document.id;
  }

  Future<void> _notifyMatchingWorkers({
    required String gigId,
    required String title,
    required String category,
    required int pay,
  }) async {
    final profiles = await _firestore
        .collection('publicProfiles')
        .where('isAvailableForGigs', isEqualTo: true)
        .get();

    final matches = profiles.docs.where((profile) {
      final skills = profile.data()['skills'];
      return profile.id != _uid &&
          profile.data()['activeRole'] == 'worker' &&
          skills is List &&
          skills.whereType<String>().any(
            (skill) => skill.trim() == category,
          );
    }).toList();

    final pushService = PushNotificationService();
    // Keep each batch below Firestore's 20-document access-call limit in rules.
    for (var start = 0; start < matches.length; start += 19) {
      final chunk = matches.skip(start).take(19).toList();
      final batch = _firestore.batch();
      final notificationIds = <String>[];
      for (final profile in chunk) {
        final ref = _firestore.collection('notifications')
            .doc('new_gig_${gigId}_${profile.id}');
        notificationIds.add(ref.id);
        batch.set(ref, {
          'recipientId': profile.id,
          'actorId': _uid,
          'type': 'new_matching_gig',
          'title': 'A new gig matches your skills',
          'body': '$title · $category · ₦$pay',
          'relatedId': gigId,
          'isRead': false,
          'createdAt': FieldValue.serverTimestamp(),
        });
      }
      await batch.commit();
      for (final id in notificationIds) {
        unawaited(pushService.sendForNotification(id).catchError((_) {}));
      }
    }
  }

  Stream<List<Gig>> watchAvailableGigs() {
    late StreamController<List<Gig>> controller;
    StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? gigsSubscription;
    StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? blockedSubscription;
    QuerySnapshot<Map<String, dynamic>>? latestGigs;
    Set<String> blockedIds = {};

    void emit() {
      final snapshot = latestGigs;
      if (snapshot == null || controller.isClosed) return;
      final gigs = snapshot.docs
          .where((document) =>
              document.data()['posterId'] != _uid &&
              !blockedIds.contains(document.data()['posterId']))
          .map((document) => Gig.fromMap(document.id, document.data()))
          .toList();
      gigs.sort((a, b) => (b.createdAt ?? DateTime(2000))
          .compareTo(a.createdAt ?? DateTime(2000)));
      controller.add(gigs);
    }

    controller = StreamController<List<Gig>>(
      onListen: () {
        gigsSubscription = _gigs
            .where('status', isEqualTo: 'open')
            .snapshots()
            .listen((snapshot) {
          latestGigs = snapshot;
          emit();
        }, onError: controller.addError);
        blockedSubscription = _firestore
            .collection('users')
            .doc(_uid)
            .collection('blockedUsers')
            .snapshots()
            .listen((snapshot) {
          blockedIds = snapshot.docs.map((doc) => doc.id).toSet();
          emit();
        }, onError: controller.addError);
      },
      onCancel: () async {
        await gigsSubscription?.cancel();
        await blockedSubscription?.cancel();
      },
    );
    return controller.stream;
  }

  Future<List<Gig>> fetchAvailableGigs() async {
    final snapshot = await _gigs
        .where('status', isEqualTo: 'open')
        .get();

    final blocked = await _firestore.collection('users').doc(_uid)
        .collection('blockedUsers').get();
    final blockedIds = blocked.docs.map((doc) => doc.id).toSet();
    final gigs = snapshot.docs
        .where((document) => document.data()['posterId'] != _uid && !blockedIds.contains(document.data()['posterId']))
        .map((document) => Gig.fromMap(
              document.id,
              document.data(),
            ))
        .toList();

    gigs.sort((a, b) {
      final aDate = a.createdAt;
      final bDate = b.createdAt;

      if (aDate == null && bDate == null) return 0;
      if (aDate == null) return 1;
      if (bDate == null) return -1;

      return bDate.compareTo(aDate);
    });

    return gigs;
  }

  Future<Gig?> fetchGigById(String gigId) async {
    final document = await _gigs.doc(gigId).get();
    if (!document.exists) return null;
    return Gig.fromMap(document.id, document.data()!);
  }

  Future<List<Gig>> fetchMyGigs() async {
    final snapshot = await _gigs
        .where('posterId', isEqualTo: _uid)
        .get();

    final gigs = snapshot.docs
        .map((document) => Gig.fromMap(
              document.id,
              document.data(),
            ))
        // Closed gigs leave the active Poster Swipe list, but remain in
        // the Matches history stream and its Closed filter.
        .where((gig) => gig.status != 'closed')
        .toList();

    gigs.sort((a, b) {
      final aDate = a.createdAt;
      final bDate = b.createdAt;

      if (aDate == null && bDate == null) return 0;
      if (aDate == null) return 1;
      if (bDate == null) return -1;

      return bDate.compareTo(aDate);
    });

    return gigs;
  }

  Future<void> submitApplication(Gig gig) async {
    final uid = _uid;

    if (gig.posterId == uid) {
      throw StateError('You cannot apply to your own gig.');
    }
    final blockedByMe = await _firestore.collection('users').doc(uid)
        .collection('blockedUsers').doc(gig.posterId).get();
    if (blockedByMe.exists) {
      throw StateError('You have blocked this poster and cannot apply.');
    }
    // Whether the poster has blocked this worker is enforced by the
    // applications create rule. A client cannot read another user's
    // private blockedUsers subcollection.

    final gigDocument = await _gigs.doc(gig.id).get();

    if (!gigDocument.exists) {
      throw StateError('This gig is no longer available.');
    }

    final gigData = gigDocument.data()!;

    if (gigData['status'] != 'open') {
      throw StateError('This gig is no longer accepting applications.');
    }

    final profileDocument =
        await _firestore.collection('users').doc(uid).get();

    final workerProfile = profileDocument.data();

    if (gigData['proofVideoRequired'] == true) {
      final proofVideoUrl = workerProfile?['proofVideoUrl'] as String?;
      if (proofVideoUrl == null || proofVideoUrl.isEmpty) {
        throw StateError(
          'This gig requires a 30-second profile video. Add one to your profile before applying.',
        );
      }
    }

    final workerName =
        (workerProfile?['fullName'] as String?)?.trim();

    final applicationId = '${gig.id}_$uid';
    final applicationRef = _applications.doc(applicationId);

    // Use a direct create write. The deterministic document ID prevents
    // duplicate applications, while Firestore rules reject updates to an
    // existing application. A transaction read here would be denied for a
    // not-yet-created document by the application's read rules.
    final batch = _firestore.batch();
    batch.set(applicationRef, {
      'gigId': gig.id,
      'workerId': uid,
      'posterId': gig.posterId,
      'workerName':
          workerName == null || workerName.isEmpty ? 'Worker' : workerName,
      'gigTitle': gigData['title'] ?? gig.title,
      'gigCategory': gigData['category'] ?? gig.category,
      'gigPay': gigData['pay'] ?? gig.pay,
      'gigLocation': gigData['location'] ?? gig.location,
      'workerPhotoUrl': workerProfile?['photoUrl'],
      'status': 'pending',
      'createdAt': FieldValue.serverTimestamp(),
    });
    final notificationRef = _firestore.collection('notifications').doc();
    batch.set(notificationRef, {
      'recipientId': gig.posterId,
      'actorId': uid,
      'type': 'application_received',
      'title': 'New gig application',
      'body': '${workerName == null || workerName.isEmpty ? 'A worker' : workerName} applied for ${gig.title}.',
      'relatedId': applicationId,
      'isRead': false,
      'createdAt': FieldValue.serverTimestamp(),
    });
    await batch.commit();
    await PushNotificationService().sendForNotification(notificationRef.id);
  }

  Stream<List<Gig>> watchMyGigs({void Function(bool fromCache)? onCacheState}) {
    return _gigs.where('posterId', isEqualTo: _uid)
        .snapshots(includeMetadataChanges: true).map((snapshot) {
      onCacheState?.call(snapshot.metadata.isFromCache);
      final gigs = snapshot.docs
          .map((document) => Gig.fromMap(document.id, document.data()))
          .toList();
      gigs.sort((a, b) => (b.createdAt ?? DateTime(2000))
          .compareTo(a.createdAt ?? DateTime(2000)));
      return gigs;
    });
  }

  Stream<List<GigApplication>> watchWorkerApplications({void Function(bool fromCache)? onCacheState}) {
    return _applications.where('workerId', isEqualTo: _uid)
        .snapshots(includeMetadataChanges: true).map((snapshot) {
      onCacheState?.call(snapshot.metadata.isFromCache);
      return snapshot.docs
          .map((document) => GigApplication.fromMap(document.id, document.data()))
          .toList()
        ..sort((a, b) => (b.createdAt ?? DateTime(2000))
            .compareTo(a.createdAt ?? DateTime(2000)));
    });
  }

  Stream<List<GigApplication>> watchPosterApplications({void Function(bool fromCache)? onCacheState}) {
    return _applications.where('posterId', isEqualTo: _uid)
        .snapshots(includeMetadataChanges: true).map((snapshot) {
      onCacheState?.call(snapshot.metadata.isFromCache);
      return snapshot.docs
          .map((document) => GigApplication.fromMap(document.id, document.data()))
          .toList()
        ..sort((a, b) => (b.createdAt ?? DateTime(2000))
            .compareTo(a.createdAt ?? DateTime(2000)));
    });
  }

  Future<List<GigApplication>> fetchWorkerApplications() async {
    final snapshot = await _applications
        .where('workerId', isEqualTo: _uid)
        .get();

    final applications = snapshot.docs
        .map((document) => GigApplication.fromMap(
              document.id,
              document.data(),
            ))
        .toList();

    applications.sort((a, b) {
      return (b.createdAt ?? DateTime(2000))
          .compareTo(a.createdAt ?? DateTime(2000));
    });

    return applications;
  }

  Future<List<GigApplication>> fetchPosterApplications() async {
    final snapshot = await _applications
        .where('posterId', isEqualTo: _uid)
        .get();

    final applications = snapshot.docs
        .map((document) => GigApplication.fromMap(
              document.id,
              document.data(),
            ))
        .toList();

    applications.sort((a, b) {
      return (b.createdAt ?? DateTime(2000))
          .compareTo(a.createdAt ?? DateTime(2000));
    });

    return applications;
  }

  Future<void> updateApplicationStatus({
    required String applicationId,
    required String status,
  }) async {
    if (status != 'accepted' && status != 'rejected') {
      throw ArgumentError('Application status must be accepted or rejected.');
    }

    final applicationRef = _applications.doc(applicationId);
    if (status == 'rejected') {
      final notificationRef = _firestore.collection('notifications').doc();
      await _firestore.runTransaction((transaction) async {
        final snapshot = await transaction.get(applicationRef);
        if (!snapshot.exists) throw StateError('Application not found.');
        final data = snapshot.data()!;
        if (data['posterId'] != _uid) {
          throw StateError('Only the poster can review this application.');
        }
        if (data['status'] != 'pending') {
          throw StateError('This application has already been reviewed.');
        }
        transaction.update(applicationRef, {
          'status': 'rejected',
          'updatedAt': FieldValue.serverTimestamp(),
        });
        transaction.set(notificationRef, {
          'recipientId': data['workerId'],
          'actorId': _uid,
          'type': 'application_rejected',
          'title': 'Application update',
          'body': 'Your application for ${data['gigTitle'] ?? 'a gig'} was not selected.',
          'relatedId': applicationId,
          'isRead': false,
          'createdAt': FieldValue.serverTimestamp(),
        });
      });
      await PushNotificationService().sendForNotification(notificationRef.id);
      return;
    }

    final notificationRef = _firestore.collection('notifications').doc();
    await _firestore.runTransaction((transaction) async {
      final applicationSnapshot = await transaction.get(applicationRef);
      if (!applicationSnapshot.exists) {
        throw StateError('Application not found.');
      }
      final application = applicationSnapshot.data()!;
      if (application['posterId'] != _uid) {
        throw StateError('Only the poster can review this application.');
      }
      if (application['status'] != 'pending') {
        throw StateError('This application has already been reviewed.');
      }

      final gigId = application['gigId'] as String;
      final gigRef = _gigs.doc(gigId);
      final gigSnapshot = await transaction.get(gigRef);
      if (!gigSnapshot.exists || gigSnapshot.data()?['status'] != 'open') {
        throw StateError('This gig is no longer available for acceptance.');
      }
      final gigData = gigSnapshot.data()!;
      final conversationRef =
          _firestore.collection('conversations').doc(applicationId);

      transaction.update(applicationRef, {
        'status': 'accepted',
        'updatedAt': FieldValue.serverTimestamp(),
      });
      transaction.update(gigRef, {
        'status': 'filled',
        'acceptedApplicationId': applicationId,
        'acceptedWorkerId': application['workerId'],
        'updatedAt': FieldValue.serverTimestamp(),
      });
      transaction.set(notificationRef, {
        'recipientId': application['workerId'],
        'actorId': _uid,
        'type': 'application_accepted',
        'title': 'You got the gig!',
        'body': 'Your application for ${application['gigTitle'] ?? 'the gig'} was accepted. You can now chat with the poster.',
        'relatedId': applicationId,
        'isRead': false,
        'createdAt': FieldValue.serverTimestamp(),
      });
      transaction.set(conversationRef, {
        'applicationId': applicationId,
        'gigId': gigId,
        'gigTitle': (application['gigTitle'] as String?)?.trim().isNotEmpty == true
            ? (application['gigTitle'] as String).trim()
            : ((gigData['title'] as String?)?.trim().isNotEmpty == true
                ? (gigData['title'] as String).trim()
                : 'Gig'),
        'workerId': application['workerId'],
        'posterId': application['posterId'],
        'workerName': (application['workerName'] as String?)?.trim().isNotEmpty == true
            ? (application['workerName'] as String).trim()
            : 'Worker',
        'posterName': (gigData['posterName'] as String?) ?? 'Poster',
        'workerPhotoUrl': application['workerPhotoUrl'],
        'posterPhotoUrl': gigData['posterPhotoUrl'],
        'participants': [application['workerId'], application['posterId']],
        'lastMessage': 'Application accepted. You can now chat.',
        'lastMessageAt': FieldValue.serverTimestamp(),
        'lastSenderId': '',
        'lastReadAt': {
          application['posterId'] as String: FieldValue.serverTimestamp(),
        },
        'createdAt': FieldValue.serverTimestamp(),
      });
    });
    await PushNotificationService().sendForNotification(notificationRef.id);
  }

  Future<void> deleteWorkerApplication(String applicationId) async {
    final ref = _applications.doc(applicationId);
    final snapshot = await ref.get();
    if (!snapshot.exists) return;
    final data = snapshot.data()!;
    if (data['workerId'] != _uid) {
      throw StateError('You can only remove your own applications.');
    }
    if (data['status'] != 'rejected') {
      throw StateError('Only rejected applications can be removed.');
    }
    await ref.delete();
  }

  Future<void> updateGig({
    required String gigId,
    required String title,
    required String description,
    required String category,
    required int pay,
    required String location,
    required String when,
    required bool proofVideoRequired,
  }) async {
    final gigSnapshot = await _gigs.doc(gigId).get();
    if (!gigSnapshot.exists || gigSnapshot.data()?['posterId'] != _uid) {
      throw StateError('Gig not found or you do not own this gig.');
    }
    if ((gigSnapshot.data()?['status'] as String? ?? 'open') != 'open') {
      throw StateError('Only open gigs can be edited.');
    }
    await _gigs.doc(gigId).update({
      'title': title.trim(),
      'description': description.trim(),
      'category': HustleLinkCategories.canonicalize(category),
      'pay': pay,
      'location': location.trim(),
      'when': when.trim(),
      'proofVideoRequired': proofVideoRequired,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> closeGig(String gigId) async {
    final gigRef = _gigs.doc(gigId);
    final snapshot = await gigRef.get();
    if (!snapshot.exists || snapshot.data()?['posterId'] != _uid) {
      throw StateError('Gig not found or you do not own this gig.');
    }
    if (snapshot.data()?['status'] != 'open') {
      throw StateError('Only open gigs can be closed.');
    }

    // Protect legacy records where an application was accepted before the
    // gig's accepted-participant fields were consistently populated.
    final applications = await _applications
        .where('gigId', isEqualTo: gigId)
        .where('posterId', isEqualTo: _uid)
        .get();
    final hasAcceptedApplication = applications.docs.any((application) {
      final status = application.data()['status'];
      return status == 'accepted' || status == 'completed';
    });
    if (hasAcceptedApplication) {
      throw StateError(
        'This gig already has an accepted worker and cannot be closed.',
      );
    }

    await gigRef.update({
      'status': 'closed',
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> deleteGig(String gigId) async {
    final gigRef = _gigs.doc(gigId);
    final gigSnapshot = await gigRef.get();
    if (!gigSnapshot.exists) return;
    final gig = gigSnapshot.data()!;
    if (gig['posterId'] != _uid) {
      throw StateError('Only the poster can delete this gig.');
    }
    if (gig['status'] != 'closed' && gig['status'] != 'completed') {
      throw StateError('Only closed or completed gigs can be deleted from these records.');
    }

    final applications = await _applications
        .where('gigId', isEqualTo: gigId)
        .where('posterId', isEqualTo: _uid)
        .get();
    final hasAcceptedApplication = applications.docs.any((application) {
      final data = application.data();
      return data['status'] == 'accepted' || data['status'] == 'completed';
    });
    final hasAcceptedParticipant =
        (gig['acceptedWorkerId'] as String?)?.isNotEmpty == true ||
        (gig['acceptedApplicationId'] as String?)?.isNotEmpty == true ||
        hasAcceptedApplication;

    if (hasAcceptedParticipant) {
      final isCompletedAndPaid =
          gig['status'] == 'completed' && gig['paid'] == true;
      if (!isCompletedAndPaid) {
        throw StateError(
          'This gig has an accepted worker. It can only be deleted after completion and payment have both been confirmed.',
        );
      }
    } else if (gig['status'] != 'closed') {
      throw StateError(
        'A gig without an accepted participant can only be deleted after it is closed.',
      );
    }

    final conversations = await _firestore
        .collection('conversations')
        .where('gigId', isEqualTo: gigId)
        .where('participants', arrayContains: _uid)
        .get();
    if (conversations.docs.length > 498) {
      throw StateError(
        'This gig has too many conversation records to archive safely. Please contact support.',
      );
    }

    String? archivedWorkerId = gig['acceptedWorkerId'] as String?;
    if (hasAcceptedParticipant &&
        (archivedWorkerId == null || archivedWorkerId.isEmpty)) {
      for (final application in applications.docs) {
        final data = application.data();
        if (data['status'] == 'accepted' || data['status'] == 'completed') {
          archivedWorkerId = data['workerId'] as String?;
          break;
        }
      }
    }

    // Archive the outcome before removing application records. The
    // immutable summary is ignored by profile totals while the live gig still
    // exists, and becomes the source of truth once the gig is deleted.
    final historyRef = _firestore.collection('gigHistory').doc(gigId);
    final historySnapshot = await historyRef.get();
    if (!historySnapshot.exists) {
      await historyRef.set({
        'gigId': gigId,
        'posterId': _uid,
        'acceptedWorkerId': archivedWorkerId,
        'status': gig['status'],
        'paid': gig['paid'] == true,
        'createdAt': gig['createdAt'],
        'completedAt': gig['completedAt'],
        'archivedAt': FieldValue.serverTimestamp(),
      });
    }

    // Remove application records while the parent gig still exists, because
    // Firestore rules verify the poster against that parent record.
    for (var start = 0; start < applications.docs.length; start += 450) {
      final batch = _firestore.batch();
      final end = start + 450 < applications.docs.length
          ? start + 450
          : applications.docs.length;
      for (final application in applications.docs.sublist(start, end)) {
        batch.delete(application.reference);
      }
      await batch.commit();
    }

    // Archive the conversation only for the poster who deleted this gig.
    // The worker's chat list and the shared message history remain intact.
    final finalBatch = _firestore.batch();
    for (final conversation in conversations.docs) {
      final hiddenFor = (conversation.data()['hiddenFor'] as List<dynamic>? ?? [])
          .whereType<String>()
          .toSet();
      if (hiddenFor.add(_uid)) {
        finalBatch.update(conversation.reference, {
          'hiddenFor': hiddenFor.toList(),
        });
      }
    }

    finalBatch.delete(gigRef);
    await finalBatch.commit();
  }
}
