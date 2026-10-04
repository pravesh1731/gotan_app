import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:geocoding/geocoding.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:http/http.dart' as http;

import '../global/common.dart';
import '../model/booking.dart';
import '../theme/app_theme.dart';
import '../widgets/ui.dart';
import 'BookingConfirmScreen.dart';

class PickedPlace {
  final LatLng latLng;
  final String address;
  const PickedPlace(this.latLng, this.address);
}

class LocationPickerPage extends StatefulWidget {
  final BookingKind kind;
  const LocationPickerPage({super.key, required this.kind});

  @override
  State<LocationPickerPage> createState() => _LocationPickerPageState();
}

enum _Field { pickup, drop }

class _LocationPickerPageState extends State<LocationPickerPage> {
  static const _gotan = LatLng(26.845, 73.99);
  static const _pickupColor = AppColors.success;
  static const _dropColor = Color(0xFFF97316);

  GoogleMapController? _map;
  LatLng _cameraTarget = _gotan;
  // Skip the first idle so the default Gotan centre is never used as pickup.
  bool _skipNextIdle = true;

  PickedPlace? _pickup;
  PickedPlace? _drop;
  _Field _active = _Field.pickup;

  final _pickupController = TextEditingController();
  final _dropController = TextEditingController();
  final _pickupFocus = FocusNode();
  final _dropFocus = FocusNode();

  List<Map<String, dynamic>> _suggestions = [];
  Timer? _debounce;
  bool _resolving = false;
  String _sessionToken = DateTime.now().microsecondsSinceEpoch.toString();

  @override
  void initState() {
    super.initState();
    _pickupFocus.addListener(() {
      if (_pickupFocus.hasFocus) setState(() => _active = _Field.pickup);
    });
    _dropFocus.addListener(() {
      if (_dropFocus.hasFocus) setState(() => _active = _Field.drop);
    });
    _useCurrentLocation(initial: true);
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _pickupController.dispose();
    _dropController.dispose();
    _pickupFocus.dispose();
    _dropFocus.dispose();
    super.dispose();
  }

  // ----------------------------------------------------------- locations

  Future<void> _useCurrentLocation({bool initial = false}) async {
    setState(() => _resolving = true);
    try {
      final pos = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(accuracy: LocationAccuracy.high, timeLimit: Duration(seconds: 12)),
      );
      final latLng = LatLng(pos.latitude, pos.longitude);
      final address = await _reverseGeocode(latLng);
      if (!mounted) return;
      _setPlace(initial ? _Field.pickup : _active, PickedPlace(latLng, address), moveCamera: true);
    } catch (_) {
      if (mounted && !initial) showAppSnack(context, 'Could not get your location. Search for the place instead.', error: true);
    } finally {
      if (mounted) setState(() => _resolving = false);
    }
  }

  Future<String> _reverseGeocode(LatLng p) async {
    try {
      final placemarks = await placemarkFromCoordinates(p.latitude, p.longitude);
      if (placemarks.isNotEmpty) {
        final pm = placemarks.first;
        final plusCode = RegExp(r'^[23456789CFGHJMPQRVWX]{4,8}\+[23456789CFGHJMPQRVWX]{2,3}$');
        final parts = <String>[];
        for (final part in [pm.name, pm.street, pm.subLocality, pm.locality, pm.subAdministrativeArea, pm.postalCode]) {
          final t = part?.trim() ?? '';
          if (t.isEmpty || plusCode.hasMatch(t) || parts.contains(t)) continue;
          parts.add(t);
        }
        if (parts.isNotEmpty) return parts.join(', ');
      }
    } catch (_) {}
    return 'Pinned location (${p.latitude.toStringAsFixed(5)}, ${p.longitude.toStringAsFixed(5)})';
  }

  void _setPlace(_Field field, PickedPlace place, {bool moveCamera = false}) {
    setState(() {
      if (field == _Field.pickup) {
        _pickup = place;
        _pickupController.text = place.address;
      } else {
        _drop = place;
        _dropController.text = place.address;
      }
      _suggestions = [];
    });
    if (moveCamera) {
      _skipNextIdle = true;
      _map?.animateCamera(CameraUpdate.newLatLngZoom(place.latLng, 16));
    }
  }

  Future<void> _onCameraIdle() async {
    if (_skipNextIdle) {
      _skipNextIdle = false;
      return;
    }
    final target = _cameraTarget;
    final field = _active;
    setState(() => _resolving = true);
    final address = await _reverseGeocode(target);
    if (!mounted) return;
    setState(() => _resolving = false);
    // Ignore if the map moved again while geocoding.
    if (target != _cameraTarget) return;
    _setPlace(field, PickedPlace(target, address));
  }

  // -------------------------------------------------------------- search

  void _onSearchChanged(String value) {
    _debounce?.cancel();
    if (value.trim().length < 2) {
      setState(() => _suggestions = []);
      return;
    }
    _debounce = Timer(const Duration(milliseconds: 400), () => _fetchSuggestions(value.trim()));
  }

  Future<void> _fetchSuggestions(String input) async {
    final uri = Uri.https('maps.googleapis.com', '/maps/api/place/autocomplete/json', {
      'input': input,
      'key': Common.mapsApiKey,
      'components': 'country:in',
      'location': '${_cameraTarget.latitude},${_cameraTarget.longitude}',
      'radius': '30000',
      'sessiontoken': _sessionToken,
    });
    try {
      final res = await http.get(uri).timeout(const Duration(seconds: 10));
      if (res.statusCode != 200) return;
      final data = jsonDecode(res.body);
      if (!mounted) return;
      setState(() {
        _suggestions = (data['predictions'] as List? ?? const []).whereType<Map>().map((m) => m.cast<String, dynamic>()).toList();
      });
    } catch (_) {
      // Leave the current suggestions; the user can retry by typing.
    }
  }

  Future<void> _selectSuggestion(Map<String, dynamic> s) async {
    final field = _active;
    final description = (s['description'] ?? '').toString();
    FocusScope.of(context).unfocus();
    setState(() {
      _suggestions = [];
      _resolving = true;
    });
    try {
      final uri = Uri.https('maps.googleapis.com', '/maps/api/place/details/json', {
        'place_id': s['place_id'].toString(),
        'fields': 'geometry,formatted_address,name',
        'key': Common.mapsApiKey,
        'sessiontoken': _sessionToken,
      });
      final res = await http.get(uri).timeout(const Duration(seconds: 10));
      final result = jsonDecode(res.body)['result'];
      final loc = result?['geometry']?['location'];
      if (loc == null) throw Exception('No coordinates');
      final latLng = LatLng((loc['lat'] as num).toDouble(), (loc['lng'] as num).toDouble());
      if (!mounted) return;
      _setPlace(field, PickedPlace(latLng, description), moveCamera: true);
      if (field == _Field.pickup && _drop == null) {
        setState(() => _active = _Field.drop);
      }
    } catch (_) {
      if (mounted) showAppSnack(context, 'Could not find that place. Try another search.', error: true);
    } finally {
      _sessionToken = DateTime.now().microsecondsSinceEpoch.toString();
      if (mounted) setState(() => _resolving = false);
    }
  }

  // ------------------------------------------------------------ continue

  void _continue() {
    final pickup = _pickup;
    final drop = _drop;
    if (pickup == null || drop == null) {
      showAppSnack(context, 'Set both pickup and drop locations', error: true);
      return;
    }
    final meters = Geolocator.distanceBetween(
      pickup.latLng.latitude,
      pickup.latLng.longitude,
      drop.latLng.latitude,
      drop.latLng.longitude,
    );
    if (meters < 50) {
      showAppSnack(context, 'Pickup and drop are the same place. Move the drop pin.', error: true);
      return;
    }
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => BookingConfirmScreen(kind: widget.kind, pickup: pickup, drop: drop)),
    );
  }

  // --------------------------------------------------------------- build

  @override
  Widget build(BuildContext context) {
    final isRide = widget.kind == BookingKind.ride;
    final pinColor = _active == _Field.pickup ? _pickupColor : _dropColor;

    return Scaffold(
      backgroundColor: AppColors.surface,
      appBar: AppBar(title: Text(isRide ? 'Book a Rider' : 'Send a Parcel')),
      body: Column(
        children: [
          Expanded(
            child: Stack(
              children: [
                GoogleMap(
                  initialCameraPosition: const CameraPosition(target: _gotan, zoom: 14),
                  myLocationEnabled: true,
                  myLocationButtonEnabled: false,
                  zoomControlsEnabled: false,
                  mapToolbarEnabled: false,
                  onMapCreated: (c) {
                    _map = c;
                    // GPS may have answered before the map existed.
                    final p = _active == _Field.pickup ? _pickup : _drop;
                    if (p != null) {
                      _skipNextIdle = true;
                      c.moveCamera(CameraUpdate.newLatLngZoom(p.latLng, 16));
                    }
                  },
                  onCameraMove: (pos) => _cameraTarget = pos.target,
                  onCameraIdle: _onCameraIdle,
                  onTap: (latLng) {
                    FocusScope.of(context).unfocus();
                    _map?.animateCamera(CameraUpdate.newLatLng(latLng));
                  },
                  markers: {
                    if (_pickup != null && _active != _Field.pickup)
                      Marker(
                        markerId: const MarkerId('pickup'),
                        position: _pickup!.latLng,
                        icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueGreen),
                        infoWindow: const InfoWindow(title: 'Pickup'),
                      ),
                    if (_drop != null && _active != _Field.drop)
                      Marker(
                        markerId: const MarkerId('drop'),
                        position: _drop!.latLng,
                        icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueOrange),
                        infoWindow: const InfoWindow(title: 'Drop'),
                      ),
                  },
                ),
                // Fixed centre pin: drag the map to move the active point.
                IgnorePointer(
                  child: Center(
                    child: Padding(
                      padding: const EdgeInsets.only(bottom: 36),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                            decoration: BoxDecoration(color: AppColors.navy, borderRadius: BorderRadius.circular(999)),
                            child: Text(
                              _active == _Field.pickup ? 'Pickup here' : 'Drop here',
                              style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w600),
                            ),
                          ),
                          Icon(Icons.location_on, size: 44, color: pinColor),
                        ],
                      ),
                    ),
                  ),
                ),
                Positioned(
                  right: 14,
                  bottom: 14,
                  child: FloatingActionButton.small(
                    heroTag: 'my-location',
                    backgroundColor: AppColors.surface,
                    foregroundColor: AppColors.teal,
                    onPressed: () => _useCurrentLocation(),
                    child: const Icon(Icons.my_location_rounded),
                  ),
                ),
                if (_resolving)
                  const Positioned(top: 0, left: 0, right: 0, child: LinearProgressIndicator(minHeight: 3)),
              ],
            ),
          ),
          _buildPanel(),
        ],
      ),
    );
  }

  Widget _buildPanel() {
    Widget field({
      required _Field which,
      required TextEditingController controller,
      required FocusNode focus,
      required String hint,
      required Color color,
    }) {
      final active = _active == which;
      return GestureDetector(
        onTap: () => setState(() => _active = which),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          decoration: BoxDecoration(
            color: active ? AppColors.surface : AppColors.background,
            borderRadius: BorderRadius.circular(AppRadius.md),
            border: Border.all(color: active ? color : AppColors.border, width: active ? 1.6 : 1),
          ),
          child: Row(
            children: [
              const SizedBox(width: 12),
              Container(
                width: 12,
                height: 12,
                decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: color, width: 3)),
              ),
              Expanded(
                child: TextField(
                  controller: controller,
                  focusNode: focus,
                  onTap: () {
                    setState(() => _active = which);
                    controller.selection = TextSelection(baseOffset: 0, extentOffset: controller.text.length);
                  },
                  onChanged: _onSearchChanged,
                  maxLines: 1,
                  style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
                  decoration: InputDecoration(
                    hintText: hint,
                    filled: false,
                    border: InputBorder.none,
                    enabledBorder: InputBorder.none,
                    focusedBorder: InputBorder.none,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 14),
                    suffixIcon: controller.text.isNotEmpty && active
                        ? IconButton(
                            icon: const Icon(Icons.close_rounded, size: 18),
                            onPressed: () {
                              controller.clear();
                              setState(() => _suggestions = []);
                              focus.requestFocus();
                            },
                          )
                        : null,
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    }

    return Container(
      padding: EdgeInsets.fromLTRB(16, 16, 16, 16 + MediaQuery.of(context).padding.bottom),
      decoration: const BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadius.xl)),
        boxShadow: AppShadows.float,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          field(
            which: _Field.pickup,
            controller: _pickupController,
            focus: _pickupFocus,
            hint: 'Search pickup location',
            color: _pickupColor,
          ),
          const SizedBox(height: 10),
          field(
            which: _Field.drop,
            controller: _dropController,
            focus: _dropFocus,
            hint: widget.kind == BookingKind.ride ? 'Where to?' : 'Where should it go?',
            color: _dropColor,
          ),
          if (_suggestions.isNotEmpty)
            Container(
              margin: const EdgeInsets.only(top: 8),
              constraints: const BoxConstraints(maxHeight: 220),
              decoration: BoxDecoration(
                border: Border.all(color: AppColors.border),
                borderRadius: BorderRadius.circular(AppRadius.md),
              ),
              child: ListView.separated(
                shrinkWrap: true,
                padding: EdgeInsets.zero,
                itemCount: _suggestions.length,
                separatorBuilder: (_, __) => const Divider(),
                itemBuilder: (context, i) {
                  final s = _suggestions[i];
                  final fmt = (s['structured_formatting'] as Map?) ?? const {};
                  return ListTile(
                    dense: true,
                    leading: const Icon(Icons.place_outlined, color: AppColors.textSecondary),
                    title: Text((fmt['main_text'] ?? s['description'] ?? '').toString(),
                        maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w600)),
                    subtitle: Text((fmt['secondary_text'] ?? '').toString(), maxLines: 1, overflow: TextOverflow.ellipsis),
                    onTap: () => _selectSuggestion(s),
                  );
                },
              ),
            )
          else ...[
            const SizedBox(height: 10),
            Text(
              _active == _Field.pickup
                  ? 'Drag the map or search to set the pickup point'
                  : 'Drag the map or search to set the drop point',
              style: const TextStyle(color: AppColors.textSecondary, fontSize: 12),
            ),
          ],
          const SizedBox(height: 14),
          if (_pickup != null && _drop == null && _active == _Field.pickup)
            AppButton(
              label: 'Confirm pickup',
              onPressed: () {
                setState(() => _active = _Field.drop);
                _dropFocus.requestFocus();
              },
            )
          else
            AppButton(
              label: 'Continue',
              icon: Icons.arrow_forward_rounded,
              onPressed: (_pickup != null && _drop != null && !_resolving) ? _continue : null,
            ),
        ],
      ),
    );
  }
}
