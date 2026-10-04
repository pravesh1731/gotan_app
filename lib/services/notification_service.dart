import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:firebase_messaging/firebase_messaging.dart';

import 'api.dart';
import 'session.dart';

class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin = FlutterLocalNotificationsPlugin();

  final StreamController<RemoteMessage> _messages = StreamController<RemoteMessage>.broadcast();

  /// Foreground pushes (e.g. "Rider Booked", "Order In Transit"). Tracking
  /// screens listen to refresh immediately instead of waiting for the next poll.
  Stream<RemoteMessage> get messages => _messages.stream;

  static const _channel = AndroidNotificationDetails(
    'order_channel_id',
    'Order Notifications',
    channelDescription: 'Ride, parcel and order updates',
    importance: Importance.max,
    priority: Priority.high,
    icon: '@drawable/logo',
  );

  Future<void> saveFcmTokenLocally(String token) async {
    final prefs = await Session.prefs;
    if (prefs.getString(Session.kDeviceToken) != token) {
      await prefs.setString(Session.kDeviceToken, token);
    }
  }

  Future<void> initialize() async {
    const initSettings = InitializationSettings(
      android: AndroidInitializationSettings('@drawable/logo'),
    );
    await flutterLocalNotificationsPlugin.initialize(initSettings);

    FirebaseMessaging.instance.getToken().then((token) {
      if (token != null) saveFcmTokenLocally(token);
    }).catchError((Object e) {
      debugPrint('FCM token unavailable: $e');
    });

    FirebaseMessaging.instance.onTokenRefresh.listen((newToken) async {
      await saveFcmTokenLocally(newToken);
      // Keep the backend in sync so ride/parcel pushes reach this device.
      final phone = await Session.phone();
      if (phone != null) {
        try {
          await Api.authenticate(phone, deviceToken: newToken);
        } catch (e) {
          debugPrint('Failed to sync refreshed FCM token: $e');
        }
      }
    });

    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      _messages.add(message);
      final notification = message.notification;
      if (notification != null) {
        flutterLocalNotificationsPlugin.show(
          notification.hashCode,
          notification.title,
          notification.body,
          const NotificationDetails(android: _channel),
        );
      }
    });
  }

  /// Call after switching accounts: issues a fresh token so the previous user's
  /// pushes stop arriving, then registers it for the current phone number.
  Future<void> resetFcmToken() async {
    try {
      await FirebaseMessaging.instance.deleteToken();
      final token = await FirebaseMessaging.instance.getToken();
      if (token == null) return;
      await saveFcmTokenLocally(token);
      final phone = await Session.phone();
      if (phone != null) await Api.authenticate(phone, deviceToken: token);
    } catch (e) {
      debugPrint('Failed to reset FCM token: $e');
    }
  }
}
