import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:gotan/global/common.dart';
import 'package:gotan/pages/homepage.dart';
import 'package:lottie/lottie.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

import '../splash/LottieSplashScreenToHome.dart';

class BookingSummaryScreen extends StatefulWidget {
  final String pickup;
  final String destination;
  final String rideType;
  final int passengers;
  final DateTime dateTime;
  final String distance;

  const BookingSummaryScreen({
    Key? key,
    required this.pickup,
    required this.destination,
    required this.rideType,
    required this.passengers,
    required this.dateTime,
    required this.distance,
  }) : super(key: key);

  @override
  State<BookingSummaryScreen> createState() => _BookingSummaryScreenState();
}

class _BookingSummaryScreenState extends State<BookingSummaryScreen> {

  bool _isLoading = false;

  @override
  void initState() {
    super.initState();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      SystemChrome.setSystemUIOverlayStyle(
        const SystemUiOverlayStyle(
          statusBarColor: Colors.blue, // or any color you want
          statusBarIconBrightness: Brightness.light, // use Brightness.light for white icons
        ),
      );
    });
  }
  Future<void> _confirmBooking(BuildContext context) async {
    setState(() {
      _isLoading = true;
    });

    try {
      final prefs = await SharedPreferences.getInstance();
      final phoneNumber = prefs.getString('gotan_phone_number') ?? '1234567890';
      final orderId = prefs.getString('gotan_orderId') ?? '0000';

      final distanceValue = double.parse(widget.distance.replaceAll(RegExp(r'[^0-9.]'), ''));
      final priceMultiplier = widget.rideType == "Bike" ? 1 : widget.rideType == "Auto" ? 2 : 3;
      final expectedPrice = (distanceValue * 10 * priceMultiplier).toStringAsFixed(2);
      //back print(expectedPrice);
      //back print('=== price');

      final payload = {
        "phoneNumber": phoneNumber,
        "orderId": orderId,
        "expectedPrice": (double.parse(expectedPrice)).round(), // or .toInt()
        "distance": widget.distance,
      };

      final uri = Uri.parse(Common.baseUrl + 'api/user/acceptBookRiderOrder')
          .replace(queryParameters: {'cityName': 'Gotan'});

      final response = await http.post(
        uri,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(payload),
      );
      //back print(payload);
      //back print('===');


      setState(() {
        _isLoading = false;
      });

      if (response.statusCode == 200) {
        final jsonData = jsonDecode(response.body);
        //back print(jsonData);
        setState(() {
          SystemChrome.setSystemUIOverlayStyle(SystemUiOverlayStyle(
            statusBarColor: Colors.white,
            statusBarIconBrightness: Brightness.dark,
          ));
        });
        // Navigator.pushReplacement(
        //   context,
        //   MaterialPageRoute(
        //     builder: (context) => LottieSplashScreen(
        //       nextPage: HomePage(),
        //       assetPath: 'assets/animations/confirm.json',
        //     ),
        //   ),
        // );
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => LottieSplashScreenToHome(orderId: orderId, phoneNumber: phoneNumber, isRide: true),
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Booking confirmation failed: ${response.body}')),
        );
      }
    } catch (e) {
      setState(() {
        _isLoading = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e')),
      );
    }
  }




  @override
  Widget build(BuildContext context) {
    // SystemChrome.setSystemUIOverlayStyle(SystemUiOverlayStyle(
    //   statusBarColor: Colors.blue, // Match gradient start
    //   statusBarIconBrightness: Brightness.light,
    // ));
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle(
        statusBarColor: Colors.blue, // or any background
        statusBarIconBrightness: Brightness.light,
      ),
      child: Scaffold(
        resizeToAvoidBottomInset: true,
        appBar: PreferredSize(
          preferredSize: const Size.fromHeight(47),
          child: Container(
            alignment: Alignment.bottomCenter,
            padding: const EdgeInsets.only(bottom: 16, right: 16, left: 16),
            decoration: const BoxDecoration(
              color: Colors.blue
            ),
            child: SafeArea(
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  GestureDetector(
                    onTap: () => Navigator.pop(context),
                    child: const Icon(Icons.arrow_back, color: Colors.white),
                  ),
                  const Text(
                    "Confirm Your Booking",
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const Opacity(
                    opacity: 0.0,
                    child: Icon(Icons.location_on, color: Colors.white, size: 20),
                  ),
                ],
              ),
            ),
          ),
        ),
        body: SafeArea(
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 20),
                // Pickup & Drop Card
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16.0),
                  child: Card(
                    elevation: 4,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Pickup
                          Row(
                            children: [
                              const Icon(Icons.location_on, color: Colors.green),
                              const SizedBox(width: 8),
                              const Text("Pickup",
                                  style: TextStyle(
                                      fontWeight: FontWeight.bold, fontSize: 16)),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Text(
                            widget.pickup,
                            style: const TextStyle(fontSize: 14),
                          ),
                          const SizedBox(height: 16),
                          // Drop
                          Row(
                            children: [
                              const Icon(Icons.location_on, color: Colors.orange),
                              const SizedBox(width: 8),
                              const Text("Drop",
                                  style: TextStyle(
                                      fontWeight: FontWeight.bold, fontSize: 16)),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Text(
                            widget.destination,
                            style: const TextStyle(fontSize: 14),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),

                const SizedBox(height: 20),

                // Booking Summary
                Column(
                  children: [
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16.0),
                      child: Container(
                        width: double.infinity,
                        decoration: BoxDecoration(
                          color: Colors.blue,
                          borderRadius: const BorderRadius.only(
                              topLeft: Radius.circular(16),
                              topRight: Radius.circular(16)),
                        ),
                        padding: const EdgeInsets.all(16.0),
                        child: const Text(
                          "Booking Summary\nPlease review your booking details",
                          textAlign: TextAlign.center,
                          style: TextStyle(
                              color: Colors.white,
                              fontSize: 16,
                              fontWeight: FontWeight.bold),
                        ),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.only(left: 16, right: 16),
                      child: Container(
                        decoration: BoxDecoration(
                          color: Colors.blue[50],
                        ),
                        width: double.infinity,
                        child: Center(
                          child: Lottie.asset(
                            "assets/animations/booking.json",
                            height: 250,
                            fit: BoxFit.contain,
                          ),
                        ),
                      ),
                    ),

                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16.0),
                      child: Container(
                        width: double.infinity,
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: const BorderRadius.vertical(bottom: Radius.circular(16)),
                          boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 4)],
                        ),
                        child: Column(
                          children: [
                            // Journey Details
                            Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text("Journey Details", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                                  const SizedBox(height: 8),
                                  _infoRow("Vehicle Type", widget.rideType),
                                  _infoRow("Distance", widget.distance),
                                  _infoRow("Pickup Time", _formatDateTime(widget.dateTime)),
                                  _infoRow("City", "Gotan"),
                                  const SizedBox(height: 16),

                                  // Fare Details
                                  const Text("Fare Details", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                                  const SizedBox(height: 8),
                                  _infoRow(
                                      "Base fare",
                                      '₹${_calculatePrice().toStringAsFixed(2)}'
                                  ),
                                  _infoRow("Service fee", "₹--"),
                                  const Divider(),
                                  _infoRow(
                                      "Total",
                                      '₹${_calculatePrice().toStringAsFixed(2)}',
                                      isBold: true
                                  ),
                                  const SizedBox(height: 16),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),

                    const SizedBox(height: 20),

                    // Action Buttons
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16.0),
                      child: Row(
                        children: [
                          Expanded(
                            child: OutlinedButton(
                              onPressed: () => Navigator.pop(context),
                              child: const Text("Cancel"),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: ElevatedButton(
                              onPressed: _isLoading ? null : () => _confirmBooking(context),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.blue,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                              child: _isLoading
                                  ? const SizedBox(
                                height: 20,
                                width: 20,
                                child: SizedBox(
                                  width: 18,
                                  height: 18,
                                  child: const CircularProgressIndicator(color: Colors.white, ),
                                )
                              )
                                  : const Text(
                                "Confirm Booking",
                                style: TextStyle(color: Colors.white),
                              ),
                            ),
                          ),

                        ],
                      ),
                    ),

                    const SizedBox(height: 20),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  double _calculatePrice() {
    final distanceValue = double.parse(widget.distance.replaceAll(RegExp(r'[^0-9.]'), ''));
    final priceMultiplier = widget.rideType == "Bike" ? 1 : widget.rideType == "Auto" ? 2 : 3;
    return distanceValue * 10 * priceMultiplier;
  }
}

String _formatDateTime(DateTime dateTime) {
  return "${_getWeekday(dateTime.weekday)}, ${_getMonth(dateTime.month)} ${dateTime.day}, ${_formatTime(dateTime)}";
}

String _getWeekday(int weekday) {
  const days = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
  return days[weekday - 1];
}

String _getMonth(int month) {
  const months = [
    'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
    'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
  ];
  return months[month - 1];
}

String _formatTime(DateTime time) {
  final hour = time.hour > 12 ? time.hour - 12 : time.hour;
  final period = time.hour >= 12 ? "PM" : "AM";
  return "$hour:${time.minute.toString().padLeft(2, '0')} $period";
}

Widget _infoRow(String label, String value, {bool isBold = false}) {
  return Padding(
    padding: const EdgeInsets.symmetric(vertical: 2),
    child: Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: TextStyle(fontWeight: isBold ? FontWeight.bold : FontWeight.normal)),
        Text(value, style: TextStyle(fontWeight: isBold ? FontWeight.bold : FontWeight.normal)),
      ],
    ),
  );
}