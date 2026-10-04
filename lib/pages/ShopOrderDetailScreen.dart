import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../global/common.dart';
import '../model/shop_order.dart';
import '../model/store.dart';
import '../services/api.dart';
import '../theme/app_theme.dart';
import '../utils/launch.dart';
import '../widgets/ui.dart';

class ShopOrderDetailScreen extends StatefulWidget {
  final ShopOrder order;
  const ShopOrderDetailScreen({super.key, required this.order});

  @override
  State<ShopOrderDetailScreen> createState() => _ShopOrderDetailScreenState();
}

class _ShopOrderDetailScreenState extends State<ShopOrderDetailScreen> {
  late ShopOrder _order = widget.order;
  Map<String, dynamic>? _dispatch;
  Store? _store;

  @override
  void initState() {
    super.initState();
    _loadExtras();
  }

  Future<void> _loadExtras() async {
    // Both are optional extras; the order itself is already on screen.
    Api.riderDispatch(_order.orderId).then((d) {
      if (mounted) setState(() => _dispatch = d);
    }).catchError((_) {});
    if (_order.shopId.isNotEmpty) {
      Api.getStore(_order.shopId).then((s) {
        if (mounted) setState(() => _store = s);
      }).catchError((_) {});
    }
  }

  Future<void> _refresh() async {
    try {
      final fresh = await Api.shopOrders(null, [_order.orderId]);
      final match = fresh.where((o) => o.orderId == _order.orderId).firstOrNull;
      if (match != null && mounted) setState(() => _order = match);
    } catch (_) {}
    await _loadExtras();
  }

  @override
  Widget build(BuildContext context) {
    final o = _order;
    final dispatchRider = (_dispatch?['riderDetails'] is List && (_dispatch!['riderDetails'] as List).isNotEmpty)
        ? ((_dispatch!['riderDetails'] as List).first as Map).cast<String, dynamic>()
        : null;
    final dispatchOtp = (_dispatch?['otp'] ?? '').toString();
    final dispatchStatus = (_dispatch?['riderStatus'] ?? '').toString();
    final status = o.status.toUpperCase();
    const steps = ['PENDING', 'CONFIRMED', 'SHIPPED', 'DELIVERED'];
    final current = steps.indexOf(status);

    return Scaffold(
      appBar: AppBar(title: Text('Order #${o.orderId.length > 8 ? o.orderId.substring(0, 8).toUpperCase() : o.orderId}')),
      body: RefreshIndicator(
        onRefresh: _refresh,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            AppCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(child: Text(o.statusLabel, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800))),
                      StatusChip(label: o.paymentMethod.isEmpty ? 'COD' : o.paymentMethod, tone: Tone.neutral, dense: true),
                    ],
                  ),
                  if (o.date != null)
                    Text('Placed ${DateFormat('d MMM yyyy, h:mm a').format(o.date!)}',
                        style: const TextStyle(color: AppColors.textSecondary, fontSize: 13)),
                  if (o.deliveryDate.isNotEmpty || o.deliveryTime.isNotEmpty) ...[
                    const SizedBox(height: 6),
                    Text('Expected delivery: ${[o.deliveryDate, o.deliveryTime].where((s) => s.isNotEmpty).join(' ')}',
                        style: const TextStyle(fontWeight: FontWeight.w600, color: AppColors.tealDark)),
                  ],
                  if (current >= 0) ...[
                    const SizedBox(height: 14),
                    Row(
                      children: [
                        for (var i = 0; i < steps.length; i++) ...[
                          Expanded(
                            child: Column(
                              children: [
                                Container(
                                  height: 5,
                                  decoration: BoxDecoration(
                                    color: i <= current ? AppColors.teal : AppColors.border,
                                    borderRadius: BorderRadius.circular(99),
                                  ),
                                ),
                                const SizedBox(height: 6),
                                Text(
                                  const ['Placed', 'Confirmed', 'On the way', 'Delivered'][i],
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: i == current ? FontWeight.w700 : FontWeight.w500,
                                    color: i <= current ? AppColors.textPrimary : AppColors.textSecondary,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          if (i < steps.length - 1) const SizedBox(width: 6),
                        ],
                      ],
                    ),
                  ],
                ],
              ),
            ),
            if (o.deliveryOtp.isNotEmpty && o.isOpen) ...[
              const SizedBox(height: 12),
              _OtpBanner(title: 'Delivery OTP', subtitle: 'Share with the shop\'s delivery person', otp: o.deliveryOtp),
            ],
            if (_dispatch != null && dispatchStatus.toLowerCase() != 'delivered') ...[
              const SizedBox(height: 12),
              AppCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Gotan rider delivery', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
                    const SizedBox(height: 8),
                    InfoRow(label: 'Status', value: _dispatch!['riderAccepted'] == true ? dispatchStatus : 'Finding a rider'),
                    if (dispatchRider != null) ...[
                      InfoRow(label: 'Rider', value: (dispatchRider['name'] ?? '').toString()),
                      if ((dispatchRider['phoneNumber'] ?? '').toString().isNotEmpty)
                        Align(
                          alignment: Alignment.centerRight,
                          child: TextButton.icon(
                            onPressed: () => callNumber(context, dispatchRider['phoneNumber'].toString()),
                            icon: const Icon(Icons.call_outlined),
                            label: const Text('Call rider'),
                          ),
                        ),
                    ],
                    if (dispatchOtp.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      _OtpBanner(title: 'Rider OTP', subtitle: 'Give this to the rider when the order arrives', otp: dispatchOtp),
                    ],
                  ],
                ),
              ),
            ],
            const SizedBox(height: 12),
            AppCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(_store?.name ?? o.shopId, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
                  const SizedBox(height: 10),
                  for (final item in o.items)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 6),
                      child: Row(
                        children: [
                          ClipRRect(
                            borderRadius: BorderRadius.circular(AppRadius.sm),
                            child: SizedBox(width: 44, height: 44, child: NetImage(item.image, fallbackIcon: Icons.shopping_basket_outlined)),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(item.name, maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w600)),
                                Text('${item.count} × ${rupees(item.unitPrice)}${item.variant.isEmpty ? '' : ' · ${item.variant}'}',
                                    style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                              ],
                            ),
                          ),
                          Text(rupees(item.total), style: const TextStyle(fontWeight: FontWeight.w700)),
                        ],
                      ),
                    ),
                  const Divider(),
                  InfoRow(label: 'Item total', value: rupees(o.itemsTotal)),
                  InfoRow(label: 'Delivery fee', value: rupees(o.deliveryFee)),
                  const Divider(),
                  InfoRow(label: 'Total', value: rupees(o.grandTotal), bold: true),
                  if (o.transactionId.isNotEmpty) InfoRow(label: 'UPI transaction', value: o.transactionId),
                ],
              ),
            ),
            const SizedBox(height: 12),
            AppCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Delivery address', style: TextStyle(fontWeight: FontWeight.w700)),
                  const SizedBox(height: 6),
                  Text(o.address, style: const TextStyle(color: AppColors.textSecondary, height: 1.4)),
                ],
              ),
            ),
            const SizedBox(height: 16),
            if ((_store?.phone ?? '').isNotEmpty)
              AppButton(
                label: 'Call shop',
                icon: Icons.call_outlined,
                variant: ButtonVariant.secondary,
                onPressed: () => callNumber(context, _store!.phone),
              ),
            const SizedBox(height: 8),
            AppButton(
              label: 'Need help? Call Gotan',
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

class _OtpBanner extends StatelessWidget {
  final String title;
  final String subtitle;
  final String otp;
  const _OtpBanner({required this.title, required this.subtitle, required this.otp});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(color: AppColors.navy, borderRadius: BorderRadius.circular(AppRadius.lg)),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title.toUpperCase(),
                    style: const TextStyle(color: AppColors.yellow, fontSize: 11, fontWeight: FontWeight.w800, letterSpacing: 1)),
                Text(subtitle, style: const TextStyle(color: AppColors.textDisabled, fontSize: 12)),
              ],
            ),
          ),
          Text(otp.split('').join(' '),
              style: const TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.w800, fontFamily: AppTheme.displayFamily)),
        ],
      ),
    );
  }
}
