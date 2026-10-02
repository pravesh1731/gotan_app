class ShopResponse {
  final String shopName;
  final String emailId;
  final List<Product> products;

  ShopResponse({
    required this.shopName,
    required this.emailId,
    required this.products,
  });

  factory ShopResponse.fromJson(Map<String, dynamic> json) {
    return ShopResponse(
      shopName: json['shopName'],
      emailId: json['emailId'],
      products: List<Product>.from(
        json['products'].map((x) => Product.fromJson(x)),
      ),
    );
  }
}

class Product {
  final String id;
  final String name;
  final List<String> images;
  final double price;
  final double discountPrice;
  final String category;
  final int units;
  final String unitType;

  Product({
    required this.id,
    required this.name,
    required this.images,
    required this.price,
    required this.discountPrice,
    required this.category,
    required this.units,
    required this.unitType,
  });

  factory Product.fromJson(Map<String, dynamic> json) {
    return Product(
      id: json['productId'],
      name: json['productName'],
      images: List<String>.from(json['productImages']),
      price: (json['productPrice'] as num).toDouble(),
      discountPrice: (json['productdiscountPrice'] as num).toDouble(),
      category: json['productCategory'],
      units: json['productUnits'],
      unitType: json['productUnitType'],
    );
  }
}


