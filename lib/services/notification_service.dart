import 'dart:convert';

import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import '../global/common.dart';

class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
  FlutterLocalNotificationsPlugin();

  Future<void> saveFcmTokenLocally(String token) async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    String? existingToken = prefs.getString('deviceToken');
    if (existingToken != token) {
      await prefs.setString('deviceToken', token);
      print("✅ FCM Token saved in SharedPreferences");
      print(token);
    }
  }

  Future<void> initialize() async {
    const AndroidInitializationSettings androidInitSettings =
    AndroidInitializationSettings('@drawable/logo');

    const InitializationSettings initSettings = InitializationSettings(
      android: androidInitSettings,
    );

    await flutterLocalNotificationsPlugin.initialize(initSettings);

    // Get token on app start
    FirebaseMessaging.instance.getToken().then((token) {
      if (token != null) {
        print("🔑 FCM Token: $token");
        saveFcmTokenLocally(token);
      }
    });

    // Listen for token refresh
    FirebaseMessaging.instance.onTokenRefresh.listen((newToken) {
      print("🔄 Refreshed FCM Token: $newToken");
      saveFcmTokenLocally(newToken);
    });

    // FirebaseMessaging.onMessage.listen((RemoteMessage message) {
    //   print('====');
    //   print('Foreground message triggered');
    //   RemoteNotification? notification = message.notification;
    //   AndroidNotification? android = message.notification?.android;
    //
    //   if (notification != null && android != null) {
    //     flutterLocalNotificationsPlugin.show(
    //       notification.hashCode,
    //       notification.title,
    //       notification.body,
    //       const NotificationDetails(
    //         android: AndroidNotificationDetails(
    //           'order_channel_id',
    //           'Order Notifications',
    //           importance: Importance.max,
    //           priority: Priority.high,
    //           icon: '@drawable/logo',
    //         ),
    //       ),
    //     );
    //   }
    // });

    // FirebaseMessaging.onMessage.listen((RemoteMessage message) {
    //   if (message.notification != null) {
    //     print("📢 Foreground Notification: ${message.notification!.title}");
    //     // Optional: show a snackbar or local notification if you want
    //   }
    //   // final data = message.data;
    //   // final title = data['title'];
    //   // final body = data['body'];
    //   //
    //   // flutterLocalNotificationsPlugin.show(
    //   //   message.hashCode,
    //   //   title,
    //   //   body,
    //   //   const NotificationDetails(
    //   //     android: AndroidNotificationDetails(
    //   //       'order_channel_id',
    //   //       'Order Notifications',
    //   //       importance: Importance.max,
    //   //       priority: Priority.high,
    //   //       icon: '@drawable/logo',
    //   //     ),
    //   //   ),
    //   // );
    // });

    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      print('📢 Foreground message received');

      RemoteNotification? notification = message.notification;
      AndroidNotification? android = message.notification?.android;

      if (notification != null && android != null) {
        flutterLocalNotificationsPlugin.show(
          notification.hashCode,
          notification.title,
          notification.body,
          const NotificationDetails(
            android: AndroidNotificationDetails(
              'order_channel_id',
              'Order Notifications',
              importance: Importance.max,
              priority: Priority.high,
              icon: '@drawable/logo',
            ),
          ),
        );
      }
    });



    print("📡 Firebase onMessage listener attached globally.");
  }

  // Call this when switching user accounts (logout/login)
  // Future<void> resetFcmToken() async {
  //   await FirebaseMessaging.instance.deleteToken();
  //   String? token = await FirebaseMessaging.instance.getToken();
  //   if (token != null) {
  //     print("🔑 FCM Token: $token");
  //     saveFcmTokenLocally(token);
  //     //call here
  //   }
  // }

  Future<void> resetFcmToken() async {
    await FirebaseMessaging.instance.deleteToken();
    String? token = await FirebaseMessaging.instance.getToken();
    if (token != null) {
      print("🔑 FCM Token: $token");
      await saveFcmTokenLocally(token);

      SharedPreferences prefs = await SharedPreferences.getInstance();
      String? phoneNumber = prefs.getString('gotan_phone_number');

      if (phoneNumber == null || phoneNumber.isEmpty) {
        print("⚠️ Phone number not found in SharedPreferences.");
        return;
      }

      try {
        final response = await http.post(
          Uri.parse("${Common.baseUrl}api/auth/authenticate"),
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode({
            "cityName": "Gotan",
            "phoneNumber": phoneNumber,
            "deviceToken": token,
          }),
        );

        print("📬 Token update API response: ${response.statusCode} - ${response.body}");
      } catch (e) {
        print("❌ Failed to update token on server: $e");
        // Optionally show a toast or store this to retry later
      }
    }
  }


}
