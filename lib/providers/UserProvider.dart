// lib/providers/UserProvider.dart
import 'package:flutter/foundation.dart';

import '../global/common.dart';
import '../services/api.dart';
import '../services/session.dart';

class UserProvider with ChangeNotifier {
  String _name = 'Customer';
  String _phone = Common.guestPhone;
  String _city = Common.cityName;
  String _otp = '';
  String _profileImage = '';

  String get name => _name;
  String get phone => _phone;
  String get city => _city;

  /// 4-digit code the rider asks for before starting a ride or parcel trip.
  String get otp => _otp;
  String get profileImage => _profileImage;
  bool get isLoggedIn => _phone != Common.guestPhone && _phone.isNotEmpty;

  void updateName(String newName) {
    _name = newName;
    notifyListeners();
  }

  void updatePhone(String newPhone) {
    _phone = newPhone;
    notifyListeners();
  }

  void loadFromPrefs(String name, String phone) {
    _name = name;
    _phone = phone;
    notifyListeners();
  }

  Future<void> load() async {
    final p = await Session.prefs;
    _phone = p.getString(Session.kPhone) ?? Common.guestPhone;
    _name = p.getString(Session.kName) ?? 'Customer';
    _city = p.getString(Session.kCity) ?? Common.cityName;
    _otp = p.getString(Session.kOtp) ?? '';
    _profileImage = p.getString(Session.kProfileImage) ?? '';
    notifyListeners();
  }

  /// Pulls the latest profile (name, ride OTP, photo) from gotanbackend.
  Future<UserProfile?> refresh() async {
    if (!isLoggedIn) return null;
    final profile = await Api.getUser(_phone);
    await applyProfile(_phone, profile);
    return profile;
  }

  Future<void> applyProfile(String phone, UserProfile profile) async {
    final name = profile.needsName ? 'Customer' : profile.name;
    await Session.saveUser(
      phone: phone,
      name: name,
      city: profile.cityName,
      otp: profile.userOtp,
      profileImage: profile.profileImage,
    );
    _phone = phone;
    _name = name;
    _city = profile.cityName.isEmpty ? Common.cityName : profile.cityName;
    _otp = profile.userOtp;
    _profileImage = profile.profileImage;
    notifyListeners();
  }

  Future<void> setProfileImage(String url) async {
    _profileImage = url;
    (await Session.prefs).setString(Session.kProfileImage, url);
    notifyListeners();
  }

  Future<void> logout() async {
    await Session.logout();
    _name = 'Customer';
    _phone = Common.guestPhone;
    _city = Common.cityName;
    _otp = '';
    _profileImage = '';
    notifyListeners();
  }
}
