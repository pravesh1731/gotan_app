import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:gotan/pages/BookingInstant.dart';
import 'package:gotan/pages/HomePage.dart';
import 'package:lottie/lottie.dart';
import 'dart:async';

import '../pages/ParcelInstant.dart';

class LottieSplashScreenToHome extends StatefulWidget {

  final String orderId;
  final String phoneNumber;
  final bool isRide;

  LottieSplashScreenToHome({Key? key, required this.orderId, required this.phoneNumber, required this.isRide}) : super(key: key);

  @override
  State<LottieSplashScreenToHome> createState() => _LottieSplashScreenToHomeState();
}

class _LottieSplashScreenToHomeState extends State<LottieSplashScreenToHome> {
  @override
  void initState() {
    super.initState();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      SystemChrome.setSystemUIOverlayStyle(
        const SystemUiOverlayStyle(
          statusBarColor: Colors.white, // or any color you want
          statusBarIconBrightness: Brightness.dark, // use Brightness.light for white icons
        ),
      );
    });

    Timer(const Duration(seconds: 3), () {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => widget.isRide? BookingInstant(orderId: widget.orderId, phoneNumber: widget.phoneNumber,):  ParcelInstant(orderId: widget.orderId, phoneNumber: widget.phoneNumber,)),
      );
    });
  }

  @override
  Widget build(BuildContext context) {

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle(
        statusBarColor: Colors.white, // or any background
        statusBarIconBrightness: Brightness.dark,
      ),
      child: Scaffold(
        backgroundColor: Colors.white,
        // extendBodyBehindAppBar: true,
        body: Center(
          child: Lottie.asset(
            'assets/animations/confirm.json',
            width: 300,
            height: 300,
            fit: BoxFit.contain,
          ),
        ),
      ),
    );
  }
}
