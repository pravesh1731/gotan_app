import 'dart:convert';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:gotan/model/cart_item.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:provider/provider.dart';
import '../providers/CartProvider.dart';
import '../providers/WishlistProvider.dart';
import '../widgets/share_dialog.dart';
import 'package:lottie/lottie.dart';

class ProductDetailScreen extends StatefulWidget {
  final dynamic product;
  final String shopId;
  final List<dynamic> maylike;

  const ProductDetailScreen({
    Key? key,
    required this.product,
    required this.shopId,
    this.maylike = const [],
  }) : super(key: key);

  @override
  State<ProductDetailScreen> createState() => _ProductDetailScreenState();
}

class _ProductDetailScreenState extends State<ProductDetailScreen> {
  Map<String, dynamic> shopHeader = {};
  late String selectedImageUrl;

  int get quantity {
    return Provider.of<CartProvider>(
      context,
      listen: false,
    ).getQuantity(widget.shopId, widget.product['productId'].toString());
  }

  bool _isVisible = true;

  Future<void> loadShopHeader() async {
    final prefs = await SharedPreferences.getInstance();
    final headerString = prefs.getString('shopHeader');
    if (headerString != null) {
      setState(() {
        shopHeader = jsonDecode(headerString);
      });
    }
  }

  @override
  void initState() {
    super.initState();
    loadShopHeader();
    final images = widget.product['productImages'] as List;
    selectedImageUrl = images.isNotEmpty ? images[0] : '';
    //back print('===== maylike =====');
    //back print(widget.maylike);
  }

  @override
  Widget build(BuildContext context) {
    final wishlistProvider = Provider.of<WishlistProvider>(context);
    final productId = widget.product['productId'].toString();
    final isInWishlist = wishlistProvider.isInWishlist(productId);
    //back print('Product ID: $productId');
    //back print('Is in wishlist before: ${wishlistProvider.isInWishlist(productId)}');

    final name = widget.product['productName'] ?? '';
    final price = widget.product['productPrice'] ?? 0;
    final discountPrice = widget.product['productdiscountPrice'] ?? 0;
    final description =
        (widget.product['productDescription'] != null &&
                widget.product['productDescription']
                    .toString()
                    .trim()
                    .isNotEmpty)
            ? widget.product['productDescription']
            : 'Description is not available';
    final category = widget.product['productCategory'] ?? '';
    final images = widget.product['productImages'] as List;

    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: SingleChildScrollView(
          child: Column(
            children: [
              _buildHeader(),
              Container(
                color: Colors.white,
                child: Column(
                  children: [
                    const SizedBox(height: 20),
                    SizedBox(
                      height: 300,
                      width: double.infinity,
                      child: Stack(
                        alignment: Alignment.center,
                        children: [
                          // Main product image (no color filter)
                          ClipRRect(
                            borderRadius: BorderRadius.circular(12),
                            child: CachedNetworkImage(
                              imageUrl: selectedImageUrl,
                              height: 300,
                              width: double.infinity,
                              fit: BoxFit.contain,
                              errorWidget:
                                  (_, __, ___) =>
                                      const Icon(Icons.broken_image),
                            ),
                          ),
                          // Out of stock overlay (centered)
                          if (widget.product['productUnits'] == 0)
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 6,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.redAccent,
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: const Text(
                                "Out of Stock",
                                style: TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),
                    if (images.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 8),
                        child: Align(
                          alignment: Alignment.centerLeft,
                          child: SingleChildScrollView(
                            scrollDirection: Axis.horizontal,
                            child: Row(
                              children:
                                  images.map<Widget>((imgUrl) {
                                    return GestureDetector(
                                      onTap: () {
                                        setState(() {
                                          selectedImageUrl = imgUrl;
                                        });
                                      },
                                      child: Container(
                                        margin: const EdgeInsets.symmetric(
                                          horizontal: 5,
                                        ),
                                        padding: const EdgeInsets.all(2),
                                        decoration: BoxDecoration(
                                          border: Border.all(
                                            color:
                                                selectedImageUrl == imgUrl
                                                    ? Colors.blue
                                                    : Colors.grey,
                                            width: 2,
                                          ),
                                        ),
                                        child: CachedNetworkImage(
                                          imageUrl: imgUrl,
                                          height: 60,
                                          width: 60,
                                          fit: BoxFit.cover,
                                          errorWidget:
                                              (_, __, ___) => const Icon(
                                                Icons.broken_image,
                                              ),
                                        ),
                                      ),
                                    );
                                  }).toList(),
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 5),
              Padding(
                padding: const EdgeInsets.all(12.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      name,
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    // const SizedBox(height: 8),
                    if (widget.product['productUnits'] < 11 &&
                        widget.product['productUnits'] > 0)
                      Text(
                        'only ' +
                            widget.product['productUnits'].toString() +
                            ' ' +
                            widget.product['productUnitType'].toString() +
                            ' left',
                        style: const TextStyle(
                          color: Colors.red,
                          fontSize: 16,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    // Text(category,
                    //     style: const TextStyle(color: Colors.grey)),
                    Divider(),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        if (price != null &&
                            discountPrice != null &&
                            price > discountPrice &&
                            price > 0)
                          Text(
                            "₹${price.toInt()}",
                            style: const TextStyle(
                              decoration: TextDecoration.lineThrough,
                              color: Colors.grey,
                            ),
                          ),
                        if (price != null &&
                            discountPrice != null &&
                            price > discountPrice &&
                            price > 0)
                          const SizedBox(width: 10),
                        Text(
                          "₹${(discountPrice ?? 0).toInt()}",
                          style: const TextStyle(
                            fontSize: 20,
                            color: Colors.blue,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        if (price != null &&
                            discountPrice != null &&
                            price > discountPrice &&
                            price > 0)
                          const SizedBox(width: 10),
                        if (price != null &&
                            discountPrice != null &&
                            price > discountPrice &&
                            price > 0)
                          Text(
                            "${((price - discountPrice) / price * 100).round()}% OFF",
                            style: const TextStyle(color: Colors.green),
                          ),
                      ],
                    ),

                    Text.rich(
                      TextSpan(
                        children: [
                          TextSpan(
                            text: 'Inclusive of all taxes  |',
                            style: TextStyle(
                              fontSize: 15,
                              color: Colors.black87,
                            ),
                          ),
                          TextSpan(
                            text:
                                '  GST: ' +
                                widget.product['gst'] +
                                '%' +
                                '  |  ',
                            style: TextStyle(
                              fontSize: 15,
                              color: Colors.black87,
                            ),
                          ),
                          TextSpan(
                            text:
                                (widget.product['paymentMethod'] != null &&
                                        widget.product['paymentMethod']
                                            .toString()
                                            .trim()
                                            .isNotEmpty)
                                    ? 'COD Available'
                                    : '',
                            style: TextStyle(fontSize: 15, color: Colors.green),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 25),

                    // ADD TO BAG button
                    // Replace the current ADD TO BAG button section with:
                    Consumer<CartProvider>(
                      builder: (context, cartProvider, child) {
                        final quantity = cartProvider.getQuantity(
                          widget.shopId,
                          widget.product['productId'].toString(),
                        );

                        return quantity > 0
                            ? Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 8,
                              ),
                              decoration: BoxDecoration(
                                border: Border.all(color: Colors.blue),
                                borderRadius: BorderRadius.circular(30),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                // mainAxisAlignment: MainAxisAlignment.start,
                                children: [
                                  GestureDetector(
                                    onTap: () {
                                      cartProvider.decreaseQuantity(
                                        widget.shopId,
                                        widget.product['productId'].toString(),
                                      );
                                    },
                                    child: const Icon(
                                      Icons.remove,
                                      color: Colors.blue,
                                    ),
                                  ),
                                  const SizedBox(width: 20),
                                  Text(
                                    '$quantity',
                                    style: const TextStyle(fontSize: 18),
                                  ),
                                  const SizedBox(width: 20),
                                  GestureDetector(
                                    onTap:
                                        quantity >=
                                                (widget.product['productUnits'] ??
                                                    0)
                                            ? () {} // disables tap when max reached
                                            : () {
                                              cartProvider.addItem(
                                                widget.shopId,
                                                widget.product,
                                              );
                                            },
                                    child: Icon(
                                      Icons.add,
                                      color:
                                          quantity >=
                                                  (widget.product['productUnits'] ??
                                                      0)
                                              ? Colors.grey
                                              : Colors.blue,
                                    ),
                                  ),
                                ],
                              ),
                            )
                            : SizedBox(
                              width: double.infinity,
                              child: ElevatedButton(
                                // onPressed: (widget.product['productUnits'] ?? 0) < 1
                                //     ? null
                                //     : () {
                                //   // your wishlist logic here
                                // },
                                onPressed:
                                    (widget.product['productUnits'] ?? 0) < 1
                                        ? null
                                        : () {
                                          cartProvider.addItem(
                                            widget.shopId,
                                            widget.product,
                                          );
                                        },
                                style: ElevatedButton.styleFrom(
                                  backgroundColor:
                                      widget.product['productUnits'] < 1
                                          ? Colors.white12
                                          : Colors.blue,
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 16,
                                  ),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(20),
                                  ),
                                ),
                                child: const Text(
                                  'ADD TO BAG',
                                  style: TextStyle(
                                    fontSize: 16,
                                    color: Colors.white,
                                  ),
                                ),
                              ),
                            );
                      },
                    ),

                    const SizedBox(height: 15),

                    ElevatedButton(
                      onPressed:
                          (widget.product['productUnits'] ?? 0) < 1
                              ? null
                              : () {
                                // final productId = widget.product['productId'].toString();
                                // final isInWishlistNow = wishlistProvider.isInWishlist(productId);

                                final wishlistProvider =
                                    Provider.of<WishlistProvider>(
                                      context,
                                      listen: false,
                                    );
                                // if (!wishlistProvider.isInitialized) {
                                //   ScaffoldMessenger.of(context).showSnackBar(
                                //     SnackBar(content: Text('Wishlist not ready yet')),
                                //   );
                                //   return;
                                // }

                                final productId =
                                    widget.product['productId'].toString();
                                if (wishlistProvider.isInWishlist(productId)) {
                                  wishlistProvider.removeFromWishlist(
                                    productId,
                                  );
                                } else {
                                  wishlistProvider.addToWishlist(
                                    widget.product,
                                  );
                                }
                              },
                      style: ElevatedButton.styleFrom(
                        elevation: 4,
                        backgroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(20),
                          side: const BorderSide(
                            color: Colors.grey,
                            width: 0.5,
                          ),
                        ),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            wishlistProvider.isInWishlist(
                                  widget.product['productId'].toString(),
                                )
                                ? Icons.remove_circle_outline
                                : CupertinoIcons.heart,
                            color:
                                wishlistProvider.isInWishlist(
                                      widget.product['productId'].toString(),
                                    )
                                    ? Colors.red
                                    : Colors.grey,
                          ),
                          const SizedBox(width: 20),
                          Text(
                            wishlistProvider.isInWishlist(
                                  widget.product['productId'].toString(),
                                )
                                ? 'REMOVE FROM WISHLIST'
                                : 'ADD TO WISHLIST',
                            style: const TextStyle(
                              fontSize: 16,
                              color: Colors.blue,
                            ),
                          ),
                        ],
                      ),
                    ),

                    SizedBox(height: 25),
                    GestureDetector(
                      onTap: () {
                        // Pass the URL string to another file's method or widget
                        showShareDialog(
                          context,
                          "https://" +
                              widget.shopId +
                              ".digistall.in/product/" +
                              widget.product['productId'],
                        );
                      },
                      child: Row(
                        children: const [
                          Icon(Icons.share),
                          SizedBox(width: 15),
                          Text(
                            'Share this product',
                            style: TextStyle(fontSize: 15),
                          ),
                        ],
                      ),
                    ),
                    SizedBox(height: 25),
                    Text(
                      'Product Description',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    SizedBox(height: 5),
                    Divider(),
                    SizedBox(height: 15),
                    Container(
                      padding: EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 5,
                      ),
                      width: double.infinity,
                      decoration: BoxDecoration(
                        color: Colors.grey.shade200,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text.rich(
                        TextSpan(
                          children: [
                            TextSpan(
                              text: 'UNIT TYPE: ',
                              style: TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            TextSpan(
                              text: widget.product['productUnitType'],
                              style: TextStyle(fontSize: 16),
                            ),
                          ],
                        ),
                      ),
                    ),
                    SizedBox(height: 10),
                    Text(description, style: TextStyle(fontSize: 15)),

                    SizedBox(height: 25),
                    Text(
                      'Product You May Like',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    SizedBox(height: 5),
                    Divider(),
                    SizedBox(height: 15),
                    _buildFilteredProductGrid(),
                    // ADD TO WISHLIST
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    if (shopHeader.isEmpty) return const SizedBox.shrink();

    return Container(
      padding: const EdgeInsets.all(12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          const SizedBox(width: 20),
          shopHeader['logo'] != null
              ? Image.network(shopHeader['logo'], width: 40)
              : const Icon(Icons.store, size: 40),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Text(
                  shopHeader['shopName'] ?? '',
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  shopHeader['email'] ?? '',
                  style: const TextStyle(color: Colors.black),
                ),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.call, color: Colors.green),
            onPressed: () async {
              var rawPhone = shopHeader['phoneNumber'] ?? '';
              var phone = rawPhone.replaceAll(RegExp(r'\D'), '');

              if (phone.isEmpty) {
                //back print("Phone number is empty");
                return;
              }

              final whatsappUrl = Uri.parse("https://wa.me/$phone");

              if (await canLaunchUrl(whatsappUrl)) {
                await launchUrl(
                  whatsappUrl,
                  mode: LaunchMode.externalApplication,
                );
              } else {
                //back print("Could not launch WhatsApp URL");
              }
            },
          ),
        ],
      ),
    );
  }

  Widget _buildFilteredProductGrid() {
    // Filter out the current product from the maylike list
    final filteredProducts =
        widget.maylike
            .where(
              (product) => product['productId'] != widget.product['productId'],
            )
            .toList();

    return filteredProducts.isEmpty
        ? Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            height: 200,
            child: Lottie.asset('assets/animations/empty_tasks.json'),
          ),
          const SizedBox(height: 16),
          const Text(
            'No products or categories found',
            style: TextStyle(
                color: Colors.grey,
                fontWeight: FontWeight.bold,
                fontSize: 16),
          ),
          const SizedBox(height: 16),
        ],
      ),
    )
        : LayoutBuilder(
      builder: (context, constraints) {
        // Calculate crossAxisCount based on screen width
        final crossAxisCount = constraints.maxWidth > 600 ? 3 : 2;

        // Adjust childAspectRatio based on screen size
        final childAspectRatio = constraints.maxWidth > 600 ? 0.75 : 0.67;

        return GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          padding: const EdgeInsets.symmetric(horizontal: 5),
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: crossAxisCount,
            childAspectRatio: childAspectRatio,
            crossAxisSpacing: 16,
            mainAxisSpacing: 16,
          ),
          itemCount: filteredProducts.length,
          itemBuilder: (context, index) {
            final product = filteredProducts[index];
            return _buildProductCard(
                context, product, widget.shopId);
          },
        );
      },
    );
  }

  Widget _buildProductCard(BuildContext context, dynamic product, String storeId) {
    final cartProvider = Provider.of<CartProvider>(context);
    int quantity = cartProvider.getQuantity(storeId, product['productId'].toString());

    final name = product['productName'] ?? '';
    final category = product['productCategory'] ?? '';
    final imageUrl = (product['productImages'] as List).isNotEmpty
        ? product['productImages'][0]
        : '';
    final price = product['productPrice'] ?? 0;
    final discountPrice = product['productdiscountPrice'] ?? 0;
    final units = product['productUnits'] ?? 0;
    final unitType = product['productUnitType'] ?? '';
    final productRibbon = product['productRibbon'] ?? '';
    final description = product['productDescription'] ?? '';

    // If quantity exceeds available units, remove from cart
    if (quantity > units) {
      Future.microtask(() {
        cartProvider.updateQuantity(
          storeId,
          product['productId'].toString(),
          units,
        );
      });
      quantity = units;
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        return InkWell(
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => ProductDetailScreen(
                    product: product, shopId: widget.shopId, maylike: widget.maylike,),
              ),
            );
          },
          child: Card(
            elevation: 2,
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12)),
            margin: EdgeInsets.zero,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Image Section
                AspectRatio(
                  aspectRatio: 1.5,
                  child: Stack(
                    children: [
                      ClipRRect(
                        borderRadius: const BorderRadius.only(
                          topLeft: Radius.circular(12),
                          topRight: Radius.circular(12),
                        ),
                        child: CachedNetworkImage(
                          imageUrl: imageUrl,
                          width: double.infinity,
                          fit: BoxFit.cover,
                          errorWidget: (_, __, ___) =>
                              Center(child: const Icon(Icons.broken_image)),
                          fadeInDuration: const Duration(milliseconds: 300),
                          fadeOutDuration: const Duration(milliseconds: 300),
                        ),
                      ),
                      if (productRibbon.isNotEmpty)
                        Positioned(
                          right: 8,
                          top: 8,
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: Colors.blue,
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Text(
                              productRibbon,
                              style: const TextStyle(
                                  color: Colors.white, fontSize: 10),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),

                // Product Info Section
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.all(8.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          name,
                          style: const TextStyle(fontWeight: FontWeight.bold),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 4),
                        Text(
                          category,
                          style: const TextStyle(color: Colors.grey, fontSize: 12),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        Row(
                          children: [
                            if (price > discountPrice)
                              Text(
                                "₹${price.toInt()}",
                                style: const TextStyle(
                                    color: Colors.grey,
                                    decoration: TextDecoration.lineThrough,
                                    fontSize: 12),
                              ),
                            const SizedBox(width: 4),
                            Text(
                              "₹${discountPrice.toInt()}",
                              style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: Colors.blue,
                                  fontSize: 14),
                            ),
                          ],
                        ),
                        // const Spacer(),

                      ],
                    ),
                  ),
                ),


                // Add to Cart Section
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  child: quantity > 0
                      ? Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      IconButton(
                        icon: const Icon(Icons.remove_circle_outline,
                            color: Colors.blue, size: 20),
                        onPressed: () {
                          cartProvider.decreaseQuantity(
                              storeId, product['productId'].toString());
                        },
                      ),
                      Text('$quantity',
                          style: const TextStyle(fontSize: 14)),
                      IconButton(
                        icon: Icon(
                          Icons.add_circle_outline,
                          color: quantity >= units
                              ? Colors.grey
                              : Colors.blue,
                          size: 20,
                        ),
                        onPressed: quantity >= units
                            ? null
                            : () {
                          cartProvider.addItem(storeId, product);
                        },
                      ),
                    ],
                  )
                      : Row(
                    children: [
                      Expanded(
                        child: ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: units < 1
                                ? Colors.grey.shade400
                                : Colors.blue,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(20),
                            ),
                            padding: const EdgeInsets.symmetric(vertical: 8),
                          ),
                          onPressed: units < 1
                              ? null
                              : () {
                            cartProvider.addItem(storeId, product);
                          },
                          child: Text(
                            units < 1 ? "OUT OF STOCK" : "ADD TO BAG",
                            style: const TextStyle(
                                fontSize: 12, color: Colors.white),
                          ),
                        ),
                      ),
                      if (quantity == 0) ...[
                        const SizedBox(width: 8),
                        IconButton(
                          icon: const Icon(Icons.share,
                              color: Colors.blue, size: 20),
                          onPressed: () {
                            showShareDialog(
                              context,
                              "https://${widget.shopId}.digistall.in/product/${product['productId']}",
                            );
                          },
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
