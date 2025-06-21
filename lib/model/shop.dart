class Shop {
  final String shopImage;
  final String heading;
  final String desc;
  final String shopId;

  Shop({required this.shopImage, required this.heading, required this.desc, required this.shopId});

  factory Shop.fromJson(Map<String, dynamic> json) {
    return Shop(
      shopImage: json['shopImage'],
      heading: json['heading'],
      desc: json['desc'],
      shopId: json['shopId'],
    );
  }
}
