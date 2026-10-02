import 'dart:convert';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:gotan/global/common.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:lottie/lottie.dart';

class Order {
  final String orderId;
  final String productName;
  final String productImage;
  final String shopId;
  final String orderStatus;
  final DateTime date;
  final int coupontotal;
  final int productCount;

  Order({
    required this.orderId,
    required this.productName,
    required this.productImage,
    required this.shopId,
    required this.orderStatus,
    required this.date,
    required this.coupontotal,
    required this.productCount,
  });

  factory Order.fromJson(Map<String, dynamic> json) {
    return Order(
      orderId: json['orderId'] ?? 'N/A',
      productName: json['productName'] ?? 'Unknown Product',
      productImage: json['productImage'] ?? '',
      shopId: json['shopId'] ?? 'Unknown Shop',
      orderStatus: json['orderStatus'] ?? 'Pending',
      date: DateTime.parse(json['date'] ?? DateTime.now().toString()),
      coupontotal: json['totalCartValue'] ?? 0,
      productCount: json['productCount'] ?? 1,
    );
  }
}

class OrderHistoryPage extends StatefulWidget {
  @override
  _OrderHistoryPageState createState() => _OrderHistoryPageState();
}

class _OrderHistoryPageState extends State<OrderHistoryPage> {
  late Future<List<Order>> futureOrders;
  Map<String, dynamic> shopHeader = {};
  bool isLoading = true;
  String? _storedEmail;

  @override
  void initState() {
    super.initState();
    loadShopHeader();
    checkStoredEmail();
    futureOrders = fetchOrders();
  }

  Future<void> checkStoredEmail() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    String? email = prefs.getString('user_email');

    if (email != null) {
      setState(() {
        _storedEmail = email;
        isLoading = false;
      });
    } else {
      setState(() {
        _storedEmail = null;
        isLoading = false;
      });
    }
  }

  Future<void> loadShopHeader() async {
    final prefs = await SharedPreferences.getInstance();
    final headerString = prefs.getString('shopHeader');
    if (headerString != null) {
      setState(() {
        shopHeader = jsonDecode(headerString);
      });
    }
  }

  Future<List<Order>> fetchOrders() async {
    try {

      final prefs = await SharedPreferences.getInstance();
      final email = prefs.getString('user_email');

      final response = await http.post(
        Uri.parse(Common.digiBaseUrl + 'customer/getcustomer'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'email': "\"$email\""}),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final List ordersJson = data['orders'] ?? [];
        //back print('------');
        //back print(data['orders']);
        return ordersJson.map((json) => Order.fromJson(json)).toList();
      } else {
        throw Exception('Failed to load orders with status: ${response.statusCode}');
      }
    } catch (e) {
      //back print('Error fetching orders: $e');
      throw Exception('Failed to load orders');
    }
  }

  // void showTrackOrderDialog(BuildContext context, String status) {
  //   showDialog(
  //     context: context,
  //     builder: (_) => AlertDialog(
  //       backgroundColor: Colors.deepPurple,
  //       contentPadding: const EdgeInsets.all(0),
  //       shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
  //       content: SizedBox(
  //         width: 300,
  //         child: Column(
  //           mainAxisSize: MainAxisSize.min,
  //           children: [
  //             Container(
  //               padding: const EdgeInsets.symmetric(vertical: 20),
  //               child: Column(
  //                 children: const [
  //                   Text("Track Order",
  //                       style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.white)),
  //                   SizedBox(height: 5),
  //                   Text("Your order is pending confirmation",
  //                       style: TextStyle(color: Colors.white)),
  //                 ],
  //               ),
  //             ),
  //             Container(
  //               decoration: BoxDecoration(
  //                   color: Colors.white,
  //                   borderRadius: BorderRadius.only(bottomRight: Radius.circular(12), bottomLeft: Radius.circular(12))
  //               ),
  //               padding: const EdgeInsets.all(16),
  //               child: Column(
  //                 children: [
  //                   Row(
  //                     mainAxisAlignment: MainAxisAlignment.spaceAround,
  //                     children: [
  //                       _buildStepCircle("1", "Pending", true),
  //                       _buildStepCircle("2", "Confirmed", false),
  //                       _buildStepCircle("3", "Shipped", false),
  //                     ],
  //                   ),
  //                   const SizedBox(height: 16),
  //                   Container(
  //                     padding: const EdgeInsets.all(10),
  //                     decoration: BoxDecoration(
  //                       color: Colors.deepPurple[100],
  //                       borderRadius: BorderRadius.circular(10),
  //                     ),
  //                     child: Row(
  //                       children: const [
  //                         Icon(Icons.inventory, color: Colors.deepPurple),
  //                         SizedBox(width: 10),
  //                         Text("Current Status: Pending",
  //                             style: TextStyle(fontWeight: FontWeight.bold)),
  //                       ],
  //                     ),
  //                   ),
  //                   const SizedBox(height: 20),
  //                   Container(
  //                     width: double.infinity,
  //                     child: ElevatedButton(
  //                       onPressed: () => Navigator.pop(context),
  //                       style: ElevatedButton.styleFrom(
  //                         elevation: 4,
  //                         backgroundColor: Colors.white,
  //                         padding: const EdgeInsets.symmetric(vertical: 16),
  //                         shape: RoundedRectangleBorder(
  //                           borderRadius: BorderRadius.circular(20),
  //                           side: const BorderSide(color: Colors.grey, width: 0.5),
  //                         ),
  //                       ),
  //                       child: const Text(
  //                         'CLOSE',
  //                         style: TextStyle(fontSize: 16, color: Colors.black),
  //                       ),
  //                     ),
  //                   ),
  //                 ],
  //               ),
  //             )
  //           ],
  //         ),
  //       ),
  //     ),
  //   );
  // }
  void showTrackOrderDialog(BuildContext context, String status) {
    final upperStatus = status.toUpperCase();

    // Color and icon based on status
    Color statusColor;
    String statusMessage;
    IconData statusIcon;

    switch (upperStatus) {
      case "CONFIRMED":
        statusColor = Colors.orange;
        statusMessage = "Your order has been confirmed";
        statusIcon = Icons.check_circle_outline;
        break;
      case "SHIPPED":
        statusColor = Colors.green;
        statusMessage = "Your order has been shipped";
        statusIcon = Icons.local_shipping_outlined;
        break;
      case "CANCEL":
        statusColor = Colors.red;
        statusMessage = "Your order has been cancelled";
        statusIcon = Icons.cancel_outlined;
        break;
      case "PENDING":
      default:
        statusColor = Colors.blue;
        statusMessage = "Your order is pending";
        statusIcon = Icons.access_time;
    }

    bool isConfirmed = upperStatus == "CONFIRMED" || upperStatus == "SHIPPED";
    bool isShipped = upperStatus == "SHIPPED";

    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: statusColor,
        contentPadding: const EdgeInsets.all(0),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
        content: SizedBox(
          width: 300,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(vertical: 20),
                child: Column(
                  children: [
                    const Text("Track Order",
                        style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.white)),
                    const SizedBox(height: 5),
                    Text(statusMessage, style: const TextStyle(color: Colors.white)),
                  ],
                ),
              ),
              Container(
                decoration: const BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.only(
                      bottomRight: Radius.circular(12),
                      bottomLeft: Radius.circular(12)),
                ),
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceAround,
                      children: [
                        _buildStepCircle("1", "Pending", true, statusColor),
                        SizedBox(width: 15,),
                        _buildStepLine(isConfirmed ? statusColor : Colors.grey),
                        SizedBox(width:15,),
                        _buildStepCircle("2", "Confirmed", isConfirmed, statusColor),
                        SizedBox(width: 15,),
                        _buildStepLine(isShipped ? statusColor : Colors.grey),
                        SizedBox(width: 15,),
                        _buildStepCircle("3", "Shipped", isShipped, statusColor),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: statusColor.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Row(
                        children: [
                          Icon(statusIcon, color: statusColor),
                          const SizedBox(width: 10),
                          Text("Current Status: ${status[0].toUpperCase()}${status.substring(1).toLowerCase()}",
                              style: const TextStyle(fontWeight: FontWeight.bold)),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: () => Navigator.pop(context),
                        style: ElevatedButton.styleFrom(
                          elevation: 4,
                          backgroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(20),
                            side: const BorderSide(color: Colors.grey, width: 0.5),
                          ),
                        ),
                        child: const Text(
                          'CLOSE',
                          style: TextStyle(fontSize: 16, color: Colors.black),
                        ),
                      ),
                    ),
                  ],
                ),
              )
            ],
          ),
        ),
      ),
    );
  }

  // Widget _buildStepCircle(String number, String label, bool active) {
  //   return Column(
  //     children: [
  //       CircleAvatar(
  //         backgroundColor: active ? Colors.deepPurple[500] : Colors.grey[300],
  //         child: Text(number,
  //             style: TextStyle(color: active ? Colors.white : Colors.black)),
  //       ),
  //       const SizedBox(height: 5),
  //       Text(label,
  //           style: TextStyle(
  //               color: active ? Colors.black : Colors.grey,
  //               fontWeight: active ? FontWeight.bold : FontWeight.normal)),
  //     ],
  //   );
  // }

  Widget _buildStepLine(Color color) {
    return Expanded(
      child: Container(
        height: 2,
        color: color,
      ),
    );
  }


  Widget _buildStepCircle(String step, String label, bool active, Color activeColor) {
    return Column(
      children: [
        CircleAvatar(
          radius: 16,
          backgroundColor: active ? activeColor : Colors.grey[300],
          child: Text(
            step,
            style: TextStyle(
                color: active ? Colors.white : Colors.black, fontWeight: FontWeight.bold),
          ),
        ),
        const SizedBox(height: 6),
        Text(label,
            style: TextStyle(
                fontSize: 12, color: active ? activeColor : Colors.grey)),
      ],
    );
  }


  Future<void> _handleRefresh() async {
    await Future.delayed(Duration(seconds: 2)); // simulate delay
    setState(() {
      loadShopHeader();
      checkStoredEmail();
      futureOrders = fetchOrders();
      // update your data here
    });
  }



  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // const SizedBox(height: 14),
            _buildHeader(),
            const SizedBox(height: 5),
            // const Divider(height: 1),
            _storedEmail == null ? SizedBox(
              height: MediaQuery.of(context).size.height - 3 * kToolbarHeight,
              child: Center(
                child: SizedBox(
                  height: 200,
                  child: Lottie.asset('assets/animations/empty_tasks.json'),
                ),
              ),
            ) :
            Expanded(
              child: FutureBuilder<List<Order>>(
                future: futureOrders,
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  if (snapshot.hasError) {
                    return Center(child: Text("Error: ${snapshot.error}"));
                  }

                  if (!snapshot.hasData || snapshot.data!.isEmpty) {
                    return Center(
                      child: SizedBox(
                        height: 200,
                        child: Lottie.asset('assets/animations/empty_tasks.json'),
                      ),
                    );
                  }

                  final orders = snapshot.data!.reversed.toList();

                  return RefreshIndicator(
                    onRefresh: _handleRefresh,
                    color: Colors.deepPurple,              // Spinner color
                    // backgroundColor: Color(0xFF265DFF),
                    child: ListView.builder(
                      itemCount: orders.length,
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      itemBuilder: (context, index) {
                        final order = orders[index];
                        return Card(
                          color: Colors.white,
                          margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(15)),
                          elevation: 4,
                          child: Padding(
                            padding: const EdgeInsets.all(15.0),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Center(
                                  child: order.productImage.isNotEmpty
                                      ? Stack(
                                    alignment: Alignment.topRight,
                                    children: [
                                      Image.network(
                                        order.productImage,
                                        height: 120,
                                        fit: BoxFit.contain,
                                        errorBuilder: (context, error, stackTrace) =>
                                        const Icon(Icons.broken_image, size: 120),
                                      ),
                                      if (order.productCount > 1)
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                          margin: const EdgeInsets.only(top: 4, right: 4),
                                          decoration: BoxDecoration(
                                            color: Colors.black54,
                                            borderRadius: BorderRadius.circular(8),
                                          ),
                                          child: Text(
                                            'X${order.productCount}',
                                            style: const TextStyle(
                                              color: Colors.white,
                                              fontWeight: FontWeight.bold,
                                              fontSize: 14,
                                            ),
                                          ),
                                        ),
                                    ],
                                  )
                                      : const Icon(Icons.image_not_supported, size: 120),
                                ),

                                const SizedBox(height: 10),
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Expanded(
                                      child: Text("Order #${order.orderId}",
                                          style: const TextStyle(fontSize: 12)),
                                    ),
                                    // Expanded(
                                    //   child: Align(
                                    //     alignment: Alignment.bottomRight,
                                    //     child: Text(
                                    //       DateFormat("yyyy-MM-dd – kk:mm").format(order.date),
                                    //       style: const TextStyle(fontSize: 12),
                                    //     ),
                                    //   ),
                                    // ),
                                    Expanded(
                                      child: Align(
                                        alignment: Alignment.bottomRight,
                                        child: Text(
                                          DateFormat("yyyy-MM-dd – kk:mm")
                                              .format(order.date.toUtc().add(const Duration(hours: 5, minutes: 30))),
                                          style: const TextStyle(fontSize: 12),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 5),
                                Text(order.productName,
                                    style: const TextStyle(
                                        fontSize: 18, fontWeight: FontWeight.bold)),
                                Text("Sold by: ${order.shopId}",
                                    style: TextStyle(color: Colors.grey[700])),
                                const SizedBox(height: 10),
                                // Container(
                                //   padding: const EdgeInsets.symmetric(
                                //       horizontal: 12, vertical: 6),
                                //   decoration: BoxDecoration(
                                //     color: Colors.blue[50],
                                //     borderRadius: BorderRadius.circular(12),
                                //   ),
                                //   child: Text(
                                //     "🔄 Your order is ${order.orderStatus}",
                                //     style: const TextStyle(color: Colors.blue),
                                //   ),
                                // ),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                  decoration: BoxDecoration(
                                    color: _getStatusColor(order.orderStatus),
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(
                                        _getStatusIcon(order.orderStatus),
                                        color: Colors.white,
                                        size: 16,
                                      ),
                                      const SizedBox(width: 6),
                                      Text(
                                        "Your order is ${order.orderStatus}",
                                        style: const TextStyle(color: Colors.white),
                                      ),
                                    ],
                                  ),
                                ),

                                const SizedBox(height: 10),
                                Row(
                                  children: [
                                    ElevatedButton.icon(
                                      onPressed: () {
                                        showTrackOrderDialog(context, order.orderStatus);
                                      },
                                      icon: const Icon(Icons.local_shipping_outlined),
                                      label: const Text("Track Order"),
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: Colors.deepPurple,
                                        foregroundColor: Colors.white,
                                        shape: RoundedRectangleBorder(
                                            borderRadius: BorderRadius.circular(10)),
                                      ),
                                    ),
                                    const Spacer(),
                                    Text(
                                      "₹${order.coupontotal+20}",
                                      style: const TextStyle(
                                          fontSize: 16,
                                          color: Colors.green,
                                          fontWeight: FontWeight.bold),
                                    ),
                                  ],
                                )
                              ],
                            ),
                          ),
                        );
                      },
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  IconData _getStatusIcon(String status) {
    switch (status.toUpperCase()) {
      case "PENDING":
        return Icons.hourglass_bottom;
      case "CONFIRMED":
        return Icons.check_circle_outline;
      case "SHIPPED":
        return Icons.local_shipping_outlined;
      case "CANCEL":
        return Icons.cancel_outlined;
      default:
        return Icons.info_outline; // fallback icon
    }
  }


  Color _getStatusColor(String status) {
    switch (status.toUpperCase()) {
      case 'PENDING':
        return Colors.blue.shade500;
      case 'CONFIRMED':
        return Colors.orange.shade500;
      case 'SHIPPED':
        return Colors.green.shade500;
      case 'CANCEL':
      case 'CANCELLED':
        return Colors.red.shade400;
      default:
        return Colors.grey.shade200; // fallback for unknown statuses
    }
  }


  Widget _buildHeader() {
    if (shopHeader.isEmpty) return const SizedBox.shrink();

    return Container(
      padding: const EdgeInsets.all(12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          const SizedBox(width: 20),
          // shopHeader['logo'] != null && shopHeader['logo'].isNotEmpty
          //     ? Image.network(shopHeader['logo'], width: 40, errorBuilder: (_, __, ___) => const Icon(Icons.store, size: 40))
          //     : const Icon(Icons.store, size: 40),
          shopHeader['logo'] != null
              ? Image.network(shopHeader['logo'], width: 40)
              : const Icon(Icons.store, size: 40),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Text(shopHeader['shopName']?.toString() ?? 'Shop',
                    style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                Text(shopHeader['email']?.toString() ?? '',
                    style: const TextStyle(color: Colors.black)),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.call, color: Colors.green),
            onPressed: () async {
              var rawPhone = shopHeader['phoneNumber']?.toString() ?? '';
              var phone = rawPhone.replaceAll(RegExp(r'\D'), ''); // Remove non-digits

              if (phone.isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('No phone number available')),
                );
                return;
              }

              final whatsappUrl = Uri.parse("https://wa.me/$phone");

              if (await canLaunchUrl(whatsappUrl)) {
                await launchUrl(whatsappUrl, mode: LaunchMode.externalApplication);
              } else {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Could not launch WhatsApp')),
                );
              }
            },
          ),
        ],
      ),
    );
  }
}