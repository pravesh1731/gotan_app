import '../widgets/ui.dart' show Tone;

/// One line of a Digistall order. The backend stores one record per product,
/// all sharing the same `orderId`.
class ShopOrderItem {
  final String productId;
  final String name;
  final String image;
  final int count;
  final num unitPrice;
  final String variant;

  ShopOrderItem({
    required this.productId,
    required this.name,
    required this.image,
    required this.count,
    required this.unitPrice,
    required this.variant,
  });

  num get total => unitPrice * count;
}

class ShopOrder {
  final String orderId;
  final String shopId;
  final String status;
  final String paymentMethod;
  final String transactionId;
  final String address;
  final String deliveryMode;
  final String deliveryOtp;
  final String deliveryDate;
  final String deliveryTime;
  final String deliveryPartner;
  final num deliveryFee;
  final DateTime? date;
  final List<ShopOrderItem> items;

  ShopOrder({
    required this.orderId,
    required this.shopId,
    required this.status,
    required this.paymentMethod,
    required this.transactionId,
    required this.address,
    required this.deliveryMode,
    required this.deliveryOtp,
    required this.deliveryDate,
    required this.deliveryTime,
    required this.deliveryPartner,
    required this.deliveryFee,
    required this.date,
    required this.items,
  });

  num get itemsTotal => items.fold<num>(0, (sum, i) => sum + i.total);
  num get grandTotal => itemsTotal + deliveryFee;
  int get itemCount => items.fold(0, (sum, i) => sum + i.count);

  String get statusLabel {
    final s = status.toUpperCase();
    return switch (s) {
      'PENDING' => 'Order placed',
      'CONFIRMED' => 'Confirmed',
      'SHIPPED' => 'Out for delivery',
      'DELIVERED' => 'Delivered',
      'CANCELLED' || 'CANCELED' || 'REJECTED' => 'Cancelled',
      _ => s.isEmpty ? 'Order placed' : '${s[0]}${s.substring(1).toLowerCase()}',
    };
  }

  Tone get tone {
    final s = status.toUpperCase();
    if (s == 'DELIVERED') return Tone.success;
    if (s == 'CANCELLED' || s == 'CANCELED' || s == 'REJECTED') return Tone.error;
    if (s == 'SHIPPED' || s == 'CONFIRMED') return Tone.info;
    return Tone.warning;
  }

  bool get isOpen {
    final s = status.toUpperCase();
    return s != 'DELIVERED' && s != 'CANCELLED' && s != 'CANCELED' && s != 'REJECTED';
  }

  /// Groups the flat per-product records from `customer/getorders`.
  static List<ShopOrder> groupFromJson(List<dynamic> records) {
    final byId = <String, List<Map<String, dynamic>>>{};
    for (final r in records.whereType<Map>()) {
      final m = r.cast<String, dynamic>();
      final id = (m['orderId'] ?? '').toString();
      if (id.isEmpty) continue;
      byId.putIfAbsent(id, () => []).add(m);
    }

    String str(dynamic v) => v == null ? '' : v.toString();
    num numOf(dynamic v) => v is num ? v : num.tryParse(str(v)) ?? 0;

    final orders = byId.entries.map((e) {
      final first = e.value.first;
      final note = (first['orderNote'] as Map?)?.cast<String, dynamic>() ?? const {};
      return ShopOrder(
        orderId: e.key,
        shopId: str(first['shopId']),
        status: str(first['orderStatus']).isEmpty ? 'PENDING' : str(first['orderStatus']),
        paymentMethod: str(first['paymentMethod']),
        transactionId: str(first['transactionId']),
        address: str(first['address']),
        deliveryMode: str(first['deliveryMode']),
        deliveryOtp: str(first['deliveryOtp']).isNotEmpty ? str(first['deliveryOtp']) : str(note['deliveryOtp']),
        deliveryDate: str(note['deliveryDate']),
        deliveryTime: str(note['deliveryTime']),
        deliveryPartner: str(note['deliveryPartner']),
        deliveryFee: numOf(first['deliveryFee']),
        date: DateTime.tryParse(str(first['date']))?.toLocal(),
        items: e.value
            .map((m) => ShopOrderItem(
                  productId: str(m['productId']),
                  name: str(m['productName']),
                  image: str(m['productImage']),
                  count: numOf(m['productCount']).toInt(),
                  unitPrice: numOf(m['onePiecePrice']),
                  variant: str(m['variant']).isNotEmpty
                      ? str(m['variant'])
                      : [str(m['size']), str(m['color'])].where((s) => s.isNotEmpty).join(' '),
                ))
            .toList(),
      );
    }).toList();

    orders.sort((a, b) => (b.date ?? DateTime(2000)).compareTo(a.date ?? DateTime(2000)));
    return orders;
  }
}
