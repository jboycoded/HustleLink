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

      return UserProfile.fromMap(user.uid, data);
    }

    return UserProfile.fromMap(
      document.id,
      document.data()!,
    );
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
  }

  Future<void> updateActiveRole(String role) async {
    if (role != 'worker' && role != 'poster') {
      throw ArgumentError('Invalid account role.');
    }

    await _users.doc(_uid).update({
      'activeRole': role,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> updateAvailability(bool isAvailable) async {
    await _users.doc(_uid).update({
      'isAvailableForGigs': isAvailable,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  Stream<UserProfile?> watchMyProfile() {
    return _users.doc(_uid).snapshots().map((document) {
      if (!document.exists) return null;

      return UserProfile.fromMap(
        document.id,
        document.data()!,
      );
    });
  }
}
