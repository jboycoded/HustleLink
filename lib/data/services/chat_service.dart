import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import 'push_notification_service.dart';

class ChatService {
  ChatService({FirebaseFirestore? firestore, FirebaseAuth? auth})
      : _firestore = firestore ?? FirebaseFirestore.instance,
        _auth = auth ?? FirebaseAuth.instance;

  final FirebaseFirestore _firestore;
  final FirebaseAuth _auth;

  String get _uid {
    final uid = _auth.currentUser?.uid;
    if (uid == null) throw StateError('You must be signed in to chat.');
    return uid;
  }

  String get currentUserId => _uid;

  Stream<DocumentSnapshot<Map<String, dynamic>>> watchConversation(String id) =>
      _conversations.doc(id).snapshots();

  CollectionReference<Map<String, dynamic>> get _conversations =>
      _firestore.collection('conversations');

  Stream<QuerySnapshot<Map<String, dynamic>>> watchConversations() {
    return _conversations
        .where('participants', arrayContains: _uid)
        .snapshots();
  }


  Future<String?> getCurrentUserRoleForGig(String gigId) async {
    final snapshot = await _firestore.collection('gigs').doc(gigId).get();
    if (snapshot.exists) {
      final data = snapshot.data()!;
      if (data['posterId'] == _uid) return 'poster';
      if (data['acceptedWorkerId'] == _uid) return 'worker';
    }

    // Older accepted gigs may not have acceptedWorkerId populated. Use the
    // conversation created for that gig as a compatibility fallback.
    final conversations = await _conversations
        .where('gigId', isEqualTo: gigId)
        .where('participants', arrayContains: _uid)
        .limit(5)
        .get();
    for (final conversation in conversations.docs) {
      final data = conversation.data();
      if (data['posterId'] == _uid) return 'poster';
      if (data['workerId'] == _uid) return 'worker';
    }
    return null;
  }

  Future<String?> getCurrentUserRoleForConversation(String conversationId) async {
    final snapshot = await _conversations.doc(conversationId).get();
    if (!snapshot.exists) return null;
    final data = snapshot.data()!;
    if (data['workerId'] == _uid) return 'worker';
    if (data['posterId'] == _uid) return 'poster';
    return null;
  }

  Stream<QuerySnapshot<Map<String, dynamic>>> watchMessages(
    String conversationId,
  ) {
    return _conversations
        .doc(conversationId)
        .collection('messages')
        .orderBy('createdAt')
        .snapshots();
  }

  Future<void> removeConversation(String conversationId) async {
    await _conversations.doc(conversationId).update({
      'hiddenFor': FieldValue.arrayUnion([_uid]),
    });
  }

  Future<void> markAsRead(String conversationId) async {
    final uid = _uid;
    await _conversations.doc(conversationId).update({
      'lastReadAt.$uid': FieldValue.serverTimestamp(),
    });
  }

  Future<void> sendMessage({
    required String conversationId,
    required String text,
  }) async {
    final cleanText = text.trim();
    if (cleanText.isEmpty) return;
    final uid = _uid;
    final conversation = _conversations.doc(conversationId);
    final conversationSnapshot = await conversation.get();
    if (!conversationSnapshot.exists) throw StateError('Conversation not found.');
    final conversationData = conversationSnapshot.data()!;
    final recipientId = conversationData['workerId'] == uid
        ? conversationData['posterId'] as String
        : conversationData['workerId'] as String;
    final message = conversation.collection('messages').doc();
    final batch = _firestore.batch();
    batch.set(message, {
      'senderId': uid,
      'text': cleanText,
      'createdAt': FieldValue.serverTimestamp(),
    });
    batch.update(conversation, {
      'lastMessage': cleanText,
      'lastMessageAt': FieldValue.serverTimestamp(),
      'lastSenderId': uid,
      'hiddenFor': FieldValue.arrayRemove([recipientId]),
    });
    final notificationRef = _firestore.collection('notifications').doc();
    batch.set(notificationRef, {
      'recipientId': recipientId,
      'actorId': uid,
      'type': 'new_message',
      'title': 'New message',
      'body': cleanText.length > 90 ? '${cleanText.substring(0, 87)}...' : cleanText,
      'relatedId': conversationId,
      'isRead': false,
      'createdAt': FieldValue.serverTimestamp(),
    });
    await batch.commit();
    await PushNotificationService().sendForNotification(notificationRef.id);
  }
}
