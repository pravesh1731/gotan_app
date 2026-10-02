import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../model/cart_item.dart';
import '../providers/CartProvider.dart';
import '../providers/WishlistProvider.dart';
import 'package:lottie/lottie.dart';

class WishlistScreen extends StatelessWidget {
  final String shopId;

  const WishlistScreen({Key? key, required this.shopId}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // backgroundColor: Colors.white,
      appBar: AppBar(
        automaticallyImplyLeading: false,
        title: const Text('My Wishlist', style: TextStyle( fontSize: 18, fontWeight: FontWeight.bold),),
        // backgroundColor: Colors.white,
        elevation: 0, // no shadow
        shadowColor: Colors.transparent, // remove shadow color entirely
      ),

      body: Consumer2<WishlistProvider, CartProvider>(
        builder: (context, wishlistProvider, cartProvider, _) {
          // Filter out items that are already in the cart for this shop
          final items = wishlistProvider.wishlist.values.where((item) {
            final quantity = cartProvider.getQuantity(shopId, item.id);
            if (quantity > 0) {
              // Remove from wishlist if already in cart
              WidgetsBinding.instance.addPostFrameCallback((_) {
                wishlistProvider.removeFromWishlist(item.id);
              });
              return false;
            }
            return true;
          }).toList();

          if (items.isEmpty) {
            return SizedBox(
              height: MediaQuery.of(context).size.height - 3 * kToolbarHeight,
              child: Center(
                child: SizedBox(
                  height: 200,
                  child: Lottie.asset('assets/animations/empty_tasks.json'),
                ),
              ),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.all(12),
            itemCount: items.length,
            itemBuilder: (context, index) {
              final item = items[index];
              return Card(
                color: Colors.white,
                margin: const EdgeInsets.only(bottom: 12),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10)),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Stack(
                      children: [
                        ClipRRect(
                          borderRadius: const BorderRadius.vertical(
                              top: Radius.circular(10)),
                          child: Image.network(
                            item.imageUrl,
                            height: 130,
                            width: double.infinity,
                            fit: BoxFit.cover,
                          ),
                        ),
                        Positioned(
                          right: 6,
                          top: 6,
                          child: GestureDetector(
                            onTap: () {
                              wishlistProvider.removeFromWishlist(item.id);
                            },
                            child: const Icon(Icons.close, color: Colors.black),
                          ),
                        ),
                      ],
                    ),
                    Padding(
                      padding: const EdgeInsets.all(12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(item.name,
                              style: const TextStyle(fontWeight: FontWeight.bold)),
                          const SizedBox(height: 4),
                          Text('Dairyfarm',
                              style: TextStyle(
                                  color: Colors.grey[600], fontSize: 12)),
                          const SizedBox(height: 4),
                          Row(
                            children: [
                              Text(
                                '₹ ${item.price.toStringAsFixed(0)}',
                                style: const TextStyle(
                                  decoration: TextDecoration.lineThrough,
                                  color: Colors.grey,
                                ),
                              ),
                              const SizedBox(width: 8),
                              Text(
                                '₹ ${item.discountPrice.toStringAsFixed(0)}',
                                style:
                                const TextStyle(fontWeight: FontWeight.bold),
                              ),
                            ],
                          ),
                          const SizedBox(height: 10),
                          SizedBox(
                            width: double.infinity,
                            child: ElevatedButton(
                              onPressed: () {
                                cartProvider.addItem(shopId, {
                                  'productId': item.id,
                                  'productName': item.name,
                                  'productCategory': item.category,
                                  'productImages': [item.imageUrl],
                                  'productPrice': item.price,
                                  'productdiscountPrice': item.discountPrice,
                                  'productUnits': item.units,
                                  'productUnitType': item.unitType,
                                  'productRibbon': item.productRibbon,
                                  'productDescription': item.description,
                                });

                                wishlistProvider.removeFromWishlist(item.id);

                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                      content: Text('Moved to cart')),
                                );
                              },
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.teal,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                padding:
                                const EdgeInsets.symmetric(vertical: 14),
                              ),
                              child: const Text('ADD TO BAG', style: TextStyle(color: Colors.white),),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              );
            },
          );
        },
      ),
    );
  }
}
