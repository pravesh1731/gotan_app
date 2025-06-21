import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:gotan/global/common.dart';
import 'package:http/http.dart' as http;
import 'package:url_launcher/url_launcher.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:lottie/lottie.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import '../providers/CartProvider.dart';
import '../widgets/TeamSection.dart';
import '../widgets/share_dialog.dart';
import 'ProductDetailScreen.dart';

class ShopScreen extends StatefulWidget {
  final String shopId;


  const ShopScreen({
    Key? key,
    required this.shopId,
  }) : super(key: key);

  @override
  State<ShopScreen> createState() => _ShopScreenState();
}

class _ShopScreenState extends State<ShopScreen> {
  Map<String, dynamic> shopResponse = {};
  Map<String, dynamic> shopResponse_header = {};
  Map<String, dynamic> shopResponse_footer = {};
  List<dynamic> shopResponse_team = [];
  List<dynamic> products = [];
  List<dynamic> categorys = [];
  int _currentIndex = 2;

  List<dynamic> filteredProducts = [];
  String selectedcategoryName = '';
  List<dynamic> allProducts = [];

  FocusNode _focusNode = FocusNode();
  bool _isFocused = false;

  TextEditingController _searchController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  // final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocusNode = FocusNode();

  bool _isVisible = true;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(() {
      //back print('Scroll position: ${_scrollController.position.pixels}');
    });

    _searchController.addListener(() {
      filterProductsBySearch();
    });
    fetchShopData();

    // FocusScope.of(context).requestFocus(_searchFocusNode);

    _searchFocusNode.addListener(() {
      if (_searchFocusNode.hasFocus) {
        // Delay scrolling until after build completes
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (_scrollController.hasClients) {
            _scrollController.animateTo(
              0, // scroll offset 0 = top
              duration: const Duration(milliseconds: 300),
              curve: Curves.easeInOut,
            );
          }
        });
      }
    });
  }

  @override
  void dispose() {
    _focusNode.dispose();
    _searchController.dispose();
    _scrollController.dispose();
    // _searchController.dispose();
    _searchFocusNode.dispose();
    super.dispose();
  }

  void filterProductsBySearch() {
    final query = _searchController.text.toLowerCase();

    setState(() {
      if (query.isEmpty) {
        filteredProducts = allProducts;
      } else {
        filteredProducts = allProducts.where((product) {
          final productName = product['productName']?.toLowerCase() ?? '';
          final categoryName = product['productCategory']?.toLowerCase() ?? '';
          return productName.contains(query) || categoryName.contains(query);
        }).toList();
      }
    });
  }


  Future<void> fetchShopData() async {
    final url = Uri.parse(Common.digiBaseUrl + 'shop');
    print(widget.shopId);
    final response = await http.post(
      url,
      headers: {"Content-Type": "application/json"},
      body: jsonEncode({"shopId": widget.shopId}),
    );

    if (response.statusCode == 200) {
      final json = jsonDecode(response.body);
      print('====');
      print(json);
      setState(() {
        shopResponse = json['response'];
        products = shopResponse['products'];
        categorys = shopResponse['categorys'];
        allProducts = shopResponse['products'];
        filteredProducts = allProducts; // Show all initially
        shopResponse_header = shopResponse['settings']['header'];
        shopResponse_footer = shopResponse['settings']['footer'];
        shopResponse_team = shopResponse['settings']['team'];
      });

      // Save to SharedPreferences
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('shopHeader', jsonEncode(shopResponse['settings']['header']));
      await prefs.setString('QRCode', jsonEncode(shopResponse['QRCode']));
      await prefs.setString('upiId', jsonEncode(shopResponse['upiId']));
      await prefs.setString('deliverPp', jsonEncode(shopResponse['deliverPp']));
      await prefs.setString('defaultDeliveryDate', jsonEncode(shopResponse['defaultDeliveryDate']));

    }
  }

  Future<void> _handleRefresh() async {
    await Future.delayed(Duration(seconds: 2)); // simulate delay
    setState(() {
      fetchShopData();
      // update your data here
    });
  }


  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: GestureDetector(
        onTap: () {
          _searchFocusNode.unfocus(); // This removes focus from the TextField
        },
        child: shopResponse.isEmpty
            ? const Center(child: CircularProgressIndicator())
            : SafeArea(
          child: RefreshIndicator(
            onRefresh: _handleRefresh,
            color: Colors.deepPurple,              // Spinner color
            // backgroundColor: Color(0xFF265DFF),
            child: SingleChildScrollView(
              controller: _scrollController,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildHeader(),
                  _buildImageHeader(shopResponse_header),
                  const SizedBox(height: 10),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 15),
                    child: Card(
                      elevation: 4,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(24),
                      ),
                      margin: EdgeInsets.zero,
                      child: Container(
                        height: 45,
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(24),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.search, color: Colors.grey),
                            const SizedBox(width: 10),
                            Expanded(
                              child: TextField(
                                controller: _searchController,
                                focusNode: _searchFocusNode, // Add this
                                decoration: const InputDecoration(
                                  hintText: 'Search for Products and categorys',
                                  hintStyle: TextStyle(color: Colors.grey),
                                  border: InputBorder.none,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                  _buildCategoryList(), // ✅ CATEGORY BAR HERE
                  const SizedBox(height: 10),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 12.0),
                    child:
                    Text("Products", style: Theme.of(context).textTheme.titleMedium),
                  ),
                  const SizedBox(height: 10),
                  _buildFilteredProductGrid(),
                  const SizedBox(height: 10),
                  Divider(),
                  const SizedBox(height: 10),

                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16.0),
                    child: TeamSection(shopResponseTeam: shopResponse_team),
                  ),
                  Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            const Icon(Icons.remove_red_eye, color: Colors.blue),
                            const SizedBox(width: 8),
                            Text(
                              '${shopResponse['count'] ?? 0}',
                              style: const TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(width: 8),
                            const Text('Total visits'),
                          ],
                        ),

                        IconButton(
                          icon: const Icon(Icons.call, color: Colors.green),
                          onPressed: () {
                            // Add WhatsApp action here
                          },
                        ),
                      ],
                    ),
                  ),
                  // const SizedBox(height: 24),

                  // About Section
                  Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Text(
                      'About ${(shopResponse['shopName'] ?? '').toString().toUpperCase()}',
                      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16.0),
                    child: Text(
                      shopResponse_footer['about'] ?? '',
                      style: const TextStyle(fontSize: 14),
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Address
                  if (shopResponse_footer['isAddressVisible'] == true) ...[
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16.0),
                      child: const Text(
                        'Address',
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16.0),
                      child: Text(shopResponse_footer['address'] ?? ''),
                    ),
                    const SizedBox(height: 24),
                  ],

                  // Social Media Icons
                  if (shopResponse_footer['isSocialSitesVisible'] == true) ...[
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16.0),
                      child: const Text(
                        'Follow Us',
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16.0),
                      child: Row(
                        children: [
                          _buildSocialIcon(shopResponse_footer['instgramUrl'], FontAwesomeIcons.instagram),
                          _buildSocialIcon(shopResponse_footer['youtubeUrl'], FontAwesomeIcons.youtube),
                          _buildSocialIcon(shopResponse_footer['facebookUrl'], FontAwesomeIcons.facebook),
                        ],
                      ),
                    ),
                    SizedBox(height: 20,),
                  ],// Only shows filteredProducts
                ],
              ),
            ),
          ),
        ),
      ),
      // bottomNavigationBar: _buildBottomNavBar(),
    );
  }

  Widget _buildSocialIcon(String? url, IconData icon) {
    return Padding(
      padding: const EdgeInsets.only(right: 16),
      child: GestureDetector(
        onTap: () {
          final fullUrl = url?.startsWith('http') == true ? url! : 'https://$url';
          // Launch logic here using url_launcher if needed
        },
        child: CircleAvatar(
          backgroundColor: Colors.grey[200],
          radius: 20,
          child: FaIcon(icon, size: 20, color: Colors.black),
        ),
      ),
    );
  }


  Widget _buildFilteredProductGrid() {
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
          padding: const EdgeInsets.symmetric(horizontal: 16),
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: crossAxisCount,
            childAspectRatio: childAspectRatio,
            crossAxisSpacing: 16,
            mainAxisSpacing: 16,
          ),
          itemCount: filteredProducts.length,
          itemBuilder: (context, index) {
            final product = filteredProducts[index];
            final matchedCategory = categorys.firstWhere(
                  (cat) => cat['categoryName'] == product['productCategory'],
              orElse: () => null,
            );

            if (matchedCategory != null) {
              product['gst'] = matchedCategory['gst'].toString();
            } else {
              product['gst'] = '0';
            }

            if (shopResponse['paymentMethod'] != null) {
              product['paymentMethod'] =
                  shopResponse['paymentMethod'].toString();
            } else {
              product['paymentMethod'] = '';
            }

            List<dynamic> mayLike = allProducts.where((prod) {
              return prod['productCategory'] == product['productCategory'];
            }).toList();

            return _buildProductCard(
                context, product, widget.shopId, mayLike);
          },
        );
      },
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.all(12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          const SizedBox(width: 20),
          // Image.network(shopResponse_header['logo'], width: 40),
          shopResponse_header['logo'] != null
              ? Image.network(shopResponse_header['logo'], width: 40)
              : const Icon(Icons.store, size: 40),
          // const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Text(
                  shopResponse_header['shopName'] ?? '',
                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                Text(
                  shopResponse_header['email'] ?? '',
                  style: const TextStyle(color: Colors.black),
                ),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.call, color: Colors.green),
            onPressed: () async {
              var rawPhone = shopResponse_header['phoneNumber'] ?? '';
              var phone = rawPhone.replaceAll(RegExp(r'\D'), ''); // Remove non-digit characters

              if (phone.isEmpty) {
                //back print("Phone number is empty");
                return;
              }

              final whatsappUrl = Uri.parse("https://wa.me/$phone");

              // Check if the URL can be launched
              if (await canLaunchUrl(whatsappUrl)) {
                // Try launching in an external browser or app (not in-app web view)
                await launchUrl(
                  whatsappUrl,
                  mode: LaunchMode.externalApplication,
                );
              } else {
                //back print("Could not launch WhatsApp URL");
              }
            },
          )

        ],
      ),
    );
  }

  // Widget _buildProductGrid() {
  //   return GridView.builder(
  //     shrinkWrap: true, // Important: allows GridView inside SingleChildScrollView
  //     physics: const NeverScrollableScrollPhysics(), // Prevent nested scrolling
  //     padding: const EdgeInsets.all(8),
  //     gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
  //       crossAxisCount: 2,
  //       childAspectRatio: 0.67,
  //       crossAxisSpacing: 10,
  //       mainAxisSpacing: 10,
  //     ),
  //     itemCount: products.length,
  //     itemBuilder: (context, index) {
  //       final product = products[index];
  //
  //
  //       return _buildProductCard(context, product, widget.shopId);
  //     },
  //   );
  // }


  Widget _buildProductCard(BuildContext context, dynamic product, String storeId, List<dynamic> mayLike) {
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
            _searchFocusNode.unfocus();
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => ProductDetailScreen(
                    product: product, shopId: widget.shopId, maylike: mayLike),
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



  Widget _buildBottomNavBar() {
    return BottomNavigationBar(
      currentIndex: _currentIndex,
      type: BottomNavigationBarType.fixed,
      onTap: (index) {
        setState(() {
          _currentIndex = index;
        });
        // Add navigation logic if needed
      },
      items: const [
        BottomNavigationBarItem(icon: Icon(Icons.favorite_border), label: 'Wishlist'),
        BottomNavigationBarItem(icon: Icon(Icons.shopping_bag_outlined), label: 'Bag'),
        BottomNavigationBarItem(icon: Icon(Icons.home), label: 'Home'),
        BottomNavigationBarItem(icon: Icon(Icons.history), label: 'History'),
        BottomNavigationBarItem(icon: Icon(Icons.login), label: 'Login'),
      ],
    );
  }

  Widget _buildCategoryList() {
    return Container(
      height: 110,
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        itemCount: categorys.length,
        itemBuilder: (context, index) {
          final category = categorys[index];
          final isSelected = selectedcategoryName == category['categoryName'];

          return GestureDetector(
            onTap: () {
              setState(() {
                selectedcategoryName = category['categoryName'];
                //back print(selectedcategoryName);
                //back print('-----');

                filteredProducts = selectedcategoryName == 'All Categorys'
                    ? allProducts
                    : allProducts
                    .where((product) =>
                product['productCategory'] == selectedcategoryName)
                    .toList();
              });
            },
            child: Container(
              margin: const EdgeInsets.symmetric(horizontal: 8),
              child: Column(
                children: [
                  Container(
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: isSelected ? Colors.blue : Colors.transparent,
                        width: 3,
                      ),
                    ),
                    child: CircleAvatar(
                      radius: 30,
                      backgroundColor: (category['categoryImg'] == null || category['categoryImg'].toString().isEmpty)
                          ? Colors.grey.shade300
                          : Colors.transparent,
                      backgroundImage: (category['categoryImg'] != null && category['categoryImg'].toString().isNotEmpty)
                          ? NetworkImage(category['categoryImg'])
                          : null,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    category['categoryName'],
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                      color: isSelected ? Colors.blue : Colors.black,
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

}

Widget _buildImageHeader(Map<String, dynamic> shopResponse_header ) {
  final bannerImage = shopResponse_header['logo'] ?? ''; // Change key if needed

  return Stack(
    children: [
      // Background Image
      CachedNetworkImage(
        imageUrl: bannerImage,
        width: double.infinity,
        height: 220,
        fit: BoxFit.cover,
        placeholder: (context, url) => Container(
          width: double.infinity,
          height: 220,
          color: Colors.grey.shade200,
        ),
        errorWidget: (context, url, error) => Container(
          width: double.infinity,
          height: 220,
          color: Colors.grey.shade300,
          child: const Icon(Icons.broken_image, size: 50),
        ),
      ),

      // Overlay gradient (optional for better text visibility)
      Container(
        width: double.infinity,
        height: 220,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [Colors.black.withOpacity(0.3), Colors.transparent],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
      ),

      // "Discover Now" button and search bar
      Positioned(
        top: 140,
        left: 20,
        right: 20,
        child: Column(
          children: [
            ElevatedButton(
              onPressed: () {
                // Your navigation logic
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.deepPurple,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 10),
              ),
              child: const Text("Discover Now", style: TextStyle(color: Colors.white)),
            ),
          ],
        ),
      ),
    ],
  );
}

