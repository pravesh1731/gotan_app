/// A shop listed on gotanbackend (`api/shop/getallshops`).
class Shop {
  final String shopImage;
  final String heading;
  final String desc;
  final String shopId;
  final List<String> formats;

  Shop({
    required this.shopImage,
    required this.heading,
    required this.desc,
    required this.shopId,
    this.formats = const [],
  });

  factory Shop.fromJson(Map<String, dynamic> json) {
    return Shop(
      shopImage: (json['shopImage'] ?? '').toString(),
      heading: (json['heading'] ?? json['shopId'] ?? '').toString(),
      desc: (json['desc'] ?? '').toString(),
      // Digistall shop ids are lowercase subdomains.
      shopId: (json['shopId'] ?? '').toString().trim().toLowerCase(),
      formats: (json['formats'] as List? ?? const []).map((e) => e.toString()).toList(),
    );
  }
}
