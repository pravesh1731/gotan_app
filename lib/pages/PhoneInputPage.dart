import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:gotan/global/common.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:provider/provider.dart';

import '../providers/UserProvider.dart';
import 'OTPVerificationPage.dart';
import 'HomePage.dart';

class PhoneInputPage extends StatefulWidget {
  @override
  _PhoneInputPageState createState() => _PhoneInputPageState();
}

class _PhoneInputPageState extends State<PhoneInputPage> {
  bool isLoading = false;
  bool showPasswordField = false;
  String countryCode = '+91';
  TextEditingController phoneController = TextEditingController();
  TextEditingController passwordController = TextEditingController();

  Future<void> loginWithPassword() async {

    final phone = phoneController.text.trim();
    final password = passwordController.text.trim();

    if (phone.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Please enter your phone number")),
      );
      return;
    }
    if (password.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Please enter your password")),
      );
      return;
    }

    setState(() {
      isLoading = true;
    });

    final loginUrl = Uri.parse(Common.baseUrl+"api/auth/loginuserwithpassword"); // 🔁 Replace
    final secondApiUrl = Uri.parse(Common.baseUrl+"api/user/getuser"); // 🔁 Replace

    try {
      // 🔐 1st API: Password Login
      final loginResponse = await http.post(
        loginUrl,
        headers: {"Content-Type": "application/json"},
        body: jsonEncode({
          "phoneNumber": phone,
          "password": password,
        }),
      );

      if (loginResponse.statusCode == 200) {
        // ✅ 2nd API: Fetch user details
        final secondResponse = await http.post(
          secondApiUrl,
          headers: {"Content-Type": "application/json"},
          body: jsonEncode({"phoneNumber": phone}),
        );

        setState(() {
          isLoading = false;
        });

        if (secondResponse.statusCode == 200) {
          final data = jsonDecode(secondResponse.body);

          // 🧠 Save to SharedPreferences
          final prefs = await SharedPreferences.getInstance();
          await prefs.setString("gotan_name", data["name"]);
          await prefs.setString("gotan_city", data["cityName"]);
          await prefs.setString("gotan_userOtp", data["userOtp"]);
          await prefs.setString("gotan_phone_number", phone);

          final userProvider = Provider.of<UserProvider>(context, listen: false);
          userProvider.loadFromPrefs(
            prefs.getString('gotan_name') ?? "Customer",
            prefs.getString('gotan_phone_number') ?? "0000000000",
          );



          // ✅ Navigate to HomePage
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (context) => HomePage()),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text("Failed to fetch user details")),
          );
        }
      } else {
        setState(() {
          isLoading = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Login failed. Please check credentials.")),
        );
      }
    } catch (e) {
      setState(() {
        isLoading = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Error: ${e.toString()}")),
      );
    }
  }


  // 🔐 OTP-based Firebase login
  Future<void> sendOTP() async {


    final phone = phoneController.text.trim();

    if (phone.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Please enter your phone number")),
      );
      return;
    }



    setState(() {
      isLoading = true;
    });

    try {

      await FirebaseAuth.instance.signOut(); // 💡 Important fix

      await FirebaseAuth.instance.verifyPhoneNumber(
        phoneNumber: '$countryCode${phone.trim()}',
        verificationCompleted: (PhoneAuthCredential credential) async {
          // await FirebaseAuth.instance.signInWithCredential(credential);
        },
        verificationFailed: (FirebaseAuthException e) {
          setState(() {
            isLoading = false;
          });
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text("Error: ${e.message}")),
          );
        },
        codeSent: (String verId, int? resendToken) {
          setState(() {
            isLoading = false;
          });
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => OTPVerificationPage(verificationId: verId),
            ),
          );
        },
        codeAutoRetrievalTimeout: (String verId) {
          setState(() {
            isLoading = false;
          });
        },
      );
    } catch (e) {
      setState(() {
        isLoading = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Failed to send OTP.")),
      );
    }
  }

  Future<void> skipLogin() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('skip', 'skipped');
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (context) => HomePage()),
    );
  }

  // ... (keep all your existing methods: loginWithPassword, sendOTP, etc.)

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xfff9fafc),
      body: SafeArea(
        child: Stack(
          children: [
            // Main centered content
            Center(
              child: SingleChildScrollView(
                child: Padding(
                  padding: const EdgeInsets.all(24.0),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        "Get Started",
                        style: TextStyle(fontSize: 28, fontWeight: FontWeight.w800),
                      ),
                      const SizedBox(height: 30),
                      Row(
                        children: [
                          Container(
                            width: 40,
                            alignment: Alignment.center,
                            child: Image.asset('assets/images/india.png', width: 24),
                          ),
                          Expanded(
                            child: TextField(
                              controller: phoneController,
                              maxLength: 10,
                              keyboardType: TextInputType.phone,
                              decoration: InputDecoration(
                                hintText: "10 digit phone number",
                                counterText: "",
                                filled: true,
                                fillColor: Colors.white,
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(10),
                                  borderSide: BorderSide.none,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                      if (showPasswordField) ...[
                        const SizedBox(height: 16),
                        TextField(
                          controller: passwordController,
                          obscureText: true,
                          decoration: InputDecoration(
                            hintText: "Enter password",
                            filled: true,
                            fillColor: Colors.white,
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(10),
                              borderSide: BorderSide.none,
                            ),
                          ),
                        ),
                      ],
                      const SizedBox(height: 20),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          onPressed: isLoading
                              ? null
                              : () {
                            if (showPasswordField) {
                              loginWithPassword();
                            } else {
                              sendOTP();
                            }
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.black,
                            padding: EdgeInsets.symmetric(horizontal: 40, vertical: 16),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                          child: isLoading
                              ? SizedBox(
                            width: 22,
                            height: 22,
                            child: CircularProgressIndicator(
                              color: Colors.white,
                              strokeWidth: 2.5,
                            ),
                          )
                              : Text(
                            showPasswordField ? "Login" : "Send OTP",
                            style: TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold),
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      TextButton(
                        onPressed: () {
                          setState(() {
                            showPasswordField = !showPasswordField;
                          });
                        },
                        child: Text(
                          showPasswordField ? "Login with OTP?" : "Login with Password",
                          style: TextStyle(
                            color: Colors.grey.shade600,
                            fontWeight: FontWeight.w400,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),

            // Skip button positioned in bottom-right
            Positioned(
              bottom: 24,
              right: 24,
              child: ElevatedButton(
                onPressed: skipLogin,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.black,
                  padding: EdgeInsets.symmetric(horizontal: 40, vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                child: Text(
                  "Skip",
                  style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}