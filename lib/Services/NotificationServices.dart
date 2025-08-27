import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

class EvOwnerNotificationService {
  static final navKey = GlobalKey<NavigatorState>();
  static final _fcm = FirebaseMessaging.instance;
  static final _local = FlutterLocalNotificationsPlugin();

  /// Initialize FCM & Local Notifications
  static Future<void> init() async {
    await _fcm.requestPermission(alert: true, badge: true, sound: true);

    // Save token
    await _saveToken();
    _fcm.onTokenRefresh.listen(_saveToken);

    // Local notifications setup
    const androidInit = AndroidInitializationSettings('@mipmap/ic_launcher');
    const iosInit = DarwinInitializationSettings();
    const initSettings = InitializationSettings(android: androidInit, iOS: iosInit);

    await _local.initialize(
      initSettings,
      onDidReceiveNotificationResponse: (resp) {
        final data = resp.payload == null
            ? <String, dynamic>{}
            : jsonDecode(resp.payload!) as Map<String, dynamic>;
        handleClick(data);
      },
    );

    // Foreground
    FirebaseMessaging.onMessage.listen((msg) async {
      await _maybePersistToFirestore(msg);
      await showLocalNotification(msg);
    });

    // When app resumed via notification
    FirebaseMessaging.onMessageOpenedApp.listen((msg) async {
      await _maybePersistToFirestore(msg);
      handleClick(msg.data);
    });

    // Cold start (app killed)
    final initial = await _fcm.getInitialMessage();
    if (initial != null) {
      await _maybePersistToFirestore(initial);
      handleClick(initial.data);
    }
  }

  /// Save FCM token to Firestore
  static Future<void> _saveToken([String? token]) async {
    token ??= await _fcm.getToken();
    final user = FirebaseAuth.instance.currentUser;
    if (user != null && token != null) {
      await FirebaseFirestore.instance.collection('users')
          .doc(user.uid)
          .set({'fcmToken': token}, SetOptions(merge: true));
    }
  }

  /// Show local notification
  static Future<void> showLocalNotification(RemoteMessage m) async {
    final title = m.data['title'] ?? 'Notification';
    final body = m.data['message'] ?? '';

    const android = AndroidNotificationDetails(
      'ev_owner_channel', 'EV Owner Notifications',
      importance: Importance.max,
      priority: Priority.high,
    );
    const ios = DarwinNotificationDetails();
    const details = NotificationDetails(android: android, iOS: ios);

    await _local.show(
      m.hashCode,
      title,
      body,
      details,
      payload: jsonEncode(m.data),
    );
  }

  /// Persist notification to Firestore if not exists
  static Future<void> _maybePersistToFirestore(RemoteMessage m) async {
    if ((m.data['notifId'] ?? '').toString().isNotEmpty) return;

    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    await FirebaseFirestore.instance.collection('notifications_to_send').add({
      'to': user.uid,
      'title': m.data['title'] ?? 'Notification',
      'message': m.data['message'] ?? '',
      'bookingId': m.data['bookingId'],
      'stationId': m.data['stationId'],
      'type': m.data['type'] ?? 'info',
      'status': m.data['status'] ?? 'pending',
      'toRole': 'ev_owner',
      'createdAt': FieldValue.serverTimestamp(),
    });
  }

  /// Handle notification tap
  static void handleClick(Map<String, dynamic> data) {
    navKey.currentState?.popUntil((r) => r.isFirst);
    navKey.currentState?.pushNamed('/notifications', arguments: {
      'bookingId': data['bookingId'],
      'notifId': data['notifId'],
      'status': data['status'],
    });
  }

  /// Called from background isolate
  static Future<void> showBackground(RemoteMessage message) async {
    await showLocalNotification(message);
  }
}
