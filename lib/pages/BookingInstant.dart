import 'dart:convert';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:gotan/global/common.dart';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

import 'HomePage.dart';

class BookingInstant extends StatefulWidget {
  final String phoneNumber;
  final String orderId;

  const BookingInstant({required this.phoneNumber, required this.orderId});

  @override
  _BookingInstantState createState() => _BookingInstantState();
}

class _BookingInstantState extends State<BookingInstant> {
  Future<void> _cancelRide() async {
    final url = Common.baseUrl + 'api/user/cancelRiderOrder';
    final payload = {
      "phoneNumber": widget.phoneNumber,
      "orderId": widget.orderId,
    };
    bool backendSuccess = false;
    String backendMessage = '';
    try {
      final response = await http.post(
        Uri.parse(url),
        headers: {"Content-Type": "application/json"},
        body: jsonEncode(payload),
      );
      backendMessage = response.body;
      if (response.statusCode == 200) {
        backendSuccess = true;
      }
    } catch (e) {
      backendMessage = e.toString();
    }
    // Always remove orderId so user can book again
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('gotan_orderId');
    if (mounted) {
      if (backendSuccess) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Ride cancelled successfully.')),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Warning: Ride may not be cancelled on server. Details: $backendMessage')),
        );
      }
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (_) => HomePage()),
        (route) => false,
      );
    }
  }
  Map<String, dynamic>? rideDetails;
  bool isLoading = true;
  Timer? _timer;
  String otp = '';

  @override
  void initState() {
    super.initState();
    fetchRideDetails();
    print('details');
    print(widget.phoneNumber+''+widget.orderId);
    _timer = Timer.periodic(const Duration(seconds: 5), (timer) {
      print('calling');
      print('details');
      print(widget.phoneNumber+''+widget.orderId);
      fetchRideDetails();
    });
    fetchOtp();
  }

  void fetchOtp() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    otp = prefs.getString('gotan_userOtp') ?? "";
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  Future<void> fetchRideDetails() async {
    const url = Common.baseUrl + 'api/user/getCurrentRiderOrder';
    final payload = {
      "phoneNumber": widget.phoneNumber,
      "orderId": widget.orderId,
    };

    try {
      final response = await http.post(
        Uri.parse(url),
        headers: {"Content-Type": "application/json"},
        body: jsonEncode(payload),
      );

      if (response.statusCode == 200) {
        print('success');
        if (!mounted) return; // ✅ Prevent setState if widget is disposed
        setState(() {
          rideDetails = jsonDecode(response.body);
          isLoading = false;
        });
      } else {
        if (!mounted) return;
        setState(() => isLoading = false);
      }
    } catch (e) {
      if (!mounted) return;
      setState(() => isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return WillPopScope(
      onWillPop: () async {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => HomePage()),
        );
        return false; // ❗ prevent default pop
      },
      child: AnnotatedRegion<SystemUiOverlayStyle>(
        value: SystemUiOverlayStyle(
        statusBarColor: Colors.white, // or any background
        statusBarIconBrightness: Brightness.dark,
        ),
        child: Scaffold(
          backgroundColor: Colors.white,
          appBar: AppBar(
            automaticallyImplyLeading: false,
            backgroundColor: Colors.white,
            title: const Text("Ride Details"),
            bottom: PreferredSize(
              preferredSize: const Size.fromHeight(40),
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                color: rideDetails?['riderStatus'] == 'In Transit'? Colors.blue : rideDetails?['riderStatus'] == 'Delivered'? Colors.green: Colors.grey.shade700,
                child: Text(
                  (rideDetails?['riderAccepted'] == false)
                      ? 'Awaiting status Update'
                      : (rideDetails?['riderStatus'] ?? 'Unknown'),
                  style: const TextStyle(color: Colors.white),
                  textAlign: TextAlign.center,
                ),
              ),
            ),
          ),
          body:
          isLoading
              ? const Center(child: CircularProgressIndicator())
              : rideDetails == null
              ? const Center(child: Text("No details found"))
              : Column(
            children: [
              Expanded(
                child: SingleChildScrollView(
                  child: Column(
                    children: [
                      Container(
                        margin: const EdgeInsets.all(16),
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(12),
                          boxShadow: const [
                            BoxShadow(blurRadius: 4, color: Colors.black12),
                          ],
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                rideDetails!['riderAccepted']
                                    ? CircleAvatar(
                                  radius: 32,
                                  backgroundColor: Colors.grey
                                      .withOpacity(0.1),
                                  child: Padding(
                                    padding: const EdgeInsets.all(8.0),
                                    child: Image.asset(
                                      'assets/images/rider.png',
                                    ),
                                  ),
                                )
                                    : CircleAvatar(
                                  radius: 32,
                                  backgroundColor: Colors.grey,
                                ),
                                const SizedBox(width: 16),
                                Column(
                                  crossAxisAlignment:
                                  CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      rideDetails!['riderAccepted']? (rideDetails?['riderDetails']?[0]?['name'] ??
                                          'Unknown'): 'Unknown',
                                      style: const TextStyle(
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    SizedBox(height: 4),
                                    Row(
                                      children: [
                                        const CircleAvatar(
                                          radius: 5,
                                          backgroundColor: Colors.grey,
                                        ),
                                        const SizedBox(width: 6),
                                        Text(
                                          (rideDetails?['riderAccepted'] ==
                                              false)
                                              ? 'Updating status...'
                                              : (rideDetails?['riderStatus'] ??
                                              'Unknown'),
                                          style: TextStyle(
                                            fontSize: 13,
                                            color: Colors.grey.shade600,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                                Spacer(),
                                GestureDetector(
                                  onTap: () async {
                                    final riderPhone =
                                    rideDetails!['riderAccepted']? (rideDetails?['riderDetails']?[0]?['phoneNumber']): '';

                                    if (riderPhone != null &&
                                        riderPhone.toString().isNotEmpty) {
                                      final Uri callUri = Uri(
                                        scheme: 'tel',
                                        path: riderPhone,
                                      );

                                      if (await canLaunchUrl(callUri)) {
                                        await launchUrl(callUri);
                                      } else {
                                        ScaffoldMessenger.of(
                                          context,
                                        ).showSnackBar(
                                          const SnackBar(
                                            content: Text(
                                              'Unable to open dialer on this device',
                                            ),
                                          ),
                                        );
                                      }
                                    } else {
                                      ScaffoldMessenger.of(
                                        context,
                                      ).showSnackBar(
                                        const SnackBar(
                                          content: Text(
                                            'Phone number not available',
                                          ),
                                        ),
                                      );
                                    }
                                  },

                                  child: const CircleAvatar(
                                    radius: 20,
                                    backgroundColor: Colors.green,
                                    child: Icon(
                                      Icons.phone,
                                      color: Colors.white,
                                    ),
                                  ),
                                ),
                                SizedBox(width: 10),
                              ],
                            ),
                            const Divider(height: 32),
                            Row(
                              children: [
                                Expanded(
                                  child: _infoRow(
                                    Icons.phone,
                                    "Phone",
                                    rideDetails!['riderAccepted']? (rideDetails?['riderDetails']?[0]?['phoneNumber']): '',
                                  ),
                                ),
                                const SizedBox(width: 16),
                                Expanded(
                                  child: _infoRow(
                                    Icons.local_taxi,
                                    "Vehicle",
                                    rideDetails?['vehicleType'],
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 5),
                            Row(
                              children: [
                                Expanded(
                                  child: _infoRow(
                                    Icons.language,
                                    "Domain",
                                    rideDetails!['riderAccepted']? (rideDetails?['riderDetails']?[0]?['riderDomain']): '',
                                  ),
                                ),
                                const SizedBox(width: 16),
                                Expanded(
                                  child: _infoRow(
                                    Icons.monetization_on,
                                    "Price",
                                    rideDetails?['expectedPrice']
                                        ?.toString(),
                                  ),
                                ),
                              ],
                            ),

                            const SizedBox(height: 16),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                vertical: 15,
                                horizontal: 12,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.grey.shade100,
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Row(
                                children: [
                                  const Icon(
                                    Icons.verified_user,
                                    color: Colors.blue,
                                  ),
                                  const SizedBox(width: 8),
                                  const Text("Customer OTP"),
                                  const Spacer(),
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 20,
                                      vertical: 8,
                                    ),
                                    decoration: BoxDecoration(
                                      color: Colors.white,
                                      borderRadius: BorderRadius.circular(
                                        12,
                                      ),
                                    ),
                                    child: Text(
                                      otp.isNotEmpty ? otp : 'unknown',
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                      Container(
                        margin: const EdgeInsets.symmetric(horizontal: 16),
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(12),
                          boxShadow: const [
                            BoxShadow(blurRadius: 4, color: Colors.black12),
                          ],
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              "Journey Details",
                              style: TextStyle(fontWeight: FontWeight.bold),
                            ),
                            const SizedBox(height: 16),
                            _locationRow(
                              title: "Pickup Location",
                              icon: Icons.location_pin,
                              color: Colors.green,
                              address:
                              rideDetails?['pickupAddress'] ??
                                  'Unknown',
                            ),
                            const SizedBox(height: 16),
                            _locationRow(
                              title: "Drop Location",
                              icon: Icons.location_pin,
                              color: Colors.orange,
                              address:
                              rideDetails?['deliveryAddress'] ??
                                  'Unknown',
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              if (!(rideDetails?['riderAccepted'] == true))
                Padding(
                  padding: const EdgeInsets.only(right:16.0, bottom: 30),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      ElevatedButton.icon(
                        onPressed: () async {
                          Navigator.pushReplacement(
                            context,
                            MaterialPageRoute(builder: (_) => HomePage()),
                          );
                        },
                        icon: const Icon(Icons.watch_later),
                        label: const Text("Check Later"),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.grey.shade300,
                          foregroundColor: Colors.black,
                        ),
                      ),
                      
            
                    ],
                  ),
                ),
              // if(rideDetails?['riderAccepted'] == true)
              //   SizedBox(height: 10,),


              if(rideDetails?['riderAccepted'] == true)
                Container(
                  padding: const EdgeInsets.only(
                    bottom: 16,
                    left: 12,
                    right: 12,
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: () async {
                            final riderPhone =
                            rideDetails!['riderAccepted']? (rideDetails?['riderDetails']?[0]?['phoneNumber']) : '';

                            if (riderPhone != null &&
                                riderPhone.toString().isNotEmpty) {
                              final Uri callUri = Uri(
                                scheme: 'tel',
                                path: riderPhone,
                              );

                              if (await canLaunchUrl(callUri)) {
                                await launchUrl(callUri);
                              } else {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text(
                                      'Unable to open dialer on this device',
                                    ),
                                  ),
                                );
                              }
                            } else {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text('Phone number not available'),
                                ),
                              );
                            }
                          },
                          icon: const Icon(Icons.call),
                          label: const Text("Call Rider"),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.grey.shade300,
                            foregroundColor: Colors.black,
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: () async {
                            final pdf = pw.Document();
                            final data = rideDetails!;

                            // Safely get rider details
                            final rider = rideDetails!['riderAccepted']
                                ? (rideDetails?['riderDetails']?.isNotEmpty ?? false
                                ? rideDetails!['riderDetails'][0]
                                : null)
                                : null;

                            try {
                              final logoImage = await imageFromAssetBundle('assets/images/gologo.png');

                              pdf.addPage(
                                pw.Page(
                                  build: (context) => pw.Column(
                                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                                    children: [
                                      pw.Center(child: pw.Image(logoImage, height: 50)),
                                      pw.SizedBox(height: 20),
                                      pw.Row(
                                        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                                        children: [
                                          pw.Column(
                                            crossAxisAlignment: pw.CrossAxisAlignment.start,
                                            children: [
                                              pw.Text("Invoice To"),
                                              pw.Text(data['sellerName']?.toString() ?? "Unknown"),
                                              pw.Text(data['sellerPhone']?.toString() ?? "Unknown"),
                                              pw.Text(data['_id']?.toString() ?? ""),
                                            ],
                                          ),
                                          pw.Column(
                                            crossAxisAlignment: pw.CrossAxisAlignment.start,
                                            children: [
                                              pw.Text("Service Type"),
                                              pw.Text("Parcel Booking"),
                                            ],
                                          ),
                                        ],
                                      ),
                                      pw.SizedBox(height: 20),
                                      pw.Container(
                                        color: PdfColors.black,
                                        padding: const pw.EdgeInsets.all(6),
                                        child: pw.Text(
                                          'Order Details',
                                          style: pw.TextStyle(color: PdfColors.white),
                                        ),
                                      ),
                                      pw.Table(
                                        columnWidths: {
                                          0: pw.FlexColumnWidth(2),
                                          1: pw.FlexColumnWidth(5),
                                        },
                                        border: pw.TableBorder.all(),
                                        children: [
                                          _tableRow("PickUp Address", data['pickupAddress']?.toString()),
                                          _tableRow("Delivery Address", data['deliveryAddress']?.toString()),
                                          _tableRow(
                                            "Date and Time",
                                            DateFormat('dd-MM-yyyy hh:mm a').format(
                                                DateTime.parse(data['pickupTime']).toLocal()
                                            ),
                                          ),
                                          // _tableRow("Passengers", data['numOfPassengers']?.toString()),
                                          _tableRow("Weight", data['weight']?.toString()),
                                          _tableRow("Message", data['message']?.toString()),
                                          _tableRow("Rider Name", rider?['name']?.toString()),
                                          _tableRow("Rider Phone", rider?['phoneNumber']?.toString()),
                                          _tableRow("Rider Domain", rider?['riderDomain']?.toString()),
                                          _tableRow("Payment (COD)", data['expectedPrice']?.toString()),
                                        ],
                                      ),
                                      pw.SizedBox(height: 30),
                                      pw.Text("Thank you for choosing Gotan"),
                                      pw.Align(
                                        alignment: pw.Alignment.bottomRight,
                                        child: pw.Column(
                                          crossAxisAlignment: pw.CrossAxisAlignment.end,
                                          children: [
                                            pw.Text("Sign"),
                                            pw.Text("JodhPur Admin"),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              );

                              await Printing.layoutPdf(
                                onLayout: (format) async => pdf.save(),
                              );
                            } catch (e) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(content: Text('Error generating PDF: ${e.toString()}')),
                              );
                            }
                          },
                          icon: const Icon(Icons.receipt),
                          label: const Text("View Invoice"),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.grey.shade800,
                            foregroundColor: Colors.white,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  pw.TableRow _tableRow(String key, String? value) {
    return pw.TableRow(
      children: [
        pw.Padding(
          padding: const pw.EdgeInsets.all(6),
          child: pw.Text(
            key,
            style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
          ),
        ),
        pw.Padding(
          padding: const pw.EdgeInsets.all(6),
          child: pw.Text(value ?? 'Unknown'),
        ),
      ],
    );
  }

  Widget _infoRow(IconData icon, String label, String? value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 18),
          const SizedBox(width: 15),
          Expanded(
            // 👈 this makes sure the text doesn't overflow the row
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  "$label:",
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 2),
                Text(
                  (value != null && value.trim().isNotEmpty)
                      ? value
                      : 'Unknown',
                  softWrap: true,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _locationRow({
    required String title,
    required IconData icon,
    required Color color,
    required String address,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Column(
          children: [
            Icon(icon, color: color, size: 20),
            const SizedBox(height: 8),
            Container(width: 2, height: 40, color: Colors.grey.shade300),
          ],
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(height: 4),
              Text(address, style: TextStyle(color: Colors.grey.shade700)),
            ],
          ),
        ),
      ],
    );
  }
}
