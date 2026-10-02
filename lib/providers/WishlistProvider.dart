import 'package:flutter/material.dart';
import '../model/cart_item.dart';
import 'package:hive_flutter/hive_flutter.dart';

class WishlistProvider with ChangeNotifier {
  late Map<String, CartItem> _wishlist;
  late Box<CartItem> _wishlistBox;

  Future<void> init() async {
    _wishlistBox = await Hive.openBox<CartItem>('wishlist');
    _wishlist = {};

    for (var key in _wishlistBox.keys) {
      _wishlist[key] = _wishlistBox.get(key)!;
    }

    notifyListeners();
  }

  void addToWishlist(Map<String, dynamic> product) {
    if (!_wishlistBox.isOpen) {
      debugPrint('Wishlist box is not open!');
      return;
    }

    final productId = product['productId'].toString();
    if (_wishlist.containsKey(productId)) return;

    final cartItem = CartItem(
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

    _wishlist[productId] = cartItem;
    _wishlistBox.put(productId, cartItem);
    notifyListeners();
  }

  void removeFromWishlist(String productId) {
    if (!_wishlistBox.isOpen) {
      debugPrint('Wishlist box is not open!');
      return;
    }

    _wishlist.remove(productId);
    _wishlistBox.delete(productId);
    notifyListeners();
  }


  Map<String, CartItem> get wishlist => _wishlist;
  bool isInWishlist(String productId) => _wishlist.containsKey(productId);
}
