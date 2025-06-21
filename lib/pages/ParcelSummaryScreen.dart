import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:gotan/pages/homepage.dart';
import 'package:lottie/lottie.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;
import 'package:gotan/global/common.dart';

import '../splash/LottieSplashScreen.dart';

class ParcelSummaryScreen extends StatefulWidget {
  final String pickup;
  final String destination;
  final String rideType;
  final int passengers;
  final DateTime dateTime;
  final String distance;
  final String weight;
  final String instructions;


  const ParcelSummaryScreen({
    Key? key,
    required this.pickup,
    required this.destination,
    required this.rideType,
    required this.passengers,
    required this.dateTime,
    required this.distance,
    required this.weight,
    required this.instructions
  }) : super(key: key);

  @override
  State<ParcelSummaryScreen> createState() => _ParcelSummaryScreenState();
}

class _ParcelSummaryScreenState extends State<ParcelSummaryScreen> {

  bool _isLoading = false;
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

      final uri = Uri.parse(Common.baseUrl + 'api/user/acceptBookParcelOrder')
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
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (context) => LottieSplashScreen(
              nextPage: HomePage(),
              assetPath: 'assets/animations/confirm.json',
            ),
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

  // String _formatLatLng(LatLng latLng) {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      resizeToAvoidBottomInset: true,
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(47),
        child: Container(
          alignment: Alignment.bottomCenter,
          padding: const EdgeInsets.only(bottom: 16, right: 16, left: 16),
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [Colors.deepPurpleAccent, Colors.blue],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
          child: SafeArea(
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                GestureDetector(
                  onTap: () {
                    Navigator.pop(context);
                  },
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
                  opacity: 0.0, // Placeholder to balance layout
                  child: Icon(
                    Icons.location_on,
                    color: Colors.white,
                    size: 20,
                  ),
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
              // Header
              SizedBox(height: 20,),
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
                            Icon(Icons.location_on, color: Colors.green),
                            SizedBox(width: 8),
                            Text("Pickup",
                                style: TextStyle(
                                    fontWeight: FontWeight.bold, fontSize: 16)),
                          ],
                        ),
                        SizedBox(height: 4),
                        Text(
                          widget.pickup,
                          style: TextStyle(fontSize: 14),
                        ),
                        SizedBox(height: 16),
                        // Drop
                        Row(
                          children: [
                            Icon(Icons.location_on, color: Colors.orange),
                            SizedBox(width: 8),
                            Text("Drop",
                                style: TextStyle(
                                    fontWeight: FontWeight.bold, fontSize: 16)),
                          ],
                        ),
                        SizedBox(height: 4),
                        Text(
                          widget.destination,
                          style: TextStyle(fontSize: 14),
                        ),
                      ],
                    ),
                  ),
                ),
              ),

              SizedBox(height: 20),

              // Booking Summary
              Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16.0),
                    child: Container(
                      width: double.infinity,
                      decoration: BoxDecoration(
                        color: Colors.blue,
                        borderRadius: BorderRadius.only(
                            topLeft: Radius.circular(16),
                            topRight: Radius.circular(16)),
                      ),
                      padding: const EdgeInsets.all(16.0),
                      child: Text(
                        "Trip Details",
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
                        // borderRadius: BorderRadius.only(
                        //     bottomLeft: Radius.circular(16),
                        //     bottomRight: Radius.circular(16)),
                      ),
                      width: double.infinity,
                      child: Center(
                        child: Lottie.asset(
                          "assets/animations/driver.json",
                          // width: 200,
                          height: 250,
                          fit: BoxFit.contain,
                        ),
                      ),
                    ),
                  ),

                  Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 16.0),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(12.0),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black12,
                                blurRadius: 4,
                                offset: Offset(0, 2),
                              ),
                            ],
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              _infoRow("Distance", "${widget.distance}", isBold: true),
                              const SizedBox(height: 8),
                              _infoRow("Price", '₹ ${(double.parse(widget.distance.replaceAll(RegExp(r'[^0-9.]'), '')) * 10).toStringAsFixed(0)}', isBold: true),
                            ],
                          ),
                        ),
                        const SizedBox(height: 8),
                        const Text(
                          "Price calculated at ₹10 per km",
                          style: TextStyle(fontSize: 12, color: Colors.grey),
                        ),
                      ],
                    ),
                  ),


                  // const SizedBox(height: 5),

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

                        // Expanded(
                        //   child: ElevatedButton(
                        //     onPressed: () {
                        //       Navigator.push(
                        //         context,
                        //         MaterialPageRoute(
                        //           // builder: (context) => MapScreen(
                        //           //   pickup: widget.pickupLocation,
                        //           //   destination: _pickedLocation,
                        //           // ),
                        //           builder: (context) => LottieSplashScreen(
                        //             nextPage: HomePage(),
                        //             assetPath: 'assets/animations/confirm.json',
                        //           ),
                        //         ),
                        //       );
                        //     },
                        //     style: ElevatedButton.styleFrom(
                        //       backgroundColor: Colors.blue,
                        //     ),
                        //     child: const Text("Confirm Booking", style: TextStyle(color: Colors.white),),
                        //   ),
                        // ),
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
    );
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
