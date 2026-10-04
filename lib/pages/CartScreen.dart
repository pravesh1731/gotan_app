import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../model/store.dart';
import '../providers/CartProvider.dart';
import '../theme/app_theme.dart';
import '../widgets/ui.dart';
import 'CheckoutScreen.dart';
import 'ShopPage.dart' show QtyStepper;

class CartScreen extends StatelessWidget {
  final Store store;
  final VoidCallback onOpenShop;
  final VoidCallback onOrderPlaced;

  const CartScreen({super.key, required this.store, required this.onOpenShop, required this.onOrderPlaced});

  @override
  Widget build(BuildContext context) {
    final cart = context.watch<CartProvider>();
    final lines = cart.getCart(store.shopId).values.toList();
    final subtotal = cart.subtotal(store.shopId);
    final mrp = lines.fold<num>(0, (sum, l) => sum + l.price * l.quantity);
    final savings = mrp - subtotal;
    final total = subtotal + store.deliveryFee;

    return Scaffold(
      appBar: AppBar(title: const Text('Your cart'), automaticallyImplyLeading: false),
      body: lines.isEmpty
          ? EmptyState(
              icon: Icons.shopping_bag_outlined,
              title: 'Your cart is empty',
              message: 'Add products from ${store.name} to place an order.',
              actionLabel: 'Start shopping',
              onAction: onOpenShop,
            )
          : ListView(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
              children: [
                AppCard(
                  padding: EdgeInsets.zero,
                  child: Column(
                    children: [
                      for (var i = 0; i < lines.length; i++) ...[
                        if (i > 0) const Divider(),
                        Padding(
                          padding: const EdgeInsets.all(12),
                          child: Row(
                            children: [
                              ClipRRect(
                                borderRadius: BorderRadius.circular(AppRadius.md),
                                child: SizedBox(
                                  width: 64,
                                  height: 64,
                                  child: NetImage(lines[i].imageUrl, fallbackIcon: Icons.shopping_basket_outlined),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(lines[i].name,
                                        maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w600)),
                                    if (lines[i].variantLabel.isNotEmpty)
                                      Text(lines[i].variantLabel, style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                                    const SizedBox(height: 4),
                                    Text(rupees(lines[i].lineTotal), style: const TextStyle(fontWeight: FontWeight.w800)),
                                    if (lines[i].quantity >= lines[i].units)
                                      const Text('Max stock reached', style: TextStyle(fontSize: 11, color: Color(0xFFB7791F))),
                                  ],
                                ),
                              ),
                              QtyStepper(
                                qty: lines[i].quantity,
                                compact: true,
                                onMinus: () => cart.decreaseQuantity(store.shopId, lines[i].lineKey),
                                onPlus: () {
                                  if (!cart.increaseQuantity(store.shopId, lines[i].lineKey)) {
                                    showAppSnack(context, 'Only ${lines[i].units} in stock');
                                  }
                                },
                              ),
                            ],
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(height: 8),
                Align(
                  alignment: Alignment.centerLeft,
                  child: TextButton.icon(
                    onPressed: onOpenShop,
                    icon: const Icon(Icons.add_rounded),
                    label: const Text('Add more items'),
                  ),
                ),
                const SizedBox(height: 8),
                AppCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Bill details', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
                      const SizedBox(height: 8),
                      InfoRow(label: 'Item total', value: rupees(subtotal)),
                      if (savings > 0) InfoRow(label: 'You save', value: '-${rupees(savings)}', valueColor: AppColors.success),
                      InfoRow(label: 'Delivery fee', value: rupees(store.deliveryFee)),
                      const Divider(),
                      InfoRow(label: 'To pay', value: rupees(total), bold: true),
                    ],
                  ),
                ),
              ],
            ),
      bottomNavigationBar: lines.isEmpty
          ? null
          : SafeArea(
              child: Container(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
                decoration: const BoxDecoration(
                  color: AppColors.surface,
                  border: Border(top: BorderSide(color: AppColors.border)),
                ),
                child: Row(
                  children: [
                    Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Total', style: TextStyle(color: AppColors.textSecondary, fontSize: 12)),
                        Text(rupees(total), style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800)),
                      ],
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: AppButton(
                        label: store.open ? 'Checkout' : 'Shop is closed',
                        onPressed: !store.open
                            ? null
                            : () async {
                                final placed = await Navigator.push<bool>(
                                  context,
                                  MaterialPageRoute(builder: (_) => CheckoutScreen(store: store)),
                                );
                                if (placed == true) onOrderPlaced();
                              },
                      ),
                    ),
                  ],
                ),
              ),
            ),
    );
  }
}
