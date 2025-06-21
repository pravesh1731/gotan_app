import 'package:flutter/material.dart';
import 'dart:convert'; // For json decoding
import 'package:http/http.dart' as http;

import '../global/common.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  Map<String, dynamic> shopHeader = {};
  Map<String, dynamic>? userData;
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    loadShopHeader();
    fetchUserData();
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

  Future<void> fetchUserData() async {

    final prefs = await SharedPreferences.getInstance();
    final email = prefs.getString('user_email');

    final response = await http.post(
      Uri.parse(Common.digiBaseUrl+"customer/getcustomer"),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        "email": "\"$email\""
      }),
    );


    if (response.statusCode == 200) {
      setState(() {
        userData = json.decode(response.body);
        isLoading = false;
        //back print('-------');
        //back print(userData);
      });
    } else {
      //back print('======');
      //back print('Failed');
      setState(() {
        isLoading = false;
      });
      // Optionally handle error here
    }
  }


  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("My Profile"),
        actions: [
          TextButton(
            onPressed: () {
              // Logout logic
            },
            child: const Text("Logout", style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : userData == null
          ? const Center(child: Text("Failed to load data"))
          : Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                boxShadow: [
                  BoxShadow(
                    blurRadius: 10,
                    color: Colors.black12,
                    offset: Offset(0, 4),
                  )
                ],
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    "MY PROFILE",
                    style: TextStyle(
                        fontWeight: FontWeight.bold, fontSize: 18),
                  ),
                  const Divider(),
                  _buildProfileRow("Full Name", userData?['name']),
                  _buildProfileRow("Mobile Number", userData?['phoneNumber']),
                  _buildProfileRow("Email ID", userData?['email']?.replaceAll('"', '')),
                  _buildProfileRow("Gender", "- not added -"),
                  _buildProfileRow("Date of Birth", "- not added -"),
                  _buildProfileRow("Location", "- not added -"),
                  _buildProfileRow("Alternate Mobile", "- not added -"),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: () {
                      // Navigate to edit screen
                    },
                    style: ElevatedButton.styleFrom(
                        minimumSize: const Size.fromHeight(40),
                        backgroundColor: Colors.teal),
                    child: const Text("Edit"),
                  )
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildProfileRow(String title, String? value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        children: [
          Expanded(flex: 2, child: Text(title, style: const TextStyle(fontWeight: FontWeight.w500))),
          Expanded(
            flex: 3,
            child: Text(value ?? "-"),
          )
        ],
      ),
    );
  }
}
