import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../model/shop_order.dart';
import '../providers/UserProvider.dart';
import '../services/api.dart';
import '../services/session.dart';
import '../theme/app_theme.dart';
import '../widgets/ui.dart';
import 'ShopOrderDetailScreen.dart';

/// Digistall orders placed from the app. Looked up by the user's phone number
/// (it is part of the delivery address) plus order ids saved on this device.
class OrderHistoryPage extends StatefulWidget {
  /// When set, only this shop's orders are shown (Orders tab inside a shop).
  final String? shopId;
  final bool embedded;

  const OrderHistoryPage({super.key, this.shopId, this.embedded = false});

  @override
  State<OrderHistoryPage> createState() => OrderHistoryPageState();
}

class OrderHistoryPageState extends State<OrderHistoryPage> {
  late Future<List<ShopOrder>> _future;

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  Future<List<ShopOrder>> _load() async {
    final user = context.read<UserProvider>();
    final ids = await Session.shopOrderIds();
    final orders = await Api.shopOrders(user.isLoggedIn ? user.phone : null, ids);
    return widget.shopId == null ? orders : orders.where((o) => o.shopId == widget.shopId).toList();
  }

  Future<void> refresh() async {
    setState(() => _future = _load());
    await _future.catchError((_) => <ShopOrder>[]);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.embedded ? 'Orders' : 'My shop orders'),
        automaticallyImplyLeading: !widget.embedded,
      ),
      body: FutureBuilder<List<ShopOrder>>(
        future: _future,
        builder: (context, snap) {
          if (snap.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snap.hasError) {
            return EmptyState(
              icon: Icons.wifi_off_rounded,
              title: 'Could not load orders',
              message: snap.error.toString(),
              actionLabel: 'Retry',
              onAction: refresh,
            );
          }
          final orders = snap.data ?? [];
          if (orders.isEmpty) {
            return RefreshIndicator(
              onRefresh: refresh,
              child: ListView(
                children: const [
                  EmptyState(
                    icon: Icons.receipt_long_outlined,
                    title: 'No orders yet',
                    message: 'Orders you place from Gotan shops will appear here.',
                  ),
                ],
              ),
            );
          }
          return RefreshIndicator(
            onRefresh: refresh,
            child: ListView.separated(
              padding: const EdgeInsets.all(16),
              itemCount: orders.length,
              separatorBuilder: (_, __) => const SizedBox(height: 12),
              itemBuilder: (context, i) => _OrderCard(
                order: orders[i],
                showShop: widget.shopId == null,
                onTap: () async {
                  await Navigator.push(context, MaterialPageRoute(builder: (_) => ShopOrderDetailScreen(order: orders[i])));
                  refresh();
                },
              ),
            ),
          );
        },
      ),
    );
  }
}

class _OrderCard extends StatelessWidget {
  final ShopOrder order;
  final bool showShop;
  final VoidCallback onTap;

  const _OrderCard({required this.order, required this.showShop, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final first = order.items.isNotEmpty ? order.items.first : null;
    return AppCard(
      onTap: onTap,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      showShop && order.shopId.isNotEmpty ? order.shopId : 'Order #${_shortId(order.orderId)}',
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                    if (order.date != null)
                      Text(DateFormat('d MMM yyyy, h:mm a').format(order.date!),
                          style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                  ],
                ),
              ),
              StatusChip(label: order.statusLabel, tone: order.tone, dense: true),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(AppRadius.md),
                child: SizedBox(width: 52, height: 52, child: NetImage(first?.image, fallbackIcon: Icons.shopping_basket_outlined)),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  order.items.map((i) => '${i.count} × ${i.name}').join(', '),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(color: AppColors.textSecondary, height: 1.35),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Text('${order.itemCount} item${order.itemCount == 1 ? '' : 's'} · ${order.paymentMethod.isEmpty ? 'COD' : order.paymentMethod}',
                  style: const TextStyle(fontSize: 13, color: AppColors.textSecondary)),
              const Spacer(),
              Text(rupees(order.grandTotal), style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
            ],
          ),
          if (order.deliveryOtp.isNotEmpty && order.isOpen) ...[
            const SizedBox(height: 10),
            StatusChip(label: 'Delivery OTP: ${order.deliveryOtp}', tone: Tone.info),
          ],
        ],
      ),
    );
  }
}

String _shortId(String id) => id.length <= 8 ? id.toUpperCase() : id.substring(0, 8).toUpperCase();
