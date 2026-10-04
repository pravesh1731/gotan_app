import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../providers/UserProvider.dart';
import '../services/session.dart';
import '../theme/app_theme.dart';
import 'PhoneInputPage.dart';
import 'homepage.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();
    _navigate();
  }

  Future<void> _navigate() async {
    await Future.delayed(const Duration(milliseconds: 1500));

    final prefs = await SharedPreferences.getInstance();
    final skipped = prefs.getString(Session.kSkip) == 'skipped';
    if (!mounted) return;
    final loggedIn = context.read<UserProvider>().isLoggedIn;

    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (_) => (loggedIn || skipped) ? const HomePage() : const PhoneInputPage()),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.surface,
      body: Stack(
        children: [
          Positioned.fill(
            child: DecoratedBox(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [AppColors.pastelBlue, AppColors.surface],
                ),
              ),
            ),
          ),
          Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Image.asset('assets/images/gologo.png', height: 72, fit: BoxFit.contain),
                const SizedBox(height: 16),
                const Text(
                  'Rides · Parcels · Local shops',
                  style: TextStyle(color: AppColors.textSecondary, fontWeight: FontWeight.w500),
                ),
              ],
            ),
          ),
          const Positioned(
            left: 0,
            right: 0,
            bottom: 40,
            child: Center(
              child: SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2.4)),
            ),
          ),
        ],
      ),
    );
  }
}
