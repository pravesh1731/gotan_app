import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';
import 'package:lottie/lottie.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../model/store.dart';
import '../providers/CartProvider.dart';
import '../providers/UserProvider.dart';
import '../services/api.dart';
import '../services/session.dart';
import '../theme/app_theme.dart';
import '../utils/address.dart';
import '../widgets/ui.dart';

/// Address + payment + place order for one store's cart. Orders go to
/// `backend.digistall.in/customer/addorder`.
class CheckoutScreen extends StatefulWidget {
  final Store store;
  const CheckoutScreen({super.key, required this.store});

  @override
  State<CheckoutScreen> createState() => _CheckoutScreenState();
}

enum _Pay { cod, upi }

class _CheckoutScreenState extends State<CheckoutScreen> {
  List<Map<String, dynamic>> _addresses = [];
  int _selectedAddress = -1;
  _Pay _pay = _Pay.cod;
  final _txnController = TextEditingController();
  bool _placing = false;
  bool _placed = false;

  Store get store => widget.store;

  @override
  void initState() {
    super.initState();
    _loadAddresses();
  }

  @override
  void dispose() {
    _txnController.dispose();
    super.dispose();
  }

  Future<void> _loadAddresses() async {
    final list = await Session.addresses();
    if (!mounted) return;
    setState(() {
      _addresses = list;
      _selectedAddress = list.isEmpty ? -1 : 0;
    });
    if (list.isEmpty) _editAddress();
  }

  Future<void> _editAddress([int? index]) async {
    final user = context.read<UserProvider>();
    final initial =
        index == null
            ? <String, dynamic>{
              'name': user.name == 'Customer' ? '' : user.name,
              'mobile': user.isLoggedIn ? user.phone : '',
              'city': 'Gotan',
              'state': 'Rajasthan',
              'pincode': '342902',
            }
            : Map<String, dynamic>.from(_addresses[index]);

    final result = await showModalBottomSheet<Map<String, dynamic>>(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadius.xl))),
      builder: (_) => _AddressForm(initial: initial),
    );
    if (result == null) return;
    setState(() {
      if (index == null) {
        _addresses.insert(0, result);
        _selectedAddress = 0;
      } else {
        _addresses[index] = result;
        _selectedAddress = index;
      }
    });
    await Session.saveAddresses(_addresses);
  }

  Future<void> _deleteAddress(int index) async {
    setState(() {
      _addresses.removeAt(index);
      if (_selectedAddress >= _addresses.length) _selectedAddress = _addresses.length - 1;
    });
    await Session.saveAddresses(_addresses);
  }

  Future<void> _openUpiApp(num amount) async {
    final uri = Uri(
      scheme: 'upi',
      host: 'pay',
      queryParameters: {
        'pa': store.upiId,
        'pn': store.name,
        'am': amount.toStringAsFixed(2),
        'cu': 'INR',
        'tn': 'Gotan order - ${store.name}',
      },
    );
    try {
      final ok = await launchUrl(uri, mode: LaunchMode.externalApplication);
      if (!ok && mounted) showAppSnack(context, 'No UPI app found. Scan the QR or copy the UPI ID.', error: true);
    } catch (_) {
      if (mounted) showAppSnack(context, 'No UPI app found. Scan the QR or copy the UPI ID.', error: true);
    }
  }

  Future<void> _placeOrder() async {
    final cart = context.read<CartProvider>();
    final lines = cart.getCart(store.shopId).values.toList();
    if (lines.isEmpty) {
      Navigator.pop(context);
      return;
    }
    if (_selectedAddress < 0 || _selectedAddress >= _addresses.length) {
      showAppSnack(context, 'Add a delivery address', error: true);
      return;
    }
    if (!store.open) {
      showAppSnack(context, 'This shop is closed right now', error: true);
      return;
    }

    final address = _addresses[_selectedAddress];
    final formatted = formatDeliveryAddress(address);
    final subtotal = cart.subtotal(store.shopId);
    final total = subtotal + store.deliveryFee;
    final paymentMethod = _pay == _Pay.upi ? 'UPI' : 'COD';
    const guestEmail = 'guest@store.com'; // Digistall's guest-checkout email.
    final lat = (address['lat'] as num?)?.toDouble();
    final lng = (address['lng'] as num?)?.toDouble();

    final orders =
        lines.map((line) {
          final product = store.productById(line.id);
          return {
            'productId': line.id,
            'productName': line.name,
            'productImage': line.imageUrl,
            'productCount': line.quantity,
            'onePiecePrice': line.sellingPrice,
            'coupontotal': line.lineTotal,
            'totalCartValue': total,
            'gst': store.gstForCategory(product?.category ?? line.category),
            'shopId': store.shopId,
            'hasVariants': line.hasVariant,
            if (line.hasVariant) 'size': line.size,
            if (line.hasVariant) 'color': line.color,
            'paymentMethod': paymentMethod,
            'transactionId': _pay == _Pay.upi ? _txnController.text.trim() : '',
            'address': formatted,
            'name': (address['name'] ?? '').toString(),
            'email': guestEmail,
            'deliveryFee': store.deliveryFee,
            'platformFee': 0,
            'lat': lat,
            'lng': lng,
          };
        }).toList();

    setState(() => _placing = true);
    try {
      final orderId = await Api.placeOrder({
        'email': guestEmail,
        // Seller's FCM token: the backend pushes "New Order" to it.
        if (store.sellerDeviceToken.isNotEmpty) 'deviceToken': store.sellerDeviceToken,
        'orders': orders,
      });
      if (orderId.isNotEmpty) await Session.addShopOrderId(orderId);
      if (mounted) setState(() => _placed = true);
      cart.clearCart(store.shopId);
      if (!mounted) return;
      await _showSuccess(orderId, total);
      if (mounted) Navigator.pop(context, true);
    } on ApiException catch (e) {
      if (!mounted) return;
      showAppSnack(context, e.message, error: true);
      if (e.statusCode == 409) {
        // Refresh stock so the cart shows what can still be ordered.
        final fresh = await Api.getStore(store.shopId).catchError((_) => null);
        if (fresh != null && mounted) cart.syncWithStore(fresh);
      }
    } catch (e) {
      if (mounted) showAppSnack(context, e.toString(), error: true);
    } finally {
      if (mounted) setState(() => _placing = false);
    }
  }

  Future<void> _showSuccess(String orderId, num total) {
    return showDialog(
      context: context,
      barrierDismissible: false,
      builder:
          (ctx) => AlertDialog(
            contentPadding: const EdgeInsets.fromLTRB(24, 20, 24, 8),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Lottie.asset('assets/animations/confirm.json', height: 130, repeat: false),
                const Text('Order placed!', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800)),
                const SizedBox(height: 6),
                Text(
                  '${store.name} has received your order of ${rupees(total)}. You can track it in Orders.',
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: AppColors.textSecondary, height: 1.4),
                ),
                if (orderId.isNotEmpty) ...[
                  const SizedBox(height: 10),
                  Text(
                    'Order #${orderId.substring(0, orderId.length.clamp(0, 8)).toUpperCase()}',
                    style: const TextStyle(fontWeight: FontWeight.w700, color: AppColors.teal),
                  ),
                ],
              ],
            ),
            actionsPadding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
            actions: [AppButton(label: 'Track order', onPressed: () => Navigator.pop(ctx))],
          ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final cart = context.watch<CartProvider>();
    final lines = cart.getCart(store.shopId).values.toList();
    final subtotal = cart.subtotal(store.shopId);
    final total = subtotal + store.deliveryFee;

    return Scaffold(
      appBar: AppBar(title: const Text('Checkout')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
        children: [
          _sectionTitle('Delivery address', action: 'Add new', onAction: () => _editAddress()),
          if (_addresses.isEmpty)
            AppCard(
              onTap: () => _editAddress(),
              child: const Row(
                children: [
                  Icon(Icons.add_location_alt_outlined, color: AppColors.teal),
                  SizedBox(width: 10),
                  Text('Add a delivery address', style: TextStyle(fontWeight: FontWeight.w600, color: AppColors.teal)),
                ],
              ),
            )
          else
            ...List.generate(_addresses.length, (i) {
              final a = _addresses[i];
              final selected = i == _selectedAddress;
              return Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: AppCard(
                  padding: const EdgeInsets.fromLTRB(8, 10, 4, 10),
                  borderColor: selected ? AppColors.teal : AppColors.border,
                  onTap: () => setState(() => _selectedAddress = i),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Padding(
                        padding: const EdgeInsets.fromLTRB(4, 8, 8, 0),
                        child: Icon(
                          selected ? Icons.radio_button_checked : Icons.radio_button_off,
                          color: selected ? AppColors.teal : AppColors.textDisabled,
                        ),
                      ),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const SizedBox(height: 8),
                            Text(
                              '${a['name'] ?? ''} · +91 ${a['mobile'] ?? ''}',
                              style: const TextStyle(fontWeight: FontWeight.w700),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              [
                                a['address'],
                                a['landmark'],
                                a['city'],
                                a['pincode'],
                              ].where((e) => e != null && e.toString().trim().isNotEmpty).join(', '),
                              style: const TextStyle(color: AppColors.textSecondary, fontSize: 13, height: 1.35),
                            ),
                          ],
                        ),
                      ),
                      PopupMenuButton<String>(
                        onSelected: (v) => v == 'edit' ? _editAddress(i) : _deleteAddress(i),
                        itemBuilder:
                            (_) => const [
                              PopupMenuItem(value: 'edit', child: Text('Edit')),
                              PopupMenuItem(value: 'delete', child: Text('Delete')),
                            ],
                      ),
                    ],
                  ),
                ),
              );
            }),
          const SizedBox(height: 14),
          _sectionTitle('Payment'),
          _PaymentOption(
            title: 'Cash on delivery',
            subtitle: 'Pay when your order arrives',
            icon: Icons.payments_outlined,
            selected: _pay == _Pay.cod,
            onTap: () => setState(() => _pay = _Pay.cod),
          ),
          if (store.acceptsUpi) ...[
            const SizedBox(height: 10),
            _PaymentOption(
              title: 'Pay with UPI',
              subtitle: 'GPay, PhonePe, Paytm or any UPI app',
              icon: Icons.qr_code_2_rounded,
              selected: _pay == _Pay.upi,
              onTap: () => setState(() => _pay = _Pay.upi),
            ),
            if (_pay == _Pay.upi) _buildUpiPanel(total),
          ],
          const SizedBox(height: 18),
          _sectionTitle('Order summary'),
          AppCard(
            child: Column(
              children: [
                for (final l in lines)
                  InfoRow(
                    label: '${l.quantity} × ${l.name}${l.variantLabel.isEmpty ? '' : ' (${l.variantLabel})'}',
                    value: rupees(l.lineTotal),
                  ),
                const Divider(),
                InfoRow(label: 'Item total', value: rupees(subtotal)),
                InfoRow(label: 'Delivery fee', value: rupees(store.deliveryFee)),
                const Divider(),
                InfoRow(label: 'To pay', value: rupees(total), bold: true),
              ],
            ),
          ),
        ],
      ),
      bottomNavigationBar:
          _placed
              ? null
              : SafeArea(
                child: Container(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
                  decoration: const BoxDecoration(
                    color: AppColors.surface,
                    border: Border(top: BorderSide(color: AppColors.border)),
                  ),
                  child: AppButton(
                    label: 'Place order · ${rupees(total)}',
                    loading: _placing,
                    onPressed: lines.isEmpty ? null : _placeOrder,
                  ),
                ),
              ),
    );
  }

  Widget _buildUpiPanel(num total) {
    return Container(
      margin: const EdgeInsets.only(top: 10),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.tealLight.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(color: AppColors.teal.withValues(alpha: 0.3)),
      ),
      child: Column(
        children: [
          if (store.qrCode.isNotEmpty)
            Container(
              width: 180,
              height: 180,
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(AppRadius.md)),
              child: NetImage(store.qrCode, fit: BoxFit.contain, fallbackIcon: Icons.qr_code_2_rounded),
            ),
          if (store.upiId.isNotEmpty) ...[
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Text('UPI ID: ', style: TextStyle(color: AppColors.textSecondary)),
                Flexible(child: Text(store.upiId, style: const TextStyle(fontWeight: FontWeight.w700))),
                IconButton(
                  visualDensity: VisualDensity.compact,
                  icon: const Icon(Icons.copy_rounded, size: 18, color: AppColors.teal),
                  onPressed: () {
                    Clipboard.setData(ClipboardData(text: store.upiId));
                    showAppSnack(context, 'UPI ID copied');
                  },
                ),
              ],
            ),
            AppButton(
              label: 'Pay ${rupees(total)} with UPI app',
              icon: Icons.open_in_new_rounded,
              variant: ButtonVariant.secondary,
              onPressed: () => _openUpiApp(total),
            ),
          ],
          const SizedBox(height: 12),
          TextField(
            controller: _txnController,
            decoration: const InputDecoration(
              labelText: 'UPI transaction ID (after paying)',
              hintText: 'Helps the shop match your payment',
            ),
          ),
        ],
      ),
    );
  }

  Widget _sectionTitle(String title, {String? action, VoidCallback? onAction}) =>
      SectionHeader(title: title, actionLabel: action, onAction: onAction, padding: const EdgeInsets.only(bottom: 10));
}

class _PaymentOption extends StatelessWidget {
  final String title;
  final String subtitle;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;

  const _PaymentOption({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return AppCard(
      onTap: onTap,
      padding: const EdgeInsets.all(14),
      borderColor: selected ? AppColors.teal : AppColors.border,
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(color: AppColors.tealLight, borderRadius: BorderRadius.circular(AppRadius.md)),
            child: Icon(icon, color: AppColors.teal),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: const TextStyle(fontWeight: FontWeight.w700)),
                Text(subtitle, style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
              ],
            ),
          ),
          Icon(
            selected ? Icons.radio_button_checked : Icons.radio_button_off,
            color: selected ? AppColors.teal : AppColors.textDisabled,
          ),
        ],
      ),
    );
  }
}

class _AddressForm extends StatefulWidget {
  final Map<String, dynamic> initial;
  const _AddressForm({required this.initial});

  @override
  State<_AddressForm> createState() => _AddressFormState();
}

class _AddressFormState extends State<_AddressForm> {
  final _formKey = GlobalKey<FormState>();
  late final _name = TextEditingController(text: widget.initial['name']?.toString() ?? '');
  late final _mobile = TextEditingController(text: widget.initial['mobile']?.toString() ?? '');
  late final _address = TextEditingController(text: widget.initial['address']?.toString() ?? '');
  late final _landmark = TextEditingController(text: widget.initial['landmark']?.toString() ?? '');
  late final _city = TextEditingController(text: widget.initial['city']?.toString() ?? 'Gotan');
  late final _pincode = TextEditingController(text: widget.initial['pincode']?.toString() ?? '');
  late final _state = TextEditingController(text: widget.initial['state']?.toString() ?? 'Rajasthan');
  late double? _lat = (widget.initial['lat'] as num?)?.toDouble();
  late double? _lng = (widget.initial['lng'] as num?)?.toDouble();
  bool _locating = false;

  @override
  void dispose() {
    for (final c in [_name, _mobile, _address, _landmark, _city, _pincode, _state]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _useLocation() async {
    setState(() => _locating = true);
    try {
      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied || permission == LocationPermission.deniedForever) {
        throw Exception('Location permission denied');
      }
      final pos = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(accuracy: LocationAccuracy.high, timeLimit: Duration(seconds: 12)),
      );
      _lat = pos.latitude;
      _lng = pos.longitude;
      final marks = await placemarkFromCoordinates(pos.latitude, pos.longitude);
      if (marks.isNotEmpty) {
        final m = marks.first;
        final street = [m.street, m.subLocality].where((s) => s != null && s.trim().isNotEmpty).toSet().join(', ');
        if (_address.text.trim().isEmpty && street.isNotEmpty) _address.text = street;
        if ((m.locality ?? '').isNotEmpty) _city.text = m.locality!;
        if ((m.postalCode ?? '').isNotEmpty) _pincode.text = m.postalCode!;
        if ((m.administrativeArea ?? '').isNotEmpty) _state.text = m.administrativeArea!;
      }
      if (mounted) showAppSnack(context, 'Location added. Add house number and landmark.');
    } catch (_) {
      if (mounted) showAppSnack(context, 'Could not get your location', error: true);
    } finally {
      if (mounted) setState(() => _locating = false);
    }
  }

  void _save() {
    if (!_formKey.currentState!.validate()) return;
    Navigator.pop(context, {
      'name': _name.text.trim(),
      'mobile': _mobile.text.trim(),
      'address': _address.text.trim(),
      'landmark': _landmark.text.trim(),
      'city': _city.text.trim(),
      'pincode': _pincode.text.trim(),
      'state': _state.text.trim(),
      if (_lat != null) 'lat': _lat,
      if (_lng != null) 'lng': _lng,
    });
  }

  @override
  Widget build(BuildContext context) {
    String? required(String? v) => (v == null || v.trim().isEmpty) ? 'Required' : null;
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 20),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Text('Delivery address', style: TextStyle(fontSize: 19, fontWeight: FontWeight.w800)),
                const SizedBox(height: 14),
                OutlinedButton.icon(
                  onPressed: _locating ? null : _useLocation,
                  icon:
                      _locating
                          ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                          : const Icon(Icons.my_location_rounded),
                  label: Text(_lat != null ? 'Location pinned · update' : 'Use my current location'),
                ),
                const SizedBox(height: 14),
                TextFormField(
                  controller: _name,
                  textCapitalization: TextCapitalization.words,
                  decoration: const InputDecoration(labelText: 'Full name'),
                  validator: required,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _mobile,
                  keyboardType: TextInputType.phone,
                  maxLength: 10,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  decoration: const InputDecoration(labelText: 'Mobile number', prefixText: '+91 ', counterText: ''),
                  validator: (v) => RegExp(r'^[6-9]\d{9}$').hasMatch(v ?? '') ? null : 'Enter a valid 10-digit number',
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _address,
                  textCapitalization: TextCapitalization.sentences,
                  maxLines: 2,
                  minLines: 1,
                  decoration: const InputDecoration(labelText: 'House no., street, area'),
                  validator: required,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _landmark,
                  textCapitalization: TextCapitalization.sentences,
                  decoration: const InputDecoration(labelText: 'Landmark (optional)'),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: TextFormField(
                        controller: _city,
                        decoration: const InputDecoration(labelText: 'City / village'),
                        validator: required,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: TextFormField(
                        controller: _pincode,
                        keyboardType: TextInputType.number,
                        maxLength: 6,
                        inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                        decoration: const InputDecoration(labelText: 'Pincode', counterText: ''),
                        validator: (v) => RegExp(r'^\d{6}$').hasMatch(v ?? '') ? null : '6 digits',
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _state,
                  decoration: const InputDecoration(labelText: 'State'),
                  validator: required,
                ),
                const SizedBox(height: 20),
                AppButton(label: 'Save address', onPressed: _save),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
