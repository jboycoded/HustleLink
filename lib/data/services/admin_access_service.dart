import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class AdminAccessService {
  AdminAccessService({
    FirebaseAuth? auth,
    FirebaseFirestore? firestore,
  })  : _auth = auth ?? FirebaseAuth.instance,
        _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseAuth _auth;
  final FirebaseFirestore _firestore;

  Future<String?> getCurrentRole() async {
    final uid = _auth.currentUser?.uid;
    if (uid == null) return null;
    final snapshot = await _firestore.collection('adminUsers').doc(uid).get();
    if (!snapshot.exists) return null;
    final data = snapshot.data();
    if (data?['active'] != true) return null;
    final role = data?['role'];
    const allowed = {
      'super_admin', 'admin', 'moderator', 'support', 'analyst',
    };
    return role is String && allowed.contains(role) ? role : null;
  }

  static String roleLabel(String role) {
    switch (role) {
      case 'super_admin':
        return 'Super Admin';
      case 'admin':
        return 'Admin';
      case 'moderator':
        return 'Moderator';
      case 'support':
        return 'Support';
      case 'analyst':
        return 'Analyst';
      default:
        return 'Administrator';
    }
  }

  static bool canAccess(String role, String permission) {
    const permissions = {
      'super_admin': {'overview', 'users', 'gigs', 'reports', 'announcements', 'audit_logs', 'admin_roles'},
      'admin': {'overview', 'users', 'gigs', 'reports', 'announcements', 'audit_logs'},
      'moderator': {'overview', 'users', 'gigs', 'reports'},
      'support': {'overview', 'reports'},
      'analyst': {'overview', 'audit_logs'},
    };
    return permissions[role]?.contains(permission) ?? false;
  }
}
