import 'package:hive/hive.dart';

import 'store.dart';

part 'cart_item.g.dart';

@HiveType(typeId: 0)
class CartItem extends HiveObject {
  @HiveField(0)
  String id;

  @HiveField(1)
  String name;

  @HiveField(2)
  String category;

  @HiveField(3)
  String imageUrl;

  @HiveField(4)
  num price;

  @HiveField(5)
  num discountPrice;

  @HiveField(6)
  int units;

  @HiveField(7)
  String unitType;

  @HiveField(8)
  String productRibbon;

  @HiveField(9)
  int quantity;

  @HiveField(10)
  String description;

  @HiveField(11, defaultValue: '')
  String storeId;

  @HiveField(12, defaultValue: '')
  String size;

  @HiveField(13, defaultValue: '')
  String color;

  CartItem({
    required this.id,
    required this.name,
    required this.category,
    required this.imageUrl,
    required this.price,
    required this.discountPrice,
    required this.units,
    required this.unitType,
    required this.productRibbon,
    this.quantity = 1,
    required this.description,
    this.storeId = '',
    this.size = '',
    this.color = '',
  });

  factory CartItem.fromProduct(Product product, {required String storeId, String size = '', String color = ''}) {
    return CartItem(
      id: product.id,
      name: product.name,
      category: product.category,
      imageUrl: product.image,
      price: product.price,
      discountPrice: product.discountPrice,
      units: product.stockFor(size: size.isEmpty ? null : size, color: color.isEmpty ? null : color),
      unitType: product.unitType,
      productRibbon: product.ribbon,
      description: product.description,
      storeId: storeId,
      size: size,
      color: color,
    );
  }

  bool get hasVariant => size.isNotEmpty || color.isNotEmpty;

  /// Cart map key; variants of one product are separate lines. (Not `key`:
  /// that is HiveObject's box key.)
  String get lineKey => keyFor(id, size: size, color: color);

  static String keyFor(String productId, {String size = '', String color = ''}) =>
      (size.isEmpty && color.isEmpty) ? productId : '$productId|$size|$color';

  num get sellingPrice => discountPrice > 0 ? discountPrice : price;
  num get lineTotal => sellingPrice * quantity;
  String get variantLabel => [size, color].where((s) => s.isNotEmpty).join(' · ');
}
