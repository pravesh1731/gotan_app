import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../global/common.dart';
import '../model/store.dart';
import '../providers/CartProvider.dart';
import '../providers/WishlistProvider.dart';
import '../services/api.dart';
import '../theme/app_theme.dart';
import '../utils/launch.dart';
import '../widgets/ui.dart';
import 'CartScreen.dart';
import 'OrderHistoryPage.dart';
import 'ShopPage.dart';
import 'WishlistScreen.dart';

/// Store shell with Shop / Wishlist / Cart / Orders tabs. The catalog comes
/// from the Digistall backend and is loaded once here for all tabs.
class ShopMainScreen extends StatefulWidget {
  final String shopId;
  final String shopName;
  final String shopImage;

  const ShopMainScreen({super.key, required this.shopId, this.shopName = '', this.shopImage = ''});

  @override
  State<ShopMainScreen> createState() => _ShopMainScreenState();
}

class _ShopMainScreenState extends State<ShopMainScreen> {
  static const shopTab = 0, cartTab = 2, ordersTab = 3;

  int _currentIndex = shopTab;
  Store? _store;
  bool _loading = true;
  String? _error;
  final _ordersKey = GlobalKey<OrderHistoryPageState>();

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final store = await Api.getStore(widget.shopId);
      if (!mounted) return;
      setState(() {
        _store = store;
        _loading = false;
      });
      if (store != null && context.read<CartProvider>().syncWithStore(store)) {
        showAppSnack(context, 'Your cart was updated with the latest prices and stock');
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = e.toString();
      });
    }
  }

  void _goTo(int index) {
    setState(() => _currentIndex = index);
    if (index == ordersTab) _ordersKey.currentState?.refresh();
  }

  @override
  Widget build(BuildContext context) {
    final title = _store?.name ?? (widget.shopName.isNotEmpty ? widget.shopName : widget.shopId);

    if (_loading) {
      return Scaffold(appBar: AppBar(title: Text(title)), body: const Center(child: CircularProgressIndicator()));
    }
    if (_error != null) {
      return Scaffold(
        appBar: AppBar(title: Text(title)),
        body: EmptyState(
          icon: Icons.wifi_off_rounded,
          title: 'Could not load this shop',
          message: _error,
          actionLabel: 'Retry',
          onAction: _load,
        ),
      );
    }

    final store = _store;
    if (store == null || store.visibleProducts.isEmpty) {
      return _NoCatalog(shopId: widget.shopId, title: title, image: widget.shopImage, store: store, onRetry: _load);
    }

    final cartCount = context.watch<CartProvider>().itemCount(store.shopId);
    final wishCount = context.watch<WishlistProvider>().forStore(store.shopId).length;

    return Scaffold(
      body: IndexedStack(
        index: _currentIndex,
        children: [
          ShopScreen(store: store, onRefresh: _load, onOpenCart: () => _goTo(cartTab)),
          WishlistScreen(store: store, onOpenShop: () => _goTo(shopTab)),
          CartScreen(store: store, onOpenShop: () => _goTo(shopTab), onOrderPlaced: () => _goTo(ordersTab)),
          OrderHistoryPage(key: _ordersKey, shopId: store.shopId, embedded: true),
        ],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _currentIndex,
        onDestinationSelected: _goTo,
        backgroundColor: AppColors.surface,
        indicatorColor: AppColors.tealLight,
        surfaceTintColor: Colors.transparent,
        height: 66,
        destinations: [
          const NavigationDestination(
            icon: Icon(Icons.storefront_outlined),
            selectedIcon: Icon(Icons.storefront, color: AppColors.teal),
            label: 'Shop',
          ),
          NavigationDestination(
            icon: Badge(isLabelVisible: wishCount > 0, label: Text('$wishCount'), child: const Icon(Icons.favorite_border)),
            selectedIcon: Badge(
              isLabelVisible: wishCount > 0,
              label: Text('$wishCount'),
              child: const Icon(Icons.favorite, color: AppColors.teal),
            ),
            label: 'Wishlist',
          ),
          NavigationDestination(
            icon: Badge(isLabelVisible: cartCount > 0, label: Text('$cartCount'), child: const Icon(Icons.shopping_bag_outlined)),
            selectedIcon: Badge(
              isLabelVisible: cartCount > 0,
              label: Text('$cartCount'),
              child: const Icon(Icons.shopping_bag, color: AppColors.teal),
            ),
            label: 'Cart',
          ),
          const NavigationDestination(
            icon: Icon(Icons.receipt_long_outlined),
            selectedIcon: Icon(Icons.receipt_long, color: AppColors.teal),
            label: 'Orders',
          ),
        ],
      ),
    );
  }
}

/// Shown when the shop has no products in Digistall yet. The website sends
/// shoppers to the shop's own storefront, so offer that here too.
class _NoCatalog extends StatelessWidget {
  final String shopId;
  final String title;
  final String image;
  final Store? store;
  final VoidCallback onRetry;

  const _NoCatalog({required this.shopId, required this.title, required this.image, required this.store, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    final phone = store?.phone ?? '';
    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: RefreshIndicator(
        onRefresh: () async => onRetry(),
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            const SizedBox(height: 12),
            Center(
              child: Container(
                width: 96,
                height: 96,
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(AppRadius.xl),
                  border: Border.all(color: AppColors.border),
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(AppRadius.lg),
                  child: NetImage(image.isNotEmpty ? image : store?.logo, fallbackIcon: Icons.storefront_outlined),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Text(title, textAlign: TextAlign.center, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800)),
            const SizedBox(height: 8),
            const Text(
              'This shop has not listed its products in the app yet. You can browse and order on its DigiStall website, or call the shop.',
              textAlign: TextAlign.center,
              style: TextStyle(color: AppColors.textSecondary, height: 1.45),
            ),
            const SizedBox(height: 24),
            AppButton(
              label: 'Open shop website',
              icon: Icons.open_in_new_rounded,
              onPressed: () => openExternal(context, Common.storefrontUrl(shopId)),
            ),
            if (phone.isNotEmpty) ...[
              const SizedBox(height: 10),
              AppButton(
                label: 'Call shop',
                icon: Icons.call_outlined,
                variant: ButtonVariant.secondary,
                onPressed: () => callNumber(context, phone),
              ),
            ],
            const SizedBox(height: 10),
            AppButton(
              label: 'Order on call · +91 ${Common.supportPhone}',
              icon: Icons.support_agent_rounded,
              variant: ButtonVariant.ghost,
              onPressed: () => callNumber(context, Common.supportPhone),
            ),
          ],
        ),
      ),
    );
  }
}
