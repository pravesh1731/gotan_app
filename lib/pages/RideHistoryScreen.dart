import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:gotan/global/common.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'RideDetailScreen.dart';
import 'dart:async'; // 👈 Important

class RideHistoryScreen extends StatefulWidget {
  @override
  _RideHistoryScreenState createState() => _RideHistoryScreenState();
}

class _RideHistoryScreenState extends State<RideHistoryScreen> {
  List<dynamic> rides = [];
  List<dynamic> filteredRides = [];
  bool isLoading = true;
  String selectedStatus = "All";
  String searchQuery = "";

  final searchController = TextEditingController();
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    fetchRideHistory();
    _timer = Timer.periodic(const Duration(seconds: 5), (timer) {
      fetchRideHistory();
    });
  }

  @override
  void dispose() {
    _timer?.cancel(); // 👈 Clean up timer to avoid memory leak
    searchController.dispose();
    super.dispose();
  }

  Future<void> fetchRideHistory() async {
    final prefs = await SharedPreferences.getInstance();
    final phoneNumber = prefs.getString('gotan_phone_number') ?? '1234567890';
    const url = Common.baseUrl + 'api/user/myRiderOrder';
    final payload = {"phoneNumber": phoneNumber};

    try {
      final response = await http.post(Uri.parse(url),
          headers: {"Content-Type": "application/json"},
          body: jsonEncode(payload));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body).reversed.toList();
        setState(() {
          rides = data;
          isLoading = false;
        });
        filterRides();
      } else {
        throw Exception('Failed to load rides');
      }
    } catch (e) {
      //back print("Error: $e");
      setState(() => isLoading = false);
    }
  }

  void filterRides() {
    final query = searchQuery.toLowerCase();
    setState(() {
      filteredRides = rides.where((ride) {
        final matchesStatus =
            selectedStatus == "All" ||
                (selectedStatus == "Delivered" && ride['riderStatus'] == "Delivered") ||
                (selectedStatus == "In Progress" && ride['riderStatus'] == "In Transit") ||
                (selectedStatus == "Pending" && ride['riderStatus'] == "En Route") ||
                (selectedStatus == "Cancelled" && ride['riderStatus'] == "Cancelled");


        final matchesSearch = ride['pickupAddress'].toLowerCase().contains(query) ||
            ride['deliveryAddress'].toLowerCase().contains(query);
        return matchesStatus && matchesSearch;
      }).toList();
    });
  }

  String formatDate(String dateTimeStr) {
    final date = DateTime.parse(dateTimeStr);
    return DateFormat("MMM d, h:mm a").format(date);
  }

  Widget buildStatusFilterButton(String status) {
    final isSelected = selectedStatus == status;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: ChoiceChip(
        label: Text(status),
        selected: isSelected,
        onSelected: (_) {
          setState(() {
            selectedStatus = status;
            filterRides();
          });
        },
        selectedColor: Colors.blue,
        labelStyle: TextStyle(
          color: isSelected ? Colors.white : Colors.black,
        ),
        backgroundColor: Colors.grey[200],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text('Ride History'),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 1,
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Search box
                TextField(
                  controller: searchController,
                  decoration: InputDecoration(
                    hintText: "Search by location or order ID",
                    filled: true,
                    fillColor: Colors.grey[100],
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none,
                    ),
                    prefixIcon: Icon(Icons.search),
                    suffixIcon: searchQuery.isNotEmpty
                        ? IconButton(
                      icon: Icon(Icons.clear),
                      onPressed: () {
                        searchController.clear();
                        setState(() {
                          searchQuery = "";
                          filterRides();
                        });
                      },
                    )
                        : null,
                  ),
                  onChanged: (value) {
                    searchQuery = value;
                    filterRides();
                  },
                ),
                const SizedBox(height: 10),
                // Filter chips
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      buildStatusFilterButton("All"),
                      buildStatusFilterButton("Delivered"),
                      buildStatusFilterButton("In Progress"),
                      buildStatusFilterButton("Pending"),
                      buildStatusFilterButton("Cancelled"),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          // Ride list
          Expanded(
            child: filteredRides.isEmpty
                ? const Center(child: Text("No rides found"))
                : ListView.builder(
              itemCount: filteredRides.length,
              itemBuilder: (context, index) {
                final ride = filteredRides[index];
                final pickup = ride['pickupAddress'] ?? '';
                final delivery = ride['deliveryAddress'] ?? '';
                final time = ride['pickupTime'] ?? '';
                final price = ride['expectedPrice'] ?? 'Calculating';
                final status = ride['riderStatus'] ?? '';

                return Card(
                  color: Colors.white,
                  margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  elevation: 3,
                  child: Padding(
                    padding: const EdgeInsets.all(12.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            CircleAvatar(
                              radius: 12,
                              backgroundColor: Colors.blue,
                              child: Text('${rides.length - index}', style: TextStyle(color: Colors.white, fontSize: 14)),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                delivery.length > 30 ? delivery.substring(0, 30) + '...' : delivery,
                                style: const TextStyle(fontWeight: FontWeight.bold),
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                              decoration: BoxDecoration(
                                  color: Colors.blue,
                                  borderRadius: BorderRadius.circular(12)),
                              child: Text(status, style: const TextStyle(color: Colors.white)),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            const Icon(Icons.calendar_today, size: 16),
                            const SizedBox(width: 6),
                            Text(formatDate(time), style: const TextStyle(fontSize: 13)),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            const Icon(Icons.location_pin, size: 18, color: Colors.green),
                            const SizedBox(width: 6),
                            Expanded(
                              child: Text(
                                pickup.length > 30 ? pickup.substring(0, 30) + '...' : pickup,
                                style: const TextStyle(fontSize: 14),
                              ),
                            ),
                            const SizedBox(width: 8),
                            const Icon(Icons.currency_rupee, size: 18, color: Colors.green),
                            Text(price.toString(), style: const TextStyle(fontWeight: FontWeight.bold)),
                          ],
                        ),
                        const SizedBox(height: 8),
                        ElevatedButton(
                          onPressed: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => RideDetailScreen(
                                  phoneNumber: ride['sellerPhone'],
                                  orderId: ride['_id'],
                                ),
                              ),
                            );
                          },
                          child: const Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text("View Details"),
                              SizedBox(width: 10),
                              Icon(Icons.arrow_forward_ios, size: 14),
                            ],
                          ),
                          style: ElevatedButton.styleFrom(
                            elevation: 0,
                            backgroundColor: Colors.grey.shade100,
                            foregroundColor: Colors.black,
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
