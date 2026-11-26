import 'dart:convert';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
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

    // Keep using the FCM registration token here: the Supabase Edge Function
    // sends through the FCM HTTP v1 API, which targets registration tokens.
    // The newer onRegistered stream provides a Firebase Installation ID,
    // which is not interchangeable with that FCM registration token.
    _messaging.onTokenRefresh.listen((token) {
      if (_auth.currentUser != null) {
        _registerToken(token);
      }
    });

    _auth.authStateChanges().listen((user) {
      if (user != null) {
        _registerCurrentToken();
      }
    });

    _initialized = true;
    if (_auth.currentUser != null) await _registerCurrentToken();
  }

  Future<void> _registerCurrentToken() async {
    try {
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
