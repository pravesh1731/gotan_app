import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:gotan/global/common.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;
import 'package:provider/provider.dart';

import '../providers/UserProvider.dart';
import 'PhoneInputPage.dart';

class MyProfileScreen extends StatefulWidget {
  @override
  State<MyProfileScreen> createState() => _MyProfileScreenState();
}

class _MyProfileScreenState extends State<MyProfileScreen> {
  String userName = "Customer";
  String phone = "0000000000";
  String otp = "---";
  File? _avatarImage;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      loadProfileData();
    });
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
      otp = prefs.getString('gotan_userOtp') ?? "---";
      String? imagePath = prefs.getString('avatar_path');
      if (imagePath != null && File(imagePath).existsSync()) {
        _avatarImage = File(imagePath);
      }
    });
  }

  Future<void> saveProfileImage(XFile image) async {
    final directory = await getApplicationDocumentsDirectory();
    final path = "${directory.path}/profile_avatar.png";
    await image.saveTo(path);

    SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.setString('avatar_path', path); // ✅ await added
    setState(() {
      _avatarImage = File(path);
    });
  }

  Future<void> showChangeNameDialog() async {
    final controller = TextEditingController();
    final screenWidth = MediaQuery.of(context).size.width;
    final userProvider = Provider.of<UserProvider>(context, listen: false);

    await showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        titlePadding: EdgeInsets.only(top: 20, left: 24, right: 24),
        contentPadding: EdgeInsets.only(left: 24, right: 24, top: 24, bottom: 24),
        actionsPadding: EdgeInsets.only(right: 16, bottom: 16),
        title: Text(
          "Change Your Name",
          style: TextStyle(fontWeight: FontWeight.w600),
        ),
        content: SizedBox(
          width: screenWidth * 0.9, // ⬅️ 90% of screen width
          child: TextField(
            controller: controller,
            decoration: InputDecoration(
              hintText: "Enter new name",
              filled: true,
              fillColor: Colors.grey.shade100,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: BorderSide(color: Colors.grey.shade300),
              ),
              contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 14),
            ),
          ),
        ),
        actions: [
          OutlinedButton(
            onPressed: () => Navigator.pop(context),
            style: OutlinedButton.styleFrom(
              side: BorderSide(color: Colors.grey.shade400),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(6),
              ),
            ),
            child: Text("Cancel", style: TextStyle(color: Colors.black)),
          ),
          ElevatedButton(
            onPressed: () async {
              final newName = controller.text.trim();
              if (newName.isEmpty) return;

              final response = await http.post(
                Uri.parse(Common.baseUrl + "api/auth/newname"),
                headers: {'Content-Type': 'application/json'},
                body: jsonEncode({"name": newName, "phoneNumber": phone}),
              );

              if (response.statusCode == 200) {
                SharedPreferences prefs = await SharedPreferences.getInstance();
                await prefs.setString('gotan_name', newName);

                userProvider.updateName(newName);
                setState(() {
                  userName = newName;
                });
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text("Name updated successfully"),
                    backgroundColor: Colors.green,
                  ),
                );
                Navigator.pop(context);
              } else {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text("Update failed"),
                    backgroundColor: Colors.red,
                  ),
                );
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Color(0xFF2563EB), // blue-600
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(6),
              ),
            ),
            child: Text("Save", style: TextStyle(color: Colors.white),),
          ),
        ],
      ),
    );
  }



  Future<void> logout() async {
    final screenWidth = MediaQuery.of(context).size.width;
    await showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        titlePadding: EdgeInsets.only(top: 20, left: 24, right: 24),
        contentPadding: EdgeInsets.only(left: 24, right: 24, top: 24, bottom: 24),
        actionsPadding: EdgeInsets.only(right: 16, bottom: 16),
        title: Text(
          "Confirm Logout",
          style: TextStyle(fontWeight: FontWeight.w600),
        ),
        content: SizedBox(
          width: screenWidth * 0.9, // ⬅️ 90% of screen width
          child: Text("Are you sure you want to logout?"),
        ),
        actions: [
          OutlinedButton(
            onPressed: () => Navigator.pop(context),
            style: OutlinedButton.styleFrom(
              side: BorderSide(color: Colors.grey.shade400),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(6),
              ),
            ),
            child: Text("Cancel", style: TextStyle(color: Colors.black)),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.of(context).pop(); // Close the dialog
              SharedPreferences prefs = await SharedPreferences.getInstance();
              await prefs.clear();
              Navigator.pushAndRemoveUntil(
                context,
                MaterialPageRoute(builder: (_) => PhoneInputPage()),
                    (route) => false,
              ); // Your logout method
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Color(0xFF2563EB), // blue-600
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(6),
              ),
            ),
            child: Text("Logout", style: TextStyle(color: Colors.white),),
          ),
        ],
      ),
    );
  }

  Future<void> pickImage() async {
    final picker = ImagePicker();
    final XFile? pickedImage =
    await picker.pickImage(source: ImageSource.gallery);

    if (pickedImage != null) {
      await saveProfileImage(pickedImage);
    }
  }

  Future<void> showAddPasswordDialog() async {
    final passwordController = TextEditingController();
    final screenWidth = MediaQuery.of(context).size.width;

    await showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        titlePadding: EdgeInsets.only(top: 20, left: 24, right: 24),
        contentPadding: EdgeInsets.only(left: 24, right: 24, top: 24, bottom: 24),
        actionsPadding: EdgeInsets.only(right: 16, bottom: 16),
        title: Text(
          "Set Password",
          style: TextStyle(fontWeight: FontWeight.w600),
        ),
        content: SizedBox(
          width: screenWidth * 0.9,
          child: TextField(
            controller: passwordController,
            obscureText: true,
            decoration: InputDecoration(
              hintText: "Enter new password",
              filled: true,
              fillColor: Colors.grey.shade100,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: BorderSide(color: Colors.grey.shade300),
              ),
              contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 14),
            ),
          ),
        ),
        actions: [
          OutlinedButton(
            onPressed: () => Navigator.pop(context),
            style: OutlinedButton.styleFrom(
              side: BorderSide(color: Colors.grey.shade400),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(6),
              ),
            ),
            child: Text("Cancel", style: TextStyle(color: Colors.black)),
          ),
          ElevatedButton(
            onPressed: () async {
              final password = passwordController.text.trim();
              if (password.isEmpty) return;

              final response = await http.post(
                Uri.parse(Common.baseUrl+"api/auth/adduserpassword"),
                headers: {'Content-Type': 'application/json'},
                body: jsonEncode({
                  "phoneNumber": phone,
                  "password": password,
                }),
              );

              if (response.statusCode == 200) {
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text("Password added successfully"),
                    backgroundColor: Colors.green,
                  ),
                );
              } else {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text("Failed to add password"),
                    backgroundColor: Colors.red,
                  ),
                );
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Color(0xFF2563EB),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(6),
              ),
            ),
            child: Text("Confirm", style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }


  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle(
        statusBarColor: Colors.white, // or any background
        statusBarIconBrightness: Brightness.dark, // for iOS
      ),
      child: Scaffold(
        backgroundColor: Colors.white.withOpacity(0.95),
        appBar: AppBar(
          backgroundColor: Colors.white,
          elevation: 0,
          title: Text('My Profile',
              style: TextStyle(
                  color: Colors.blue[800], fontWeight: FontWeight.bold)),
          centerTitle: true,
          leading: IconButton(
            icon: Icon(Icons.arrow_back_ios_new, color: Colors.black87),
            onPressed: () => Navigator.pop(context),
          ),
        ),
        body: SingleChildScrollView(
          child: Column(
            children: [
              _buildHeaderCard(),
              _buildSettingsSection(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeaderCard() {
    return Padding(
      padding: const EdgeInsets.only(top: 16, right: 16, left: 16),
      child: Card(
        elevation: 6,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            Column(
              children: [
                Container(
                  height: 100,
                  decoration: BoxDecoration(
                    color: Colors.blue,
                    borderRadius:
                    BorderRadius.vertical(top: Radius.circular(16)),
                  ),
                ),
                Container(
                  width: double.infinity,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius:
                    BorderRadius.vertical(bottom: Radius.circular(16)),
                  ),
                  child: Column(
                    children: [
                      SizedBox(height: 60),
                      Text(userName,
                          style: TextStyle(
                              fontWeight: FontWeight.bold, fontSize: 18)),
                      SizedBox(height: 4),
                      Text("+91 $phone",
                          style: TextStyle(color: Colors.grey[700])),
                      SizedBox(height: 12),
                      Container(
                        padding:
                        EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                        decoration: BoxDecoration(
                          color: Colors.grey[100],
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text('OTP: $otp',
                            style: TextStyle(
                                color: Colors.black87,
                                fontWeight: FontWeight.w500)),
                      ),
                      SizedBox(height: 16),
                    ],
                  ),
                ),
              ],
            ),
            Positioned(
              top: 55,
              left: 0,
              right: 0,
              child: Center(
                child: Stack(
                  clipBehavior: Clip.none,
                  children: [
                    CircleAvatar(
                      radius: 45,
                      backgroundColor: Colors.white,
                      backgroundImage:
                      _avatarImage != null ? FileImage(_avatarImage!) : null,
                      child: _avatarImage == null
                          ? Icon(Icons.person, size: 42, color: Colors.grey)
                          : null,
                    ),
                    Positioned(
                      bottom: 0,
                      right: 0,
                      child: GestureDetector(
                        onTap: pickImage,
                        child: CircleAvatar(
                          radius: 16,
                          backgroundColor: Colors.blue,
                          child: Icon(Icons.camera_alt,
                              size: 14, color: Colors.white),
                        ),
                      ),
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

  Widget _buildSettingsSection() {
    final settings = [
      {
        'icon': Icons.edit,
        'label': 'Change Name',
        'onTap': showChangeNameDialog,
        'color': Colors.blue,
      },
      {
        'icon': Icons.lock,
        'label': 'Add Password',
        'onTap': showAddPasswordDialog,
        'color': Colors.blue,
      },
      {
        'icon': Icons.logout,
        'label': 'Logout',
        'onTap': logout,
        'color': Colors.blue,
      },
    ];

    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Card(
        elevation: 6,
        child: Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
          ),
          child: Column(
            children: [
              const SizedBox(height: 10),
              Container(
                padding: const EdgeInsets.only(left: 16),
                alignment: AlignmentDirectional.centerStart,
                child: const Text(
                  'Settings',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
              ),
              ...settings.map((item) => ListTile(
                leading: Icon(item['icon'] as IconData,
                    color: item['color'] as Color? ?? Colors.blue),
                title: Text(
                  item['label'] as String,
                  style: TextStyle(
                      color: Colors.black),
                ),
                trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                onTap: item['onTap'] as void Function()?,
              )),
            ],
          ),
        ),
      ),
    );
  }
}
