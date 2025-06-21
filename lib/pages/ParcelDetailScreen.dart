import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:gotan/global/common.dart';

class ParcelDetailScreen extends StatefulWidget {
  final String phoneNumber;
  final String orderId;

  ParcelDetailScreen({required this.phoneNumber, required this.orderId});

  @override
  _ParcelDetailScreenState createState() => _ParcelDetailScreenState();
}

class _ParcelDetailScreenState extends State<ParcelDetailScreen> {
  Map<String, dynamic>? rideDetails;
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    fetchRideDetails();
  }

  Future<void> fetchRideDetails() async {
    const url = Common.baseUrl + 'api/user/getCurrentParcelOrder';
    final payload = {
      "phoneNumber": widget.phoneNumber,
      "orderId": widget.orderId
    };

    try {
      final response = await http.post(
        Uri.parse(url),
        headers: {"Content-Type": "application/json"},
        body: jsonEncode(payload),
      );

      if (response.statusCode == 200) {
        setState(() {
          rideDetails = jsonDecode(response.body);
          isLoading = false;
        });
      } else {
        throw Exception('Failed to load ride details');
      }
    } catch (e) {
      //back print("Error: $e");
      setState(() => isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        title: const Text("Parcel Details"),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(40),
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            color: Colors.grey.shade700,
            child: const Text(
              "Awaiting Status Update",
              style: TextStyle(color: Colors.white),
              textAlign: TextAlign.center,
            ),
          ),
        ),
      ),
      body: isLoading
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
                      boxShadow: [
                        BoxShadow(
                          blurRadius: 4,
                          color: Colors.black12,
                        )
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        const CircleAvatar(
                          radius: 32,
                          backgroundColor: Colors.grey,
                        ),
                        const SizedBox(height: 8),
                        const Text(
                          "• Updating status...",
                          style: TextStyle(color: Colors.grey),
                        ),
                        const Divider(height: 32),
                        _infoRow(Icons.phone, "Phone", rideDetails!['sellerPhone']),
                        _infoRow(Icons.local_taxi, "Vehicle", rideDetails!['vehicleType']),
                        _infoRow(Icons.language, "Domain", rideDetails!['cityName']),
                        _infoRow(Icons.monetization_on, "Price", rideDetails!['expectedPrice']),
                        const SizedBox(height: 16),
                        Container(
                          padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
                          decoration: BoxDecoration(
                            color: Colors.grey.shade100,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Row(
                            children: [
                              const Icon(Icons.verified_user, color: Colors.blue),
                              const SizedBox(width: 8),
                              const Text("Customer OTP"),
                              const Spacer(),
                              ElevatedButton(
                                onPressed: () {},
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.grey.shade200,
                                  foregroundColor: Colors.black,
                                  padding: const EdgeInsets.symmetric(horizontal: 12),
                                ),
                                child: const Text("Show to rider"),
                              )
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
                      boxShadow: [
                        BoxShadow(
                          blurRadius: 4,
                          color: Colors.black12,
                        )
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text("Journey Details", style: TextStyle(fontWeight: FontWeight.bold)),
                        const SizedBox(height: 16),
                        _locationRow(
                          title: "Pickup Location",
                          icon: Icons.location_pin,
                          color: Colors.green,
                          address: rideDetails!['pickupAddress'],
                        ),
                        const SizedBox(height: 16),
                        _locationRow(
                          title: "Drop Location",
                          icon: Icons.location_pin,
                          color: Colors.orange,
                          address: rideDetails!['deliveryAddress'],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () {},
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
                    onPressed: () {},
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
          )
        ],
      ),
    );
  }

  Widget _infoRow(IconData icon, String label, String? value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Icon(icon, size: 18),
          const SizedBox(width: 8),
          Text("$label: "),
          Expanded(child: Text(value ?? 'N/A')),
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
