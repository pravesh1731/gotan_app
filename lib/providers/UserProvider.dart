// lib/providers/UserProvider.dart
import 'package:flutter/foundation.dart';

class UserProvider with ChangeNotifier {
  String _name = 'Customer';
  String _phone = '0000000000';

  String get name => _name;
  String get phone => _phone;

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
}