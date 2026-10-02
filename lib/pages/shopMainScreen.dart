import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/CartProvider.dart';
import '../providers/WishlistProvider.dart'; // Make sure to import your WishlistProvider
import '../testing/CheckoutScreen.dart';
import 'CartScreen.dart';
import 'OrderHistoryPage.dart';
import 'ShopPage.dart';
import 'WishlistScreen.dart';

class ShopMainScreen extends StatefulWidget {
  final String shopId;

  const ShopMainScreen({
    Key? key,
    required this.shopId,
  }) : super(key: key);

  @override
  State<ShopMainScreen> createState() => _ShopMainScreenState();
}

class _ShopMainScreenState extends State<ShopMainScreen> {
  int _currentIndex = 2;
  late List<Widget> _screens;

  @override
  void initState() {
    super.initState();
    _screens = [
  WishlistScreen(shopId: widget.shopId),
  CheckoutScreen(storeId: widget.shopId),
  ShopScreen(shopId: widget.shopId),
  OrderHistoryPage(),
  // GoogleLoginAndProfilePage(),
    ];
  }

  @override
  Widget build(BuildContext context) {
    final cartItemCount = context.watch<CartProvider>().getCart(widget.shopId).length;
    final wishlistItemCount = context.watch<WishlistProvider>().wishlist.length;

    return Scaffold(
      body: _screens[_currentIndex],
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex,
        type: BottomNavigationBarType.fixed,
        selectedItemColor: Colors.blue,
        unselectedItemColor: Colors.grey,
        onTap: (int index) {
          setState(() {
            _currentIndex = index;
          });
        },
        items: [
          BottomNavigationBarItem(
            icon: Stack(
              children: [
                const Icon(Icons.favorite_border),
                if (wishlistItemCount > 0)
                  Positioned(
                    right: 0,
                    top: 0,
                    child: Container(
                      padding: const EdgeInsets.all(2),
                      decoration: BoxDecoration(
                        color: Colors.red,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      constraints: const BoxConstraints(
                        minWidth: 16,
                        minHeight: 16,
                      ),
                      child: Center(
                        child: Text(
                          '$wishlistItemCount',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 8,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
            label: 'Wishlist',
          ),
          BottomNavigationBarItem(
            icon: Stack(
              children: [
                const Icon(Icons.shopping_bag_outlined),
                if (cartItemCount > 0)
                  Positioned(
                    right: 0,
                    top: 0,
                    child: Container(
                      padding: const EdgeInsets.all(2),
                      decoration: BoxDecoration(
                        color: Colors.red,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      constraints: const BoxConstraints(
                        minWidth: 16,
                        minHeight: 16,
                      ),
                      child: Center(
                        child: Text(
                          '$cartItemCount',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 8,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
            label: 'Bag',
          ),
          const BottomNavigationBarItem(
            icon: Icon(Icons.home),
            label: 'Home',
          ),
          const BottomNavigationBarItem(
            icon: Icon(Icons.history),
            label: 'History',
          ),
          const BottomNavigationBarItem(
            icon: Icon(Icons.login),
            label: 'Login',
          ),
        ],
      ),
    );
  }
}