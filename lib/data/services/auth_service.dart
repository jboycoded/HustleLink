
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  Stream<User?> get authStateChanges => _auth.authStateChanges();

  User? get currentUser => _auth.currentUser;

  Future<UserCredential> register({
    required String fullName,
    required String email,
    required String password,
  }) async {
    final normalizedEmail = email.trim().toLowerCase();

    final credential = await _auth.createUserWithEmailAndPassword(
      email: normalizedEmail,
      password: password,
    );

    final user = credential.user!;

    try {
      await _firestore.collection('users').doc(user.uid).set({
        'uid': user.uid,
        'fullName': fullName.trim(),
        'email': normalizedEmail,
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
      });
    } catch (_) {
      await user.delete();
      rethrow;
    }

    return credential;
  }

  Future<UserCredential> signIn({
    required String email,
    required String password,
  }) {
    return _auth.signInWithEmailAndPassword(
      email: email.trim().toLowerCase(),
      password: password,
    );
  }

  Future<void> sendPasswordResetEmail(String email) {
    final normalizedEmail = email.trim().toLowerCase();
    if (normalizedEmail.isEmpty || !normalizedEmail.contains('@')) {
      throw ArgumentError('Enter a valid email address.');
    }
    return _auth.sendPasswordResetEmail(email: normalizedEmail);
  }

  Future<void> signOut() => _auth.signOut();
}
