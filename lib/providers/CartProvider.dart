import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';

import '../model/cart_item.dart';
import '../model/store.dart';

/// One cart per store (`Map<storeId, Map<lineKey, CartItem>>`), persisted to
/// the Hive box `storeCarts`. Digistall rejects orders that mix shops, so carts
/// are never merged.
class CartProvider with ChangeNotifier {
  final Map<String, Map<String, CartItem>> _storeCarts = {};
  Box<Map>? _box;

  Future<Box<Map>> _openBox() async => _box ??= await Hive.openBox<Map>('storeCarts');

  Future<void> loadCartFromStorage() async {
    final box = await _openBox();

    for (final storeId in box.keys) {
      final cartMap = <String, CartItem>{};
      final storedItems = box.get(storeId) ?? const {};

      for (final value in storedItems.values) {
        if (value is! CartItem) continue;
        if (value.storeId.isEmpty) value.storeId = storeId.toString();
        cartMap[value.lineKey] = value;
      }

      if (cartMap.isNotEmpty) _storeCarts[storeId.toString()] = cartMap;
    }

    notifyListeners();
  }

  Future<void> _save(String storeId) async {
    final box = await _openBox();
    final cart = _storeCarts[storeId];
    if (cart == null || cart.isEmpty) {
      _storeCarts.remove(storeId);
      await box.delete(storeId);
    } else {
      await box.put(storeId, Map<String, CartItem>.from(cart));
    }
  }

  Map<String, CartItem> getCart(String storeId) => _storeCarts[storeId] ?? const {};

  int itemCount(String storeId) => getCart(storeId).values.fold(0, (sum, i) => sum + i.quantity);

  num subtotal(String storeId) => getCart(storeId).values.fold<num>(0, (sum, i) => sum + i.lineTotal);

  int getQuantity(String storeId, String lineKey) => getCart(storeId)[lineKey]?.quantity ?? 0;

  /// Adds one unit. Returns false when stock would be exceeded.
  bool addProduct(String storeId, Product product, {String size = '', String color = ''}) {
    final cart = _storeCarts.putIfAbsent(storeId, () => {});
    final key = CartItem.keyFor(product.id, size: size, color: color);
    final stock = product.stockFor(size: size.isEmpty ? null : size, color: color.isEmpty ? null : color);
    final existing = cart[key];

    if (existing != null) {
      existing.units = stock;
      if (existing.quantity >= stock) return false;
      existing.quantity++;
    } else {
      if (stock <= 0) return false;
      cart[key] = CartItem.fromProduct(product, storeId: storeId, size: size, color: color);
    }

    _save(storeId);
    notifyListeners();
    return true;
  }

  /// Returns false when stock would be exceeded.
  bool increaseQuantity(String storeId, String lineKey) {
    final item = _storeCarts[storeId]?[lineKey];
    if (item == null || item.quantity >= item.units) return false;
    item.quantity++;
    _save(storeId);
    notifyListeners();
    return true;
  }

  void decreaseQuantity(String storeId, String lineKey) {
    final cart = _storeCarts[storeId];
    final item = cart?[lineKey];
    if (cart == null || item == null) return;
    item.quantity--;
    if (item.quantity < 1) cart.remove(lineKey);
    _save(storeId);
    notifyListeners();
  }

  void removeItem(String storeId, String lineKey) {
    _storeCarts[storeId]?.remove(lineKey);
    _save(storeId);
    notifyListeners();
  }

  /// Re-checks cart lines against the latest catalog: refreshes prices and
  /// stock, caps quantities and drops products the shop removed or hid.
  /// Returns true if anything changed.
  bool syncWithStore(Store store) {
    final cart = _storeCarts[store.shopId];
    if (cart == null) return false;
    var changed = false;
    for (final key in cart.keys.toList()) {
      final item = cart[key]!;
      final product = store.productById(item.id);
      if (product == null || !product.visible) {
        cart.remove(key);
        changed = true;
        continue;
      }
      final stock = product.stockFor(size: item.size.isEmpty ? null : item.size, color: item.color.isEmpty ? null : item.color);
      if (item.price != product.price || item.discountPrice != product.discountPrice || item.units != stock) {
        item
          ..price = product.price
          ..discountPrice = product.discountPrice
          ..units = stock;
        changed = true;
      }
      if (stock <= 0) {
        cart.remove(key);
        changed = true;
      } else if (item.quantity > stock) {
        item.quantity = stock;
        changed = true;
      }
    }
    if (changed) {
      _save(store.shopId);
      notifyListeners();
    }
    return changed;
  }

  void clearCart(String storeId) {
    _storeCarts.remove(storeId);
    _save(storeId);
    notifyListeners();
  }
}
