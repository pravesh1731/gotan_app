import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:gotan/global/common.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;

import '../services/notification_service.dart';

class GoogleSignInHelper {
  static final GoogleSignIn _googleSignIn = GoogleSignIn();
  static final FirebaseAuth _auth = FirebaseAuth.instance;

  static Future<User?> signInWithGoogle(BuildContext context) async {
    try {
      // Sign out from previous sessions
      await _googleSignIn.signOut();
      await _auth.signOut();

      // Trigger Google Sign In flow
      final GoogleSignInAccount? googleUser = await _googleSignIn.signIn();
      if (googleUser == null) return null;

      // Get authentication tokens
      final GoogleSignInAuthentication googleAuth =
      await googleUser.authentication;

      // Create Firebase credential
      final credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );

      // Sign in to Firebase
      final UserCredential userCredential =
      await _auth.signInWithCredential(credential);

      // Store user email
      if (userCredential.user?.email != null) {
        final String email = userCredential.user!.email!;
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('user_email', userCredential.user!.email!);
        await NotificationService().resetFcmToken(); // Ensure a fresh token
        final updatedPrefs = await SharedPreferences.getInstance();
        final deviceToken = updatedPrefs.getString('deviceToken');
        print(deviceToken);
        try {
          final initialResponse = await http.post(
            Uri.parse(Common.digiBaseUrl + "customer/verifyotpnew"),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({"email": "\"$email\"", "deviceToken": deviceToken}),
          );

          if (initialResponse.statusCode == 200) {
            // Only proceed to fetch user data if the first API call succeeds
            // await fetchUserData(email);
            return userCredential.user;
          } else {
          }
        } on Exception catch (e) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Someting went wrong')),
          );
        }
      }


      return userCredential.user;
    } catch (e) {
      debugPrint("Google sign in error: $e");
      return null;
    }
  }

  static Future<void> signOut() async {
    await _googleSignIn.signOut();
    await _auth.signOut();
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('user_email');
  }
}

class GoogleSignInScreen extends StatelessWidget {
  const GoogleSignInScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
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
                  final user = await GoogleSignInHelper.signInWithGoogle(context);
                  if (user != null) {
                    Navigator.pop(context, user); // Return user data to caller
                  }
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
          ],
        ),
      ),
    );
  }
}