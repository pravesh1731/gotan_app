import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:gotan/firebase_options.dart';
import 'package:gotan/pages/SplashScreen.dart';
import 'package:gotan/providers/CartProvider.dart';
import 'package:gotan/providers/UserProvider.dart';
import 'package:gotan/providers/WishlistProvider.dart';
import 'package:gotan/services/notification_service.dart';
import 'package:gotan/theme/app_theme.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'model/cart_item.dart';
import 'package:provider/provider.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';

// Background message handler
@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  // Notification messages are shown by the system tray while in background.
  await Firebase.initializeApp();
}

Future<void> _initFirebase() async {
  // Android reads google-services.json; web needs explicit options.
  if (kIsWeb) {
    await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
    return;
  }
  await Firebase.initializeApp();
  FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);
  await NotificationService().initialize();
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setSystemUIOverlayStyle(AppTheme.lightStatusBar);

  try {
    await _initFirebase();
  } catch (e) {
    // Booking, shops and password login still work without Firebase.
    debugPrint('Firebase init failed: $e');
  }

  await Hive.initFlutter();
  Hive.registerAdapter(CartItemAdapter());

  final cartProvider = CartProvider();
  await cartProvider.loadCartFromStorage();

  final wishlistProvider = WishlistProvider();
  await wishlistProvider.init();

  final userProvider = UserProvider();
  await userProvider.load();

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider.value(value: cartProvider),
        ChangeNotifierProvider.value(value: wishlistProvider),
        ChangeNotifierProvider.value(value: userProvider),
      ],
      child: const MyApp(),
    ),
  );
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Gotan',
      theme: AppTheme.light,
      builder: (context, child) => GestureDetector(
        // Tap outside a text field to dismiss the keyboard.
        onTap: () => FocusManager.instance.primaryFocus?.unfocus(),
        behavior: HitTestBehavior.translucent,
        child: child,
      ),
      home: const SplashScreen(),
    );
  }
}
