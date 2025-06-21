import 'package:flutter/material.dart';
import 'package:gotan/MapScreen.dart';
import 'package:gotan/pages/LocationPickerPage.dart';
import 'package:gotan/pages/MyProfileScreen.dart';
import 'package:gotan/pages/PhoneInputPage.dart';
import 'package:gotan/pages/PhoneLoginScreen.dart';
import 'package:gotan/pages/SplashScreen.dart';
import 'package:gotan/pages/UserProfilePage.dart';
import 'package:gotan/pages/homepage.dart';
import 'package:gotan/providers/CartProvider.dart';
import 'package:gotan/providers/UserProvider.dart';
import 'package:gotan/providers/WishlistProvider.dart';
import 'package:gotan/services/notification_service.dart';
import 'package:gotan/testing/CheckoutScreen.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'model/cart_item.dart';
import 'package:provider/provider.dart';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
FlutterLocalNotificationsPlugin();

// Background message handler
@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp();

  // final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
  // FlutterLocalNotificationsPlugin();
  //
  // const AndroidInitializationSettings initializationSettingsAndroid =
  // AndroidInitializationSettings('@drawable/logo');
  //
  // const InitializationSettings initializationSettings =
  // InitializationSettings(android: initializationSettingsAndroid);
  //
  // await flutterLocalNotificationsPlugin.initialize(initializationSettings);
  //
  // final data = message.data;
  // final title = data['title'];
  // final body = data['body'];

  print('📨 Background notification triggered');

  // if (title != null && body != null) {
  //   flutterLocalNotificationsPlugin.show(
  //     message.hashCode,
  //     title,
  //     body,
  //     const NotificationDetails(
  //       android: AndroidNotificationDetails(
  //         'order_channel_id',
  //         'Order Notifications',
  //         importance: Importance.max,
  //         priority: Priority.high,
  //         icon: '@drawable/logo',
  //       ),
  //     ),
  //   );
  // }
}



void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();


  FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);

  await NotificationService().initialize();

  const AndroidInitializationSettings initializationSettingsAndroid =
  AndroidInitializationSettings('@drawable/logo');

  const InitializationSettings initializationSettings =
  InitializationSettings(android: initializationSettingsAndroid);

  await flutterLocalNotificationsPlugin.initialize(initializationSettings);


  await Hive.initFlutter();
  Hive.registerAdapter(CartItemAdapter());

  // Initialize providers
  final cartProvider = CartProvider();
  await cartProvider.loadCartFromStorage();

  final wishlistProvider = WishlistProvider();
  await wishlistProvider.init();

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider.value(value: cartProvider),
        ChangeNotifierProvider.value(value: wishlistProvider),
        ChangeNotifierProvider(create: (_) => UserProvider()),
      ],
      child: MyApp(),
    ),
  );
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  // This widget is the root of your application.
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      // showSemanticsDebugger: true,
      debugShowCheckedModeBanner: false,
      title: 'Gotan',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
      ),
      // home: MapScreen(),
      // home: CheckoutScreen(),
      // home: ProfileScreen(),
      home: GestureDetector(
        onTap: (){
          FocusScopeNode currentNode = FocusScope.of(context);
          if(currentNode.focusedChild != null && !currentNode.hasPrimaryFocus){
            FocusManager.instance.primaryFocus!.unfocus();
          }
        },
        child: SplashScreen(),
      ),
      // home: HomePage(),
      // home: MyProfileScreen(),
      // home: LocationPickerPage(),

    );
  }
}
