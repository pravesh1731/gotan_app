import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../model/cart_item.dart';
import '../model/store.dart';
import '../providers/CartProvider.dart';
import '../providers/WishlistProvider.dart';
import '../theme/app_theme.dart';
import '../widgets/ui.dart';
import 'ShopPage.dart' show QtyStepper;

class ProductDetailScreen extends StatefulWidget {
  final Store store;
  final Product product;

  const ProductDetailScreen({super.key, required this.store, required this.product});

  @override
  State<ProductDetailScreen> createState() => _ProductDetailScreenState();
}

class _ProductDetailScreenState extends State<ProductDetailScreen> {
  int _imageIndex = 0;
  String? _size;
  String? _color;

  Product get _p => widget.product;

  @override
  void initState() {
    super.initState();
    if (_p.hasVariants) {
      // Preselect the first size/colour that is in stock.
      outer:
      for (final s in _p.sizes) {
        for (final c in _p.colorsFor(s)) {
          if (_p.stockFor(size: s, color: c) > 0) {
            _size = s;
            _color = c;
            break outer;
          }
        }
      }
    }
  }

  String get _lineKey => CartItem.keyFor(_p.id, size: _size ?? '', color: _color ?? '');

  int get _stock => _p.hasVariants
      ? (_size == null || _color == null ? 0 : _p.stockFor(size: _size, color: _color))
      : _p.stock;

  void _add(CartProvider cart) {
    if (_p.hasVariants && (_size == null || _color == null)) {
      showAppSnack(context, 'Please choose a size and colour', error: true);
      return;
    }
    final ok = cart.addProduct(widget.store.shopId, _p, size: _size ?? '', color: _color ?? '');
    if (!ok) showAppSnack(context, 'Only $_stock in stock');
  }

  @override
  Widget build(BuildContext context) {
    final cart = context.watch<CartProvider>();
    final wishlist = context.watch<WishlistProvider>();
    final qty = cart.getQuantity(widget.store.shopId, _lineKey);
    final inWishlist = wishlist.isInWishlist(_p.id);
    final images = _p.images.isEmpty ? [''] : _p.images;

    return Scaffold(
      backgroundColor: AppColors.surface,
      appBar: AppBar(
        title: Text(widget.store.name),
        actions: [
          IconButton(
            onPressed: () => wishlist.toggle(widget.store.shopId, _p),
            icon: Icon(inWishlist ? Icons.favorite : Icons.favorite_border, color: inWishlist ? AppColors.error : null),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.only(bottom: 24),
        children: [
          AspectRatio(
            aspectRatio: 1.1,
            child: Stack(
              children: [
                PageView.builder(
                  itemCount: images.length,
                  onPageChanged: (i) => setState(() => _imageIndex = i),
                  itemBuilder: (_, i) => Container(
                    color: AppColors.background,
                    child: NetImage(images[i], fit: BoxFit.contain, fallbackIcon: Icons.shopping_basket_outlined),
                  ),
                ),
                if (images.length > 1)
                  Positioned(
                    bottom: 12,
                    left: 0,
                    right: 0,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: List.generate(
                        images.length,
                        (i) => AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          margin: const EdgeInsets.symmetric(horizontal: 3),
                          width: i == _imageIndex ? 18 : 7,
                          height: 7,
                          decoration: BoxDecoration(
                            color: i == _imageIndex ? AppColors.teal : AppColors.border,
                            borderRadius: BorderRadius.circular(99),
                          ),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 18, 16, 0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (_p.category.isNotEmpty)
                  Text(_p.category.toUpperCase(),
                      style: const TextStyle(color: AppColors.teal, fontSize: 11, fontWeight: FontWeight.w800, letterSpacing: 0.8)),
                const SizedBox(height: 4),
                Text(_p.name, style: const TextStyle(fontSize: 21, fontWeight: FontWeight.w800, height: 1.25)),
                if (_p.unitType.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(_p.unitType, style: const TextStyle(color: AppColors.textSecondary)),
                ],
                const SizedBox(height: 14),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(rupees(_p.sellingPrice), style: const TextStyle(fontSize: 26, fontWeight: FontWeight.w800)),
                    if (_p.hasDiscount) ...[
                      const SizedBox(width: 10),
                      Padding(
                        padding: const EdgeInsets.only(bottom: 4),
                        child: Text(rupees(_p.price),
                            style: const TextStyle(color: AppColors.textSecondary, decoration: TextDecoration.lineThrough)),
                      ),
                      const SizedBox(width: 8),
                      Padding(
                        padding: const EdgeInsets.only(bottom: 3),
                        child: StatusChip(label: '${_p.discountPercent}% OFF', tone: Tone.success, dense: true),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  _stock > 0 ? (_stock <= 5 ? 'Only $_stock left' : 'In stock') : 'Out of stock',
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    color: _stock > 0 ? (_stock <= 5 ? const Color(0xFFB7791F) : AppColors.success) : AppColors.error,
                  ),
                ),
                if (_p.hasVariants) ..._buildVariantPickers(),
                if (_p.description.isNotEmpty) ...[
                  const SizedBox(height: 22),
                  const Text('About this product', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
                  const SizedBox(height: 6),
                  Text(_p.description, style: const TextStyle(color: AppColors.textSecondary, height: 1.5)),
                ],
              ],
            ),
          ),
        ],
      ),
      bottomNavigationBar: SafeArea(
        child: Container(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
          decoration: const BoxDecoration(border: Border(top: BorderSide(color: AppColors.border))),
          child: _stock <= 0
              ? const AppButton(label: 'Out of stock', onPressed: null)
              : qty == 0
                  ? AppButton(label: 'Add to cart', icon: Icons.add_shopping_cart_rounded, onPressed: () => _add(cart))
                  : Row(
                      children: [
                        QtyStepper(
                          qty: qty,
                          onMinus: () => cart.decreaseQuantity(widget.store.shopId, _lineKey),
                          onPlus: () => _add(cart),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: AppButton(
                            label: 'Go to cart',
                            variant: ButtonVariant.secondary,
                            onPressed: () => Navigator.pop(context),
                          ),
                        ),
                      ],
                    ),
        ),
      ),
    );
  }

  List<Widget> _buildVariantPickers() {
    Widget chips(List<String> values, String? selected, bool Function(String) available, ValueChanged<String> onTap) => Wrap(
          spacing: 8,
          runSpacing: 8,
          children: values.map((v) {
            final ok = available(v);
            return ChoiceChip(
              label: Text(v),
              selected: selected == v,
              showCheckmark: false,
              onSelected: ok ? (_) => onTap(v) : null,
              labelStyle: TextStyle(
                color: !ok ? AppColors.textDisabled : (selected == v ? AppColors.tealDark : AppColors.textPrimary),
                decoration: ok ? null : TextDecoration.lineThrough,
              ),
            );
          }).toList(),
        );

    final colors = _size == null ? <String>[] : _p.colorsFor(_size!);
    return [
      const SizedBox(height: 20),
      const Text('Size', style: TextStyle(fontWeight: FontWeight.w700)),
      const SizedBox(height: 8),
      chips(
        _p.sizes,
        _size,
        (s) => _p.colorsFor(s).any((c) => _p.stockFor(size: s, color: c) > 0),
        (s) => setState(() {
          _size = s;
          final options = _p.colorsFor(s);
          if (!options.contains(_color) || _p.stockFor(size: s, color: _color) <= 0) {
            _color = options.where((c) => _p.stockFor(size: s, color: c) > 0).firstOrNull;
          }
        }),
      ),
      if (colors.isNotEmpty) ...[
        const SizedBox(height: 16),
        const Text('Colour', style: TextStyle(fontWeight: FontWeight.w700)),
        const SizedBox(height: 8),
        chips(colors, _color, (c) => _p.stockFor(size: _size, color: c) > 0, (c) => setState(() => _color = c)),
      ],
    ];
  }
}
