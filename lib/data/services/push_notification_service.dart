import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/config/supabase_config.dart';

class PushNotificationService {
  PushNotificationService({
    FirebaseMessaging? messaging,
    FirebaseAuth? auth,
    FlutterLocalNotificationsPlugin? localNotifications,
  })  : _messaging = messaging ?? FirebaseMessaging.instance,
        _auth = auth ?? FirebaseAuth.instance,
        _localNotifications =
            localNotifications ?? FlutterLocalNotificationsPlugin();

  static const String channelId = 'hustlelink_notifications';
  static const String channelName = 'HustleLink notifications';

  final FirebaseMessaging _messaging;
  final FirebaseAuth _auth;
  final FlutterLocalNotificationsPlugin _localNotifications;

  Future<void> Function(Map<String, dynamic>)? _onNotificationTap;
  bool _initialized = false;

  Future<void> initialize({
    required Future<void> Function(Map<String, dynamic>) onNotificationTap,
  }) async {
    if (_initialized || !SupabaseConfig.isConfigured) return;
    _onNotificationTap = onNotificationTap;

    const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
    const initializationSettings = InitializationSettings(
      android: androidSettings,
    );
    await _localNotifications.initialize(
      settings: initializationSettings,
      onDidReceiveNotificationResponse: (response) {
        final payload = response.payload;
        if (payload == null || payload.isEmpty) return;
        try {
          final data = jsonDecode(payload);
          if (data is Map<String, dynamic>) {
            _onNotificationTap?.call(data);
          }
        } catch (_) {
          // Ignore malformed local-notification payloads.
        }
      },
    );

    const channel = AndroidNotificationChannel(
      channelId,
      channelName,
      description: 'Applications, messages and gig updates.',
      importance: Importance.max,
      playSound: true,
    );
    await _localNotifications
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(channel);

    await _messaging.requestPermission(
      alert: true,
      badge: true,
      sound: true,
      provisional: false,
    );

    FirebaseMessaging.onMessage.listen(_showForegroundNotification);
    FirebaseMessaging.onMessageOpenedApp.listen(_handleRemoteTap);
    final initialMessage = await _messaging.getInitialMessage();
    if (initialMessage != null) {
      await _handleRemoteTap(initialMessage);
    }

    // The current Edge Function sends to FCM HTTP v1 registration tokens.
    // firebase_messaging 17 still exposes these token APIs, although deprecated;
    // its new onRegistered stream supplies a Firebase Installation ID instead.
    // ignore: deprecated_member_use
    _messaging.onTokenRefresh.listen((token) {
      if (_auth.currentUser != null) {
        _registerToken(token);
      }
    });

    _auth.authStateChanges().listen((user) {
      if (user != null) {
        _handleSignedInUser(user.uid);
      }
    });

    _initialized = true;
  }

  final Set<String> _usersSyncingMissedNotifications = {};

  Future<void> _handleSignedInUser(String userId) async {
    await _registerCurrentToken();
    if (!_usersSyncingMissedNotifications.add(userId)) return;
    try {
      await _showMissedNotifications(userId);
    } catch (error) {
      debugPrint('HustleLink missed-notification sync failed: $error');
    } finally {
      _usersSyncingMissedNotifications.remove(userId);
    }
  }

  Future<void> _showMissedNotifications(String userId) async {
    final preferences = await SharedPreferences.getInstance();
    final lastSyncKey = 'hustlelink_notification_sync_$userId';
    final lastSyncMillis = preferences.getInt(lastSyncKey);
    // Read only a recent window instead of downloading the account's
    // entire notification history on every sign-in. Filtering by read state
    // and last sync remains local within this bounded result set.
    final snapshot = await FirebaseFirestore.instance
        .collection('notifications')
        .where('recipientId', isEqualTo: userId)
        .orderBy('createdAt', descending: true)
        .limit(50)
        .get();

    final pending = snapshot.docs.where((document) {
      final data = document.data();
      if (data['isRead'] == true) return false;
      final createdAt = data['createdAt'];
      if (createdAt is! Timestamp) return false;
      if (lastSyncMillis == null) return true;
      return createdAt.millisecondsSinceEpoch > lastSyncMillis;
    }).toList()
      ..sort((a, b) {
        final aDate = a.data()['createdAt'] as Timestamp;
        final bDate = b.data()['createdAt'] as Timestamp;
        return bDate.compareTo(aDate);
      });

    // Limit the initial catch-up so a long-unused account does not flood
    // the notification shade with a large historical backlog.
    for (final document in pending.take(10).toList().reversed) {
      final data = document.data();
      await _localNotifications.show(
        id: document.id.hashCode & 0x7fffffff,
        title: data['title'] as String? ?? 'HustleLink',
        body: data['body'] as String? ?? 'You have a new update.',
        notificationDetails: const NotificationDetails(
          android: AndroidNotificationDetails(
            channelId,
            channelName,
            channelDescription: 'Applications, messages and gig updates.',
            importance: Importance.max,
            priority: Priority.high,
            playSound: true,
          ),
        ),
        payload: jsonEncode({
          'type': data['type'] as String? ?? '',
          'relatedId': data['relatedId'] as String? ?? '',
          'notificationId': document.id,
        }),
      );
    }

    await preferences.setInt(
      lastSyncKey,
      DateTime.now().millisecondsSinceEpoch,
    );
  }

  Future<void> _registerCurrentToken() async {
    try {
      // ignore: deprecated_member_use
      final token = await _messaging.getToken();
      if (token != null && token.isNotEmpty) await _registerToken(token);
    } catch (error) {
      debugPrint('HustleLink push token registration failed: $error');
    }
  }

  Future<void> _registerToken(String token) async {
    await _invoke({
      'action': 'register-token',
      'token': token,
      'platform': defaultTargetPlatform.name,
    });
  }

  Future<void> unregisterCurrentDevice() async {
    final user = _auth.currentUser;
    if (user == null) return;
    try {
      // ignore: deprecated_member_use
      final token = await _messaging.getToken();
      if (token != null && token.isNotEmpty) {
        await _invoke({'action': 'remove-token', 'token': token});
      }
    } catch (error) {
      debugPrint('HustleLink push token removal failed: $error');
    }
  }

  Future<void> sendForNotification(String notificationId) async {
    if (notificationId.isEmpty || _auth.currentUser == null) return;
    try {
      await _invoke({
        'action': 'send-notification',
        'notificationId': notificationId,
      });
    } catch (error) {
      // The Firestore notification is already saved. Push delivery is best
      // effort and must not make the original application/chat action fail.
      debugPrint('HustleLink push delivery failed: $error');
    }
  }

  Future<void> _invoke(Map<String, dynamic> body) async {
    final user = _auth.currentUser;
    if (user == null) return;
    final idToken = await user.getIdToken();
    if (idToken == null || idToken.isEmpty) return;
    await Supabase.instance.client.functions.invoke(
      'push-notification',
      headers: {'Authorization': 'Bearer $idToken'},
      body: body,
    );
  }

  Future<void> _showForegroundNotification(RemoteMessage message) async {
    final notification = message.notification;
    if (notification == null) return;
    await _localNotifications.show(
      id: message.hashCode,
      title: notification.title ?? 'HustleLink',
      body: notification.body ?? '',
      notificationDetails: const NotificationDetails(
        android: AndroidNotificationDetails(
          channelId,
          channelName,
          channelDescription: 'Applications, messages and gig updates.',
          importance: Importance.max,
          priority: Priority.high,
          playSound: true,
        ),
      ),
      payload: jsonEncode(message.data),
    );
  }

  Future<void> _handleRemoteTap(RemoteMessage message) async {
    await _onNotificationTap?.call(message.data);
  }
}
