import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;
import 'package:permission_handler/permission_handler.dart';
import 'package:provider/provider.dart';

import '../global/common.dart';
import '../model/booking.dart';
import '../model/shop.dart';
import '../providers/UserProvider.dart';
import '../services/api.dart';
import '../services/session.dart';
import '../theme/app_theme.dart';
import '../utils/launch.dart';
import '../widgets/ui.dart';
import 'BookingHistoryScreen.dart';
import 'BookingTrackingScreen.dart';
import 'MyProfileScreen.dart';
import 'OrderHistoryPage.dart';
import 'PhoneInputPage.dart';
import 'booking_flow.dart';
import 'shopMainScreen.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _ShopFormat {
  final String id;
  final String title;
  final String subtitle;
  final Color bg;
  final Color fg;
  final IconData icon;
  const _ShopFormat(this.id, this.title, this.subtitle, this.bg, this.fg, this.icon);
}

class _HomePageState extends State<HomePage> {
  // Same tags and formats as the website (mainContainer.jsx / ShopFormats.jsx).
  static const _categories = [
    ('All', 'assets/images/store.png'),
    ('Grocery', 'assets/images/Grocery1.png'),
    ('Herbal', 'assets/images/herbal.jpg'),
    ('Stationary', 'assets/images/Stationary.png'),
  ];
  static const _formats = [
    _ShopFormat('super-mart', 'Super Mart', 'Everything stores', AppColors.pastelBlue, Color(0xFF3B82F6),
        FontAwesomeIcons.shop),
    _ShopFormat('dairy-mart', 'Dairy Mart', 'Milk & fresh dairy', AppColors.pastelYellow, Color(0xFFCA8A04),
        FontAwesomeIcons.whiskeyGlass),
    _ShopFormat('sweets', 'Sweets & Snacks', 'Halwai shops', AppColors.pastelPink, Color(0xFFEC4899),
        FontAwesomeIcons.cookieBite),
    _ShopFormat('vegetables', 'Vegetable Market', 'Fresh sabzi daily', AppColors.pastelGreen, Color(0xFF22C55E),
        FontAwesomeIcons.leaf),
  ];

  // The visitor counter increments on every call, so count once per launch.
  static int? _cachedVisits;

  final _scrollController = ScrollController();
  final _searchController = TextEditingController();
  final _searchFocus = FocusNode();
  final _servicesKey = GlobalKey();
  final _earnKey = GlobalKey();
  final _shopsKey = GlobalKey();
  Timer? _debounce;

  String _selectedTag = 'All';
  _ShopFormat? _selectedFormat;
  String _search = '';
  String _activeTab = 'Shop';

  List<Shop> _shops = [];
  List<Map<String, dynamic>> _matchedProducts = [];
  bool _loadingShops = true;
  String? _shopsError;
  int _shopsRequest = 0;

  int? _visits = _cachedVisits;
  String _temperature = '';
  Booking? _activeRide;
  Booking? _activeParcel;
  DateTime? _lastBackPressed;

  @override
  void initState() {
    super.initState();
    _loadShops();
    _loadVisits();
    _loadWeather();
    _loadActiveBookings();
    WidgetsBinding.instance.addPostFrameCallback((_) => _askNotificationPermissionOnce());
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _scrollController.dispose();
    _searchController.dispose();
    _searchFocus.dispose();
    super.dispose();
  }

  // ------------------------------------------------------------------ data

  Future<void> _loadShops() async {
    final request = ++_shopsRequest;
    setState(() {
      _loadingShops = true;
      _shopsError = null;
    });
    try {
      final result = await Api.getShops(search: _search, tag: _selectedTag, format: _selectedFormat?.id);
      if (!mounted || request != _shopsRequest) return;
      setState(() {
        _shops = result.shops;
        _matchedProducts = _search.isEmpty ? [] : result.matchedProducts;
        _loadingShops = false;
      });
    } catch (e) {
      if (!mounted || request != _shopsRequest) return;
      setState(() {
        _loadingShops = false;
        _shopsError = e.toString();
      });
    }
  }

  Future<void> _loadVisits() async {
    if (_cachedVisits != null) return;
    try {
      final count = await Api.visitCount();
      _cachedVisits = count;
      if (mounted) setState(() => _visits = count);
    } catch (_) {
      // The counter is decorative; ignore failures.
    }
  }

  Future<void> _loadWeather() async {
    try {
      final permission = await Geolocator.checkPermission();
      if (permission != LocationPermission.always && permission != LocationPermission.whileInUse) return;
      final pos = await Geolocator.getLastKnownPosition() ??
          await Geolocator.getCurrentPosition(
            locationSettings: const LocationSettings(accuracy: LocationAccuracy.low, timeLimit: Duration(seconds: 8)),
          );
      final uri = Uri.parse('https://api.openweathermap.org/data/2.5/weather'
          '?lat=${pos.latitude}&lon=${pos.longitude}&units=metric&appid=${Common.weatherApiKey}');
      final res = await http.get(uri).timeout(const Duration(seconds: 10));
      if (res.statusCode != 200) return;
      final temp = (jsonDecode(res.body)['main']?['temp'] as num?)?.round();
      if (temp != null && mounted) setState(() => _temperature = '$temp°C');
    } catch (_) {
      // Weather is optional.
    }
  }

  Future<void> _loadActiveBookings() async {
    final phone = await Session.phone();
    if (phone == null) {
      if (mounted) setState(() => _activeRide = _activeParcel = null);
      return;
    }
    Future<Booking?> check(BookingKind kind) async {
      final ride = kind == BookingKind.ride;
      final id = await Session.activeOrderId(ride: ride);
      if (id == null) return null;
      try {
        final booking = await Api.getBooking(kind, phone, id);
        if (booking == null || !booking.isActive) {
          await Session.clearActiveOrderId(ride: ride);
          return null;
        }
        return booking;
      } catch (_) {
        return null; // Keep the id; we'll retry on the next refresh.
      }
    }

    final results = await Future.wait([check(BookingKind.ride), check(BookingKind.parcel)]);
    if (!mounted) return;
    setState(() {
      _activeRide = results[0];
      _activeParcel = results[1];
    });
  }

  Future<void> _askNotificationPermissionOnce() async {
    final prefs = await Session.prefs;
    if (prefs.getBool('asked_notification_permission') == true) return;
    await prefs.setBool('asked_notification_permission', true);
    try {
      await Permission.notification.request();
    } catch (_) {}
  }

  Future<void> _refresh() async {
    await Future.wait([
      _loadShops(),
      _loadActiveBookings(),
      _loadWeather(),
      if (context.read<UserProvider>().isLoggedIn)
        context.read<UserProvider>().refresh().then((_) {}, onError: (_) {}),
    ]);
  }

  void _onSearchChanged(String value) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 450), () {
      if (value.trim() == _search) return;
      _search = value.trim();
      _loadShops();
    });
  }

  void _selectTag(String tag) {
    setState(() {
      _selectedTag = tag;
      _search = '';
      _searchController.clear();
    });
    _loadShops();
  }

  void _selectFormat(_ShopFormat? format) {
    setState(() => _selectedFormat = format);
    _loadShops();
    if (format != null) _scrollTo(_shopsKey);
  }

  void _scrollTo(GlobalKey key) {
    final ctx = key.currentContext;
    if (ctx != null) {
      Scrollable.ensureVisible(ctx, duration: const Duration(milliseconds: 400), curve: Curves.easeOutCubic);
    }
  }

  // ------------------------------------------------------------- navigation

  Future<void> _book(BookingKind kind) async {
    _searchFocus.unfocus();
    await startBooking(context, kind);
    _loadActiveBookings();
  }

  void _openShop(Shop shop) {
    _searchFocus.unfocus();
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => ShopMainScreen(shopId: shop.shopId, shopName: shop.heading, shopImage: shop.shopImage)),
    );
  }

  Future<void> _openTracking(Booking booking) async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => BookingTrackingScreen(kind: booking.kind, orderId: booking.id)),
    );
    _loadActiveBookings();
  }

  Future<bool> _confirmExit() async {
    if (_searchFocus.hasFocus) {
      _searchFocus.unfocus();
      return false;
    }
    final now = DateTime.now();
    if (_lastBackPressed == null || now.difference(_lastBackPressed!) > const Duration(seconds: 2)) {
      _lastBackPressed = now;
      showAppSnack(context, 'Press back again to exit');
      return false;
    }
    return true;
  }

  // ----------------------------------------------------------------- build

  @override
  Widget build(BuildContext context) {
    final user = context.watch<UserProvider>();

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop) return;
        if (await _confirmExit()) SystemNavigator.pop();
      },
      child: AnnotatedRegion<SystemUiOverlayStyle>(
        value: AppTheme.lightStatusBar,
        child: Scaffold(
          backgroundColor: AppColors.surface,
          drawer: MainDrawer(onChanged: _loadActiveBookings),
          body: Builder(
            builder: (scaffoldContext) => RefreshIndicator(
              onRefresh: _refresh,
              color: AppColors.teal,
              child: CustomScrollView(
                controller: _scrollController,
                physics: const AlwaysScrollableScrollPhysics(),
                slivers: [
                  SliverToBoxAdapter(child: _buildTopSection(scaffoldContext, user)),
                  SliverToBoxAdapter(child: _buildPromoBanner()),
                  SliverToBoxAdapter(child: _buildFilterTabs()),
                  SliverToBoxAdapter(child: _buildCategories()),
                  SliverToBoxAdapter(child: _buildFormats()),
                  if (_matchedProducts.isNotEmpty) SliverToBoxAdapter(child: _buildMatchedProducts()),
                  SliverToBoxAdapter(child: _buildShopsHeader()),
                  _buildShopList(),
                  SliverToBoxAdapter(child: _buildCounter()),
                  const SliverToBoxAdapter(child: HomeFooter()),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTopSection(BuildContext scaffoldContext, UserProvider user) {
    final firstName = user.isLoggedIn && user.name != 'Customer' ? user.name.split(' ').first : null;
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [AppColors.pastelBlue, AppColors.surface],
        ),
      ),
      child: SafeArea(
        bottom: false,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Navbar
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 8, 0),
              child: Row(
                children: [
                  Image.asset('assets/images/gologo.png', height: 34),
                  const Spacer(),
                  const Icon(Icons.location_on_outlined, color: AppColors.teal, size: 19),
                  const SizedBox(width: 2),
                  Text(
                    _temperature.isEmpty ? Common.cityName : '${Common.cityName} · $_temperature',
                    style: const TextStyle(fontWeight: FontWeight.w600, color: AppColors.textSecondary, fontSize: 13),
                  ),
                  const SizedBox(width: 4),
                  IconButton(
                    tooltip: 'Menu',
                    icon: const Icon(Icons.segment_rounded, size: 28, color: AppColors.textPrimary),
                    onPressed: () {
                      _searchFocus.unfocus();
                      Scaffold.of(scaffoldContext).openDrawer();
                    },
                  ),
                ],
              ),
            ),
            // Hero
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 20, 16, 16),
              child: Text.rich(
                TextSpan(
                  text: firstName == null ? 'Hey! ' : 'Hey $firstName! ',
                  children: const [
                    TextSpan(text: 'What are you looking for?', style: TextStyle(color: AppColors.teal)),
                  ],
                ),
                style: const TextStyle(
                  fontSize: 28,
                  height: 1.2,
                  fontWeight: FontWeight.w700,
                  letterSpacing: -0.4,
                  color: AppColors.textPrimary,
                ),
              ),
            ),
            if (_activeRide != null) _ActiveBookingBanner(booking: _activeRide!, onTap: () => _openTracking(_activeRide!)),
            if (_activeParcel != null)
              _ActiveBookingBanner(booking: _activeParcel!, onTap: () => _openTracking(_activeParcel!)),
            // Primary actions
            Padding(
              key: _servicesKey,
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
              child: Row(
                children: [
                  Expanded(
                    child: _PrimaryActionCard(
                      icon: FontAwesomeIcons.motorcycle,
                      iconColor: AppColors.yellow,
                      iconBg: AppColors.yellowLight,
                      title: 'Book a Rider',
                      subtitle: 'Pickup & drop, 15 min',
                      onTap: () => _book(BookingKind.ride),
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: _PrimaryActionCard(
                      icon: FontAwesomeIcons.boxOpen,
                      iconColor: AppColors.teal,
                      iconBg: AppColors.tealLight,
                      title: 'Deliver a Parcel',
                      subtitle: 'Send anywhere in Gotan',
                      onTap: () => _book(BookingKind.parcel),
                    ),
                  ),
                ],
              ),
            ),
            // Search
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 10, 16, 8),
              child: Container(
                decoration: BoxDecoration(borderRadius: BorderRadius.circular(AppRadius.lg), boxShadow: AppShadows.soft),
                child: TextField(
                  controller: _searchController,
                  focusNode: _searchFocus,
                  textInputAction: TextInputAction.search,
                  onChanged: (v) {
                    setState(() {});
                    _onSearchChanged(v);
                  },
                  onSubmitted: (v) {
                    _debounce?.cancel();
                    _search = v.trim();
                    _loadShops();
                    _scrollTo(_shopsKey);
                  },
                  decoration: InputDecoration(
                    hintText: 'Search groceries, sweets, dairy, shops...',
                    prefixIcon: const Icon(Icons.search_rounded, color: AppColors.textSecondary),
                    suffixIcon: _searchController.text.isEmpty
                        ? null
                        : IconButton(
                            icon: const Icon(Icons.close_rounded, size: 20),
                            onPressed: () {
                              _searchController.clear();
                              _search = '';
                              setState(() {});
                              _loadShops();
                            },
                          ),
                    contentPadding: const EdgeInsets.symmetric(vertical: 16),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPromoBanner() {
    return Padding(
      key: _earnKey,
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 20),
      child: Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(color: AppColors.navy, borderRadius: BorderRadius.circular(AppRadius.xl)),
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            Positioned(
              right: -40,
              top: -40,
              child: Container(
                width: 130,
                height: 130,
                decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.05), shape: BoxShape.circle),
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 8,
                      height: 8,
                      decoration: const BoxDecoration(color: AppColors.yellow, shape: BoxShape.circle),
                    ),
                    const SizedBox(width: 8),
                    const Expanded(
                      child: Text(
                        'Own a shop or a bike? Earn with Gotan',
                        style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 15),
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                      decoration: BoxDecoration(color: AppColors.yellow, borderRadius: BorderRadius.circular(4)),
                      child: const Text(
                        '100% FREE',
                        style: TextStyle(color: AppColors.navy, fontSize: 10, fontWeight: FontWeight.w800, letterSpacing: 0.6),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 18),
                _EarnTile(
                  icon: FontAwesomeIcons.store,
                  iconColor: AppColors.teal,
                  title: 'Open your DigiStall',
                  subtitle: 'Sell to all of Gotan • your own store link',
                  action: 'Register',
                  onTap: () => openExternal(context, Common.digistallUrl),
                ),
                const SizedBox(height: 10),
                _EarnTile(
                  icon: FontAwesomeIcons.motorcycle,
                  iconColor: AppColors.yellow,
                  title: 'Ride & Earn',
                  subtitle: 'Deliver orders & parcels • weekly payouts',
                  action: 'Join',
                  onTap: () => openExternal(context, Common.riderUrl),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFilterTabs() {
    Widget tab(String name, IconData icon, Color iconColor, GlobalKey target) {
      final active = _activeTab == name;
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 5),
        child: Material(
          color: active ? const Color(0xFF182531) : AppColors.surface,
          shape: StadiumBorder(side: BorderSide(color: active ? const Color(0xFF182531) : AppColors.border)),
          child: InkWell(
            customBorder: const StadiumBorder(),
            onTap: () {
              setState(() => _activeTab = name);
              _scrollTo(target);
            },
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
              child: Row(
                children: [
                  FaIcon(icon, size: 14, color: iconColor),
                  const SizedBox(width: 8),
                  Text(
                    name,
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 13,
                      color: active ? Colors.white : AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          tab('Shop', FontAwesomeIcons.bagShopping, const Color(0xFFF472B6), _shopsKey),
          tab('Services', FontAwesomeIcons.screwdriverWrench, const Color(0xFFFACC15), _servicesKey),
          tab('Earn', FontAwesomeIcons.briefcase, const Color(0xFF92400E), _earnKey),
        ],
      ),
    );
  }

  Widget _buildCategories() {
    return Padding(
      padding: const EdgeInsets.only(top: 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SectionHeader(title: 'Categories'),
          const SizedBox(height: 14),
          SizedBox(
            height: 100,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              itemCount: _categories.length,
              separatorBuilder: (_, __) => const SizedBox(width: 16),
              itemBuilder: (context, i) {
                final (name, image) = _categories[i];
                final selected = _selectedTag == name;
                return GestureDetector(
                  onTap: () => _selectTag(name),
                  child: SizedBox(
                    width: 72,
                    child: Column(
                      children: [
                        AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          width: 66,
                          height: 66,
                          padding: const EdgeInsets.all(3),
                          decoration: BoxDecoration(
                            color: AppColors.surface,
                            shape: BoxShape.circle,
                            border: Border.all(color: selected ? AppColors.teal : Colors.transparent, width: 3),
                            boxShadow: AppShadows.soft,
                          ),
                          child: ClipOval(child: Image.asset(image, fit: BoxFit.cover)),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: selected ? AppColors.teal : AppColors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFormats() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SectionHeader(title: 'Shop by format', padding: EdgeInsets.zero),
          const SizedBox(height: 14),
          GridView.count(
            crossAxisCount: 2,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            mainAxisSpacing: 12,
            crossAxisSpacing: 12,
            childAspectRatio: 2.35,
            children: _formats.map((f) {
              final selected = _selectedFormat?.id == f.id;
              return AppCard(
                padding: const EdgeInsets.all(10),
                radius: AppRadius.xl,
                borderColor: selected ? AppColors.teal : AppColors.border,
                onTap: () => _selectFormat(selected ? null : f),
                child: Row(
                  children: [
                    Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(color: f.bg, borderRadius: BorderRadius.circular(AppRadius.md)),
                      child: Center(child: FaIcon(f.icon, color: f.fg, size: 19)),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(f.title,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
                          const SizedBox(height: 2),
                          Text(f.subtitle,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(fontSize: 11, color: AppColors.textSecondary)),
                        ],
                      ),
                    ),
                  ],
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildMatchedProducts() {
    return Padding(
      padding: const EdgeInsets.only(top: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SectionHeader(title: 'Products matching "$_search"'),
          const SizedBox(height: 12),
          SizedBox(
            height: 172,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              itemCount: _matchedProducts.length,
              separatorBuilder: (_, __) => const SizedBox(width: 12),
              itemBuilder: (context, i) {
                final p = _matchedProducts[i];
                final images = p['productImages'] as List? ?? const [];
                final price = p['productdiscountPrice'] is num && (p['productdiscountPrice'] as num) > 0
                    ? p['productdiscountPrice'] as num
                    : p['productPrice'] as num?;
                final shopId = (p['shopId'] ?? '').toString();
                return SizedBox(
                  width: 130,
                  child: AppCard(
                    padding: EdgeInsets.zero,
                    onTap: () {
                      final shop = _shops.where((s) => s.shopId == shopId.toLowerCase()).firstOrNull ??
                          Shop(shopImage: '', heading: (p['shopName'] ?? shopId).toString(), desc: '', shopId: shopId.toLowerCase());
                      _openShop(shop);
                    },
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        SizedBox(
                          height: 90,
                          width: double.infinity,
                          child: NetImage(images.isNotEmpty ? images.first.toString() : null, fallbackIcon: Icons.shopping_basket_outlined),
                        ),
                        Padding(
                          padding: const EdgeInsets.all(8),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text((p['productName'] ?? '').toString(),
                                  maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                              Text((p['shopName'] ?? shopId).toString(),
                                  maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 11, color: AppColors.textSecondary)),
                              const SizedBox(height: 2),
                              Text(rupees(price), style: const TextStyle(fontWeight: FontWeight.w700, color: AppColors.teal)),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildShopsHeader() {
    return Padding(
      key: _shopsKey,
      padding: const EdgeInsets.fromLTRB(0, 24, 0, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SectionHeader(
            title: _search.isNotEmpty ? 'Shops for "$_search"' : 'Shops near you',
            actionLabel: (_selectedTag != 'All' || _selectedFormat != null || _search.isNotEmpty) ? 'Clear filters' : null,
            onAction: () {
              setState(() {
                _selectedTag = 'All';
                _selectedFormat = null;
                _search = '';
                _searchController.clear();
              });
              _loadShops();
            },
          ),
          if (_selectedTag != 'All' || _selectedFormat != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
              child: Wrap(
                spacing: 8,
                children: [
                  if (_selectedTag != 'All')
                    InputChip(label: Text(_selectedTag), onDeleted: () => _selectTag('All')),
                  if (_selectedFormat != null)
                    InputChip(label: Text(_selectedFormat!.title), onDeleted: () => _selectFormat(null)),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildShopList() {
    if (_loadingShops && _shops.isEmpty) {
      return const SliverToBoxAdapter(
        child: Padding(padding: EdgeInsets.all(32), child: Center(child: CircularProgressIndicator())),
      );
    }
    if (_shopsError != null && _shops.isEmpty) {
      return SliverToBoxAdapter(
        child: EmptyState(
          icon: Icons.wifi_off_rounded,
          title: 'Could not load shops',
          message: _shopsError,
          actionLabel: 'Retry',
          onAction: _loadShops,
        ),
      );
    }
    if (_shops.isEmpty) {
      return SliverToBoxAdapter(
        child: EmptyState(
          icon: Icons.storefront_outlined,
          title: _selectedFormat != null ? 'No ${_selectedFormat!.title} shops yet' : 'No shops found',
          message: 'Try another category or search term.',
        ),
      );
    }
    return SliverPadding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      sliver: SliverList.separated(
        itemCount: _shops.length,
        separatorBuilder: (_, __) => const SizedBox(height: 12),
        itemBuilder: (context, i) => _ShopCard(shop: _shops[i], onTap: () => _openShop(_shops[i])),
      ),
    );
  }

  Widget _buildCounter() {
    if (_visits == null) return const SizedBox(height: 24);
    return Padding(
      padding: const EdgeInsets.only(top: 36, bottom: 8),
      child: Column(
        children: [
          const FaIcon(FontAwesomeIcons.eye, size: 26, color: AppColors.textPrimary),
          const SizedBox(height: 6),
          Text('$_visits',
              style: const TextStyle(fontSize: 26, fontWeight: FontWeight.w800, fontFamily: AppTheme.displayFamily)),
          const Text('visits to Gotan', style: TextStyle(color: AppColors.textSecondary, fontSize: 12)),
        ],
      ),
    );
  }
}

// --------------------------------------------------------------- widgets

class _PrimaryActionCard extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final Color iconBg;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  const _PrimaryActionCard({
    required this.icon,
    required this.iconColor,
    required this.iconBg,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return AppCard(
      onTap: onTap,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 20),
      child: Column(
        children: [
          Container(
            width: 58,
            height: 58,
            decoration: BoxDecoration(color: iconBg, borderRadius: BorderRadius.circular(AppRadius.xl)),
            child: Center(child: FaIcon(icon, color: iconColor, size: 26)),
          ),
          const SizedBox(height: 14),
          Text(title, textAlign: TextAlign.center, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
          const SizedBox(height: 3),
          Text(
            subtitle,
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 12, color: AppColors.textSecondary, fontWeight: FontWeight.w500),
          ),
        ],
      ),
    );
  }
}

class _EarnTile extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String title;
  final String subtitle;
  final String action;
  final VoidCallback onTap;

  const _EarnTile({
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.subtitle,
    required this.action,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white.withValues(alpha: 0.10),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadius.lg),
        side: BorderSide(color: Colors.white.withValues(alpha: 0.10)),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: iconColor.withValues(alpha: 0.18),
                  borderRadius: BorderRadius.circular(AppRadius.md),
                  border: Border.all(color: iconColor.withValues(alpha: 0.3)),
                ),
                child: Center(child: FaIcon(icon, color: iconColor, size: 17)),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 14)),
                    const SizedBox(height: 2),
                    Text(subtitle, style: const TextStyle(color: AppColors.textDisabled, fontSize: 11)),
                  ],
                ),
              ),
              Text('$action ▶', style: const TextStyle(color: AppColors.yellow, fontWeight: FontWeight.w600, fontSize: 13)),
            ],
          ),
        ),
      ),
    );
  }
}

class _ShopCard extends StatelessWidget {
  final Shop shop;
  final VoidCallback onTap;

  const _ShopCard({required this.shop, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return AppCard(
      onTap: onTap,
      padding: const EdgeInsets.all(14),
      child: Row(
        children: [
          Container(
            width: 66,
            height: 66,
            padding: const EdgeInsets.all(3),
            decoration: BoxDecoration(
              color: AppColors.background,
              borderRadius: BorderRadius.circular(AppRadius.lg),
              border: Border.all(color: AppColors.border),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(AppRadius.md),
              child: NetImage(shop.shopImage, fallbackIcon: Icons.storefront_outlined),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(shop.heading,
                    maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
                const SizedBox(height: 4),
                Text(
                  shop.desc.isEmpty ? 'Local shop' : shop.desc,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(color: AppColors.textSecondary, fontSize: 13),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 4),
                decoration: BoxDecoration(color: AppColors.tealLight, borderRadius: BorderRadius.circular(4)),
                child: const Text(
                  'DIGISTALL',
                  style: TextStyle(color: AppColors.teal, fontSize: 10, fontWeight: FontWeight.w800, letterSpacing: 0.8),
                ),
              ),
              const SizedBox(height: 8),
              const Icon(Icons.chevron_right_rounded, color: AppColors.textSecondary),
            ],
          ),
        ],
      ),
    );
  }
}

class _ActiveBookingBanner extends StatelessWidget {
  final Booking booking;
  final VoidCallback onTap;

  const _ActiveBookingBanner({required this.booking, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final ride = booking.kind == BookingKind.ride;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
      child: Material(
        color: AppColors.teal,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(AppRadius.lg),
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Row(
              children: [
                Container(
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.18), shape: BoxShape.circle),
                  child: Center(
                    child: FaIcon(ride ? FontAwesomeIcons.motorcycle : FontAwesomeIcons.boxOpen, color: Colors.white, size: 18),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        ride ? 'Your ride · ${booking.stageLabel}' : 'Your parcel · ${booking.stageLabel}',
                        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        booking.drop,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(color: Colors.white.withValues(alpha: 0.85), fontSize: 12),
                      ),
                    ],
                  ),
                ),
                const Text('Track', style: TextStyle(color: AppColors.yellow, fontWeight: FontWeight.w700)),
                const Icon(Icons.chevron_right_rounded, color: AppColors.yellow),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Website footer: contact, socials, legal and policy links.
class HomeFooter extends StatelessWidget {
  const HomeFooter({super.key});

  @override
  Widget build(BuildContext context) {
    Widget social(IconData icon, String url) => IconButton(
          onPressed: () => openExternal(context, url),
          icon: FaIcon(icon, size: 20, color: AppColors.textSecondary),
        );
    Widget link(String label, String url) => TextButton(
          onPressed: () => openExternal(context, url),
          child: Text(label, style: const TextStyle(color: AppColors.textSecondary, fontWeight: FontWeight.w500)),
        );

    return Container(
      margin: const EdgeInsets.only(top: 24),
      padding: const EdgeInsets.fromLTRB(20, 28, 20, 36),
      color: AppColors.background,
      child: Column(
        children: [
          Image.asset('assets/images/gologo.png', height: 36),
          const SizedBox(height: 16),
          InkWell(
            onTap: () => openWhatsApp(context, Common.supportPhone),
            child: const Padding(
              padding: EdgeInsets.all(4),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  FaIcon(FontAwesomeIcons.whatsapp, size: 16, color: AppColors.success),
                  SizedBox(width: 8),
                  Text('+91 ${Common.supportPhone}', style: TextStyle(fontWeight: FontWeight.w600)),
                ],
              ),
            ),
          ),
          InkWell(
            onTap: () => emailSupport(context),
            child: const Padding(
              padding: EdgeInsets.all(4),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.mail_outline_rounded, size: 16, color: AppColors.textSecondary),
                  SizedBox(width: 8),
                  Text(Common.supportEmail),
                ],
              ),
            ),
          ),
          const SizedBox(height: 4),
          const Text('7 Siyag House, Gotan, Rajasthan 342902',
              textAlign: TextAlign.center, style: TextStyle(color: AppColors.textSecondary, fontSize: 13)),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              social(FontAwesomeIcons.instagram, 'https://www.instagram.com/digistallapp/'),
              social(FontAwesomeIcons.linkedin, 'https://www.linkedin.com/company/humans-of-rural-india/'),
              social(FontAwesomeIcons.facebook, 'https://www.facebook.com/humansofruralindia/'),
              social(FontAwesomeIcons.xTwitter, 'https://x.com/DigistallApp'),
              social(FontAwesomeIcons.youtube, 'https://www.youtube.com/@digistall'),
            ],
          ),
          Wrap(
            alignment: WrapAlignment.center,
            children: [
              link('Newsletter', 'https://digistall.substack.com/'),
              link('Privacy Policy', Common.privacyUrl),
              link('Terms', Common.termsUrl),
            ],
          ),
          const SizedBox(height: 8),
          const Text(
            'Siyag Rural Market Private Limited [© Digistall]\nCIN: U52100RJ2021PTC077111 · GSTIN: 08ABGCS8909L1ZN',
            textAlign: TextAlign.center,
            style: TextStyle(color: AppColors.textSecondary, fontSize: 11, height: 1.5),
          ),
        ],
      ),
    );
  }
}

/// Side menu, matching the website navbar sidebar.
class MainDrawer extends StatelessWidget {
  final VoidCallback? onChanged;

  const MainDrawer({super.key, this.onChanged});

  @override
  Widget build(BuildContext context) {
    final user = context.watch<UserProvider>();

    void go(Widget page) {
      Navigator.pop(context);
      Navigator.push(context, MaterialPageRoute(builder: (_) => page)).then((_) => onChanged?.call());
    }

    Widget item(IconData icon, String title, VoidCallback onTap) => ListTile(
          leading: Icon(icon, color: AppColors.textSecondary, size: 22),
          title: Text(title, style: const TextStyle(fontWeight: FontWeight.w500, fontSize: 15)),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.md)),
          onTap: onTap,
        );

    return Drawer(
      width: 290,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(),
      child: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 12, 8, 12),
              child: Row(
                children: [
                  Image.asset('assets/images/gologo.png', height: 32),
                  const Spacer(),
                  IconButton(icon: const Icon(Icons.close_rounded), onPressed: () => Navigator.pop(context)),
                ],
              ),
            ),
            const Divider(),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
                children: [
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    child: user.isLoggedIn
                        ? InkWell(
                            onTap: () => go(const MyProfileScreen()),
                            borderRadius: BorderRadius.circular(AppRadius.md),
                            child: Container(
                              padding: const EdgeInsets.all(14),
                              decoration: BoxDecoration(
                                color: AppColors.tealLight,
                                borderRadius: BorderRadius.circular(AppRadius.md),
                                border: Border.all(color: AppColors.teal.withValues(alpha: 0.2)),
                              ),
                              child: Row(
                                children: [
                                  CircleAvatar(
                                    radius: 24,
                                    backgroundColor: AppColors.surface,
                                    child: ClipOval(
                                      child: user.profileImage.isEmpty
                                          ? const Icon(Icons.person_outline_rounded, color: AppColors.teal)
                                          : NetImage(user.profileImage, width: 48, height: 48, fallbackIcon: Icons.person_outline),
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(user.name,
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                            style: const TextStyle(fontWeight: FontWeight.w700)),
                                        Text('+91 ${user.phone}',
                                            style: const TextStyle(color: AppColors.textSecondary, fontSize: 12)),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          )
                        : AppButton(label: 'Login / Register', onPressed: () => go(const PhoneInputPage())),
                  ),
                  const SizedBox(height: 20),
                  item(Icons.home_outlined, 'Home', () => Navigator.pop(context)),
                  if (user.isLoggedIn) item(Icons.person_outline_rounded, 'My Profile', () => go(const MyProfileScreen())),
                  item(Icons.pedal_bike_rounded, 'Rider History', () => go(const BookingHistoryScreen(initialKind: BookingKind.ride))),
                  item(Icons.inventory_2_outlined, 'Parcel History', () => go(const BookingHistoryScreen(initialKind: BookingKind.parcel))),
                  item(Icons.receipt_long_outlined, 'My Shop Orders', () => go(const OrderHistoryPage())),
                  const SizedBox(height: 24),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    child: Column(
                      children: [
                        _DrawerCard(
                          color: AppColors.successBg,
                          borderColor: AppColors.success.withValues(alpha: 0.2),
                          iconBg: AppColors.surface,
                          icon: const Icon(Icons.call_outlined, color: AppColors.success),
                          label: 'ORDER ON CALL',
                          labelColor: AppColors.success,
                          title: '+91 ${Common.supportPhone}',
                          titleColor: AppColors.textPrimary,
                          onTap: () => callNumber(context, Common.supportPhone),
                        ),
                        const SizedBox(height: 12),
                        _DrawerCard(
                          color: AppColors.navy,
                          borderColor: AppColors.navy,
                          iconBg: AppColors.teal,
                          icon: const FaIcon(FontAwesomeIcons.motorcycle, color: Colors.white, size: 18),
                          label: 'DIGICAPTAIN',
                          labelColor: AppColors.tealLight,
                          title: 'Become a Rider',
                          titleColor: Colors.white,
                          onTap: () => openExternal(context, Common.riderUrl),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DrawerCard extends StatelessWidget {
  final Color color;
  final Color borderColor;
  final Color iconBg;
  final Widget icon;
  final String label;
  final Color labelColor;
  final String title;
  final Color titleColor;
  final VoidCallback onTap;

  const _DrawerCard({
    required this.color,
    required this.borderColor,
    required this.iconBg,
    required this.icon,
    required this.label,
    required this.labelColor,
    required this.title,
    required this.titleColor,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: color,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.md), side: BorderSide(color: borderColor)),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppRadius.md),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(color: iconBg, shape: BoxShape.circle, boxShadow: AppShadows.soft),
                child: Center(child: icon),
              ),
              const SizedBox(width: 12),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label,
                      style: TextStyle(color: labelColor, fontSize: 11, fontWeight: FontWeight.w700, letterSpacing: 0.8)),
                  Text(title, style: TextStyle(color: titleColor, fontWeight: FontWeight.w700, fontSize: 14)),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
