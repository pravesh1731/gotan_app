import 'dart:convert';

import 'package:flutter/material.dart';
// import 'package:gotan/pages/GoogleLoginPage.dart';
import 'package:provider/provider.dart';
import '../global/common.dart';
import '../model/cart_item.dart';
import '../providers/CartProvider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:lottie/lottie.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';

import '../providers/WishlistProvider.dart';
// import 'GoogleSignInOnly.dart';

class CartScreen extends StatefulWidget {
  final String storeId;
  // final Function(List<dynamic>) onNext;
  final VoidCallback onNext;
  final Function(List<dynamic>) onProductsSelected;
  const CartScreen({Key? key, required this.storeId, required this.onNext, required this.onProductsSelected, }) : super(key: key);

  @override
  State<CartScreen> createState() => _CartScreenState();
}

class _CartScreenState extends State<CartScreen> {
  Map<String, dynamic> shopResponse = {};
  List<dynamic> products = [];
  final Set<String> selectedItemIds = {};
  Map<String, dynamic> shopHeader = {};
  String email = '';
  List<dynamic> categorys = [];

  @override
  void initState() {
    super.initState();
    loadShopHeader();
    fetchShopData();
    final cartItems = context.read<CartProvider>().getCart(widget.storeId);
    selectedItemIds.addAll(cartItems.keys);
  }

  int calculateTotalMRP(Map<String, CartItem> cartItems) {
    return cartItems.entries
        .where((entry) => selectedItemIds.contains(entry.key))
        .fold(0, (sum, entry) => sum + (entry.value.discountPrice * entry.value.quantity));
  }

  Future<void> fetchShopData() async {
    final url = Uri.parse(Common.digiBaseUrl + 'shop');
    final response = await http.post(
      url,
      headers: {"Content-Type": "application/json"},
      body: jsonEncode({"shopId": widget.storeId}),
    );

    if (response.statusCode == 200) {
      final json = jsonDecode(response.body);
      setState(() {
        shopResponse = json['response'];
        products = shopResponse['products'] ?? [];
        categorys = shopResponse['categorys'] ?? [];
      });

      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('shopHeader', jsonEncode(shopResponse['settings']['header']));
    }
  }

  Future<void> loadShopHeader() async {
    final prefs = await SharedPreferences.getInstance();
    final headerString = prefs.getString('shopHeader');
    email = prefs.getString('user_email')!;
    if (headerString != null) {
      setState(() {
        shopHeader = jsonDecode(headerString);
      });
    }
  }

  Map<String, dynamic>? findProductById(String productId) {
    try {
      return products.firstWhere(
            (product) => product['productId'] == productId,
      );
    } catch (e) {
      return null;
    }
  }

  void _removeSelectedItems(BuildContext context) {
    final cartProvider = context.read<CartProvider>();

    // Remove all selected items from cart
    for (final itemId in selectedItemIds) {
      cartProvider.removeItem(widget.storeId, itemId);
    }

    // Clear selection


    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('${selectedItemIds.length} items removed from cart')),
    );
    setState(() {
      selectedItemIds.clear();
    });
  }

  void _moveToWishlist(BuildContext context) async {
    final cartProvider = context.read<CartProvider>();
    final wishlistProvider = context.read<WishlistProvider>();
    final cartItems = cartProvider.getCart(widget.storeId);

    // Initialize wishlist if not already done
    // if (!wishlistProvider._wishlistBox.isOpen) {
    //   await wishlistProvider.init();
    // }

    int movedCount = 0;

    // Move each selected item to wishlist
    for (final itemId in selectedItemIds) {
      final cartItem = cartItems[itemId];
      if (cartItem != null) {
        final product = findProductById(cartItem.id);
        if (product != null) {
          wishlistProvider.addToWishlist(product);
          movedCount++;
        }
      }
    }

    // Remove moved items from cart
    for (final itemId in selectedItemIds) {
      cartProvider.removeItem(widget.storeId, itemId);
    }

    // Clear selection
    setState(() {
      selectedItemIds.clear();
    });

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('$movedCount items moved to wishlist')),
    );
  }

  @override
  Widget build(BuildContext context) {
    final cartProvider = context.watch<CartProvider>();
    final cartItems = cartProvider.getCart(widget.storeId);

    final totalMRP = calculateTotalMRP(cartItems);
    const deliveryFee = 20;
    const gst = 0;
    final totalPayable = totalMRP + deliveryFee + gst;

    final allSelected = selectedItemIds.length == cartItems.length;

    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          child: Column(
            children: [
              // _buildHeader(),
              cartItems.isEmpty
                  ? SizedBox(
                height: MediaQuery.of(context).size.height - 3 * kToolbarHeight,
                child: Center(
                  child: SizedBox(
                    height: 200,
                    child: Lottie.asset('assets/animations/empty_tasks.json'),
                  ),
                ),
              )
                  : Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    child: Row(
                      children: [
                        Checkbox(
                          value: allSelected,
                          onChanged: (value) {
                            setState(() {
                              if (value == true) {
                                selectedItemIds.addAll(cartItems.keys);
                              } else {
                                selectedItemIds.clear();
                              }
                            });
                          },
                        ),
                        // const SizedBox(width: 0),
                        Text(
                          "${selectedItemIds.length} / ${cartItems.length} Items Selected",
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 12,
                          ),
                        ),
                        const Spacer(),
                        Row(
                          children: [
                            // REMOVE button with larger tap area
                            InkWell(
                              onTap: () => _removeSelectedItems(context),
                              borderRadius: BorderRadius.circular(4),
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                child: const Text(
                                  "REMOVE",
                                  style: TextStyle(
                                    color: Colors.blue,
                                    fontSize: 12,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ),
                            ),
                            const Padding(
                              padding: EdgeInsets.symmetric(horizontal: 4),
                              child: Text("|", style: TextStyle(color: Colors.grey)),
                            ),
                            // MOVE TO WISHLIST button with larger tap area
                            InkWell(
                              onTap: () => _moveToWishlist(context),
                              borderRadius: BorderRadius.circular(4),
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                child: const Text(
                                  "MOVE TO WISHLIST",
                                  style: TextStyle(
                                    color: Colors.blue,
                                    fontSize: 12,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        )
                      ],
                    ),
                  ),
                  ...cartItems.entries.map((entry) {
                    final itemId = entry.key;
                    final cartItem = entry.value;
                    final isSelected = selectedItemIds.contains(itemId);
                    final product = findProductById(cartItem.id);

                    // Skip if product not found
                    if (product == null) return const SizedBox.shrink();

                    return Container(
                      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        border: Border.all(color: Colors.grey.shade300),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Checkbox(
                            value: isSelected,
                            onChanged: (_) {
                              setState(() {
                                if (isSelected) {
                                  selectedItemIds.remove(itemId);
                                } else {
                                  selectedItemIds.add(itemId);
                                }
                              });
                            },
                          ),
                          const SizedBox(width: 8),
                          product['productImages'] != null && product['productImages'].isNotEmpty
                              ? ClipRRect(
                            borderRadius: BorderRadius.circular(8),
                            child: Image.network(
                              product['productImages'][0],
                              width: 60,
                              height: 60,
                              fit: BoxFit.cover,
                            ),
                          )
                              : const Icon(Icons.image_not_supported, size: 60),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  product['productName']?.toString().toUpperCase() ?? 'No Name',
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    color: Colors.teal,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                if (product['description'] != null && product['description'].isNotEmpty)
                                  Text(
                                    product['description'],
                                    style: const TextStyle(fontSize: 13),
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                Text(
                                  'Sold by: ${widget.storeId}',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: Colors.grey.shade600,
                                  ),
                                ),
                                Row(
                                  children: [
                                    const Text("Qnt:  "),
                                    IconButton(
                                      onPressed: () => cartProvider
                                          .decreaseQuantity(widget.storeId, cartItem.id),
                                      icon: const Icon(Icons.remove, size: 20),
                                      constraints: const BoxConstraints(),
                                      padding: EdgeInsets.zero,
                                    ),
                                    Text(cartItem.quantity.toString()),
                                    IconButton(
                                      onPressed: () {
                                        cartProvider.addItem(widget.storeId, {
                                          'productId': product['productId'],
                                          'productName': product['productName'],
                                          'productCategory': product['productCategory'],
                                          'productImages': product['productImages'] ?? [],
                                          'productPrice': product['productPrice'],
                                          'productdiscountPrice': product['productdiscountPrice'] ?? product['productPrice'],
                                          'productUnits': product['productUnits'],
                                          'productUnitType': product['productUnitType'],
                                          'productRibbon': product['productRibbon'],
                                          'description': product['description'] ?? '',
                                        });
                                      },
                                      icon: Icon(Icons.add, size: 20, color: cartItem.quantity >= (product['productUnits'] ?? 0) ? Colors.grey : Colors.blue),
                                      constraints: const BoxConstraints(),
                                      padding: EdgeInsets.zero,
                                    ),
                                    const Spacer(),
                                    IconButton(
                                      onPressed: () {
                                        setState(() {
                                          selectedItemIds.remove(itemId);
                                        });
                                        cartProvider.removeItem(
                                            widget.storeId, cartItem.id);
                                      },
                                      icon: const Icon(Icons.close),
                                    ),
                                  ],
                                ),
                                Text(
                                  "Rs : ${product['productdiscountPrice'] ?? product['productPrice']}",
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  "Delivery till: ${DateFormat('dd MMM yyyy').format(DateTime.now().add(const Duration(days: 7)))}",
                                  style: const TextStyle(fontSize: 12),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    );
                  }).toList(),
                  Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Card(
                      elevation: 4,
                      child: Container(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            _buildPriceRow('Total MRP', '₹$totalMRP'),
                            _buildPriceRow('Delivery Fee', '₹$deliveryFee'),
                            _buildPriceRow('GST', '₹$gst'),
                            const Divider(),
                            _buildPriceRow(
                              'Total Payable',
                              '₹$totalPayable',
                              isBold: true,
                            ),
                            const SizedBox(height: 10),
                            Row(
                              children: [
                                Expanded(
                                  child: TextField(
                                    decoration: const InputDecoration(
                                      hintText: 'Enter coupon code',
                                      border: OutlineInputBorder(),
                                      contentPadding:
                                      EdgeInsets.symmetric(horizontal: 10),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 10),
                                SizedBox(
                                  height: 48,
                                  child: ElevatedButton(
                                    onPressed: () {},
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: Colors.teal,
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 16),
                                      shape: RoundedRectangleBorder(
                                        borderRadius:
                                        BorderRadius.circular(4),
                                      ),
                                    ),
                                    child: const Text(
                                      "Apply Coupon",
                                      style: TextStyle(color: Colors.white),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 10),
                            SizedBox(
                              width: double.infinity,
                              child: ElevatedButton(
                                onPressed: () async {
                                  final prefs = await SharedPreferences.getInstance();
                                  final email = prefs.getString('user_email') ?? '';

                                  if (email.isEmpty) {
                                    // Navigator.push(
                                    //   context,
                                    //   MaterialPageRoute(builder: (context) => GoogleSignInScreen()),
                                    // );
                                    return;
                                  }

                                  if (selectedItemIds.isNotEmpty) {
                                    final selectedProducts = cartItems.entries
                                        .where((entry) => selectedItemIds.contains(entry.key))
                                        .map((entry) {
                                      final productDetails = findProductById(entry.value.id);
                                      return {
                                        ...?productDetails,
                                        'productCount': entry.value.quantity,
                                        'onePiecePrice': entry.value.discountPrice,
                                        'totalCartValue': totalPayable,
                                        'shopId': widget.storeId,
                                        'checked': true,
                                        'transactionId': "",
                                        'email': email,
                                        'coupontotal': 300,
                                      };
                                    }).toList();

                                    for (var product in selectedProducts) {
                                      final matchedCategory = categorys.firstWhere(
                                            (cat) => cat['categoryName'] == product['productCategory'],
                                        orElse: () => null,
                                      );
                                      product['gst'] = matchedCategory != null
                                          ? matchedCategory['gst'].toString()
                                          : '0';
                                    }

                                    widget.onProductsSelected(selectedProducts);
                                    widget.onNext();
                                  } else {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(
                                        content: Text("Please select at least one item to continue"),
                                      ),
                                    );
                                  }
                                },
                                style: ElevatedButton.styleFrom(
                                  padding: const EdgeInsets.all(16),
                                  backgroundColor: Colors.teal,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                ),
                                child: const Text(
                                  "PLACE ORDER",
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(height: 10),
                            const Center(
                              child: Text("Most Delivery happens on Time"),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    if (shopHeader.isEmpty) return const SizedBox.shrink();

    return Container(
      padding: const EdgeInsets.all(12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          const SizedBox(width: 20),
          shopHeader['logo'] != null
              ? Image.network(shopHeader['logo'], width: 40)
              : const Icon(Icons.store, size: 40),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Text(
                  shopHeader['shopName'] ?? '',
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  shopHeader['email'] ?? '',
                  style: const TextStyle(color: Colors.black),
                ),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.call, color: Colors.green),
            onPressed: () async {
              var rawPhone = shopHeader['phoneNumber'] ?? '';
              var phone = rawPhone.replaceAll(RegExp(r'\D'), '');

              if (phone.isEmpty) {
                //back print("Phone number is empty");
                return;
              }

              final whatsappUrl = Uri.parse("https://wa.me/$phone");

              if (await canLaunchUrl(whatsappUrl)) {
                await launchUrl(whatsappUrl,
                    mode: LaunchMode.externalApplication);
              } else {
                //back print("Could not launch WhatsApp URL");
              }
            },
          ),
        ],
      ),
    );
  }

  Widget _buildPriceRow(String label, String value, {bool isBold = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(
              fontWeight: isBold ? FontWeight.bold : FontWeight.normal,
            ),
          ),
          Text(
            value,
            style: TextStyle(
              fontWeight: isBold ? FontWeight.bold : FontWeight.normal,
            ),
          ),
        ],
      ),
    );
  }
}