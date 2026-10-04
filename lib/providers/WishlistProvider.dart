import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';

import '../model/cart_item.dart';
import '../model/store.dart';

/// Saved products, persisted to the Hive box `wishlist`. Each item remembers
/// its store so it can only be added to that store's cart.
class WishlistProvider with ChangeNotifier {
  final Map<String, CartItem> _wishlist = {};
  Box<CartItem>? _wishlistBox;

  Future<void> init() async {
    _wishlistBox = await Hive.openBox<CartItem>('wishlist');
    _wishlist.clear();
    for (final key in _wishlistBox!.keys) {
      final item = _wishlistBox!.get(key);
      if (item != null) _wishlist[key.toString()] = item;
    }
    notifyListeners();
  }

  Map<String, CartItem> get wishlist => _wishlist;

  List<CartItem> forStore(String storeId) =>
      _wishlist.values.where((i) => i.storeId.isEmpty || i.storeId == storeId).toList();

  bool isInWishlist(String productId) => _wishlist.containsKey(productId);

  void toggle(String storeId, Product product) {
    if (isInWishlist(product.id)) {
      removeFromWishlist(product.id);
    } else {
      addToWishlist(storeId, product);
    }
  }

  void addToWishlist(String storeId, Product product) {
    final box = _wishlistBox;
    if (box == null || !box.isOpen || _wishlist.containsKey(product.id)) return;
    final item = CartItem.fromProduct(product, storeId: storeId);
    _wishlist[product.id] = item;
    box.put(product.id, item);
    notifyListeners();
  }

  void removeFromWishlist(String productId) {
    final box = _wishlistBox;
    if (box == null || !box.isOpen) return;
    _wishlist.remove(productId);
    box.delete(productId);
    notifyListeners();
  }
}
