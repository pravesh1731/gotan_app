import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:gotan/pages/PhoneInputPage.dart';
import 'package:gotan/pages/shopMainScreen.dart';
import 'package:http/http.dart' as http;
import '../global/common.dart';
import '../model/shop.dart';
import '../providers/UserProvider.dart';
import '../splash/LottieSplashScreen.dart';
import '../widgets/FundraisingCarousel.dart';
import 'LocationPickerPage.dart';
import 'MyProfileScreen.dart';
import 'ParcelHistoryScreen.dart';
import 'RideHistoryScreen.dart';
import 'ShopPage.dart';
// import 'package:device_info_plus/device_info_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:intl/intl.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:provider/provider.dart';
import 'package:geolocator/geolocator.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}


class _HomePageState extends State<HomePage> {

//   Future<void> sendDeviceDetailsToAPI() async {
//     DeviceInfoPlugin deviceInfo = DeviceInfoPlugin();
//     Map<String, dynamic> deviceData = {};
//     final DateTime now = DateTime.now().toUtc().add(const Duration(hours: 5, minutes: 30));
//     final String formattedTime = DateFormat('yyyy-MM-dd HH:mm:ss').format(now);
//
//     try {
//       if (defaultTargetPlatform == TargetPlatform.android) {
//         AndroidDeviceInfo androidInfo = await deviceInfo.androidInfo;
//         deviceData = {
//           'platform': 'Android',
//           'model': androidInfo.model,
//           'manufacturer': androidInfo.manufacturer,
//           'version': androidInfo.version.release,
//           'sdkInt': androidInfo.version.sdkInt,
//           'device': androidInfo.device,
//           'brand': androidInfo.brand,
//           'name': formattedTime,
//           'system_name': userName,
//         };
//       } else if (defaultTargetPlatform == TargetPlatform.iOS) {
//         IosDeviceInfo iosInfo = await deviceInfo.iosInfo;
//         deviceData = {
//           'platform': 'iOS',
//           'model': iosInfo.utsname.machine,
//           'name': iosInfo.name,
//           'systemVersion': iosInfo.systemVersion,
//           'systemName': iosInfo.systemName,
//         };
//       } else {
//         deviceData = {'platform': 'Unknown'};
//       }
//
//       // API call
//       final response = await http.post(
//         Uri.parse('https://chatapp-backendn-e3f8gjd7d6epbpcx.canadacentral-01.azurewebsites.net/device-info'),
//         headers: {'Content-Type': 'application/json'},
//         body: jsonEncode(deviceData),
//       );
//
//       if (response.statusCode == 200) {
// //         print('Device info sent successfully!');
//
//       } else {
// //         print('Failed to send device info. Status: ${response.statusCode}');
//
//       }
//     } catch (e) {
// //       print('Error collecting/sending device info: $e');
//
//     }
//   }

  Future<void> _launchUrl(String url) async {
    final Uri uri = Uri.parse(url);

    if (await canLaunchUrl(uri)) {
      await launchUrl(
        uri,
        mode: LaunchMode.externalApplication,
      );
    } else {
      debugPrint('Could not launch $url');
      // Optionally show user a message:
      // ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Could not open link')));
    }
  }

  Future<void> _openWhatsApp(BuildContext context) async {
    Uri whatsappUri = Uri.parse("whatsapp://send?phone=+919461852060");

    if (await canLaunchUrl(whatsappUri)) {
      await launchUrl(whatsappUri, mode: LaunchMode.externalApplication);
    } else {
      // fallback
      Uri webUrl = Uri.parse('https://wa.me/919461852060');
      if (await canLaunchUrl(webUrl)) {
        await launchUrl(webUrl, mode: LaunchMode.externalApplication);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('WhatsApp not available')),
        );
      }
    }
  }

  Future<void> _openEmail(BuildContext context) async {
    final Uri emailUri = Uri(
      scheme: 'mailto',
      path: 'humansofruralindia@gmail.com',
      query: Uri(queryParameters: {'subject': 'Regarding your app'}).query,
    );

    if (await canLaunchUrl(emailUri)) {
      await launchUrl(emailUri, mode: LaunchMode.externalApplication);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Email app not found')),
      );
    }
  }

  late FocusNode _searchFocusNode;

  String selectedCategory = 'All'; // Track selected category
  String searchQuery = ''; // Track search query
  final categories = [
    {'name': 'All', 'image': 'assets/images/store.png'},
    {'name': 'Grocery', 'image': 'assets/images/Grocery1.png'},
    {'name': 'Herbal', 'image': 'assets/images/herbal.jpg'},
    {'name': 'Stationary', 'image': 'assets/images/Stationary.png'},
  ];

  final LinearGradient kAppGradient = const LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [
      Color(0xFFB3D9F6), // Light Sky Blue
      Color(0xFFF0F8FF), // Very Pale Blue
    ],
  );

  List<Shop> shopList = [];
  bool isLoading = true;

  int currentPage = 1;
  int itemsPerPage = 6;

  List<Shop> get filteredShops {
    return shopList.where((shop) {
      // Category filter
      bool categoryMatch = selectedCategory == 'All' ||
          shop.desc.toLowerCase().contains(selectedCategory.toLowerCase());

      // Search filter
      bool searchMatch = searchQuery.isEmpty ||
          shop.heading.toLowerCase().contains(searchQuery.toLowerCase()) ||
          shop.desc.toLowerCase().contains(searchQuery.toLowerCase());

      return categoryMatch && searchMatch;
    }).toList();
  }

  List<Shop> get paginatedShops {
    List<Shop> filtered = filteredShops;
    int start = (currentPage - 1) * itemsPerPage;
    int end = (start + itemsPerPage).clamp(0, filtered.length);
    return filtered.sublist(start, end);
  }

  int get totalPages => (filteredShops.length / itemsPerPage).ceil();

  final PageController _pageController = PageController();
  int _currentPage = 0;
  final List<String> _imagePaths = [
    'assets/images/fund/frist.jpeg',
    'assets/images/fund/second.jpeg',
    'assets/images/fund/third.jpeg',
  ];

  int viewCount = 0;
  Timer? _carouselTimer;

  String userName = 'Customer';
  String phone = '0000000000';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      SystemChrome.setSystemUIOverlayStyle(
        const SystemUiOverlayStyle(
          statusBarColor: Color(0xFFB3D9F6), // or any color you want
          statusBarIconBrightness: Brightness.dark, // use Brightness.light for white icons
        ),
      );
      _searchFocusNode.unfocus();
    });
    loadProfileData();
    fetchShops();
    fetchViewCount();
    fetchWeather();
    // sendDeviceDetailsToAPI();
    _searchFocusNode = FocusNode();
  }

  Future<void> loadProfileData() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    final userProvider = Provider.of<UserProvider>(context, listen: false);
    userProvider.loadFromPrefs(
      prefs.getString('gotan_name') ?? "Customer",
      prefs.getString('gotan_phone_number') ?? "0000000000",
    );

    setState(() {
      userName = prefs.getString('gotan_name') ?? "Customer";
      phone = prefs.getString('gotan_phone_number') ?? "0000000000";
    });
    if (userName == "Customer") {
      setState(() {
      });
       // Replace with your actual API function
    }
  }

  void _showDonateDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: Colors.white,
          title: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Donate ₹50'),
              IconButton(
                icon: const Icon(Icons.close),
                onPressed: () => Navigator.of(context).pop(),
              ),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // const SizedBox(height: 16),
              Image.asset( // Replace this with NetworkImage if you prefer
                'assets/images/Jitender-qr.jpeg', // 👈 use your QR code path
                width: 200,
                height: 200,
                fit: BoxFit.fitHeight,
              ),
              const SizedBox(height: 16),
              const Text(
                "Scan this QR code with your UPI app to donate ₹50",
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 4),
              RichText(
                text: const TextSpan(
                  text: "UPI ID: ",
                  style: TextStyle(color: Colors.black),
                  children: [
                    TextSpan(
                      text: "9461852060@ybl",
                      style: TextStyle(color: Colors.blue),
                    ),
                  ],
                ),
              )
            ],
          ),
        );
      },
    );
  }


  void _startAutoScroll() {
    _carouselTimer?.cancel(); // Cancel any existing timer
    _carouselTimer = Timer.periodic(Duration(seconds: 3), (Timer timer) {
      if (_pageController.hasClients) { // Check if controller is attached
        if (_currentPage < _imagePaths.length - 1) {
          _currentPage++;
        } else {
          _currentPage = 0;
        }
        _pageController.animateToPage(
          _currentPage,
          duration: Duration(milliseconds: 500),
          curve: Curves.easeInOut,
        );
      }
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Start the timer after the first frame when the PageView is built
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _startAutoScroll();
    });
  }


  @override
  void dispose() {
    _carouselTimer?.cancel(); // Cancel the timer when widget is disposed
    _pageController.dispose();
    _searchFocusNode.dispose();
    super.dispose();
  }

  Future<void> fetchShops() async {
    final response = await http.get(Uri.parse(Common.baseUrl+'api/shop/getallshops?cityName=Gotan'));

    if (response.statusCode == 200) {
      final jsonData = jsonDecode(response.body);
      print('====');
      print(jsonData['shops']);
      final List shops = jsonData['shops'];

      setState(() {
        shopList = shops.map((shop) => Shop.fromJson(shop)).toList();
        isLoading = false;
      });
    } else {
      setState(() {
        isLoading = false;
      });
      throw Exception('Failed to load shops');
    }
  }

  Future<void> fetchViewCount() async {
    try {
      final response = await http.get(Uri.parse(Common.baseUrl+'api/counter/gotanCounter'));
      if (response.statusCode == 200) {
        setState(() {
          viewCount = int.parse(response.body.trim());
        });
      } else {
        //back print("Failed to load view count: ${response.statusCode}");

      }
    } catch (e) {
      //back print("Error fetching view count: $e");

    }
  }

  Future<bool> close() async {
    final result = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        titlePadding: EdgeInsets.only(top: 20, left: 24, right: 24),
        contentPadding: EdgeInsets.only(left: 24, right: 24, top: 14, bottom: 24),
        actionsPadding: EdgeInsets.only(right: 16, bottom: 16),
        title: Text(
          "Confirm Exit",
          style: TextStyle(fontWeight: FontWeight.w800, color: Color(0xFF2563EB), fontSize: 20),
        ),
        content: SizedBox(
          width: MediaQuery.of(context).size.width * 0.9,
          child: Text("Are you sure you want to Exit?", style: TextStyle(fontSize: 16),),
        ),
        actions: [
          OutlinedButton(
            onPressed: () => Navigator.pop(context, false),
            style: OutlinedButton.styleFrom(
              side: BorderSide(color: Colors.grey.shade400),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
            ),
            child: Text("Cancel", style: TextStyle(color: Colors.black)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Color(0xFF2563EB),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
            ),
            child: Text("Exit", style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    return result ?? false; // Return false if dialog is dismissed without pressing a button
  }

  Future<void> _handleRefresh() async {
    await Future.delayed(Duration(seconds: 2)); // simulate delay
    setState(() {
      loadProfileData();
      fetchShops();
      fetchViewCount();
      fetchWeather();
      checkNotificationPermission(context);
      // update your data here
    });
  }

  Future<void> checkNotificationPermission(BuildContext context) async {

    var status = await Permission.notification.status;

    if (status.isGranted) {
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
          style: TextStyle(fontWeight: FontWeight.w600, fontSize: 18, color: Colors.blue),
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

  DateTime? _lastBackPressed;

  String temperature = '';
  String weather = '';
  String city = '';
  bool loading = true;

  final String apiKey = 'c76914cee1a87f8a02128c92786eecd3';

  Future<void> fetchWeather() async {
    setState(() => loading = true);

    // Request location permission
    if (await Permission.location.request().isGranted) {
      Position position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );

      double lat = position.latitude;
      double lon = position.longitude;

      final url =
          'https://api.openweathermap.org/data/2.5/weather?lat=$lat&lon=$lon&units=metric&appid=$apiKey';

      try {
        final response = await http.get(Uri.parse(url));
        if (response.statusCode == 200) {
          final data = json.decode(response.body);
          setState(() {
            temperature = data['main']['temp'].toString() + '°C';
            weather = data['weather'][0]['main'];
            city = data['name'];
            loading = false;
          });
        } else {
          throw Exception('Failed to load weather data');
        }
      } catch (e) {
        setState(() {
          loading = false;
          weather = 'Error: ${e.toString()}';
        });
      }
    } else {
      setState(() {
        loading = false;
        weather = 'Location permission denied';
      });

    }
    await checkNotificationPermission(context);
  }

  void showPermissionSettingsDialog(BuildContext context) {
    showDialog(
      // context: context,
      // builder: (_) => AlertDialog(
      //   title: Text("Location Permission Required"),
      //   content: Text("Location permission is permanently denied. Please enable it from settings."),
      //   actions: [
      //     TextButton(
      //       onPressed: () => Navigator.pop(context),
      //       child: Text("Cancel"),
      //     ),
      //     TextButton(
      //       onPressed: () {
      //         Navigator.pop(context);
      //         openAppSettings();
      //       },
      //       child: Text("Open Settings"),
      //     ),
      //   ],
      // ),

      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        titlePadding: EdgeInsets.only(top: 20, left: 24, right: 24),
        contentPadding: EdgeInsets.only(left: 24, right: 24, top: 14, bottom: 24),
        actionsPadding: EdgeInsets.only(right: 16, bottom: 16),
        title: Text(
          "Location Permission Required",
          style: TextStyle(fontWeight: FontWeight.w600, fontSize: 18, color: Color(0xFF2563EB)),
        ),
        content: SizedBox(
          width: MediaQuery.of(context).size.width * 0.9,
          child: Text("Location permission is permanently denied. Please enable it from settings.", style: TextStyle(fontSize: 15),),
        ),
        actions: [
          OutlinedButton(
            onPressed: () => Navigator.pop(context, false),
            style: OutlinedButton.styleFrom(
              side: BorderSide(color: Colors.grey.shade400),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
            ),
            child: Text("Cancel", style: TextStyle(color: Colors.black)),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              openAppSettings();
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Color(0xFF2563EB),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
            ),
            child: Text("Open Settings", style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  void showPermissionRequestDialog(BuildContext context) {
    showDialog(
      // context: context,
      // builder: (_) => AlertDialog(
      //   title: Text("Permission Needed"),
      //   content: Text("Please allow location permission to continue."),
      //   actions: [
      //     TextButton(
      //       onPressed: () => Navigator.pop(context),
      //       child: Text("OK"),
      //     ),
      //   ],
      // ),
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        titlePadding: EdgeInsets.only(top: 20, left: 24, right: 24),
        contentPadding: EdgeInsets.only(left: 24, right: 24, top: 14, bottom: 24),
        actionsPadding: EdgeInsets.only(right: 16, bottom: 16),
        title: Text(
          "Permission Needed",
          style: TextStyle(fontWeight: FontWeight.w600, color: Color(0xFF2563EB)),
        ),
        content: SizedBox(
          width: MediaQuery.of(context).size.width * 0.9,
          child: Text("Please allow location permission to continue.", style: TextStyle(fontSize: 16),),
        ),
        actions: [
          ElevatedButton(
            onPressed: () => Navigator.pop(context),
            style: ElevatedButton.styleFrom(
              backgroundColor: Color(0xFF2563EB),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
            ),
            child: Text("Ok", style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }



  @override
  Widget build(BuildContext context) {

    final userProvider = Provider.of<UserProvider>(context);

    return WillPopScope(
      onWillPop: () async {
        if (_searchFocusNode.hasFocus) {
          _searchFocusNode.unfocus();
          return false;
        }

        final now = DateTime.now();
        if (_lastBackPressed == null ||
            now.difference(_lastBackPressed!) > Duration(seconds: 2)) {
          _lastBackPressed = now;

          // Show exit confirmation
          final shouldExit = await close();
          return shouldExit;
        }

        return false; // Exit the app
      },
      child: Scaffold(

        drawer: MainDrawer(
          userName: userName,
          phone: phone,
        ),

        appBar: AppBar(
          automaticallyImplyLeading: false, // disables default back/menu icon
          backgroundColor: const Color(0xFFB3D9F6), // set background color directly
          elevation: 1, // this now shows shadow correctly
          shadowColor: Colors.grey.shade500, // optional: set shadow color
          title: Padding(
            padding: const EdgeInsets.only(left: 5),
            child: Image.asset('assets/images/gologo.png', height: 40),
          ),
          actions: [
            Builder(
              builder: (context) => IconButton(
                icon: const Icon(Icons.menu, color: Colors.black),
                onPressed: () {
                  _searchFocusNode.unfocus(); // ✅ Unfocus first
                  Scaffold.of(context).openDrawer(); // ❌ This throws error in this context
                },
              ),
            ),
          ],
        ),


        body: RefreshIndicator(
          onRefresh: _handleRefresh,
          color: Color(0xFF265DFF),              // Spinner color
          backgroundColor: Colors.white,
          child: GestureDetector(
            onTap: () {
              _searchFocusNode.unfocus(); // This removes focus from the TextField
            },
            child: Container(
              decoration: BoxDecoration(gradient: kAppGradient),
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Hey, ${userProvider.name}',
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
                    // Text('Hey, '+userName, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
                    SizedBox(height: 4),
                    Text('What are you looking for?', style: TextStyle(fontSize: 16)),
                    SizedBox(height: 4),
                    if (temperature.isNotEmpty)
                      Column(
                        children: [
                          // Text('City: $city', style: TextStyle(fontSize: 20)),
                          Text(temperature, style: TextStyle(fontSize: 15, color: Colors.blue, fontWeight: FontWeight.bold),),
                          // Text('Weather: $weather', style: TextStyle(fontSize: 20)),
                        ],
                      ),
          
                    SizedBox(height: 10),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: GestureDetector(
                            onTap: () async{
                              // Navigator.push(
                              //   context,
                              //   MaterialPageRoute(builder: (context) => LocationPickerPage()),
                              // );

                              if (phone != "0000000000") {
                                var status = await Permission.location.status;

                                if (status.isGranted) {
                                  // ✅ Permission already granted, navigate
                                  await checkNotificationPermission(context);
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(builder: (context) => LottieSplashScreen(
                                      nextPage: LocationPickerPage(page:1),
                                      assetPath: 'assets/animations/travel.json',
                                    )),
                                  );
                                } else if (status.isPermanentlyDenied) {
                                  // ❌ Permission permanently denied
                                  showPermissionSettingsDialog(context);
                                } else {
                                  // ❓ Not yet granted or denied, ask nowDeloi
                                  var newStatus = await Permission.location.request();
                                  if (newStatus.isGranted) {
                                    Navigator.push(
                                      context,
                                      MaterialPageRoute(builder: (context) => LottieSplashScreen(
                                        nextPage: LocationPickerPage(page:1),
                                        assetPath: 'assets/animations/travel.json',
                                      )),
                                    );
                                  } else {
                                    showPermissionRequestDialog(context);
                                  }
                                }
                              }
                              if(phone=='0000000000')
                              Navigator.push(
                                context,
                                MaterialPageRoute(builder: (context) => PhoneInputPage()
                              ));
                              // if(phone!='0000000000')
                              // Navigator.push(
                              //   context,
                              //   MaterialPageRoute(builder: (context) => LottieSplashScreen(
                              //     nextPage: LocationPickerPage(page:1),
                              //     assetPath: 'assets/animations/travel.json',
                              //   )),
                              // );
                              _searchFocusNode.unfocus();
                            },
                            child: Container(
                              child: _buildActionCard('Book a Rider', 'assets/images/rider.png'),
                            ),
                          ),
                        ),
                        // SizedBox(width: 20),
                        Expanded(
                          child: GestureDetector(
                            onTap: () async{
                              // Navigator.push(
                              //   context,
                              //   MaterialPageRoute(builder: (context) => LocationPickerPage()),
                              // );
                              if(phone=='0000000000')
                                Navigator.push(
                                    context,
                                    MaterialPageRoute(builder: (context) => PhoneInputPage()
                                    ));
                              if (phone != "0000000000") {
                                var status = await Permission.location.status;

                                if (status.isGranted) {
                                  await checkNotificationPermission(context);
                                  // ✅ Permission already granted, navigate
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(builder: (context) => LottieSplashScreen(
                                      nextPage: LocationPickerPage(page:2),
                                      assetPath: 'assets/animations/travel.json',
                                    )),
                                  );
                                } else if (status.isPermanentlyDenied) {
                                  // ❌ Permission permanently denied
                                  showPermissionSettingsDialog(context);
                                } else {
                                  // ❓ Not yet granted or denied, ask now
                                  var newStatus = await Permission.location.request();
                                  if (newStatus.isGranted) {
                                    Navigator.push(
                                      context,
                                      MaterialPageRoute(builder: (context) => LottieSplashScreen(
                                        nextPage: LocationPickerPage(page:2),
                                        assetPath: 'assets/animations/travel.json',
                                      )),
                                    );
                                  } else {
                                    showPermissionRequestDialog(context);
                                  }
                                }
                              }
                              // if(phone!='0000000000')
                              // Navigator.push(
                              //   context,
                              //   MaterialPageRoute(builder: (context) => LottieSplashScreen(
                              //     nextPage: LocationPickerPage(page:2),
                              //     assetPath: 'assets/animations/travel.json',
                              //   )),
                              // );
                              _searchFocusNode.unfocus();
                            },
                            child: Container(
                              child: _buildActionCard('Deliver a Parcel', 'assets/images/parcel3.png'),
                            ),
                          ),
                        ),

                        Expanded(
                          child: GestureDetector(
                            onTap: () async{

                              final Uri url = Uri.parse("https://digistall.in/");

                              if (await canLaunchUrl(url)) {
                                await launchUrl(url, mode: LaunchMode.externalApplication);
                              } else {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(content: Text('Could not launch website')),
                                );
                              }
                              _searchFocusNode.unfocus();
                            },
                            child: Container(
                              child: _buildActionCard('Create Store', 'assets/images/store2.png'),
                            ),
                          ),
                        ),
                      ],
                    ),
          
                    SizedBox(height: 10),
                    Card(
                      elevation: 4,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(24),
                      ),
                      margin: EdgeInsets.zero,
                      child: Container(
                        height: 45,
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(24),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.search, color: Colors.grey),
                            const SizedBox(width: 10),
                            Expanded(
                              child: TextField(
                                focusNode: _searchFocusNode,
                                cursorColor: Colors.grey,      // 👈 Cursor color
                                cursorHeight: 20,
                                decoration: const InputDecoration(
                                  hintText: 'Search for shops and categorys',
                                  hintStyle: TextStyle(color: Colors.grey),
                                  border: InputBorder.none,
                                ),
                                onChanged: (value) {
                                  setState(() {
                                    searchQuery = value;
                                    currentPage = 1; // Reset to first page when searching
                                  });
                                },
                              ),
                            ),
          
                          ],
                        ),
                      ),
                    ),
                    // TextField(
                    //   decoration: InputDecoration(
                    //     hintText: 'Search...',
                    //     border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                    //     prefixIcon: Icon(Icons.search),
                    //   ),
                    //   onChanged: (value) {
                    //     setState(() {
                    //       searchQuery = value;
                    //       currentPage = 1; // Reset to first page when searching
                    //     });
                    //   },
                    // ),
          
                    SizedBox(height: 20),
                    Text('Categories', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
                    SizedBox(height: 15),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceAround,
                      children: categories.map((cat) {
                        return GestureDetector(
                          // In your category onTap handler:
                          onTap: () {
                            setState(() {
                              selectedCategory = cat['name']!;
                              currentPage = 1; // Reset to first page when changing category
                            });
                          },
                          child: Column(
                            children: [
                              CircleAvatar(
                                backgroundImage: AssetImage(cat['image']!),
                                radius: 30,
                                backgroundColor: selectedCategory == cat['name']
                                    ? Colors.blue.withOpacity(0.2)
                                    : Colors.transparent,
                              ),
                              SizedBox(height: 5),
                              Text(
                                cat['name']!,
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: selectedCategory == cat['name']
                                      ? FontWeight.bold
                                      : FontWeight.normal,
                                ),
                              ),
                            ],
                          ),
                        );
                      }).toList(),
                    ),
          
                    SizedBox(height: 24,),
          
                    isLoading
                        ? const Center(child: CircularProgressIndicator())
                        : filteredShops.isEmpty
                        ? const Center(
                      child: Text(
                        'No shops found matching your criteria',
                        style: TextStyle(fontSize: 16),
                      ),
                    )
                        : Column(
                      children: [
                        GridView.count(
                          crossAxisCount: 2,
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          childAspectRatio: 0.75,
                          mainAxisSpacing: 16,
                          crossAxisSpacing: 16,
                          children: paginatedShops
                              .map((shop) => _buildShopCard(
                            shop.shopImage,
                            shop.heading,
                            shop.desc,
                            shop.shopId,
                            context,
                          ))
                              .toList(),
                        ),
                        const SizedBox(height: 16),
                        if (totalPages > 1)
                          Wrap(
                            spacing: 8,
                            children: List.generate(totalPages, (index) {
                              int pageNumber = index + 1;
                              return ElevatedButton(
                                onPressed: () {
                                  setState(() {
                                    currentPage = pageNumber;
                                  });
                                },
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: currentPage == pageNumber
                                      ? Colors.blue
                                      : Colors.grey.shade300,
                                  foregroundColor: currentPage == pageNumber
                                      ? Colors.white
                                      : Colors.black,
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 16,
                                    vertical: 8,
                                  ),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                ),
                                child: Text("$pageNumber"),
                              );
                            }),
                          ),
                      ],
                    ),
          
                    SizedBox(height: 20,),
                    buildFundraisingSection(context),
                    const SizedBox(height: 10),
                    SingleChildScrollView(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          // Eye icon and view count (optional for mobile top)

                          const SizedBox(height: 4),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                            children: [
                              Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  const Icon(Icons.remove_red_eye, size: 32),
                                  Text(
                                    '$viewCount',
                                    style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
                                  ),
                                ],
                              ),
                              Image.asset(
                                'assets/images/gologo.png',
                                height: 40,
                              ),
                            ],
                          ),
                          const SizedBox(height: 20),
          
                          // Social Icon
          
                          // Company Info Section (Left Column originally)
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.center,
                            children: [
                              // Image.asset(
                              //   'assets/images/gologo.png',
                              //   height: 40,
                              // ),
                              // const SizedBox(height: 12),
                              GestureDetector(
                                onTap: () => _openWhatsApp(context),
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: const [
                                    Icon(Icons.phone, size: 16),
                                    SizedBox(width: 8),
                                    Text('+91 9461852060'),
                                  ],
                                ),
                              ),
                              const SizedBox(height: 8),
                              GestureDetector(
                                onTap: () => _openEmail(context),
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: const [
                                    Icon(Icons.email, size: 16),
                                    SizedBox(width: 8),
                                    Text('humansofruralindia@gmail.com'),
                                  ],
                                ),
                              ),
                              const SizedBox(height: 8),
                              const Text('7 Siyag House, Gotan, Rajasthan 342902'),
                            ],
                          ),
                          const SizedBox(height: 24),
                          Wrap(
                            spacing: 16,
                            alignment: WrapAlignment.center,
                            children: [
                              GestureDetector(
                                onTap: () => _launchUrl('https://www.instagram.com/digistallapp/'),
                                child: Image.asset('assets/images/instagram.png', height: 32),
                              ),
                              GestureDetector(
                                onTap: () => _launchUrl('https://www.linkedin.com/company/humans-of-rural-india/'),
                                child: Image.asset('assets/images/linkedin.png', height: 32),
                              ),
                              GestureDetector(
                                onTap: () => _launchUrl('https://www.facebook.com/humansofruralindia/'),
                                child: Image.asset('assets/images/facebook.png', height: 32),
                              ),
                              GestureDetector(
                                onTap: () => _launchUrl('https://x.com/DigistallApp'),
                                child: Image.asset('assets/images/twitter.png', height: 32),
                              ),
                              GestureDetector(
                                onTap: () => _launchUrl('https://www.youtube.com/@digistall'),
                                child: Image.asset('assets/images/youtube.png', height: 32),
                              ),
                            ],
                          ),
                          const SizedBox(height: 24),
          
                          // Legal Info (Center Column)
                          Column(
                            children: const [
                              Text("Siyag Rural Market Private Limited [© Digistall]"),
                              Text("CIN No. :- U52100RJ2021PTC077111"),
                              Text("GSTIN :- 08ABGCS8909L1ZN"),
                            ],
                          ),
                          const SizedBox(height: 24),
          
                          // Right Column (Newsletter & Policies)
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.center,
                            children: [
                              GestureDetector(
                                onTap: () => _openUrl("https://digistall.substack.com/", context),
                                child: const Text("Newsletter"),
                              ),
                              const SizedBox(height: 8),
                              GestureDetector(
                                onTap: () => _openUrl("https://digistall.in/privacy_and_policy", context),
                                child: const Text("Privacy Policy"),
                              ),
                              const SizedBox(height: 8),
                              GestureDetector(
                                onTap: () => _openUrl("https://digistall.in/terms_and_conditions", context),
                                child: const Text("Terms and Condition"),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
          
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  void _openUrl(String url, BuildContext context) async {
    final Uri uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not open the link')),
      );
    }
  }

  Widget buildFundraisingSection(context) {
    return Padding(
      padding: const EdgeInsets.all(8.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Title Text
          Container(
            alignment: Alignment.center,
            child: const Text.rich(
              TextSpan(
                text: 'Help Us Cleanse This ',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 24,
                ),
                children: [
                  TextSpan(
                    text: 'Pond',
                    style: TextStyle(color: Colors.blue),
                  ),
                  TextSpan(text: ',\nRestore '),
                  TextSpan(
                    text: "Nature's",
                    style: TextStyle(color: Colors.green),
                  ),
                  TextSpan(text: ' Beauty.'),
                ],
              ),
              textAlign: TextAlign.center,
            ),
          ),
          const SizedBox(height: 12),

          // Image with arrows
          FundraisingCarousel(),
          const SizedBox(height: 20),

          // Left-aligned text
          const Text(
            "Hello all,",
            style: TextStyle(fontSize: 16),
            textAlign: TextAlign.left,
          ),
          const SizedBox(height: 8),

          const Text.rich(
            TextSpan(
              text: "We're launching a crucial ",
              children: [
                TextSpan(
                  text: "fundraising campaign ",
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                TextSpan(
                  text: "to restore and cleanse this pond",
                ),
              ],
            ),
            textAlign: TextAlign.left,
          ),
          const SizedBox(height: 12),

          const Text(
            "Through your generous contributions, we can make a significant impact, reclaiming this natural treasure for future generations to enjoy.",
            textAlign: TextAlign.left,
          ),
          const SizedBox(height: 20),

          // Center-aligned fundraising details
          Center(
            child: Column(
              children: const [
                Text(
                  "We are Raising",
                  style: TextStyle(fontSize: 16),
                ),
                SizedBox(height: 4),
                Text(
                  "Rs. 50,000",
                  style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Center-aligned button
          Center(
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green,
                padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              onPressed: () {
                _showDonateDialog(context);
              },
              child: const Text(
                "Donate Now",
                style: TextStyle(color: Colors.white, fontSize: 16),
              ),
            ),
          ),
        ],
      ),
    );
  }
  Widget _buildShopCard(String imagePath, String name, String category, String shopId, BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black12,
            blurRadius: 8,
            offset: Offset(0, 4),
          )
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            decoration: BoxDecoration(
              color: Colors.grey.shade200,
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(16),
                topRight: Radius.circular(16),
              ),
            ),
            height: 120,
            child: imagePath.isNotEmpty
                ? ClipRRect(
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(16),
                topRight: Radius.circular(16),
              ),
              child: Image.network(
                imagePath,
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) => Container(
                  color: Colors.grey.shade300,
                  child: const Center(
                    child: Icon(Icons.store, size: 40, color: Colors.grey),
                  ),
                ),
              ),
            )
                : const Center(
              child: Icon(Icons.store, size: 40, color: Colors.grey),
            ),
          ),
          const SizedBox(height: 8),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8.0),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  // Container(height: 100,color: Colors.black,),
                  Column(
                    children: [
                      SizedBox(
                        child: SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          child: Text(
                            name,
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              color: Colors.blue,
                            ),
                            maxLines: 1,
                          ),
                        ),
                      ),
                      const SizedBox(height: 4),
                      SizedBox(
                        child: SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          child: Text(
                            category,
                            style: const TextStyle(color: Colors.grey),
                            maxLines: 2,
                          ),
                        ),
                      ),
                    ],
                  ),
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF265DFF),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      minimumSize: const Size(100, 36),
                    ),
                    onPressed: () {
                      _searchFocusNode.unfocus();
                      // FocusScope.of(context).unfocus();
                      Navigator.push(context, MaterialPageRoute(builder: (context) => ShopMainScreen(shopId: shopId.toLowerCase())));

                    },
                    child: const Text("Visit Shop", style: TextStyle(color: Colors.white)),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

Widget _buildActionCard(String title, String imagePath) {
  return Container(
    // width: 140,
    // height: 160,
    margin: const EdgeInsets.all(8),
    decoration: BoxDecoration(
      // color: Colors.white,
      borderRadius: BorderRadius.circular(12),
      // border: Border.all(color: Colors.grey.shade300),
      boxShadow: [
        // BoxShadow(
        //   color: Colors.black.withOpacity(0.05),
        //   blurRadius: 6,
        //   offset: const Offset(0, 2),
        // ),
      ],
    ),
    child: Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Card(
          elevation: 3,
          child: Container(
            width: 70,
            height: 70,
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(10),
              // border: Border.all(color: Colors.grey.shade400),
            ),
            child: imagePath=='assets/images/store2.png'? Padding(
              padding: const EdgeInsets.all(10.0),
              child: Image.asset(
                imagePath,
                fit: BoxFit.contain,
              ),
            ): Image.asset(
              imagePath,
              fit: BoxFit.contain,
            ),
          ),
        ),
        const SizedBox(height: 5),
        Text(
          title,
          textAlign: TextAlign.center,
          style: const TextStyle(
            fontWeight: FontWeight.w300,
            fontSize: 13,
            color: Colors.black,
          ),
        ),
      ],
    ),
  );
}


Widget _buildDrawerItem(IconData icon, String title, BuildContext context) {
  return ListTile(
    leading: Icon(icon, color: Colors.blue),
    title: Text(title),
    onTap: () {
      Navigator.pop(context);
      Navigator.push(
        context,
        MaterialPageRoute(builder: (context) => MyProfileScreen()),
      );

    },
  );
}






class MainDrawer extends StatelessWidget {
  final String userName;
  final String phone;

  const MainDrawer({
    super.key,
    required this.userName,
    required this.phone,
  });

  @override
  Widget build(BuildContext context) {
    final userProvider = Provider.of<UserProvider>(context);

    return Drawer(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 25),
            // App Logo
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Image.asset('assets/images/gologo.png', height: 45),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),

            const SizedBox(height: 12),
            const Divider(),
            const SizedBox(height: 12),

            if(phone=='0000000000')
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF265DFF),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  minimumSize: const Size(double.infinity, 50),
                ),
                onPressed: () {
                  // FocusScope.of(context).unfocus();
                  Navigator.push(context, MaterialPageRoute(builder: (context) => PhoneInputPage()));

                },
                child: const Text("Login / Register", style: TextStyle(color: Colors.white, fontSize: 16)),
              ),
            // User Info Box
            if(phone!='0000000000')
            GestureDetector(
              onTap: (){
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => MyProfileScreen()),
                );
              },
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.blue.shade50,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Row(
                  children: [
                    const CircleAvatar(
                      backgroundColor: Colors.white,
                      child: Icon(Icons.person, color: Colors.blue),
                    ),
                    const SizedBox(width: 10),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Text(userName, style: const TextStyle(fontWeight: FontWeight.bold)),
                        // Text(phone, style: const TextStyle(color: Colors.grey)),
                        Text(userProvider.name,
                            style: const TextStyle(fontWeight: FontWeight.bold)),
                        Text(userProvider.phone,
                            style: const TextStyle(color: Colors.grey)),
                      ],
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 24),

            // Menu Items
            _buildDrawerItem(Icons.home, "Home", context),
            if(phone=='0000000000')
            _buildDrawerItem(Icons.person_outline, "Login / Register", context),
            if(phone!='0000000000')
            _buildDrawerItem(Icons.person_outline, "My Profile", context),
            _buildDrawerItem(Icons.pedal_bike, "Rider History", context),
            _buildDrawerItem(Icons.inventory_2_outlined, "Parcel History", context),

            const SizedBox(height: 16),
            const Divider(),

            // ListTile(
            //   leading: const Icon(Icons.download_outlined),
            //   title: const Text("Download APP"),
            //   onTap: () {},
            // ),

            const SizedBox(height: 16),

            // Order on Call Section
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.green.shade50,
                borderRadius: BorderRadius.circular(10),
              ),
              child: InkWell(
                onTap: () async {
                  final phoneNumber = "9461852060"; // international format, no spaces
                  final uri = Uri.parse("https://wa.me/${phoneNumber.replaceAll('+', '')}");
                  if (await canLaunchUrl(uri)) {
                    await launchUrl(uri, mode: LaunchMode.externalApplication);
                  } else {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Could not open WhatsApp')),
                    );
                  }
                },
                child: Row(
                  children: const [
                    Icon(Icons.phone, color: Colors.green),
                    SizedBox(width: 10),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text("Order on Call", style: TextStyle(color: Colors.green)),
                        Text("+91 9461852060", style: TextStyle(fontWeight: FontWeight.bold)),
                      ],
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 16),

            // Become DigiCaptain Section
            InkWell(
              onTap: () async {
                final Uri url = Uri.parse('https://rider.digistall.in/');
                if (await canLaunchUrl(url)) {
                  await launchUrl(url, mode: LaunchMode.externalApplication); // opens in browser
                } else {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Could not open the website')),
                  );
                }
              },
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.purple.shade50,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Row(
                  children: const [
                    Icon(Icons.motorcycle, color: Colors.purple),
                    SizedBox(width: 10),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text("DigiCaptain", style: TextStyle(color: Colors.purple)),
                        Text("Become DigiCaptain", style: TextStyle(fontWeight: FontWeight.bold)),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDrawerItem(IconData icon, String title, BuildContext context) {
    return ListTile(
      leading: Icon(icon, color: Colors.blue),
      title: Text(title),
      onTap: () {
        Navigator.pop(context);
        if (title == "Login / Register") {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => PhoneInputPage()),
          );
        }
        if (title == "My Profile") {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => MyProfileScreen()),
          );
        }
        if (title == "Rider History") {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => RideHistoryScreen()),
          );
        }
        if (title == "Parcel History") {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => ParcelHistoryScreen()),
          );
        }
        // Add other navigation cases as needed
      },
    );
  }
}







