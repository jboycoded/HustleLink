import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class AdminOverview {
  const AdminOverview({
    required this.users,
    required this.gigs,
    required this.openGigs,
    required this.reports,
    required this.pendingReports,
  });

  final int users;
  final int gigs;
  final int openGigs;
  final int reports;
  final int pendingReports;
}

class AdminService {
  AdminService({
    FirebaseFirestore? firestore,
    FirebaseAuth? auth,
    SupabaseClient? supabase,
  })  : _firestore = firestore ?? FirebaseFirestore.instance,
        _auth = auth ?? FirebaseAuth.instance,
        _supabase = supabase ?? Supabase.instance.client;

  final FirebaseFirestore _firestore;
  final FirebaseAuth _auth;
  final SupabaseClient _supabase;

  Future<AdminOverview> loadOverview() async {
    final result = await invoke('admin-overview');
    return AdminOverview(
      users: (result['users'] as num?)?.toInt() ?? 0,
      gigs: (result['gigs'] as num?)?.toInt() ?? 0,
      openGigs: (result['openGigs'] as num?)?.toInt() ?? 0,
      reports: (result['reports'] as num?)?.toInt() ?? 0,
      pendingReports: (result['pendingReports'] as num?)?.toInt() ?? 0,
    );
  }

  Stream<QuerySnapshot<Map<String, dynamic>>> watchUsers() => _firestore
      .collection('users')
      .orderBy('createdAt', descending: true)
      .limit(200)
      .snapshots();

  Stream<QuerySnapshot<Map<String, dynamic>>> watchGigs() => _firestore
      .collection('gigs')
      .orderBy('createdAt', descending: true)
      .limit(200)
      .snapshots();

  Stream<QuerySnapshot<Map<String, dynamic>>> watchReports() => _firestore
      .collection('reports')
      .orderBy('createdAt', descending: true)
      .limit(200)
      .snapshots();

  Stream<QuerySnapshot<Map<String, dynamic>>> watchAnnouncements() => _firestore
      .collection('adminAnnouncements')
      .orderBy('createdAt', descending: true)
      .limit(100)
      .snapshots();

  Stream<QuerySnapshot<Map<String, dynamic>>> watchAuditLogs() => _firestore
      .collection('adminAuditLogs')
      .orderBy('createdAt', descending: true)
      .limit(200)
      .snapshots();

  Future<Map<String, dynamic>> invoke(String action, [Map<String, dynamic> payload = const {}]) async {
    final user = _auth.currentUser;
    if (user == null) throw StateError('Your session has expired. Please sign in again.');
    final token = await user.getIdToken();
    if (token == null || token.isEmpty) {
      throw StateError('Unable to verify your session. Please sign in again.');
    }
    final response = await _supabase.functions.invoke(
      'push-notification',
      headers: {'Authorization': 'Bearer $token'},
      body: {'action': action, ...payload},
    );
    final data = response.data;
    if (data is Map<String, dynamic>) return data;
    return <String, dynamic>{'success': true};
  }

  Future<void> setUserSuspended({
    required String userId,
    required bool suspended,
    String reason = '',
  }) async {
    await invoke('admin-set-user-status', {
      'userId': userId,
      'suspended': suspended,
      'reason': reason,
    });
  }

  Future<void> moderateGig({
    required String gigId,
    required bool remove,
    String note = '',
  }) async {
    await invoke(remove ? 'admin-remove-gig' : 'admin-close-gig', {
      'gigId': gigId,
      'note': note,
    });
  }

  Future<void> reviewReport({
    required String reportId,
    required String status,
    String resolutionNote = '',
  }) async {
    await invoke('admin-review-report', {
      'reportId': reportId,
      'status': status,
      'resolutionNote': resolutionNote,
    });
  }

  Future<Map<String, dynamic>?> getReportTarget({
    required String targetType,
    required String targetId,
  }) async {
    final result = await invoke('admin-get-report-target', {
      'targetType': targetType,
      'targetId': targetId,
    });
    final target = result['target'];
    return target is Map<String, dynamic> ? target : null;
  }

  Future<Map<String, dynamic>> sendAnnouncement({
    required String title,
    required String body,
    required String audience,
    String targetUserId = '',
  }) {
    return invoke('admin-send-announcement', {
      'title': title,
      'body': body,
      'audience': audience,
      'targetUserId': targetUserId,
    });
  }
}
