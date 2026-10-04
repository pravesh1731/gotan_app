/// A Digistall store catalog (`POST backend.digistall.in/shop`).
class Store {
  final String shopId;
  final String name;
  final String tagline;
  final String logo;
  final String phone;
  final String email;
  final String address;
  final String about;
  final List<String> banners;
  final List<StoreCategory> categories;
  final List<Product> products;
  final bool open;
  final bool cod;
  final String upiId;
  final String qrCode;
  final num deliveryFee;

  /// The seller's FCM token; `customer/addorder` uses it to push "New Order".
  final String sellerDeviceToken;
  final double? pickupLat;
  final double? pickupLng;

  Store({
    required this.shopId,
    required this.name,
    required this.tagline,
    required this.logo,
    required this.phone,
    required this.email,
    required this.address,
    required this.about,
    required this.banners,
    required this.categories,
    required this.products,
    required this.open,
    required this.cod,
    required this.upiId,
    required this.qrCode,
    required this.deliveryFee,
    required this.sellerDeviceToken,
    this.pickupLat,
    this.pickupLng,
  });

  /// Products shoppers can see (sellers can hide products).
  List<Product> get visibleProducts => products.where((p) => p.visible).toList();

  List<StoreCategory> get visibleCategories => categories
      .where((c) => c.visible && products.any((p) => p.visible && p.category == c.name))
      .toList();

  bool get acceptsUpi => upiId.isNotEmpty || qrCode.isNotEmpty;

  Product? productById(String id) {
    for (final p in products) {
      if (p.id == id) return p;
    }
    return null;
  }

  num gstForCategory(String category) {
    for (final c in categories) {
      if (c.name == category) return c.gst;
    }
    return 0;
  }

  factory Store.fromJson(Map<String, dynamic> json) {
    final settings = (json['settings'] as Map?)?.cast<String, dynamic>() ?? const {};
    final header = (settings['header'] as Map?)?.cast<String, dynamic>() ?? const {};
    final footer = (settings['footer'] as Map?)?.cast<String, dynamic>() ?? const {};
    final banner = (settings['welcomeBanner'] as Map?)?.cast<String, dynamic>() ?? const {};

    String str(dynamic v) => v == null ? '' : v.toString().trim();

    // The default header from the Digistall schema ("HRI", +919999999999) is a
    // placeholder, so prefer the shop's own fields when they exist.
    final headerName = str(header['shopName']);
    final name = str(json['shopName']).isNotEmpty
        ? str(json['shopName'])
        : str(json['bussinessName']).isNotEmpty
            ? str(json['bussinessName'])
            : (headerName.isNotEmpty && headerName != 'HRI')
                ? headerName
                : str(json['heading']).isNotEmpty
                    ? str(json['heading'])
                    : str(json['shopId']);
    final headerPhone = str(header['phoneNumber']);
    final phone = str(json['phone']).isNotEmpty
        ? str(json['phone'])
        : (headerPhone == '+919999999999' ? '' : headerPhone);

    return Store(
      shopId: str(json['shopId']),
      name: name,
      tagline: header['isTaglineVisible'] == false ? '' : str(header['tagline']),
      logo: str(json['shopLogo']).isNotEmpty ? str(json['shopLogo']) : str(header['logo']),
      phone: phone,
      email: str(json['email']).isNotEmpty ? str(json['email']) : str(header['email']),
      address: str(json['address']).isNotEmpty ? str(json['address']) : str(footer['address']),
      about: str(footer['about']),
      banners: (banner['bannerImages'] as List? ?? const []).map((e) => e.toString()).toList(),
      categories: (json['categorys'] as List? ?? const [])
          .whereType<Map>()
          .map((c) => StoreCategory.fromJson(c.cast<String, dynamic>()))
          .toList(),
      products: (json['products'] as List? ?? const [])
          .whereType<Map>()
          .map((p) => Product.fromJson(p.cast<String, dynamic>()))
          .toList(),
      open: json['open'] != false,
      cod: json['cod'] == true,
      upiId: str(json['upiId']),
      qrCode: str(json['QRCode']),
      deliveryFee: (json['deliverPp'] as num?) ?? 20,
      sellerDeviceToken: str(json['deviceToken']),
      pickupLat: (json['pickupLat'] as num?)?.toDouble(),
      pickupLng: (json['pickupLng'] as num?)?.toDouble(),
    );
  }
}

class StoreCategory {
  final String id;
  final String name;
  final String image;
  final num gst;
  final bool visible;

  StoreCategory({required this.id, required this.name, required this.image, required this.gst, required this.visible});

  factory StoreCategory.fromJson(Map<String, dynamic> json) => StoreCategory(
        id: (json['categoryId'] ?? '').toString(),
        name: (json['categoryName'] ?? '').toString(),
        image: (json['categoryImg'] ?? '').toString(),
        gst: num.tryParse('${json['gst'] ?? 0}') ?? 0,
        visible: json['categoryVisibility'] != false,
      );
}

class Product {
  final Map<String, dynamic> raw;
  final String id;
  final String name;
  final String description;
  final String category;
  final String ribbon;
  final String unitType;
  final List<String> images;
  final num price;
  final num discountPrice;
  final int stock;
  final bool visible;
  final bool hasVariants;

  /// size -> color -> variant data (holds at least `stock`).
  final Map<String, Map<String, Map<String, dynamic>>> variants;

  Product({
    required this.raw,
    required this.id,
    required this.name,
    required this.description,
    required this.category,
    required this.ribbon,
    required this.unitType,
    required this.images,
    required this.price,
    required this.discountPrice,
    required this.stock,
    required this.visible,
    required this.hasVariants,
    required this.variants,
  });

  /// Digistall treats `productdiscountPrice` as the selling price when set.
  num get sellingPrice => discountPrice > 0 ? discountPrice : price;
  bool get hasDiscount => discountPrice > 0 && discountPrice < price;
  int get discountPercent => hasDiscount ? (((price - discountPrice) / price) * 100).round() : 0;
  String get image => images.isNotEmpty ? images.first : '';

  List<String> get sizes => variants.keys.toList();
  List<String> colorsFor(String size) => variants[size]?.keys.toList() ?? const [];

  /// Backend `decreseCount` rejects orders above stock, so a missing or zero
  /// stock means the product cannot be ordered.
  int stockFor({String? size, String? color}) {
    if (!hasVariants) return stock;
    if (size == null || color == null) {
      return variants.values.expand((c) => c.values).fold(0, (sum, v) => sum + _intOf(v['stock']));
    }
    return _intOf(variants[size]?[color]?['stock']);
  }

  bool get inStock => stockFor() > 0;

  static int _intOf(dynamic v) => v is num ? v.toInt() : int.tryParse('${v ?? ''}') ?? 0;
  static num _numOf(dynamic v) => v is num ? v : num.tryParse('${v ?? ''}') ?? 0;

  factory Product.fromJson(Map<String, dynamic> json) {
    final variants = <String, Map<String, Map<String, dynamic>>>{};
    final rawVariants = json['variants'];
    if (rawVariants is Map) {
      rawVariants.forEach((size, colors) {
        if (colors is Map) {
          final colorMap = <String, Map<String, dynamic>>{};
          colors.forEach((color, data) {
            if (data is Map) colorMap[color.toString()] = data.cast<String, dynamic>();
          });
          if (colorMap.isNotEmpty) variants[size.toString()] = colorMap;
        }
      });
    }
    return Product(
      raw: json,
      id: (json['productId'] ?? '').toString(),
      name: (json['productName'] ?? '').toString(),
      description: (json['productDescription'] ?? '').toString(),
      category: (json['productCategory'] ?? '').toString(),
      ribbon: (json['productRibbon'] ?? '').toString(),
      unitType: (json['productUnitType'] ?? '').toString(),
      images: (json['productImages'] as List? ?? const []).map((e) => e.toString()).where((e) => e.isNotEmpty).toList(),
      price: _numOf(json['productPrice']),
      discountPrice: _numOf(json['productdiscountPrice']),
      stock: _intOf(json['productUnits']),
      visible: json['productVisibility'] != false,
      hasVariants: json['hasVariants'] == true && variants.isNotEmpty,
      variants: variants,
    );
  }
}
