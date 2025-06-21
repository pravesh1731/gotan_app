import 'package:flutter/material.dart';
import 'package:lottie/lottie.dart';
import 'dart:async';

class LottieSplashScreen extends StatefulWidget {
  final Widget nextPage;
  final String assetPath;

  const LottieSplashScreen({
    Key? key,
    required this.nextPage,
    required this.assetPath,
  }) : super(key: key);

  @override
  State<LottieSplashScreen> createState() => _LottieSplashScreenState();
}

class _LottieSplashScreenState extends State<LottieSplashScreen> {
  @override
  void initState() {
    super.initState();

    Timer(const Duration(seconds: 3), () {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => widget.nextPage),
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Lottie.asset(
          widget.assetPath,
          width: 300,
          height: 300,
          fit: BoxFit.contain,
        ),
      ),
    );
  }
}
