import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:gotan/global/common.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;
import 'package:url_launcher/url_launcher.dart';
import 'package:permission_handler/permission_handler.dart';

import '../services/notification_service.dart';

class GoogleLoginAndProfilePage extends StatefulWidget {
  const GoogleLoginAndProfilePage({super.key});

  @override
  State<GoogleLoginAndProfilePage> createState() => _GoogleLoginAndProfilePageState();
}

class _GoogleLoginAndProfilePageState extends State<GoogleLoginAndProfilePage> {
  final GoogleSignIn _googleSignIn = GoogleSignIn();
  String? _errorMessage;
  Map<String, dynamic>? userData;
  bool isLoading = true;
  String? _storedEmail;
  Map<String, dynamic> shopHeader = {};
  int _selectedTab = 0;
  final _mobileController = TextEditingController();
  final _mobileController1 = TextEditingController();
  final _nameController = TextEditingController();
  final _locationController = TextEditingController();
  DateTime? _selectedDOB;
  String? _selectedGender;
  bool _isEditMode = false;
  final List<Map<String, String>> _savedAddresses = [];
  bool _showForm = false;
  final TextEditingController _nameControllers = TextEditingController();
  final TextEditingController _mobileControllers = TextEditingController();
  final TextEditingController _addressController = TextEditingController();
  final TextEditingController _pincodeController = TextEditingController();
  final TextEditingController _stateController = TextEditingController();
  int? _selectedIndex;

  bool _notificationsEnabled = true; // or fetch the actual state if saved


  @override
  void initState() {
    super.initState();
    loadShopHeader();
    checkStoredEmail();
    _loadSavedAddresses();
    _checkNotificationStatus();
  }

  void _checkNotificationStatus() async {
    final status = await Permission.notification.status;
    setState(() {
      _notificationsEnabled = status.isGranted;
    });
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

  Future<void> _saveAddress() async {
    if (_nameControllers.text.isEmpty ||
        _mobileControllers.text.isEmpty ||
        _addressController.text.isEmpty ||
        _pincodeController.text.isEmpty ||
        _stateController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("All fields are required")),
      );
      return;
    }

    final newAddress = {
      "name": _nameControllers.text,
      "mobile": _mobileControllers.text,
      "address": _addressController.text,
      "pincode": _pincodeController.text,
      "state": _stateController.text,
    };

    setState(() {
      _savedAddresses.add(newAddress);
      _showForm = false;
    });

    final prefs = await SharedPreferences.getInstance();
    final encodedList = _savedAddresses.map((e) => json.encode(e)).toList();
    await prefs.setStringList('saved_addresses', encodedList);

    // Clear inputs
    _nameControllers.clear();
    _mobileControllers.clear();
    _addressController.clear();
    _pincodeController.clear();
    _stateController.clear();
  }

  void _removeAddress(int index) async {
    SharedPreferences prefs = await SharedPreferences.getInstance();

    setState(() {
      _savedAddresses.removeAt(index); // Remove from local list
    });

    // Save updated list to SharedPreferences
    List<String> updatedJsonList = _savedAddresses.map((addr) => jsonEncode(addr)).toList();
    await prefs.setStringList('saved_addresses', updatedJsonList);
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

  Future<void> checkStoredEmail() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    String? email = prefs.getString('user_email');

    if (email != null) {
      setState(() {
        _storedEmail = email;
      });
      fetchUserData(email);
    } else {
      setState(() {
        isLoading = false;
      });
    }
  }

  Future<void> signInWithGoogle() async {
    try {
      await _googleSignIn.signOut();
      await FirebaseAuth.instance.signOut();

      final GoogleSignInAccount? googleUser = await _googleSignIn.signIn();
      // if (googleUser == null) {
      //   setState(() {
      //     _errorMessage = "Sign in aborted by user.";
      //   });
      //   return;
      // }
      if (googleUser == null) return null;

      final GoogleSignInAuthentication googleAuth = await googleUser.authentication;
      final credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );

      UserCredential userCredential = await FirebaseAuth.instance.signInWithCredential(credential);
      final user = userCredential.user;

      if (user != null) {
        final email = user.email;
        SharedPreferences prefs = await SharedPreferences.getInstance();
        await prefs.setString('user_email', email!);
        // final deviceToken = await prefs.getString('deviceToken');
        await NotificationService().resetFcmToken(); // Ensure a fresh token
        final updatedPrefs = await SharedPreferences.getInstance();
        final deviceToken = updatedPrefs.getString('deviceToken');
        print(deviceToken);

        setState(() {
          _storedEmail = email;
        });

        // First make the initial API call
        final initialResponse = await http.post(
          Uri.parse(Common.digiBaseUrl + "customer/verifyotpnew"),
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode({"email": "\"$email\"", "deviceToken": deviceToken}),
        );

        if (initialResponse.statusCode == 200) {
          // Only proceed to fetch user data if the first API call succeeds
          await fetchUserData(email);
        } else {
          setState(() {
            _errorMessage = "Initial API call failed";
            isLoading = false;
          });
        }
      }
    } on FirebaseAuthException catch (e) {
      setState(() {
        _errorMessage = "FirebaseAuth error: ${e.message}";
        isLoading = false;
      });
    } catch (e) {
      setState(() {
        _errorMessage = "Unexpected error: $e";
        isLoading = false;
      });
    }
  }

  Future<void> fetchUserData(String email) async {
    setState(() {
      isLoading = true;
    });

    final response = await http.post(
      Uri.parse(Common.digiBaseUrl + "customer/getcustomer"),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({"email": "\"$email\""}),
    );

    if (response.statusCode == 200) {
      //back print("===");
      //back print(response.body);
      setState(() {
        print("===");
        userData = json.decode(response.body);
        print(userData?['deviceToken']);
        isLoading = false;
      });
    } else {
      setState(() {
        _errorMessage = "Failed to load user data";
        isLoading = false;
      });
    }
  }

  Future<void> signOut() async {
    await _googleSignIn.signOut();
    await FirebaseAuth.instance.signOut();
    SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.remove('user_email');
    await NotificationService().resetFcmToken();


    setState(() {
      _storedEmail = null;
      userData = null;
      _errorMessage = null;
      isLoading = false;
    });
  }

  String _getStringValue(dynamic value) {
    if (value == null || value.toString().trim().isEmpty) {
      return "- not added -";
    }
    return value.toString();
  }

  Widget _buildProfileRow(String title, dynamic value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        children: [
          Expanded(
            flex: 2,
            child: Text(
              title,
              style: const TextStyle(fontWeight: FontWeight.w500),
            ),
          ),
          Expanded(
            flex: 3,
            child: Text(_getStringValue(value)),
          ),
        ],
      ),
    );
  }

  Widget _buildProfileView() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(color: Colors.black12, blurRadius: 6, offset: Offset(0, 2)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            "MY PROFILE",
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
          ),
          const Divider(),
          _buildProfileRow("Full Name", userData?['name']),
          _buildProfileRow("Mobile Number", userData?['phoneNumber']),
          _buildProfileRow("Email ID", userData?['email']?.replaceAll('"', '')),
          _buildProfileRow("Gender", userData?['gender']),
          _buildProfileRow(
            "Date of Birth",
            userData?['DOB'] != null
                ? DateTime.tryParse(userData!['DOB'])?.toLocal().toString().split(' ')[0]
                : null,
          ),
          _buildProfileRow("Location", userData?['location']),
          _buildProfileRow("Alternate Mobile", userData?['alternateNumber']),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () {
                setState(() {
                  _isEditMode = true;

                  // Alternate Mobile
                  final altNumber = _getStringValue(userData?['alternateNumber']);
                  _mobileController.text = (altNumber == "- not added -") ? '' : altNumber;

                  // Primary Mobile
                  final primaryNumber = _getStringValue(userData?['phoneNumber']);
                  _mobileController1.text = (primaryNumber == "- not added -") ? '' : primaryNumber;

                  // Full Name
                  final fullName = _getStringValue(userData?['fullName'] ?? userData?['name']);
                  _nameController.text = (fullName == "- not added -") ? '' : fullName;

                  // Location
                  final location = _getStringValue(userData?['location']);
                  _locationController.text = (location == "- not added -") ? '' : location;

                  // Gender
                  final gender = _getStringValue(userData?['gender']);
                  _selectedGender = (gender == "- not added -") ? null : gender;

                  // Date of Birth
                  final dob = _getStringValue(userData?['DOB']);
                  _selectedDOB = (dob == "- not added -") ? null : DateTime.tryParse(dob);
                });
              },

              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.teal,
                minimumSize: const Size.fromHeight(40),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              child: const Text(
                "Edit",
                style: TextStyle(color: Colors.white),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAddressSection() {
    return Column(
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
                setState(() => _showForm = true);
              },
              child: const Text("ADD ADDRESS", style: TextStyle(color: Colors.teal)),
            ),
          ),
          const SizedBox(height: 16),
          ..._savedAddresses.asMap().entries.map((entry) {
            final index = entry.key;
            final address = entry.value;

            return Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
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
                        _selectedIndex = value!;
                      });
                    },
                    activeColor: Colors.teal,
                  ),
                  title: Text(address['name'] ?? '', style: const TextStyle(fontWeight: FontWeight.bold)),
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

          // const SizedBox(height: 16),
          // Padding(
          //   padding: const EdgeInsets.symmetric(horizontal: 16),
          //   child: SizedBox(
          //     width: double.infinity,
          //     child: ElevatedButton(
          //       style: ElevatedButton.styleFrom(
          //         padding: const EdgeInsets.all(16),
          //         backgroundColor: Colors.teal,
          //         shape: RoundedRectangleBorder(
          //           borderRadius: BorderRadius.circular(8),
          //         ),
          //       ),
          //       onPressed: () {
          //         _saveAddress();
          //       },
          //       child: const Text(
          //         "CONFIRM ADDRESS",
          //         style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
          //       ),
          //     ),
          //   ),
          // ),
        ] else ...[
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text("CONTACT DETAILS", style: TextStyle(fontWeight: FontWeight.bold)),
                const SizedBox(height: 10),
                TextField(controller: _nameControllers, decoration: const InputDecoration(hintText: "Name")),
                const SizedBox(height: 10),
                TextField(controller: _mobileControllers, keyboardType: TextInputType.phone, decoration: const InputDecoration(hintText: "Mobile Number")),
                const SizedBox(height: 20),
                const Text("ADDRESS", style: TextStyle(fontWeight: FontWeight.bold)),
                const SizedBox(height: 10),
                TextField(controller: _addressController, decoration: const InputDecoration(hintText: "Address(House no, Building, Street area)")),
                const SizedBox(height: 10),
                TextField(controller: _pincodeController, keyboardType: TextInputType.number, decoration: const InputDecoration(hintText: "Pin Code")),
                const SizedBox(height: 10),
                TextField(controller: _stateController, decoration: const InputDecoration(hintText: "State")),
                const SizedBox(height: 20),
                Row(
                  children: [

                    Expanded(
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(backgroundColor: Colors.teal),
                        onPressed: () => setState(() => _showForm = false),
                        child: const Text("Cancel", style: TextStyle(color: Colors.white)),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(backgroundColor: Colors.teal),
                        onPressed: _saveAddress,
                        child: const Text("ADD ADDRESS", style: TextStyle(color: Colors.white)),
                      ),
                    ),
                  ],
                )
              ],
            ),
          ),
        ],
        const SizedBox(height: 20),
        const Text("(c) ALL RIGHTS RESERVED | HRI",
            style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500)),
        const SizedBox(height: 16),
      ],
    );
  }

  Widget _buildHeader() {
    if (shopHeader.isEmpty) return const SizedBox.shrink();

    return Container(
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
                Text(_getStringValue(shopHeader['shopName']), style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                Text(_getStringValue(shopHeader['email']), style: const TextStyle(color: Colors.black)),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.call, color: Colors.green),
            onPressed: () async {
              var rawPhone = _getStringValue(shopHeader['phoneNumber']);
              var phone = rawPhone.replaceAll(RegExp(r'\D'), '');

              if (phone.isEmpty) return;

              final whatsappUrl = Uri.parse("https://wa.me/$phone");

              if (await canLaunchUrl(whatsappUrl)) {
                await launchUrl(whatsappUrl, mode: LaunchMode.externalApplication);
              }
            },
          ),
        ],
      ),
    );
  }

  void _saveProfile() async {
    final updatedData = <String, dynamic>{};

      updatedData['alternateNumber'] = _mobileController.text;
      updatedData['phoneNumber'] = _mobileController1.text;
      updatedData['name'] = _nameController.text;
      updatedData['location'] = _locationController.text;
      updatedData['DOB'] = _selectedDOB!.toIso8601String().split('T')[0];
      updatedData['gender'] = _selectedGender;
    // if (_mobileController.text.isNotEmpty) {
    //   updatedData['alternateNumber'] = _mobileController.text;
    // }
    // if (_mobileController1.text.isNotEmpty) {
    //   updatedData['phoneNumber'] = _mobileController1.text;
    // }
    //
    // if (_nameController.text.isNotEmpty) {
    //   updatedData['name'] = _nameController.text;
    // }
    //
    // if (_locationController.text.isNotEmpty) {
    //   updatedData['location'] = _locationController.text;
    // }
    //
    // if (_selectedDOB != null) {
    //   updatedData['DOB'] = _selectedDOB!.toIso8601String().split('T')[0];
    // }
    //
    // if (_selectedGender != null) {
    //   updatedData['gender'] = _selectedGender;
    // }

    // Required fields
    updatedData['email'] = userData!['email'];
    updatedData['orders'] = userData!['orders'] ?? [];
    updatedData['password'] = '';
    updatedData['passwordEnabled'] = false;
    updatedData['__v'] = 0;
    updatedData['_id'] = userData!['_id'];

    final payload = {
      "email": userData!['email'],
      "updatedData": updatedData
    };
    //back print('====');
    //back print("Sending payload: $payload");

    const url = Common.digiBaseUrl+'customer/updatecustomer';

    try {
      final response = await http.post(
        Uri.parse(url),
        headers: {
          'Content-Type': 'application/json',
        },
        body: jsonEncode(payload),
      );

      if (response.statusCode == 201) {
        final responseBody = jsonDecode(response.body);
        //back print("Profile updated: $responseBody");

        setState(() {
          _isEditMode = false;
          userData = {...userData!, ...updatedData};
        });

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Profile updated successfully!")),
        );
      } else {
        //back print("Error: ${response.statusCode} - ${response.body}");
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Failed to update profile. (${response.statusCode})")),
        );
      }
    } catch (e) {
      //back print("Exception: $e");
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Something went wrong. Try again.")),
      );
    }
  }

  Widget _buildEditProfile() {
    return Card(
      color: Colors.white,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text("Edit Profile", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            const SizedBox(height: 16),
            _buildTextField("Full Name", _nameController),
            const SizedBox(height: 10),
            _buildTextField("Mobile Number", _mobileController1),
            const SizedBox(height: 10),
            TextFormField(
              enabled: false,
              initialValue: _getStringValue(userData!['email']?.replaceAll('"', '')),
              decoration: const InputDecoration(labelText: 'E-Mail Address'),
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => setState(() => _selectedGender = 'Male'),
                    style: OutlinedButton.styleFrom(
                      backgroundColor: _selectedGender == 'Male' ? Colors.teal[100] : null,
                    ),
                    child: const Text('Male'),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => setState(() => _selectedGender = 'Female'),
                    style: OutlinedButton.styleFrom(
                      backgroundColor: _selectedGender == 'Female' ? Colors.teal[100] : null,
                    ),
                    child: const Text('Female'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            GestureDetector(
              onTap: () async {
                final picked = await showDatePicker(
                  context: context,
                  initialDate: DateTime(2000),
                  firstDate: DateTime(1950),
                  lastDate: DateTime.now(),
                );
                if (picked != null) {
                  setState(() => _selectedDOB = picked);
                }
              },
              child: AbsorbPointer(
                child: TextFormField(
                  decoration: const InputDecoration(labelText: 'Date of Birth'),
                  controller: TextEditingController(
                    text: _selectedDOB == null
                        ? ''
                        : "${_selectedDOB!.year}-${_selectedDOB!.month.toString().padLeft(2, '0')}-${_selectedDOB!.day.toString().padLeft(2, '0')}",
                  ),
                ),
              ),
            ),
            const SizedBox(height: 10),
            _buildTextField("Location", _locationController),
            _buildTextField("Alternate Mobile Number", _mobileController),
            const SizedBox(height: 10),
            const SizedBox(height: 20),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () {
                      setState(() {
                        _isEditMode = false;
                      });
                    },
                    child: const Text("Cancel"),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: ElevatedButton(
                    onPressed: _saveProfile,
                    style: ElevatedButton.styleFrom(backgroundColor: Colors.teal),
                    child: const Text("Save", style: TextStyle(color: Colors.white),),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTextField(String label, TextEditingController controller) {
    return TextField(
      controller: controller,
      decoration: InputDecoration(labelText: label),
    );
  }

  Widget _buildLoginUI() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Image.asset('assets/images/gologo.png', height: 60),
          const SizedBox(height: 16),
          const Text("Digistall",
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
          const SizedBox(height: 50),
          Padding(
            padding: EdgeInsets.symmetric(horizontal: 16),
            child: ElevatedButton.icon(
              onPressed: () async {
                signInWithGoogle();
              },
              icon: const Icon(Icons.g_mobiledata, size: 30, color: Colors.white),
              label: const Text("Continue with Google",
                  style: TextStyle(color: Colors.white)),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.teal[700],
                minimumSize: const Size(double.infinity, 50),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10)),
              ),
            ),
          ),
          const SizedBox(height: 16),
          const Text("Buy the products with our Digistall platform!",
              textAlign: TextAlign.center),
          if (_errorMessage != null) ...[
            const SizedBox(height: 20),
            Text(
              _errorMessage!,
              style: const TextStyle(color: Colors.red),
              textAlign: TextAlign.center,
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildErrorUI() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.error_outline, color: Colors.red, size: 48),
          const SizedBox(height: 20),
          Text(
            _errorMessage ?? "An unknown error occurred",
            style: const TextStyle(color: Colors.red, fontSize: 18),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 20),
          ElevatedButton(
            onPressed: () {
              setState(() {
                _errorMessage = null;
                isLoading = false;
              });
            },
            child: const Text("Try Again"),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: _storedEmail == null
              ? _buildLoginUI()
              // : userData == null
              // ? _buildErrorUI()
              : SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildHeader(),
                const SizedBox(height: 10),
                Row(
                  children: [
                    GestureDetector(
                      onTap: () => setState(() {
                        _selectedTab = 0;
                        _isEditMode = false;
                      }),
                      child: Padding(
                        padding: const EdgeInsets.only(right: 20.0),
                        child: Text(
                          "PROFILE",
                          style: TextStyle(
                            fontWeight: _selectedTab == 0 ? FontWeight.bold : FontWeight.normal,
                            color: _selectedTab == 0 ? Colors.teal : Colors.grey,
                          ),
                        ),
                      ),
                    ),
                    GestureDetector(
                      onTap: () => setState(() {
                        _selectedTab = 1;
                        _isEditMode = false;
                      }),
                      child: Text(
                        "ADDRESS",
                        style: TextStyle(
                          fontWeight: _selectedTab == 1 ? FontWeight.bold : FontWeight.normal,
                          color: _selectedTab == 1 ? Colors.teal : Colors.grey,
                        ),
                      ),
                    ),
                    const Spacer(),
                    TextButton(
                      onPressed: () {
                        showDialog(
                          context: context,
                          builder: (BuildContext context) {
                            return AlertDialog(
                              title: const Text("Confirm Logout", style: TextStyle(color: Colors.teal, fontWeight: FontWeight.bold, fontSize: 18),),
                              content: const Text("Are you sure you want to logout?"),
                              actions: [
                                ElevatedButton(
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.teal,
                                    minimumSize: const Size(80, 40),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                  ),
                                  child: const Text("Cancel", style: TextStyle(color: Colors.white)),
                                  onPressed: () {
                                    Navigator.of(context).pop(); // Close the dialog
                                  },
                                ),
                                ElevatedButton(
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.teal,
                                    minimumSize: const Size(80, 40),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                  ),
                                  child: const Text("Logout", style: TextStyle(color: Colors.white)),
                                  onPressed: () {
                                    Navigator.of(context).pop(); // Close the dialog
                                    signOut(); // Your logout method
                                  },
                                ),
                              ],
                            );
                          },
                        );
                      },
                      child: const Text("Logout", style: TextStyle(color: Colors.teal)),
                    )


                  ],
                ),
                const SizedBox(height: 12),
                _selectedTab == 0
                    ? (_isEditMode ? _buildEditProfile() : _buildProfileView())
                    : _buildAddressSection(),

                const SizedBox(height: 12),
                Card(
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          "Notifications",
                          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
                        ),
                        Switch(
                          value: _notificationsEnabled,
                          activeColor: Colors.teal,
                          onChanged: (bool newValue) async {
                            final status = await Permission.notification.status;

                            if (status.isGranted) {
                              setState(() {
                                _notificationsEnabled = newValue;
                              });
                            } else if (status.isDenied) {
                              final result = await Permission.notification.request();
                              if (result.isGranted) {
                                setState(() {
                                  _notificationsEnabled = true;
                                });
                              }
                            } else if (status.isPermanentlyDenied) {
                              showDialog(
                                context: context,
                                builder: (context) => AlertDialog(
                                  backgroundColor: Colors.white,
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                  titlePadding: EdgeInsets.only(top: 20, left: 24, right: 24),
                                  contentPadding: EdgeInsets.only(left: 24, right: 24, top: 14, bottom: 24),
                                  actionsPadding: EdgeInsets.only(right: 16, bottom: 16),
                                  title: const Text(
                                    "Permission Required",
                                    style: TextStyle(fontWeight: FontWeight.bold, color: Colors.teal),
                                  ),
                                  content: const Text("Notifications are permanently denied. Please enable them in app settings."),
                                  actions: [
                                    OutlinedButton(
                                      onPressed: () => Navigator.of(context).pop(),
                                      style: OutlinedButton.styleFrom(
                                        side: BorderSide(color: Colors.grey.shade400),
                                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                                      ),
                                      child: Text("Cancel", style: TextStyle(color: Colors.black)),
                                    ),
                                    ElevatedButton(
                                      onPressed: () {
                                        openAppSettings();
                                        Navigator.of(context).pop();
                                      },
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: Colors.teal,
                                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                                      ),
                                      child: Text("Open Settings", style: TextStyle(color: Colors.white)),
                                    ),
                                  ],
                                ),
                              );
                            }
                          },
                        ),
                      ],
                    ),
                  ),
                ),

              ],
            ),
          ),
        ),
      ),
    );
  }
}