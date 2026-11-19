import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

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

  Stream<QuerySnapshot<Map<String, dynamic>>> watchMessages(
    String conversationId,
  ) {
    return _conversations
        .doc(conversationId)
        .collection('messages')
        .orderBy('createdAt')
        .snapshots();
  }

  Future<void> sendMessage({
    required String conversationId,
    required String text,
  }) async {
    final cleanText = text.trim();
    if (cleanText.isEmpty) return;
    final uid = _uid;
    final conversation = _conversations.doc(conversationId);
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
    });
    await batch.commit();
  }
}
