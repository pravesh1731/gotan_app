import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:intl/intl.dart';
import 'package:lottie/lottie.dart' show Lottie;
import 'package:provider/provider.dart';

import '../global/common.dart';
import '../model/booking.dart';
import '../model/directions.dart';
import '../providers/UserProvider.dart';
import '../repo/directions_repository.dart';
import '../services/api.dart';
import '../services/session.dart';
import '../theme/app_theme.dart';
import '../utils/fare.dart';
import '../widgets/ui.dart';
import 'BookingTrackingScreen.dart';
import 'LocationPickerPage.dart';

/// Step 2 of booking (website: datentime.jsx + waiting.jsx): choose vehicle or
/// parcel details, see the fare, and confirm.
class BookingConfirmScreen extends StatefulWidget {
  final BookingKind kind;
  final PickedPlace pickup;
  final PickedPlace drop;

  const BookingConfirmScreen({super.key, required this.kind, required this.pickup, required this.drop});

  @override
  State<BookingConfirmScreen> createState() => _BookingConfirmScreenState();
}

class _BookingConfirmScreenState extends State<BookingConfirmScreen> {
  static const _vehicles = [
    ('Bike', 'assets/images/vehicles/bike.png'),
    ('Auto', 'assets/images/vehicles/auto.png'),
    ('Car', 'assets/images/vehicles/car.png'),
  ];

  GoogleMapController? _map;
  Directions? _route;
  bool _loadingRoute = true;
  bool _approximate = false;
  int _meters = 0;
  String _distanceText = '';
  String _durationText = '';

  String _vehicle = 'Bike';
  int _passengers = 1;
  DateTime? _scheduledAt;

  final _weightController = TextEditingController();
  final _messageController = TextEditingController();

  bool _submitting = false;

  bool get _isRide => widget.kind == BookingKind.ride;

  @override
  void initState() {
    super.initState();
    _loadRoute();
  }

  @override
  void dispose() {
    _weightController.dispose();
    _messageController.dispose();
    super.dispose();
  }

  Future<void> _loadRoute() async {
    setState(() => _loadingRoute = true);
    Directions? route;
    try {
      route = await DirectionsRepository().getDirections(origin: widget.pickup.latLng, destination: widget.drop.latLng);
    } catch (_) {
      route = null;
    }
    if (!mounted) return;

    if (route != null && route.distanceMeters > 0) {
      setState(() {
        _route = route;
        _approximate = false;
        _meters = route!.distanceMeters;
        _distanceText = route.totalDistance;
        _durationText = route.totalDuration;
        _loadingRoute = false;
      });
      _map?.animateCamera(CameraUpdate.newLatLngBounds(route.bounds, 48));
    } else {
      // No road route (or Directions unavailable): estimate from straight-line
      // distance so booking still works, and say so on screen.
      final straight = Geolocator.distanceBetween(
        widget.pickup.latLng.latitude,
        widget.pickup.latLng.longitude,
        widget.drop.latLng.latitude,
        widget.drop.latLng.longitude,
      );
      final meters = (straight * 1.3).round();
      setState(() {
        _route = null;
        _approximate = true;
        _meters = meters;
        _distanceText = '${(meters / 1000).toStringAsFixed(1)} km';
        _durationText = '';
        _loadingRoute = false;
      });
      _fitMarkers();
    }
  }

  void _fitMarkers() {
    final a = widget.pickup.latLng, b = widget.drop.latLng;
    final bounds = LatLngBounds(
      southwest: LatLng(a.latitude < b.latitude ? a.latitude : b.latitude, a.longitude < b.longitude ? a.longitude : b.longitude),
      northeast: LatLng(a.latitude > b.latitude ? a.latitude : b.latitude, a.longitude > b.longitude ? a.longitude : b.longitude),
    );
    _map?.animateCamera(CameraUpdate.newLatLngBounds(bounds, 56));
  }

  int get _fare => _isRide ? Fare.ride(_vehicle, _meters) : Fare.parcel(_meters);

  Future<void> _pickSchedule() async {
    final now = DateTime.now();
    final earliest = now.add(const Duration(minutes: 15));
    final date = await showDatePicker(
      context: context,
      initialDate: _scheduledAt ?? earliest,
      firstDate: DateTime(now.year, now.month, now.day),
      lastDate: now.add(const Duration(days: 30)),
    );
    if (date == null || !mounted) return;
    final time = await showTimePicker(context: context, initialTime: TimeOfDay.fromDateTime(_scheduledAt ?? earliest));
    if (time == null || !mounted) return;
    final picked = DateTime(date.year, date.month, date.day, time.hour, time.minute);
    if (picked.isBefore(earliest)) {
      showAppSnack(context, 'Pick a time at least 15 minutes from now', error: true);
      return;
    }
    setState(() => _scheduledAt = picked);
  }

  String _formatPickupTime(DateTime t) => DateFormat("yyyy-MM-dd'T'HH:mm").format(t);

  Future<void> _confirm() async {
    if (_loadingRoute) return;
    if (_meters < Fare.minDistanceMeters) {
      showAppSnack(context, 'Pickup and drop are too close. Please check the locations.', error: true);
      return;
    }
    if (!_isRide) {
      if (_weightController.text.trim().isEmpty) {
        showAppSnack(context, 'Please enter the parcel weight', error: true);
        return;
      }
      if (_messageController.text.trim().isEmpty) {
        showAppSnack(context, 'Tell the rider what you are sending', error: true);
        return;
      }
    }

    final user = context.read<UserProvider>();
    final phone = user.phone;
    final name = user.name;
    final city = await Session.city();
    final pickupTime = _formatPickupTime(_scheduledAt ?? DateTime.now());
    final price = _fare;

    final orderDetails = <String, dynamic>{
      'sellerName': name,
      'sellerPhone': phone,
      // Riders' dashboards filter by this city.
      'cityName': Common.cityName,
      'pickupAddress': widget.pickup.address,
      'deliveryAddress': widget.drop.address,
      'pickupTime': pickupTime,
      if (_isRide) ...{
        'vehicleType': _vehicle,
        'numOfPassengers': _passengers,
      } else ...{
        'weight': '${_weightController.text.trim()} kg',
        'message': _messageController.text.trim(),
      },
    };

    setState(() => _submitting = true);
    String? orderId;
    try {
      orderId = await Api.createBooking(widget.kind, phone, orderDetails);
      await Api.confirmBooking(
        widget.kind,
        phone: phone,
        orderId: orderId,
        price: price,
        distance: _distanceText,
        cityName: city,
      );
      await Session.setActiveOrderId(orderId, ride: _isRide);
      if (!mounted) return;
      await _showConfirmedAnimation();
      if (!mounted) return;
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (_) => BookingTrackingScreen(kind: widget.kind, orderId: orderId!)),
        (route) => route.isFirst,
      );
    } catch (e) {
      // Don't leave a half-created booking behind.
      if (orderId != null) {
        Api.cancelBooking(widget.kind, phone, orderId).catchError((_) {});
      }
      if (!mounted) return;
      final msg = e is ApiException && e.statusCode == 404
          ? 'Your account was not found. Please log out and log in again.'
          : e.toString();
      showAppSnack(context, msg, error: true);
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  Future<void> _showConfirmedAnimation() async {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => Dialog(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Lottie.asset('assets/animations/confirm.json', height: 150, repeat: false),
              Text(_isRide ? 'Ride booked!' : 'Parcel booked!',
                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
              const SizedBox(height: 4),
              const Text('Finding a rider near you…', style: TextStyle(color: AppColors.textSecondary)),
            ],
          ),
        ),
      ),
    );
    await Future.delayed(const Duration(milliseconds: 1800));
    if (mounted) Navigator.of(context, rootNavigator: true).pop();
  }

  // --------------------------------------------------------------- build

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(_isRide ? 'Choose your ride' : 'Parcel details')),
      body: ListView(
        padding: const EdgeInsets.only(bottom: 24),
        children: [
          SizedBox(height: 210, child: _buildMap()),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
            child: AppCard(
              child: Column(
                children: [
                  RouteSummary(pickup: widget.pickup.address, drop: widget.drop.address, maxLines: 2),
                  const SizedBox(height: 14),
                  const Divider(),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      _metric(Icons.route_outlined, 'Distance', _loadingRoute ? '…' : '$_distanceText${_approximate ? ' (approx.)' : ''}'),
                      const SizedBox(width: 12),
                      _metric(Icons.schedule_outlined, 'Travel time', _loadingRoute ? '…' : (_durationText.isEmpty ? '--' : _durationText)),
                    ],
                  ),
                  if (_approximate) ...[
                    const SizedBox(height: 10),
                    const Text(
                      'Road route unavailable. Fare is estimated from straight-line distance.',
                      style: TextStyle(color: Color(0xFFB7791F), fontSize: 12),
                    ),
                  ],
                ],
              ),
            ),
          ),
          if (_isRide) ..._buildRideOptions() else ..._buildParcelOptions(),
          _buildScheduleCard(),
          _buildFareCard(),
        ],
      ),
      bottomNavigationBar: SafeArea(
        child: Container(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
          decoration: const BoxDecoration(
            color: AppColors.surface,
            border: Border(top: BorderSide(color: AppColors.border)),
          ),
          child: Row(
            children: [
              Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Total fare', style: TextStyle(color: AppColors.textSecondary, fontSize: 12)),
                  Text(_loadingRoute ? '₹--' : rupees(_fare),
                      style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800, fontFamily: AppTheme.displayFamily)),
                ],
              ),
              const SizedBox(width: 16),
              Expanded(
                child: AppButton(
                  label: _isRide ? 'Book $_vehicle' : 'Book parcel',
                  loading: _submitting,
                  onPressed: _loadingRoute ? null : _confirm,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMap() {
    final markers = {
      Marker(
        markerId: const MarkerId('pickup'),
        position: widget.pickup.latLng,
        icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueGreen),
      ),
      Marker(
        markerId: const MarkerId('drop'),
        position: widget.drop.latLng,
        icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueOrange),
      ),
    };
    final polylines = <Polyline>{
      if (_route != null)
        Polyline(
          polylineId: const PolylineId('route'),
          color: AppColors.teal,
          width: 5,
          points: _route!.polylinePoints.map((p) => LatLng(p.latitude, p.longitude)).toList(),
        ),
    };
    return Stack(
      children: [
        GoogleMap(
          initialCameraPosition: CameraPosition(target: widget.pickup.latLng, zoom: 13),
          markers: markers,
          polylines: polylines,
          zoomControlsEnabled: false,
          myLocationButtonEnabled: false,
          mapToolbarEnabled: false,
          liteModeEnabled: false,
          onMapCreated: (c) {
            _map = c;
            if (_route != null) {
              c.animateCamera(CameraUpdate.newLatLngBounds(_route!.bounds, 48));
            } else {
              Future.delayed(const Duration(milliseconds: 300), _fitMarkers);
            }
          },
        ),
        if (_loadingRoute) const Positioned(top: 0, left: 0, right: 0, child: LinearProgressIndicator(minHeight: 3)),
      ],
    );
  }

  Widget _metric(IconData icon, String label, String value) {
    return Expanded(
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(color: AppColors.tealLight, borderRadius: BorderRadius.circular(AppRadius.md)),
            child: Icon(icon, size: 18, color: AppColors.teal),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: const TextStyle(fontSize: 11, color: AppColors.textSecondary)),
                Text(value, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w700)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  List<Widget> _buildRideOptions() {
    final maxPassengers = Fare.maxPassengers[_vehicle] ?? 1;
    return [
      const Padding(padding: EdgeInsets.fromLTRB(16, 24, 16, 12), child: Text('Choose your ride', style: _sectionStyle)),
      ..._vehicles.map((v) {
        final (name, image) = v;
        final selected = _vehicle == name;
        return Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
          child: AppCard(
            padding: const EdgeInsets.all(12),
            borderColor: selected ? AppColors.teal : AppColors.border,
            color: selected ? AppColors.tealLight.withValues(alpha: 0.45) : AppColors.surface,
            onTap: () => setState(() {
              _vehicle = name;
              _passengers = _passengers.clamp(1, Fare.maxPassengers[name] ?? 1);
            }),
            child: Row(
              children: [
                Container(
                  width: 58,
                  height: 58,
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: selected ? AppColors.surface : AppColors.background,
                    shape: BoxShape.circle,
                  ),
                  child: Image.asset(image, fit: BoxFit.contain),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(name, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
                      const SizedBox(height: 2),
                      Text(
                        'Up to ${Fare.maxPassengers[name]} passenger${Fare.maxPassengers[name] == 1 ? '' : 's'} · ₹${Fare.ratePerKm[name]}/km',
                        style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
                      ),
                    ],
                  ),
                ),
                Text(
                  _loadingRoute ? '--' : rupees(Fare.ride(name, _meters)),
                  style: TextStyle(fontWeight: FontWeight.w800, fontSize: 17, color: selected ? AppColors.tealDark : AppColors.textPrimary),
                ),
              ],
            ),
          ),
        );
      }),
      Padding(
        padding: const EdgeInsets.fromLTRB(16, 6, 16, 0),
        child: AppCard(
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Passengers', style: TextStyle(fontWeight: FontWeight.w700)),
                    Text('Maximum $maxPassengers for $_vehicle', style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                  ],
                ),
              ),
              _Stepper(
                value: _passengers,
                min: 1,
                max: maxPassengers,
                onChanged: (v) => setState(() => _passengers = v),
              ),
            ],
          ),
        ),
      ),
    ];
  }

  List<Widget> _buildParcelOptions() {
    return [
      const Padding(padding: EdgeInsets.fromLTRB(16, 24, 16, 12), child: Text('What are you sending?', style: _sectionStyle)),
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: AppCard(
          child: Column(
            children: [
              TextField(
                controller: _weightController,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9.]'))],
                decoration: const InputDecoration(
                  labelText: 'Approx. weight',
                  hintText: 'e.g. 2',
                  suffixText: 'kg',
                  prefixIcon: Icon(Icons.scale_outlined),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _messageController,
                maxLines: 3,
                minLines: 2,
                textCapitalization: TextCapitalization.sentences,
                decoration: const InputDecoration(
                  labelText: 'Package details & instructions',
                  hintText: 'e.g. Documents in an envelope. Call receiver on arrival.',
                  alignLabelWithHint: true,
                ),
              ),
            ],
          ),
        ),
      ),
    ];
  }

  Widget _buildScheduleCard() {
    Widget option(String label, String sub, bool selected, VoidCallback onTap) => Expanded(
          child: AppCard(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
            borderColor: selected ? AppColors.teal : AppColors.border,
            color: selected ? AppColors.tealLight.withValues(alpha: 0.45) : AppColors.surface,
            onTap: onTap,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: const TextStyle(fontWeight: FontWeight.w700)),
                const SizedBox(height: 2),
                Text(sub, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
              ],
            ),
          ),
        );

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 24, 16, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(_isRide ? 'When do you want to ride?' : 'When should we pick it up?', style: _sectionStyle),
          const SizedBox(height: 12),
          Row(
            children: [
              option('Now', 'Rider comes ASAP', _scheduledAt == null, () => setState(() => _scheduledAt = null)),
              const SizedBox(width: 10),
              option(
                'Schedule',
                _scheduledAt == null ? 'Pick date & time' : DateFormat('d MMM, h:mm a').format(_scheduledAt!),
                _scheduledAt != null,
                _pickSchedule,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildFareCard() {
    final rate = _isRide ? Fare.ratePerKm[_vehicle]! : Fare.parcelRatePerKm;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 24, 16, 0),
      child: AppCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Row(
              children: [
                Icon(Icons.payments_outlined, color: AppColors.teal, size: 20),
                SizedBox(width: 8),
                Text('Fare details', style: TextStyle(fontWeight: FontWeight.w700)),
              ],
            ),
            const SizedBox(height: 10),
            InfoRow(label: 'Distance', value: _loadingRoute ? '…' : _distanceText),
            InfoRow(label: 'Rate', value: '₹$rate per km'),
            const Divider(),
            InfoRow(label: 'Total', value: _loadingRoute ? '₹--' : rupees(_fare), bold: true),
            const SizedBox(height: 6),
            const Text(
              'Pay the rider directly in cash or UPI after the trip.',
              style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
            ),
          ],
        ),
      ),
    );
  }
}

const _sectionStyle = TextStyle(fontSize: 17, fontWeight: FontWeight.w700, color: AppColors.textPrimary);

class _Stepper extends StatelessWidget {
  final int value;
  final int min;
  final int max;
  final ValueChanged<int> onChanged;

  const _Stepper({required this.value, required this.min, required this.max, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    Widget btn(IconData icon, bool enabled, VoidCallback onTap) => InkWell(
          onTap: enabled ? onTap : null,
          customBorder: const CircleBorder(),
          child: Padding(
            padding: const EdgeInsets.all(8),
            child: Icon(icon, size: 20, color: enabled ? AppColors.teal : AppColors.textDisabled),
          ),
        );
    return Container(
      decoration: BoxDecoration(
        border: Border.all(color: AppColors.border),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          btn(Icons.remove_rounded, value > min, () => onChanged(value - 1)),
          SizedBox(width: 28, child: Text('$value', textAlign: TextAlign.center, style: const TextStyle(fontWeight: FontWeight.w700))),
          btn(Icons.add_rounded, value < max, () => onChanged(value + 1)),
        ],
      ),
    );
  }
}
