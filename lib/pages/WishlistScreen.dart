import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../model/store.dart';
import '../providers/CartProvider.dart';
import '../providers/WishlistProvider.dart';
import '../theme/app_theme.dart';
import '../widgets/ui.dart';
import 'ProductDetailScreen.dart';

class WishlistScreen extends StatelessWidget {
  final Store store;
  final VoidCallback onOpenShop;

  const WishlistScreen({super.key, required this.store, required this.onOpenShop});

  @override
  Widget build(BuildContext context) {
    final wishlist = context.watch<WishlistProvider>();
    // Only items from this shop can be ordered here; match against the live catalog.
    final items = wishlist
        .forStore(store.shopId)
        .map((i) => (item: i, product: store.productById(i.id)))
        .where((e) => e.product != null)
        .toList();

    return Scaffold(
      appBar: AppBar(title: const Text('Wishlist'), automaticallyImplyLeading: false),
      body: items.isEmpty
          ? EmptyState(
              icon: Icons.favorite_border_rounded,
              title: 'Your wishlist is empty',
              message: 'Tap the heart on a product to save it for later.',
              actionLabel: 'Browse products',
              onAction: onOpenShop,
            )
          : ListView.separated(
              padding: const EdgeInsets.all(16),
              itemCount: items.length,
              separatorBuilder: (_, __) => const SizedBox(height: 10),
              itemBuilder: (context, i) {
                final product = items[i].product!;
                return AppCard(
                  padding: const EdgeInsets.all(10),
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => ProductDetailScreen(store: store, product: product)),
                  ),
                  child: Row(
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(AppRadius.md),
                        child: SizedBox(width: 72, height: 72, child: NetImage(product.image, fallbackIcon: Icons.shopping_basket_outlined)),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(product.name, maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w600)),
                            const SizedBox(height: 4),
                            Text(rupees(product.sellingPrice), style: const TextStyle(fontWeight: FontWeight.w800)),
                            if (!product.inStock)
                              const Padding(
                                padding: EdgeInsets.only(top: 4),
                                child: StatusChip(label: 'Out of stock', tone: Tone.error, dense: true),
                              ),
                          ],
                        ),
                      ),
                      Column(
                        children: [
                          IconButton(
                            tooltip: 'Remove',
                            onPressed: () => wishlist.removeFromWishlist(product.id),
                            icon: const Icon(Icons.delete_outline_rounded, color: AppColors.textSecondary),
                          ),
                          if (product.inStock)
                            IconButton.filledTonal(
                              tooltip: 'Move to cart',
                              onPressed: () {
                                if (product.hasVariants) {
                                  Navigator.push(context,
                                      MaterialPageRoute(builder: (_) => ProductDetailScreen(store: store, product: product)));
                                  return;
                                }
                                context.read<CartProvider>().addProduct(store.shopId, product);
                                wishlist.removeFromWishlist(product.id);
                                showAppSnack(context, 'Moved to cart');
                              },
                              icon: const Icon(Icons.add_shopping_cart_rounded, color: AppColors.teal),
                            ),
                        ],
                      ),
                    ],
                  ),
                );
              },
            ),
    );
  }
}
