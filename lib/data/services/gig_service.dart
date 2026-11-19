import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../models/gig.dart';

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
