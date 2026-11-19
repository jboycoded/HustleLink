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
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    });

    return document.id;
  }

  Future<List<Gig>> fetchAvailableGigs() async {
    final snapshot = await _gigs
        .where('status', isEqualTo: 'open')
        .get();

    final gigs = snapshot.docs
        .where((document) => document.data()['posterId'] != _uid)
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
      'status': 'pending',
      'createdAt': FieldValue.serverTimestamp(),
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
    final ref = _applications.doc(applicationId);
    final snapshot = await ref.get();
    if (!snapshot.exists) throw StateError('Application not found.');
    if (snapshot.data()?['posterId'] != _uid) {
      throw StateError('Only the poster can review this application.');
    }
    if (snapshot.data()?['status'] != 'pending') {
      throw StateError('This application has already been reviewed.');
    }
    final application = snapshot.data()!;

    if (status == 'accepted') {
      final gigSnapshot = await _gigs.doc(application['gigId'] as String).get();
      final gigData = gigSnapshot.data() ?? <String, dynamic>{};
      final conversationRef =
          _firestore.collection('conversations').doc(applicationId);
      final batch = _firestore.batch();

      batch.update(ref, {
        'status': status,
        'updatedAt': FieldValue.serverTimestamp(),
      });
      batch.set(conversationRef, {
        'applicationId': applicationId,
        'gigId': application['gigId'],
        'gigTitle': application['gigTitle'],
        'workerId': application['workerId'],
        'posterId': application['posterId'],
        'workerName': application['workerName'],
        'posterName': (gigData['posterName'] as String?) ?? 'Poster',
        'participants': [
          application['workerId'],
          application['posterId'],
        ],
        'lastMessage': 'Application accepted. You can now chat.',
        'lastMessageAt': FieldValue.serverTimestamp(),
        'lastSenderId': '',
        'lastReadAt': {
          application['posterId'] as String: FieldValue.serverTimestamp(),
        },
        'createdAt': FieldValue.serverTimestamp(),
      });
      await batch.commit();
    } else {
      await ref.update({
        'status': status,
        'updatedAt': FieldValue.serverTimestamp(),
      });
    }
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
