import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../global/common.dart';

/// SharedPreferences keys and helpers for the logged-in user. The backend has
/// no auth token: the phone number identifies the user in every request.
class Session {
  static const kPhone = 'gotan_phone_number';
  static const kName = 'gotan_name';
  static const kCity = 'gotan_city';
  static const kOtp = 'gotan_userOtp';
  static const kProfileImage = 'gotan_profileImage';
  static const kRideOrderId = 'gotan_orderId';
  static const kParcelOrderId = 'gotan_parcelOrderId';
  static const kShopOrderIds = 'gotan_shopOrderIds';
  static const kAddresses = 'saved_addresses';
  static const kSkip = 'skip';
  static const kDeviceToken = 'deviceToken';

  static Future<SharedPreferences> get prefs => SharedPreferences.getInstance();

  static Future<String?> phone() async {
    final p = (await prefs).getString(kPhone);
    return (p == null || p.isEmpty || p == Common.guestPhone) ? null : p;
  }

  static Future<String?> deviceToken() async {
    final t = (await prefs).getString(kDeviceToken);
    return (t == null || t.isEmpty) ? null : t;
  }

  static Future<String> city() async {
    final c = (await prefs).getString(kCity);
    return (c == null || c.isEmpty) ? Common.cityName : c;
  }

  static Future<void> saveUser({
    required String phone,
    String? name,
    String? city,
    String? otp,
    String? profileImage,
  }) async {
    final p = await prefs;
    await p.setString(kPhone, phone);
    if (name != null) await p.setString(kName, name);
    if (city != null && city.isNotEmpty) await p.setString(kCity, city);
    if (otp != null) await p.setString(kOtp, otp);
    if (profileImage != null) await p.setString(kProfileImage, profileImage);
    await p.remove(kSkip);
  }

  static Future<void> skipLogin() async => (await prefs).setString(kSkip, 'skipped');

  /// Clears everything tied to the user but keeps the FCM token, which belongs
  /// to the device and is sent with the next login.
  static Future<void> logout() async {
    final p = await prefs;
    final token = p.getString(kDeviceToken);
    await p.clear();
    if (token != null) await p.setString(kDeviceToken, token);
  }

  static Future<String?> activeOrderId({required bool ride}) async {
    final id = (await prefs).getString(ride ? kRideOrderId : kParcelOrderId);
    return (id == null || id.isEmpty) ? null : id;
  }

  static Future<void> setActiveOrderId(String orderId, {required bool ride}) async =>
      (await prefs).setString(ride ? kRideOrderId : kParcelOrderId, orderId);

  static Future<void> clearActiveOrderId({required bool ride}) async =>
      (await prefs).remove(ride ? kRideOrderId : kParcelOrderId);

  /// Digistall order ids placed from this device. Sent to `customer/getorders`
  /// so orders show up even if the delivery address used another phone number.
  static Future<List<String>> shopOrderIds() async => (await prefs).getStringList(kShopOrderIds) ?? [];

  static Future<void> addShopOrderId(String orderId) async {
    final p = await prefs;
    final ids = p.getStringList(kShopOrderIds) ?? [];
    if (!ids.contains(orderId)) {
      ids.insert(0, orderId);
      await p.setStringList(kShopOrderIds, ids.take(100).toList());
    }
  }

  static Future<List<Map<String, dynamic>>> addresses() async {
    final list = (await prefs).getStringList(kAddresses) ?? [];
    final result = <Map<String, dynamic>>[];
    for (final s in list) {
      try {
        final decoded = jsonDecode(s);
        if (decoded is Map) result.add(decoded.cast<String, dynamic>());
      } catch (_) {
        // Skip entries written by older builds in another format.
      }
    }
    return result;
  }

  static Future<void> saveAddresses(List<Map<String, dynamic>> addresses) async =>
      (await prefs).setStringList(kAddresses, addresses.map(jsonEncode).toList());
}
