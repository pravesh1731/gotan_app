import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:lottie/lottie.dart';

import 'PhoneInputPage.dart';
import 'homepage.dart';

class SplashScreen extends StatefulWidget {
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
    await Future.delayed(Duration(seconds: 3)); // Lottie delay

    SharedPreferences prefs = await SharedPreferences.getInstance();
    final phone = prefs.getString('gotan_phone_number');
    final skip = prefs.getString('skip');

    if ((phone == null) && (skip == 'skipped')) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => HomePage()),
      );
    } else if((phone == null) && (skip == null)) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => PhoneInputPage()),
      );
    }
    else{
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => HomePage()),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Center(
          child: Image.asset(
            'assets/images/logo.png',
            width: 200,
            height: 200,
            fit: BoxFit.contain,
          ),
        ),
      ),
    );
  }
}
