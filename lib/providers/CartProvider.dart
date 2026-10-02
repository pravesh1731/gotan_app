import 'package:flutter/material.dart';
import '../model/cart_item.dart';
import 'package:hive_flutter/hive_flutter.dart';

class CartProvider with ChangeNotifier {
  final Map<String, Map<String, CartItem>> _storeCarts = {};

  Future<void> loadCartFromStorage() async {
    final box = await Hive.openBox<Map>('storeCarts');

    for (var storeId in box.keys) {
      final cartMap = <String, CartItem>{};
      final storedItems = box.get(storeId)!;

      for (var entry in storedItems.entries) {
        cartMap[entry.key] = entry.value as CartItem;
      }

      _storeCarts[storeId] = cartMap;
    }

    notifyListeners();
  }

  Future<void> _saveCartToStorage() async {
    final box = await Hive.openBox<Map>('storeCarts');

    for (var entry in _storeCarts.entries) {
      box.put(entry.key, entry.value);
    }
  }

  void addItem(String storeId, dynamic product) {
    final productId = product['productId'].toString();
    _storeCarts.putIfAbsent(storeId, () => {});
    final storeCart = _storeCarts[storeId]!;

    if (storeCart.containsKey(productId)) {
      if (storeCart[productId]!.quantity < (product['productUnits'] ?? 0)) {
        storeCart[productId]!.quantity++;
      }
    } else {
      storeCart[productId] = CartItem(
        id: productId,
        name: product['productName'] ?? '',
        category: product['productCategory'] ?? '',
        imageUrl: (product['productImages'] as List).isNotEmpty
            ? product['productImages'][0]
            : '',
        price: product['productPrice'] ?? 0,
        discountPrice: product['productdiscountPrice'] ?? 0,
        units: product['productUnits'] ?? 0,
        unitType: product['productUnitType'] ?? '',
        productRibbon: product['productRibbon'] ?? '',
        description: product['productDescription'] ?? '',
      );
    }

    _saveCartToStorage();
    notifyListeners();
  }

  void removeItem(String storeId, String productId) {
    final storeCart = _storeCarts[storeId];
    if (storeCart != null && storeCart.containsKey(productId)) {
      storeCart.remove(productId);
    }

    _saveCartToStorage();
    notifyListeners();
  }

  void decreaseQuantity(String storeId, String productId) {
    final storeCart = _storeCarts[storeId];
    if (storeCart != null && storeCart.containsKey(productId)) {
      final item = storeCart[productId]!;
      item.quantity--;

      if (item.quantity < 1) {
        storeCart.remove(productId);
      }

      _saveCartToStorage();
      notifyListeners();
    }
  }

  Map<String, CartItem> getCart(String storeId) {
    return _storeCarts[storeId] ?? {};
  }

  int getQuantity(String storeId, String productId) {
    final storeCart = _storeCarts[storeId];
    if (storeCart != null && storeCart.containsKey(productId)) {
      return storeCart[productId]!.quantity;
    }
    return 0;
  }

  void updateQuantity(String storeId, String productId, int newQuantity) {
    final storeCart = _storeCarts[storeId];
    if (storeCart != null && storeCart.containsKey(productId)) {
      storeCart[productId]!.quantity = newQuantity;

      _saveCartToStorage();
      notifyListeners();
    }
  }

  void clearCart(String storeId) {
    _storeCarts.remove(storeId);
    _saveCartToStorage();
    notifyListeners();
  }
}
