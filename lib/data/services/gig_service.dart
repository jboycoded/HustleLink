import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../models/gig.dart';
import '../models/gig_application.dart';

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

  Future<void> _syncPublicProfile(
    String uid,
    Map<String, dynamic>? profile,
  ) async {
    if (profile == null) return;
    await _firestore.collection('publicProfiles').doc(uid).set({
      'uid': uid,
      'fullName': profile['fullName'] as String? ?? '',
      'activeRole': profile['activeRole'] as String? ?? 'worker',
      'location': profile['location'] as String? ?? '',
      'skills': List<String>.from(profile['skills'] ?? []),
      'isAvailableForGigs': profile['isAvailableForGigs'] as bool? ?? true,
      'rating': (profile['rating'] as num?)?.toDouble() ?? 0,
      'completedGigs': (profile['completedGigs'] as num?)?.toInt() ?? 0,
      'proofVideoUrl': profile['proofVideoUrl'] as String?,
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
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
    await _syncPublicProfile(uid, profileData);

    final posterName =
        (profileData?['fullName'] as String?)?.trim().isNotEmpty == true
            ? (profileData!['fullName'] as String).trim()
            : (_auth.currentUser?.email ?? 'Poster');

    final document = _gigs.doc();

    await document.set({
      'title': title.trim(),
      'description': description.trim(),
      'category': category.trim(),
      'pay': pay,
      'posterId': uid,
      'posterName': posterName,
      'location': location.trim(),
      'when': when.trim(),
      'status': 'open',
      'proofVideoRequired': proofVideoRequired,
      'posterPhotoUrl': profileData?['photoUrl'],
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    });

    return document.id;
  }

  Stream<List<Gig>> watchAvailableGigs() {
    return _gigs.where('status', isEqualTo: 'open').snapshots().asyncMap((snapshot) async {
      final blocked = await _firestore.collection('users').doc(_uid)
          .collection('blockedUsers').get();
      final blockedIds = blocked.docs.map((doc) => doc.id).toSet();
      final gigs = snapshot.docs
          .where((document) => document.data()['posterId'] != _uid && !blockedIds.contains(document.data()['posterId']))
          .map((document) => Gig.fromMap(document.id, document.data()))
          .toList();
      gigs.sort((a, b) => (b.createdAt ?? DateTime(2000))
          .compareTo(a.createdAt ?? DateTime(2000)));
      return gigs;
    });
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
    await _syncPublicProfile(uid, workerProfile);

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
    await applicationRef.set({
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
    await _firestore.collection('notifications').add({
      'recipientId': gig.posterId,
      'actorId': uid,
      'type': 'application_received',
      'title': 'New gig application',
      'body': '${workerName == null || workerName.isEmpty ? 'A worker' : workerName} applied for ${gig.title}.',
      'relatedId': applicationId,
      'isRead': false,
      'createdAt': FieldValue.serverTimestamp(),
    });
  }

  Stream<List<Gig>> watchMyGigs() {
    return _gigs.where('posterId', isEqualTo: _uid).snapshots().map((snapshot) {
      final gigs = snapshot.docs
          .map((document) => Gig.fromMap(document.id, document.data()))
          .toList();
      gigs.sort((a, b) => (b.createdAt ?? DateTime(2000))
          .compareTo(a.createdAt ?? DateTime(2000)));
      return gigs;
    });
  }

  Stream<List<GigApplication>> watchWorkerApplications() {
    return _applications.where('workerId', isEqualTo: _uid).snapshots().map(
      (snapshot) => snapshot.docs
          .map((document) => GigApplication.fromMap(document.id, document.data()))
          .toList()
        ..sort((a, b) => (b.createdAt ?? DateTime(2000))
            .compareTo(a.createdAt ?? DateTime(2000))),
    );
  }

  Stream<List<GigApplication>> watchPosterApplications() {
    return _applications.where('posterId', isEqualTo: _uid).snapshots().map(
      (snapshot) => snapshot.docs
          .map((document) => GigApplication.fromMap(document.id, document.data()))
          .toList()
        ..sort((a, b) => (b.createdAt ?? DateTime(2000))
            .compareTo(a.createdAt ?? DateTime(2000))),
    );
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
      final snapshot = await applicationRef.get();
      if (!snapshot.exists) throw StateError('Application not found.');
      final data = snapshot.data()!;
      if (data['posterId'] != _uid) {
        throw StateError('Only the poster can review this application.');
      }
      if (data['status'] != 'pending') {
        throw StateError('This application has already been reviewed.');
      }
      await applicationRef.update({
        'status': 'rejected',
        'updatedAt': FieldValue.serverTimestamp(),
      });
      await _firestore.collection('notifications').add({
        'recipientId': data['workerId'],
        'actorId': _uid,
        'type': 'application_rejected',
        'title': 'Application update',
        'body': 'Your application for ${data['gigTitle'] ?? 'a gig'} was not selected.',
        'relatedId': applicationId,
        'isRead': false,
        'createdAt': FieldValue.serverTimestamp(),
      });
      return;
    }

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
      final notificationRef = _firestore.collection('notifications').doc();
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
    await _gigs.doc(gigId).update({
      'title': title.trim(),
      'description': description.trim(),
      'category': category.trim(),
      'pay': pay,
      'location': location.trim(),
      'when': when.trim(),
      'proofVideoRequired': proofVideoRequired,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> closeGig(String gigId) async {
    await _gigs.doc(gigId).update({
      'status': 'closed',
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> deleteGig(String gigId) async {
    await _gigs.doc(gigId).delete();
  }
}
