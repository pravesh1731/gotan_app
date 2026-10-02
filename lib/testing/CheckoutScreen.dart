import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:gotan/pages/OrderHistoryPage.dart';
import 'package:gotan/pages/ShopPage.dart';
import 'package:url_launcher/url_launcher.dart';
import '../global/common.dart';
import '../pages/CartScreen.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:http/http.dart' as http;
import 'package:provider/provider.dart';
import 'package:flutter/services.dart'; // For Clipboard
import '../pages/shopMainScreen.dart';
import '../providers/CartProvider.dart';
import '../splash/LottieSplashScreen.dart';
import '../splash/LottieSplashScreen.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:path_provider/path_provider.dart';
import 'package:dio/dio.dart';
import 'dart:io';
// import 'package:device_info_plus/device_info_plus.dart';
import 'package:path/path.dart' as path;
import 'package:file_picker/file_picker.dart';


class CheckoutScreen extends StatefulWidget {
  final String storeId;

  const CheckoutScreen({Key? key, required this.storeId}) : super(key: key);

  @override
  _CheckoutScreenState createState() => _CheckoutScreenState();
}

class _CheckoutScreenState extends State<CheckoutScreen> with WidgetsBindingObserver {
  int _currentStep = 0;
  final List<String> _steps = ['Bag', 'Address', 'Payment'];
  Map<String, dynamic> shopHeader = {};

  // Add these to track the state
  List<dynamic> selectedProducts = [];
  Map<String, dynamic>? selectedAddress;



  void _goToStep(int index) {
    // Prevent navigation to payment step unless coming from address confirmation
    if (index > _currentStep) {
      return;
    }

    setState(() {
      _currentStep = index;
    });
  }

  void _nextStep() {
    if (_currentStep < _steps.length - 1) {
      setState(() {
        _currentStep++;
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

  // Add this method to update selected products
  void _updateSelectedProducts(List<dynamic> products) {
    setState(() {
      selectedProducts = products;
    });
  }

  // Add this method to update selected address
  void _updateSelectedAddress(Map<String, dynamic> address) {
    setState(() {
      selectedAddress = address;
    });
  }

  // ... rest of your existing methods ...

  Widget _buildStepContent() {
    switch (_currentStep) {
      case 0:
        return CartScreen(
          storeId: widget.storeId,

          onNext: () {
            _nextStep();
          },
          onProductsSelected: _updateSelectedProducts, // Pass the callback
        );
      case 1:
        return CustomAddressPage(
          onConfirm: _nextStep,
          onAddressSelected: _updateSelectedAddress, // Pass the callback
        );
      case 2:
        return PaymentPage(
          selectedProducts: selectedProducts,
          selectedAddress: selectedAddress,
          shopId : widget.storeId
        );
      default:
        return Container();
    }
  }

  void checkNotificationPermission(BuildContext context) async {
    final prefs = await SharedPreferences.getInstance();
    final email = prefs.getString('user_email') ?? '';

    if (email.isNotEmpty) {
      var status = await Permission.notification.status;

      if (status.isGranted) {
        // ✅ Already granted — do nothing
        return;
      }

      // 👇 Request permission (this will show the system permission popup if possible)
      var result = await Permission.notification.request();

      // 👉 Only handle the case where the permission was asked and user denied it
      if (result.isDenied) {
        // Delay the dialog until the frame is built
        WidgetsBinding.instance.addPostFrameCallback((_) {
          showStyledPermissionDialog(
            context: context,
            title: "Notification Permission Needed",
            message: "We use notifications to alert you about important updates. Please enable permission.",
            // showSettingsButton: result.isPermanentlyDenied, // only show settings if needed
          );
        });
      }
    }
  }



  void showStyledPermissionDialog({
    required BuildContext context,
    required String title,
    required String message,
    // bool showSettingsButton = true,
  }) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        titlePadding: EdgeInsets.only(top: 20, left: 24, right: 24),
        contentPadding: EdgeInsets.only(left: 24, right: 24, top: 14, bottom: 24),
        actionsPadding: EdgeInsets.only(right: 16, bottom: 16),
        title: Text(
          title,
          style: TextStyle(fontWeight: FontWeight.w600, fontSize: 18, color: Colors.teal),
        ),
        content: SizedBox(
          width: MediaQuery.of(context).size.width * 0.9,
          child: Text(message, style: TextStyle(fontSize: 15)),
        ),
        actions: [
          OutlinedButton(
            onPressed: () => Navigator.pop(context),
            style: OutlinedButton.styleFrom(
              side: BorderSide(color: Colors.grey.shade400),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
            ),
            child: Text("Cancel", style: TextStyle(color: Colors.black)),
          ),
          // if (showSettingsButton)
          //   ElevatedButton(
          //     onPressed: () {
          //       Navigator.pop(context);
          //       openAppSettings();
          //     },
          //     style: ElevatedButton.styleFrom(
          //       backgroundColor: Color(0xFF2563EB),
          //       shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
          //     ),
          //     child: Text("Open Settings", style: TextStyle(color: Colors.white)),
          //   ),
        ],
      ),
    );
  }



  @override
  void initState() {
    super.initState();
    loadShopHeader();
    // WidgetsBinding.instance.addObserver(this);
    checkNotificationPermission(context);
  }

  // @override
  // void didChangeAppLifecycleState(AppLifecycleState state) {
  //   if (state == AppLifecycleState.resumed) {
  //     // Called when the screen comes back into focus
  //     checkNotificationPermission(context);
  //   }
  // }
  //
  @override
  void dispose() {
    // WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }



  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            _buildHeader(),
            const SizedBox(height: 10),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children:
                  _steps.asMap().entries.map((entry) {
                    int index = entry.key;
                    String label = entry.value;
                    bool isActive = _currentStep == index;

                    return GestureDetector(
                      onTap: () => _goToStep(index),
                      child: Column(
                        children: [
                          Text(
                            label,
                            style: TextStyle(
                              color: isActive ? Colors.teal : Colors.grey,
                              fontWeight:
                                  isActive
                                      ? FontWeight.bold
                                      : FontWeight.normal,
                              fontSize: 14,
                            ),
                          ),
                          if (isActive)
                            Container(
                              margin: const EdgeInsets.only(top: 4),
                              height: 2,
                              width: 20,
                              color: Colors.teal,
                            ),
                        ],
                      ),
                    );
                  }).toList(),
            ),
            const Divider(),
            Expanded(child: _buildStepContent()),
          ],
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

              if (phone.isEmpty) return;

              final whatsappUrl = Uri.parse("https://wa.me/$phone");

              if (await canLaunchUrl(whatsappUrl)) {
                await launchUrl(
                  whatsappUrl,
                  mode: LaunchMode.externalApplication,
                );
              } else {
                //back print("Could not launch WhatsApp URL");
              }
            },
          ),
        ],
      ),
    );
  }
}

// ✅ Custom Address Page (Based on Screenshot)
// import 'dart:convert';
//
// import 'package:flutter/material.dart';
// import 'package:shared_preferences/shared_preferences.dart';

class CustomAddressPage extends StatefulWidget {
  final VoidCallback onConfirm;
  final Function(Map<String, dynamic>)? onAddressSelected;

  const CustomAddressPage({
    Key? key,
    required this.onConfirm,
    this.onAddressSelected,
  }) : super(key: key);

  @override
  State<CustomAddressPage> createState() => _CustomAddressPageState();
}

class _CustomAddressPageState extends State<CustomAddressPage> {
  final List<Map<String, String>> _savedAddresses = [];
  bool _showForm = false;
  int? _selectedIndex;
  bool _showAddressRequired = false; // New flag to show error message

  // Controllers for form input
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _mobileController = TextEditingController();
  final TextEditingController _addressController = TextEditingController();
  final TextEditingController _pincodeController = TextEditingController();
  final TextEditingController _stateController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadSavedAddresses();
  }

  Future<void> _loadSavedAddresses() async {
    final prefs = await SharedPreferences.getInstance();
    final List<String>? storedList = prefs.getStringList('saved_addresses');

    if (storedList != null) {
      setState(() {
        _savedAddresses.addAll(
          storedList.map((e) => Map<String, String>.from(json.decode(e))),
        );
      });
    }
  }

  void _removeAddress(int index) async {
    SharedPreferences prefs = await SharedPreferences.getInstance();

    setState(() {
      _savedAddresses.removeAt(index);
      if (_selectedIndex == index) {
        _selectedIndex = null;
      }
    });

    // Save updated list to SharedPreferences
    List<String> updatedJsonList =
        _savedAddresses.map((addr) => jsonEncode(addr)).toList();
    await prefs.setStringList('saved_addresses', updatedJsonList);
  }

  Future<void> _saveAddress() async {
    if (_nameController.text.isEmpty ||
        _mobileController.text.isEmpty ||
        _addressController.text.isEmpty ||
        _pincodeController.text.isEmpty ||
        _stateController.text.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text("All fields are required")));
      return;
    }

    final newAddress = {
      "name": _nameController.text,
      "mobile": _mobileController.text,
      "address": _addressController.text,
      "pincode": _pincodeController.text,
      "state": _stateController.text,
    };

    setState(() {
      _savedAddresses.add(newAddress);
      _showForm = false;
      _selectedIndex =
          _savedAddresses.length - 1; // Select the newly added address
      _showAddressRequired = false; // Hide error message if shown
    });

    final prefs = await SharedPreferences.getInstance();
    final encodedList = _savedAddresses.map((e) => json.encode(e)).toList();
    await prefs.setStringList('saved_addresses', encodedList);

    // Clear inputs
    _nameController.clear();
    _mobileController.clear();
    _addressController.clear();
    _pincodeController.clear();
    _stateController.clear();
  }

  void _handleConfirm() {
    if (_selectedIndex == null) {
      // No address selected, show error message
      setState(() {
        _showAddressRequired = true;
      });
      // ScaffoldMessenger.of(context).showSnackBar(
      //   const SnackBar(
      //     content: Text("Please select or add an address"),
      //     duration: Duration(seconds: 2),
      //   ),
      // );
    } else {
      // Address selected, proceed with confirmation
      widget.onAddressSelected?.call(_savedAddresses[_selectedIndex!]);
      widget.onConfirm();
    }
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      child: Column(
        children: [
          const SizedBox(height: 16),
          if (!_showForm) ...[
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: OutlinedButton(
                style: OutlinedButton.styleFrom(
                  side: const BorderSide(color: Colors.teal),
                  minimumSize: const Size.fromHeight(45),
                ),
                onPressed: () {
                  setState(() {
                    _showForm = true;
                    _showAddressRequired =
                        false; // Hide error when showing form
                  });
                },
                child: const Text(
                  "ADD ADDRESS",
                  style: TextStyle(color: Colors.teal),
                ),
              ),
            ),
            const SizedBox(height: 16),
            if (_showAddressRequired && _savedAddresses.isEmpty)
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 16),
                child: Text(
                  "Please add an address to continue",
                  style: TextStyle(color: Colors.red),
                ),
              ),
            if (_showAddressRequired && _savedAddresses.isNotEmpty)
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 16),
                child: Text(
                  "Please select an address to continue",
                  style: TextStyle(color: Colors.red),
                ),
              ),
            ..._savedAddresses.asMap().entries.map((entry) {
              final index = entry.key;
              final address = entry.value;

              return Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 8,
                ),
                child: Container(
                  decoration: BoxDecoration(
                    color: Colors.grey[200],
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.grey),
                  ),
                  child: ListTile(
                    leading: Radio<int>(
                      value: index,
                      groupValue: _selectedIndex,
                      onChanged: (int? value) {
                        setState(() {
                          _selectedIndex = value;
                          _showAddressRequired =
                              false; // Hide error when selecting
                        });
                      },
                      activeColor: Colors.teal,
                    ),
                    title: Text(
                      address['name'] ?? '',
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    subtitle: Text(
                      "${address['mobile']},\n${address['address']}, ${address['pincode']}, ${address['state']}",
                      style: const TextStyle(height: 1.5),
                    ),
                    trailing: IconButton(
                      icon: const Icon(Icons.delete, color: Colors.red),
                      onPressed: () {
                        _removeAddress(index);
                      },
                    ),
                  ),
                ),
              );
            }),
            const SizedBox(height: 16),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.all(16),
                    backgroundColor: Colors.teal,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  onPressed: _handleConfirm,
                  child: const Text(
                    "CONFIRM ADDRESS",
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
            ),
          ] else ...[
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    "CONTACT DETAILS",
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: _nameController,
                    decoration: const InputDecoration(hintText: "Name"),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: _mobileController,
                    keyboardType: TextInputType.phone,
                    decoration: const InputDecoration(
                      hintText: "Mobile Number",
                    ),
                  ),
                  const SizedBox(height: 20),
                  const Text(
                    "ADDRESS",
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: _addressController,
                    decoration: const InputDecoration(
                      hintText: "Address(House no, Building, Street area)",
                    ),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: _pincodeController,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(hintText: "Pin Code"),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: _stateController,
                    decoration: const InputDecoration(hintText: "State"),
                  ),
                  const SizedBox(height: 20),
                  Row(
                    children: [
                      Expanded(
                        child: ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.teal,
                          ),
                          onPressed: () => setState(() => _showForm = false),
                          child: const Text(
                            "Cancel",
                            style: TextStyle(color: Colors.white),
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.teal,
                          ),
                          onPressed: _saveAddress,
                          child: const Text(
                            "ADD ADDRESS",
                            style: TextStyle(color: Colors.white),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
          const SizedBox(height: 20),
          const Text(
            "(c) ALL RIGHTS RESERVED | HRI",
            style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500),
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }
}

class PaymentPage extends StatefulWidget {
  final List<dynamic> selectedProducts;
  final Map<String, dynamic>? selectedAddress;
  final String shopId;


  const PaymentPage({
    Key? key,
    required this.selectedProducts,
    this.selectedAddress,
    required this.shopId
  }) : super(key: key);

  @override
  State<PaymentPage> createState() => _PaymentPageState();
}

class _PaymentPageState extends State<PaymentPage> {
  bool _isProcessingPayment = false;
  bool isCODSelected = false;
  bool isOnlinePaymentSelected = false;

  void _selectOnlinePayment() {
    setState(() {
      isOnlinePaymentSelected = true;
      isCODSelected = false;
    });
  }

  void _selectCOD() {
    setState(() {
      isCODSelected = true;
      isOnlinePaymentSelected = false;
    });
  }

  String qr = '';
  String up = '';
  @override
  void initState() {
    // TODO: implement initState
    super.initState();
    _loadQr();
  }

  Future<void> _loadQr() async {
    final prefs = await SharedPreferences.getInstance();
    final headerString = prefs.getString('shopHeader');
    qr = prefs.getString('QRCode')?.replaceAll('"', '') ?? '';
    up = prefs.getString('upiId')?.replaceAll('"', '') ?? '';

    setState(() {
      qr = prefs.getString('QRCode')?.replaceAll('"', '') ?? '';
      up = prefs.getString('upiId')?.replaceAll('"', '') ?? '';
    });
    //back print('QR Image URL: $qr');

    // if (headerString != null) {
    //   setState(() {
    //     shopHeader = jsonDecode(headerString);
    //   });
    // }
  }

  String _formatAddress(Map<String, dynamic>? rawAddress) {
    if (rawAddress == null) return "";

    try {
      final components = [
        rawAddress['name']?.toString().trim() ?? '',
        rawAddress['mobile'] != null
            ? '+91-${rawAddress['mobile']}'.trim()
            : '',
        rawAddress['address']?.toString().trim() ?? '',
        rawAddress['pincode'] != null ? '${rawAddress['pincode']}'.trim() : '',
        rawAddress['state']?.toString().trim() ?? '',
        'India',
      ];

      return components.where((c) => c.isNotEmpty).join(', ');
    } catch (e) {
      return rawAddress['address']?.toString() ?? '';
    }
  }

  Future<Map<String, dynamic>> _prepareOrderPayload(
    String paymentMethod,
  ) async {
    final formattedAddress = _formatAddress(widget.selectedAddress);
    final prefs = await SharedPreferences.getInstance();
    final email = prefs.getString('user_email');
    final fcmToken = prefs.getString('deviceToken') ?? "";

    double totalCartValue = widget.selectedProducts.fold(0, (sum, product) {
      final price =
          (product['productdiscountPrice'] ?? product['productPrice'] ?? 0)
              .toDouble();
      final count = product['productCount'] ?? 1;
      return sum + (price * count);
    });

    final formattedOrders =
        widget.selectedProducts.map((product) {
          final price =
              (product['productdiscountPrice'] ?? product['productPrice'] ?? 0)
                  .toDouble();
          final count = product['productCount'] ?? 1;

          return {
            ...product,
            'totalCartValue': price * count,
            'productImage':
                product['productImages']?.isNotEmpty == true
                    ? product['productImages'][0]
                    : '',
            'address': formattedAddress,
            'paymentMethod': paymentMethod,
            'email': '"$email"',
          };
        }).toList();

    return {'email': '"$email"', 'orders': formattedOrders, 'fcmToken': fcmToken};
  }

  void _showCODConfirmationDialog(BuildContext context) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder:
          (context) => AlertDialog(
            title: const Text(
              'Please Be Available While Delivery.',
              style: TextStyle(fontSize: 16),
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  height: 100,
                  child: CachedNetworkImage(
                    imageUrl:
                        'https://gotandairy.digistall.in/static/media/cod.439a770f9f419dc71b13.png',
                    fit: BoxFit.cover,
                    errorWidget:
                        (_, __, ___) => const Icon(Icons.payment, size: 50),
                  ),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('CANCEL'),
              ),
              ElevatedButton(
                onPressed: () {
                  Navigator.pop(context);
                  _processPayment('COD', context);
                },
                style: ElevatedButton.styleFrom(backgroundColor: Colors.teal),
                child: const Text('CONFIRM'),
              ),
            ],
          ),
    );
  }

  Future<void> _processPayment(String paymentMethod, BuildContext context) async {
    setState(() {
      _isProcessingPayment = true; // Start loading
    });

    try {
      final payload = await _prepareOrderPayload(paymentMethod);
      debugPrint('Payment Payload: ${json.encode(payload)}');

      final response = await http.post(
        Uri.parse(Common.digiBaseUrl + 'customer/addorder'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode(payload),
      );

      if (response.statusCode == 200) {
        final decoded = jsonDecode(response.body);
        print('====');
        print(decoded); // This prints raw JSON string
        final cartProvider = Provider.of<CartProvider>(context, listen: false);
        for (final product in widget.selectedProducts) {
          cartProvider.removeItem(product['shopId'], product['productId']);
        }

        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (context) => LottieSplashScreen(
              nextPage: ShopMainScreen(shopId: widget.shopId),
              assetPath: 'assets/animations/confirm.json',
            ),
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Payment failed: ${response.body}')),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e')),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isProcessingPayment = false; // Stop loading
        });
      }
    }
  }

  double _calculateTotal() {
    return widget.selectedProducts.fold(0, (sum, product) {
      final price =
          (product['productdiscountPrice'] ?? product['productPrice'] ?? 0)
              .toDouble();
      final count = product['productCount'] ?? 1;
      return sum + (price * count);
    });
  }

  // Future<void> _downloadQRCode(BuildContext context, String qrUrl) async {
  //   try {
  //     if (qrUrl.isEmpty) {
  //       ScaffoldMessenger.of(context).showSnackBar(
  //         const SnackBar(content: Text('QR code not available')),
  //       );
  //       return;
  //     }
  //
  //     final deviceInfo = DeviceInfoPlugin();
  //     final androidInfo = await deviceInfo.androidInfo;
  //     final sdkInt = androidInfo.version.sdkInt ?? 0;
  //
  //     // ✅ Ask for required permission
  //     if (sdkInt >= 33) {
  //       final photosStatus = await Permission.photos.request();
  //       final mediaStatus = await Permission.mediaLibrary.request();
  //       if (!photosStatus.isGranted && !mediaStatus.isGranted) {
  //         ScaffoldMessenger.of(context).showSnackBar(
  //           const SnackBar(content: Text('Photos or media access denied')),
  //         );
  //         return;
  //       }
  //     } else {
  //       final storageStatus = await Permission.storage.request();
  //       if (!storageStatus.isGranted) {
  //         ScaffoldMessenger.of(context).showSnackBar(
  //           const SnackBar(content: Text('Storage permission denied')),
  //         );
  //         return;
  //       }
  //     }
  //
  //     // 📂 Ask user to pick a folder to save the file
  //     String? selectedDirectory = await FilePicker.platform.getDirectoryPath();
  //
  //     if (selectedDirectory == null) {
  //       ScaffoldMessenger.of(context).showSnackBar(
  //         const SnackBar(content: Text('Folder selection canceled')),
  //       );
  //       return;
  //     }
  //
  //     final fileName = 'qr_code_${DateTime.now().millisecondsSinceEpoch}.png';
  //     final filePath = path.join(selectedDirectory, fileName);
  //
  //     final response = await Dio().download(qrUrl, filePath);
  //
  //     if (response.statusCode == 200) {
  //       ScaffoldMessenger.of(context).showSnackBar(
  //         SnackBar(content: Text('Saved to: $filePath')),
  //       );
  //     } else {
  //       throw Exception('Failed to download QR code.');
  //     }
  //   } catch (e) {
  //     ScaffoldMessenger.of(context).showSnackBar(
  //       SnackBar(content: Text('Download failed: $e')),
  //     );
  //   }
  // }


  @override
  Widget build(BuildContext context) {
    final totalAmount = _calculateTotal();
    const deliveryFee = 20;
    final totalPayable = totalAmount + deliveryFee;

    return Scaffold(
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child:
            isCODSelected
                ? ConstrainedBox(
                  constraints: BoxConstraints(
                    minHeight: MediaQuery.of(context).size.height / 1.5,
                  ),
                  child: IntrinsicHeight(
                    child: Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          const Text(
                            'Please Be Available While Delivery.',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 20),
                          SizedBox(
                            height: 100,
                            child: CachedNetworkImage(
                              imageUrl:
                                  'https://gotandairy.digistall.in/static/media/cod.439a770f9f419dc71b13.png',
                              fit: BoxFit.cover,
                              errorWidget:
                                  (_, __, ___) =>
                                      const Icon(Icons.payment, size: 50),
                            ),
                          ),
                          const SizedBox(height: 20),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              ElevatedButton(
                                onPressed: () {
                                  setState(() {
                                    isCODSelected = false;
                                  });
                                },
                                child: const Text('Cancel'),
                              ),
                              const SizedBox(width: 20),
                              ElevatedButton(
                                onPressed: _isProcessingPayment
                                    ? null
                                    : () => _processPayment('COD', context),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.teal,
                                ),
                                child: _isProcessingPayment
                                    ? const SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(
                                    color: Colors.white,
                                    strokeWidth: 2,
                                  ),
                                )
                                    : const Text(
                                  'CONFIRM ORDER',
                                  style: TextStyle(color: Colors.white),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                )
                : isOnlinePaymentSelected
                ? SingleChildScrollView(
                  child: ConstrainedBox(
                    constraints: BoxConstraints(
                      minHeight: MediaQuery.of(context).size.height / 1.5,
                    ),
                    child: IntrinsicHeight(
                      child: Center(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 10.0),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [

                              // ElevatedButton(
                              //   onPressed: () => _downloadQRCode(context, qr),
                              //   child: const Text('Download QR Code'),
                              // ),
                              // SizedBox(height: 10),



                              CachedNetworkImage(
                                imageUrl: qr,
                                height: 200,
                                width: 200,
                                errorWidget:
                                    (_, __, ___) => const Icon(Icons.image),
                              ),
                              const SizedBox(height: 8),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  const Text(
                                    'UPI ID: ',
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      color: Colors.grey, // lighter for label
                                    ),
                                  ),
                                  Text(
                                    up,
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                      color: Colors.black, // darker for value
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  InkWell(
                                    onTap: () {
                                      Clipboard.setData(ClipboardData(text: up));
                                      ScaffoldMessenger.of(context).showSnackBar(
                                        const SnackBar(
                                          content: Text('UPI ID copied to clipboard'),
                                          duration: Duration(seconds: 2),
                                        ),
                                      );
                                    },
                                    child: const Icon(Icons.copy, size: 20, color: Colors.teal),
                                  ),
                                ],
                              ),


                              // Text(_formatAddress(widget.selectedAddress)),
                              const SizedBox(height: 20),
                              const Text(
                                'ORDER SUMMARY',
                                style: TextStyle(fontWeight: FontWeight.bold),
                              ),
                              const SizedBox(height: 20),
                              Align(
                                alignment: AlignmentDirectional.centerStart,
                                child: const Text(
                                  'PRICE DETAILS',
                                  style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold),
                                ),
                              ),
                              const SizedBox(height: 20),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  const Text('Total MRP'),
                                  Text('₹$totalAmount'),
                                ],
                              ),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: const [Text('Delivery Fee'), Text('₹20.0')],
                              ),
                              const Divider(thickness: 1),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  const Text(
                                    'Total Amount',
                                    style: TextStyle(fontWeight: FontWeight.bold),
                                  ),
                                  Text(
                                    '₹${totalAmount + deliveryFee}',
                                    style: TextStyle(fontWeight: FontWeight.bold),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 20),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  ElevatedButton(
                                    onPressed: () {
                                      setState(() {
                                        isOnlinePaymentSelected = false;
                                      });
                                    },
                                    child: const Text('Cancel'),
                                  ),
                                  const SizedBox(width: 20),
                                  ElevatedButton(
                                    onPressed: _isProcessingPayment
                                        ? null
                                        : () => _processPayment('UPI', context),
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: Colors.teal,
                                    ),
                                    child: _isProcessingPayment
                                        ? const SizedBox(
                                      width: 20,
                                      height: 20,
                                      child: CircularProgressIndicator(
                                        color: Colors.white,
                                        strokeWidth: 2,
                                      ),
                                    )
                                        : const Text('CONFIRM ORDER', style: TextStyle(color: Colors.white)),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                )
                : ConstrainedBox(
                  constraints: BoxConstraints(
                    minHeight: MediaQuery.of(context).size.height / 1.5,
                  ),
                  child: IntrinsicHeight(
                    child: Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Text(
                            'Choose your preferred payment method',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 40),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              _buildPaymentOption(
                                imagePath:
                                    'https://gotandairy.digistall.in/static/media/pod.41809bded9b2eb2a8810.png',
                                label: 'PAY ONLINE',
                                onTap: _selectOnlinePayment,
                              ),
                              const SizedBox(width: 40),
                              _buildPaymentOption(
                                imagePath:
                                    'https://gotandairy.digistall.in/static/media/cod.439a770f9f419dc71b13.png',
                                label: 'CASH ON DELIVERY',
                                onTap: _selectCOD,
                              ),
                            ],
                          ),
                          // const SizedBox(height: 40),
                          // if (widget.selectedAddress != null) ...[
                          //   const Text(
                          //     'Delivery Address:',
                          //     style: TextStyle(fontWeight: FontWeight.bold),
                          //   ),
                          //   const SizedBox(height: 10),
                          //   Text(_formatAddress(widget.selectedAddress)),
                          //   const SizedBox(height: 20),
                          // ],
                          // const Text(
                          //   'Order Summary:',
                          //   style: TextStyle(fontWeight: FontWeight.bold),
                          // ),
                          // const SizedBox(height: 10),
                          // ...widget.selectedProducts.map((product) {
                          //   final price = (product['productdiscountPrice'] ?? product['productPrice'] ?? 0).toDouble();
                          //   final count = product['productCount'] ?? 1;
                          //   return Padding(
                          //     padding: const EdgeInsets.symmetric(vertical: 4),
                          //     child: Text(
                          //       '${product['productName']} x $count - ₹${price * count}',
                          //     ),
                          //   );
                          // }).toList(),
                          // const SizedBox(height: 20),
                          // Text(
                          //   'Total: ₹$totalPayable',
                          //   style: const TextStyle(
                          //     fontWeight: FontWeight.bold,
                          //     fontSize: 18,
                          //   ),
                          // ),
                        ],
                      ),
                    ),
                  ),
                ),
      ),
    );
  }

  Widget _buildPaymentOption({
    required String imagePath,
    required String label,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        children: [
          Container(
            width: 100,
            height: 100,
            decoration: BoxDecoration(
              border: Border.all(color: Colors.grey),
              borderRadius: BorderRadius.circular(50),
            ),
            child: ClipOval(
              child: CachedNetworkImage(
                imageUrl: imagePath,
                fit: BoxFit.cover,
                errorWidget:
                    (_, __, ___) => const Icon(Icons.payment, size: 50),
              ),
            ),
          ),
          const SizedBox(height: 8),
          Text(label, style: const TextStyle(fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }
}

class OrderConfirmationScreen extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Order Confirmed')),
      body: const Center(
        child: Text('Your order has been placed successfully!'),
      ),
    );
  }
}
