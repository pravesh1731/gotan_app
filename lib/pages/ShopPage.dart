import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../model/cart_item.dart';
import '../model/store.dart';
import '../providers/CartProvider.dart';
import '../providers/WishlistProvider.dart';
import '../theme/app_theme.dart';
import '../utils/launch.dart';
import '../widgets/ui.dart';
import 'ProductDetailScreen.dart';

class ShopScreen extends StatefulWidget {
  final Store store;
  final Future<void> Function() onRefresh;
  final VoidCallback onOpenCart;

  const ShopScreen({super.key, required this.store, required this.onRefresh, required this.onOpenCart});

  @override
  State<ShopScreen> createState() => _ShopScreenState();
}

class _ShopScreenState extends State<ShopScreen> {
  final _searchController = TextEditingController();
  String _query = '';
  String _category = 'All';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  List<Product> get _filtered {
    final q = _query.toLowerCase();
    return widget.store.visibleProducts.where((p) {
      final inCategory = _category == 'All' || p.category == _category;
      final matches = q.isEmpty ||
          p.name.toLowerCase().contains(q) ||
          p.category.toLowerCase().contains(q) ||
          p.description.toLowerCase().contains(q);
      return inCategory && matches;
    }).toList()
      // In-stock first, like a shelf.
      ..sort((a, b) => (b.inStock ? 1 : 0) - (a.inStock ? 1 : 0));
  }

  @override
  Widget build(BuildContext context) {
    final store = widget.store;
    final categories = store.visibleCategories;
    final products = _filtered;
    final cart = context.watch<CartProvider>();
    final cartCount = cart.itemCount(store.shopId);

    return Scaffold(
      body: RefreshIndicator(
        onRefresh: widget.onRefresh,
        child: CustomScrollView(
          slivers: [
            SliverAppBar(
              pinned: true,
              expandedHeight: 168,
              backgroundColor: AppColors.surface,
              surfaceTintColor: Colors.transparent,
              title: Text(store.name),
              actions: [
                if (store.phone.isNotEmpty)
                  IconButton(tooltip: 'Call shop', onPressed: () => callNumber(context, store.phone), icon: const Icon(Icons.call_outlined)),
              ],
              flexibleSpace: FlexibleSpaceBar(
                collapseMode: CollapseMode.pin,
                background: _StoreHeader(store: store),
              ),
            ),
            if (!store.open)
              SliverToBoxAdapter(
                child: Container(
                  margin: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(color: AppColors.errorBg, borderRadius: BorderRadius.circular(AppRadius.md)),
                  child: const Row(
                    children: [
                      Icon(Icons.schedule_rounded, color: AppColors.error, size: 20),
                      SizedBox(width: 8),
                      Expanded(
                        child: Text('This shop is closed right now. You can browse, but ordering is paused.',
                            style: TextStyle(color: AppColors.error, fontWeight: FontWeight.w600, fontSize: 13)),
                      ),
                    ],
                  ),
                ),
              ),
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 14, 16, 4),
                child: TextField(
                  controller: _searchController,
                  onChanged: (v) => setState(() => _query = v.trim()),
                  decoration: InputDecoration(
                    hintText: 'Search in ${store.name}',
                    prefixIcon: const Icon(Icons.search_rounded),
                    suffixIcon: _query.isEmpty
                        ? null
                        : IconButton(
                            icon: const Icon(Icons.close_rounded, size: 20),
                            onPressed: () {
                              _searchController.clear();
                              setState(() => _query = '');
                            },
                          ),
                  ),
                ),
              ),
            ),
            if (categories.isNotEmpty)
              SliverToBoxAdapter(
                child: SizedBox(
                  height: 52,
                  child: ListView(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    children: [
                      for (final name in ['All', ...categories.map((c) => c.name)])
                        Padding(
                          padding: const EdgeInsets.only(right: 8),
                          child: ChoiceChip(
                            label: Text(name),
                            selected: _category == name,
                            showCheckmark: false,
                            onSelected: (_) => setState(() => _category = name),
                            labelStyle: TextStyle(
                              color: _category == name ? AppColors.tealDark : AppColors.textSecondary,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            if (products.isEmpty)
              const SliverToBoxAdapter(
                child: EmptyState(icon: Icons.search_off_rounded, title: 'No products found', message: 'Try another search or category.'),
              )
            else
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 96),
                sliver: SliverGrid(
                  gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                    maxCrossAxisExtent: 220,
                    mainAxisSpacing: 12,
                    crossAxisSpacing: 12,
                    childAspectRatio: 0.62,
                  ),
                  delegate: SliverChildBuilderDelegate(
                    (context, i) => ProductCard(store: store, product: products[i]),
                    childCount: products.length,
                  ),
                ),
              ),
          ],
        ),
      ),
      floatingActionButton: cartCount == 0
          ? null
          : FloatingActionButton.extended(
              onPressed: widget.onOpenCart,
              backgroundColor: AppColors.teal,
              foregroundColor: Colors.white,
              icon: const Icon(Icons.shopping_bag_outlined),
              label: Text('$cartCount item${cartCount == 1 ? '' : 's'} · ${rupees(cart.subtotal(store.shopId))}'),
            ),
    );
  }
}

class _StoreHeader extends StatelessWidget {
  final Store store;
  const _StoreHeader({required this.store});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [AppColors.pastelBlue, AppColors.surface]),
      ),
      padding: EdgeInsets.fromLTRB(16, MediaQuery.of(context).padding.top + kToolbarHeight, 16, 12),
      child: Row(
        children: [
          Container(
            width: 64,
            height: 64,
            padding: const EdgeInsets.all(3),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(AppRadius.lg),
              border: Border.all(color: AppColors.border),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(AppRadius.md),
              child: NetImage(store.logo, fit: BoxFit.contain, fallbackIcon: Icons.storefront_outlined),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    StatusChip(label: store.open ? 'Open now' : 'Closed', tone: store.open ? Tone.success : Tone.error, dense: true),
                    const SizedBox(width: 6),
                    StatusChip(label: 'Delivery ${rupees(store.deliveryFee)}', tone: Tone.info, dense: true),
                  ],
                ),
                if (store.tagline.isNotEmpty) ...[
                  const SizedBox(height: 6),
                  Text(store.tagline, maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(color: AppColors.textSecondary)),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Grid tile with add / quantity controls. Products with variants open the
/// detail screen so the shopper can pick size and colour.
class ProductCard extends StatelessWidget {
  final Store store;
  final Product product;

  const ProductCard({super.key, required this.store, required this.product});

  void _openDetail(BuildContext context) {
    Navigator.push(context, MaterialPageRoute(builder: (_) => ProductDetailScreen(store: store, product: product)));
  }

  @override
  Widget build(BuildContext context) {
    final cart = context.watch<CartProvider>();
    final wishlist = context.watch<WishlistProvider>();
    final qty = product.hasVariants ? 0 : cart.getQuantity(store.shopId, CartItem.keyFor(product.id));
    final inWishlist = wishlist.isInWishlist(product.id);

    return AppCard(
      padding: EdgeInsets.zero,
      onTap: () => _openDetail(context),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Stack(
              children: [
                Positioned.fill(
                  child: Opacity(
                    opacity: product.inStock ? 1 : 0.45,
                    child: NetImage(product.image, fallbackIcon: Icons.shopping_basket_outlined),
                  ),
                ),
                if (product.hasDiscount || product.ribbon.isNotEmpty)
                  Positioned(
                    left: 8,
                    top: 8,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                      decoration: BoxDecoration(color: AppColors.yellow, borderRadius: BorderRadius.circular(4)),
                      child: Text(
                        product.ribbon.isNotEmpty ? product.ribbon : '${product.discountPercent}% OFF',
                        style: const TextStyle(color: AppColors.navy, fontSize: 10, fontWeight: FontWeight.w800),
                      ),
                    ),
                  ),
                Positioned(
                  right: 4,
                  top: 4,
                  child: IconButton(
                    visualDensity: VisualDensity.compact,
                    style: IconButton.styleFrom(backgroundColor: Colors.white.withValues(alpha: 0.9)),
                    onPressed: () => wishlist.toggle(store.shopId, product),
                    icon: Icon(inWishlist ? Icons.favorite : Icons.favorite_border, size: 18, color: inWishlist ? AppColors.error : AppColors.textSecondary),
                  ),
                ),
                if (!product.inStock)
                  const Positioned(
                    left: 0,
                    right: 0,
                    bottom: 8,
                    child: Center(child: StatusChip(label: 'Out of stock', tone: Tone.error, dense: true)),
                  ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(10, 8, 10, 10),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(product.name, maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13, height: 1.25)),
                if (product.unitType.isNotEmpty)
                  Text(product.unitType, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 11, color: AppColors.textSecondary)),
                const SizedBox(height: 6),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(rupees(product.sellingPrice), style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15)),
                          if (product.hasDiscount)
                            Text(
                              rupees(product.price),
                              style: const TextStyle(fontSize: 11, color: AppColors.textSecondary, decoration: TextDecoration.lineThrough),
                            ),
                        ],
                      ),
                    ),
                    if (product.inStock)
                      qty == 0
                          ? _AddButton(onTap: () {
                              if (product.hasVariants) {
                                _openDetail(context);
                              } else {
                                cart.addProduct(store.shopId, product);
                              }
                            })
                          : QtyStepper(
                              qty: qty,
                              compact: true,
                              onMinus: () => cart.decreaseQuantity(store.shopId, CartItem.keyFor(product.id)),
                              onPlus: () {
                                if (!cart.addProduct(store.shopId, product)) {
                                  showAppSnack(context, 'Only ${product.stock} in stock');
                                }
                              },
                            ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _AddButton extends StatelessWidget {
  final VoidCallback onTap;
  const _AddButton({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.surface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.sm), side: const BorderSide(color: AppColors.teal)),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppRadius.sm),
        child: const Padding(
          padding: EdgeInsets.symmetric(horizontal: 14, vertical: 6),
          child: Text('ADD', style: TextStyle(color: AppColors.teal, fontWeight: FontWeight.w800, fontSize: 12)),
        ),
      ),
    );
  }
}

class QtyStepper extends StatelessWidget {
  final int qty;
  final VoidCallback onMinus;
  final VoidCallback onPlus;
  final bool compact;

  const QtyStepper({super.key, required this.qty, required this.onMinus, required this.onPlus, this.compact = false});

  @override
  Widget build(BuildContext context) {
    final pad = compact ? 5.0 : 8.0;
    Widget btn(IconData icon, VoidCallback onTap) => InkWell(
          onTap: onTap,
          child: Padding(padding: EdgeInsets.all(pad), child: Icon(icon, size: compact ? 16 : 18, color: Colors.white)),
        );
    return Container(
      decoration: BoxDecoration(color: AppColors.teal, borderRadius: BorderRadius.circular(AppRadius.sm)),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          btn(Icons.remove_rounded, onMinus),
          ConstrainedBox(
            constraints: BoxConstraints(minWidth: compact ? 18 : 24),
            child: Text('$qty', textAlign: TextAlign.center, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800)),
          ),
          btn(Icons.add_rounded, onPlus),
        ],
      ),
    );
  }
}
