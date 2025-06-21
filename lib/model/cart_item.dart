import 'package:hive/hive.dart';

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
  int price;

  @HiveField(5)
  int discountPrice;

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
  });
}
