import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../../features/profile/models/user_profile.dart';

class UserProfileRepository {
  UserProfileRepository({
    FirebaseFirestore? firestore,
    FirebaseAuth? auth,
  })  : _firestore = firestore ?? FirebaseFirestore.instance,
        _auth = auth ?? FirebaseAuth.instance;

  final FirebaseFirestore _firestore;
  final FirebaseAuth _auth;

  CollectionReference<Map<String, dynamic>> get _users =>
      _firestore.collection('users');

  String get _uid {
    final user = _auth.currentUser;

    if (user == null) {
      throw StateError('You must be signed in to access your profile.');
    }

    return user.uid;
  }

  DocumentReference<Map<String, dynamic>> _publicProfile(String uid) =>
      _firestore.collection('publicProfiles').doc(uid);

  Map<String, dynamic> _publicData({
    required String uid,
    required String fullName,
    required String activeRole,
    required String location,
    required List<String> skills,
    required bool isAvailable,
    required double rating,
    required int completedGigs,
    String? proofVideoUrl,
    String? photoUrl,
  }) =>
      {
        'uid': uid,
        'fullName': fullName,
        'activeRole': activeRole,
        'location': location,
        'skills': skills,
        'isAvailableForGigs': isAvailable,
        'rating': rating,
        'completedGigs': completedGigs,
        'proofVideoUrl': proofVideoUrl,
        'photoUrl': photoUrl,
        'updatedAt': FieldValue.serverTimestamp(),
      };

  Future<Map<String, dynamic>> _computedProfileStats(
    String userId,
    String role,
  ) async {
    final results = await Future.wait([
      _firestore.collection('reviews')
          .where('revieweeId', isEqualTo: userId).get(),
      _firestore.collection('gigs')
          .where('posterId', isEqualTo: userId).get(),
      _firestore.collection('gigs')
          .where('acceptedWorkerId', isEqualTo: userId).get(),
    ]);
    final reviews = results[0].docs;
    final posted = results[1].docs;
    final worked = results[2].docs;
    final ratings = reviews
        .map((doc) => (doc.data()['rating'] as num?)?.toDouble())
        .whereType<double>()
        .toList();
    final completed = role == 'poster'
        ? posted.where((doc) => doc.data()['status'] == 'completed').length
        : worked.where((doc) => doc.data()['status'] == 'completed').length;
    return {
      'rating': ratings.isEmpty
          ? 0.0
          : ratings.reduce((a, b) => a + b) / ratings.length,
      'completedGigs': completed,
      'postedGigs': posted.length,
      'paidGigs': posted.where((doc) => doc.data()['paid'] == true).length,
    };
  }

  Future<UserProfile?> getPublicProfile(String userId) async {
    final document = await _publicProfile(userId).get();
    if (!document.exists) return null;
    final data = Map<String, dynamic>.from(document.data()!);
    final role = data['activeRole'] as String? ?? 'worker';
    data.addAll(await _computedProfileStats(userId, role));
    return UserProfile.fromMap(document.id, data);
  }

  Future<UserProfile> getMyProfile() async {
    final user = _auth.currentUser;

    if (user == null) {
      throw StateError('You must be signed in to access your profile.');
    }

    final document = await _users.doc(user.uid).get();

    if (!document.exists) {
      final data = {
        'uid': user.uid,
        'fullName': user.displayName ?? '',
        'email': user.email ?? '',
        'roles': ['worker', 'poster'],
        'activeRole': 'worker',
        'location': '',
        'skills': <String>[],
        'isVerified': false,
        'profileCompleted': false,
        'isAvailableForGigs': true,
        'rating': 0,
        'completedGigs': 0,
        'createdAt': FieldValue.serverTimestamp(),
      };

      await _users.doc(user.uid).set(data);
      await _publicProfile(user.uid).set(_publicData(
        uid: user.uid,
        fullName: data['fullName'] as String,
        activeRole: data['activeRole'] as String,
        location: data['location'] as String,
        skills: const [],
        isAvailable: true,
        rating: 0,
        completedGigs: 0,
        proofVideoUrl: null,
        photoUrl: null,
      ));

      return UserProfile.fromMap(user.uid, data);
    }

    final data = document.data()!;
    await _publicProfile(user.uid).set(_publicData(
      uid: user.uid,
      fullName: data['fullName'] as String? ?? '',
      activeRole: data['activeRole'] as String? ?? 'worker',
      location: data['location'] as String? ?? '',
      skills: List<String>.from(data['skills'] ?? []),
      isAvailable: data['isAvailableForGigs'] as bool? ?? true,
      rating: (data['rating'] as num?)?.toDouble() ?? 0,
      completedGigs: (data['completedGigs'] as num?)?.toInt() ?? 0,
      proofVideoUrl: data['proofVideoUrl'] as String?,
      photoUrl: data['photoUrl'] as String?,
    ), SetOptions(merge: true));

    final computed = await _computedProfileStats(
      user.uid,
      data['activeRole'] as String? ?? 'worker',
    );
    return UserProfile.fromMap(document.id, {...data, ...computed});
  }

  Future<void> updateProfile({
    required String fullName,
    required String location,
    required List<String> skills,
  }) async {
    await _users.doc(_uid).update({
      'fullName': fullName.trim(),
      'location': location.trim(),
      'skills': skills,
      'profileCompleted': true,
      'updatedAt': FieldValue.serverTimestamp(),
    });
    await _publicProfile(_uid).set({
      'fullName': fullName.trim(),
      'location': location.trim(),
      'skills': skills,
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  Future<void> updateProfilePhotoUrl(String? url) async {
    final uid = _uid;
    final batch = _firestore.batch();
    final value = url ?? FieldValue.delete();
    final update = {
      'photoUrl': value,
      'updatedAt': FieldValue.serverTimestamp(),
    };
    batch.update(_users.doc(uid), update);
    batch.set(_publicProfile(uid), update, SetOptions(merge: true));
    await batch.commit();
  }

  Future<void> updateProofVideoUrl(String? url) async {
    final uid = _uid;
    final batch = _firestore.batch();
    final value = url ?? FieldValue.delete();
    final update = {
      'proofVideoUrl': value,
      'updatedAt': FieldValue.serverTimestamp(),
    };

    batch.update(_users.doc(uid), update);
    batch.set(_publicProfile(uid), update, SetOptions(merge: true));
    await batch.commit();
  }

  Future<void> updateActiveRole(String role) async {
    if (role != 'worker' && role != 'poster') {
      throw ArgumentError('Invalid account role.');
    }

    await _users.doc(_uid).update({
      'activeRole': role,
      'updatedAt': FieldValue.serverTimestamp(),
    });
    await _publicProfile(_uid).set({
      'activeRole': role,
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  Future<void> updateAvailability(bool isAvailable) async {
    await _users.doc(_uid).update({
      'isAvailableForGigs': isAvailable,
      'updatedAt': FieldValue.serverTimestamp(),
    });
    await _publicProfile(_uid).set({
      'isAvailableForGigs': isAvailable,
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  Stream<UserProfile?> watchMyProfile() {
    return _users.doc(_uid).snapshots().asyncMap((document) async {
      if (!document.exists) return null;
      final data = document.data()!;
      final computed = await _computedProfileStats(
        document.id,
        data['activeRole'] as String? ?? 'worker',
      );
      return UserProfile.fromMap(document.id, {...data, ...computed});
    });
  }
}
