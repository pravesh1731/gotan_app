import 'package:flutter_test/flutter_test.dart';
import 'package:gotan/model/booking.dart';
import 'package:gotan/model/cart_item.dart';
import 'package:gotan/model/shop.dart';
import 'package:gotan/model/shop_order.dart';
import 'package:gotan/model/store.dart';
import 'package:gotan/utils/address.dart';
import 'package:gotan/utils/fare.dart';

void main() {
  group('Fare (matches gotan.in waiting.jsx)', () {
    test('ride fare is km x 10/20/30, rounded', () {
      expect(Fare.ride('Bike', 5300), 53);
      expect(Fare.ride('Auto', 5300), 106);
      expect(Fare.ride('Car', 5300), 159);
    });

    test('short trips are priced in km, not metres', () {
      // The old app parsed "850 m" as 850 km (₹8500 for a bike).
      expect(Fare.ride('Bike', 850), 9);
    });

    test('parcel fare rounds up', () {
      expect(Fare.parcel(5300), 53);
      expect(Fare.parcel(850), 9);
      expect(Fare.parcel(1001), 11);
    });
  });

  group('Booking.stage', () {
    Booking b(Map<String, dynamic> json) => Booking.fromJson(BookingKind.ride, {'_id': 'x', ...json});

    test('pending (not confirmed) is a draft', () {
      expect(b({'user': 'Pending'}).stage, BookingStage.draft);
    });
    test('accepted by user but no rider yet is searching', () {
      final booking = b({'user': 'accepted', 'riderAccepted': false, 'riderStatus': 'En Route'});
      expect(booking.stage, BookingStage.searching);
      expect(booking.isActive, isTrue);
      expect(booking.canCancel, isTrue);
    });
    test('rider accepted is assigned and cannot be cancelled', () {
      final booking = b({
        'user': 'accepted',
        'riderAccepted': true,
        'riderStatus': 'En Route',
        'riderDetails': [
          {'name': 'Ramesh', 'phoneNumber': '9000000000', 'riderDomain': 'ramesh'}
        ],
      });
      expect(booking.stage, BookingStage.assigned);
      expect(booking.canCancel, isFalse);
      expect(booking.rider?.name, 'Ramesh');
    });
    test('OTP verified means in transit', () {
      expect(b({'user': 'accepted', 'riderAccepted': true, 'acceptedUserOtp': true, 'riderStatus': 'In Transit'}).stage,
          BookingStage.inTransit);
    });
    test('delivered and rejected end the booking', () {
      expect(b({'user': 'accepted', 'riderAccepted': true, 'riderStatus': 'Delivered'}).stage, BookingStage.delivered);
      expect(b({'user': 'rejected'}).stage, BookingStage.cancelled);
      expect(b({'user': 'rejected'}).isActive, isFalse);
    });
  });

  group('Store.fromJson', () {
    final store = Store.fromJson({
      'shopId': 'gotandairy',
      'shopName': 'Gotan Dairy',
      'deliverPp': 15,
      'open': true,
      'upiId': 'dairy@upi',
      'deviceToken': 'seller-token',
      'settings': {
        'header': {'shopName': 'HRI', 'phoneNumber': '+919999999999', 'tagline': 'Fresh milk'},
      },
      'categorys': [
        {'categoryName': 'Milk', 'gst': 5, 'categoryVisibility': true},
      ],
      'products': [
        {
          'productId': 'p1',
          'productName': 'Cow milk',
          'productPrice': 60,
          'productdiscountPrice': 55.5,
          'productUnits': 10,
          'productCategory': 'Milk',
          'productImages': ['http://res.cloudinary.com/x.jpg'],
        },
        {'productId': 'p2', 'productName': 'Hidden', 'productPrice': 10, 'productVisibility': false},
        {
          'productId': 'p3',
          'productName': 'T-shirt',
          'productPrice': 300,
          'hasVariants': true,
          'variants': {
            'M': {'Red': {'stock': 2}, 'Blue': {'stock': 0}},
          },
        },
      ],
    });

    test('ignores Digistall placeholder header values', () {
      expect(store.name, 'Gotan Dairy');
      expect(store.phone, isEmpty);
      expect(store.tagline, 'Fresh milk');
    });
    test('reads delivery fee, UPI and seller token', () {
      expect(store.deliveryFee, 15);
      expect(store.acceptsUpi, isTrue);
      expect(store.sellerDeviceToken, 'seller-token');
    });
    test('parses decimal prices and hides invisible products', () {
      final milk = store.productById('p1')!;
      expect(milk.sellingPrice, 55.5);
      expect(milk.hasDiscount, isTrue);
      expect(store.visibleProducts.map((p) => p.id), ['p1', 'p3']);
      expect(store.gstForCategory('Milk'), 5);
    });
    test('variant stock', () {
      final shirt = store.productById('p3')!;
      expect(shirt.hasVariants, isTrue);
      expect(shirt.stockFor(size: 'M', color: 'Red'), 2);
      expect(shirt.stockFor(size: 'M', color: 'Blue'), 0);
      expect(shirt.inStock, isTrue);
    });
  });

  test('Shop.fromJson tolerates missing image and lowercases id', () {
    final shop = Shop.fromJson({'heading': 'Karni', 'shopId': 'KarniMegaStore'});
    expect(shop.shopImage, '');
    expect(shop.shopId, 'karnimegastore');
  });

  test('ShopOrder groups per-product records by orderId', () {
    final orders = ShopOrder.groupFromJson([
      {
        'orderId': 'o1',
        'shopId': 's',
        'productName': 'A',
        'productCount': 2,
        'onePiecePrice': 10,
        'deliveryFee': 20,
        'orderStatus': 'SHIPPED',
        'orderNote': {'deliveryOtp': '4321'},
        'date': '2026-10-01T10:00:00.000Z',
      },
      {'orderId': 'o1', 'shopId': 's', 'productName': 'B', 'productCount': 1, 'onePiecePrice': 5, 'deliveryFee': 20},
      {'orderId': 'o2', 'shopId': 's', 'productName': 'C', 'productCount': 1, 'onePiecePrice': 7, 'date': '2026-09-01T10:00:00.000Z'},
    ]);
    expect(orders.map((o) => o.orderId), ['o1', 'o2']);
    final o1 = orders.first;
    expect(o1.items.length, 2);
    expect(o1.itemsTotal, 25);
    expect(o1.grandTotal, 45);
    expect(o1.deliveryOtp, '4321');
    expect(o1.statusLabel, 'Out for delivery');
  });

  test('delivery address keeps name first and the phone searchable', () {
    final formatted = formatDeliveryAddress({
      'name': 'Sita',
      'mobile': '9876543210',
      'address': '12 Main Road',
      'landmark': 'Temple',
      'city': 'Gotan',
      'pincode': '342902',
      'state': 'Rajasthan',
    });
    expect(formatted.split(',').first, 'Sita');
    expect(formatted, contains('+91-9876543210'));
    expect(formatted, 'Sita, +91-9876543210, 12 Main Road, Near Temple, Gotan, 342902, Rajasthan, India');
  });

  test('cart line keys separate variants', () {
    expect(CartItem.keyFor('p1'), 'p1');
    expect(CartItem.keyFor('p1', size: 'M', color: 'Red'), 'p1|M|Red');
  });
}
