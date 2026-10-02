import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;
import 'package:permission_handler/permission_handler.dart';
import 'package:geocoding/geocoding.dart';

import '../splash/LottieSplashScreen.dart';
import '../MapScreen.dart';
import 'MapScreenParcel.dart';


class LocationPickerPage extends StatefulWidget {
  final int page;
  const LocationPickerPage({Key? key, required this.page}) : super(key: key);

  @override
  _LocationPickerPageState createState() => _LocationPickerPageState();
}

class _LocationPickerPageState extends State<LocationPickerPage> {
  GoogleMapController? _controller;
  LatLng? _pickupLocation;
  LatLng? _destinationLocation;
  TextEditingController _pickupController = TextEditingController();
  TextEditingController _destinationController = TextEditingController();
  final FocusNode _destinationFocusNode = FocusNode();
  bool _isLoading = false;
  bool _selectingPickup = true; // true: picking pickup, false: picking destination
  bool _pickupConfirmed = false;
  List<dynamic> _suggestions = [];
  Timer? _debounce;
  final String _googleApiKey = 'AIzaSyB-HKYA7Ps8XvDkW4FBY6DR25Yk9yOnteQ';



  @override
  void initState() {
    super.initState();
    _checkPermissions().then((_) async {
      await _setCurrentLocationAsDefault();
    });
  }

  Future<void> _setCurrentLocationAsDefault() async {
    setState(() => _isLoading = true);
    try {
      Position position = await Geolocator.getCurrentPosition();
      LatLng currentLatLng = LatLng(position.latitude, position.longitude);
      _pickupLocation = currentLatLng;
      _pickupController.text = await _getAddressFromLatLng(currentLatLng);
      _controller?.animateCamera(CameraUpdate.newLatLngZoom(currentLatLng, 15));
    } catch (e) {
      print("Failed to get current location: $e");
    } finally {
      setState(() => _isLoading = false);
    }
  }


  Future<void> _checkPermissions() async {
    await Permission.location.request();
    await Geolocator.requestPermission();
  }

  void _updatePickedLocation(LatLng latLng) async {
    setState(() {
      if (_selectingPickup && !_pickupConfirmed) {
        _pickupLocation = latLng;
      } else if (!_selectingPickup) {
        _destinationLocation = latLng;
      }
    });
    _updateMapLocation(latLng);
    String address = await _getAddressFromLatLng(latLng);
    setState(() {
      if (_selectingPickup && !_pickupConfirmed) {
        _pickupController.text = address;
      } else if (!_selectingPickup) {
        _destinationController.text = address;
      }
    });
    // If pickup just confirmed, move focus to destination
    if (_pickupConfirmed && _selectingPickup == false) {
      FocusScope.of(context).requestFocus(_destinationFocusNode);
    }
  }

  Future<void> _goToCurrentLocation() async {
    setState(() => _isLoading = true);
    try {
      Position position = await Geolocator.getCurrentPosition();
      LatLng currentLatLng = LatLng(position.latitude, position.longitude);
      _updatePickedLocation(currentLatLng);
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Failed to get current location")),
      );
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<String> _getAddressFromLatLng(LatLng position) async {
    setState(() => _isLoading = true);
    try {
      List<Placemark> placemarks = await placemarkFromCoordinates(
        position.latitude, position.longitude,
      );
      if (placemarks.isNotEmpty) {
        Placemark place = placemarks.first;
        String detailedAddress = [
          place.name,
          place.street,
          place.subThoroughfare,
          place.thoroughfare,
          place.subLocality,
          place.locality,
          place.subAdministrativeArea,
          place.administrativeArea,
          place.postalCode,
          place.country,
        ].where((part) => part != null && part!.isNotEmpty).toSet().join(', ');
        return detailedAddress;
      }
      return "";
    } catch (e) {
      return "Unable to get address";
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _getLatLngFromAddress(String address) async {
    setState(() => _isLoading = true);
    try {
      List<Location> locations = await locationFromAddress(address);
      if (locations.isNotEmpty) {
        final location = locations.first;
        LatLng latLng = LatLng(location.latitude, location.longitude);
        _updatePickedLocation(latLng);
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Could not find location")),
      );
    } finally {
      setState(() => _isLoading = false);
    }
  }

  void _updateMapLocation(LatLng location) {
    _controller?.animateCamera(CameraUpdate.newLatLngZoom(location, 15));
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _pickupController.dispose();
    _destinationController.dispose();
    _destinationFocusNode.dispose();
    super.dispose();
  }


  Future<void> _fetchSuggestions(String input) async {
    final String url =
        'https://maps.googleapis.com/maps/api/place/autocomplete/json?input=$input&key=$_googleApiKey&components=country:in';

    try {
      final response = await http.get(Uri.parse(url));
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        setState(() {
          _suggestions = data['predictions'];
        });
      } else {
        setState(() {
          _suggestions = [];
        });
      }
    } catch (e) {
      print("Autocomplete Error: $e");
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      resizeToAvoidBottomInset: true,

      appBar: PreferredSize(
        preferredSize: Size.fromHeight(56),
        child: Container(
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.85),
            boxShadow: [
              BoxShadow(
                color: Colors.black12,
                blurRadius: 8,
                offset: Offset(0, 2),
              ),
            ],
            borderRadius: BorderRadius.vertical(bottom: Radius.circular(18)),
          ),
          child: SafeArea(
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                IconButton(
                  icon: Icon(Icons.arrow_back, color: Colors.black),
                  onPressed: () => Navigator.pop(context),
                ),
                Text(
                  "Set Locations",
                  style: TextStyle(
                    color: Colors.black,
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 0.5,
                  ),
                ),
                SizedBox(width: 48),
              ],
            ),
          ),
        ),
      ),
      body: SafeArea(
        child: Column(
          children: [
            // Map on top half
            Flexible(
              flex: 1,
              child: Stack(
                children: [
                  GoogleMap(
                    initialCameraPosition: CameraPosition(
                      target: _pickupLocation ?? LatLng(28.6139, 77.2090),
                      zoom: 14,
                    ),
                    myLocationEnabled: true,
                    onMapCreated: (controller) {
                      _controller = controller;
                    },
                    onTap: (LatLng location) {
                      _updatePickedLocation(location);
                    },
                    markers: {
                      if (_pickupLocation != null)
                        Marker(
                          markerId: MarkerId('pickup'),
                          position: _pickupLocation!,
                          icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueBlue),
                          infoWindow: InfoWindow(title: 'Pickup Location'),
                        ),
                      if (_destinationLocation != null)
                        Marker(
                          markerId: MarkerId('destination'),
                          position: _destinationLocation!,
                          icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueRed),
                          infoWindow: InfoWindow(title: 'Destination Location'),
                        ),
                    },
                  ),
                  if (_isLoading)
                    Center(child: CircularProgressIndicator()),
                ],
              ),
            ),
            // Modern card for address fields and confirm button
            Flexible(
              flex: 1,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
                child: Center(
                  child: Card(
                    elevation: 8,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(24),
                    ),
                    color: Colors.white,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 18),
                      child: SingleChildScrollView(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            // Pickup field
                            AnimatedContainer(
                              duration: Duration(milliseconds: 300),
                              decoration: BoxDecoration(
                                color: _pickupConfirmed ? Colors.green[50] : Colors.blue[50],
                                borderRadius: BorderRadius.circular(14),
                              ),
                              child: TextField(
                                controller: _pickupController,
                                readOnly: false,
                                onSubmitted: (value) async {
                                  if (value.isNotEmpty) {
                                    await _getLatLngFromAddress(value);
                                  }
                                },
                                onChanged: (value) {
                                  if (_selectingPickup && value.isNotEmpty) {
                                    if (_debounce?.isActive ?? false) _debounce?.cancel();
                                    _debounce = Timer(const Duration(milliseconds: 500), () {
                                      _fetchSuggestions(value);
                                    });
                                  }
                                },
                                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
                                decoration: InputDecoration(
                                  prefixIcon: Icon(Icons.location_on, color: Colors.blue),
                                  labelText: "Pickup Location",
                                  filled: true,
                                  fillColor: Colors.transparent,
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(14),
                                    borderSide: BorderSide(color: Colors.blueAccent, width: 1.2),
                                  ),
                                  enabledBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(14),
                                    borderSide: BorderSide(color: Colors.blueAccent, width: 1.2),
                                  ),
                                  focusedBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(14),
                                    borderSide: BorderSide(color: Colors.blue, width: 2),
                                  ),
                                  suffixIcon: _pickupConfirmed
                                      ? Icon(Icons.check_circle, color: Colors.green)
                                      : (_selectingPickup ? Icon(Icons.edit, color: Colors.blue) : null),
                                ),
                              ),
                            ),
                            SizedBox(height: 16),
                            // Destination field
                            AnimatedContainer(
                              duration: Duration(milliseconds: 300),
                              decoration: BoxDecoration(
                                color: (!_selectingPickup && _pickupConfirmed) ? Colors.green[50] : Colors.grey[100],
                                borderRadius: BorderRadius.circular(14),
                              ),
                              child: Focus(
                                onFocusChange: (hasFocus) {
                                  setState(() {});
                                },
                                child: TextField(
                                  focusNode: _destinationFocusNode,
                                  controller: _destinationController,
                                  readOnly: false,
                                  onTap: () => setState(() => _selectingPickup = false),
                                  onSubmitted: (value) async {
                                    if (value.isNotEmpty) {
                                      setState(() => _selectingPickup = false);
                                      await _getLatLngFromAddress(value);
                                    }
                                  },
                                  onChanged: (value) {
                                    if (!_selectingPickup && value.isNotEmpty) {
                                      if (_debounce?.isActive ?? false) _debounce?.cancel();
                                      _debounce = Timer(const Duration(milliseconds: 500), () {
                                        _fetchSuggestions(value);
                                      });
                                    }
                                  },
                                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
                                  decoration: InputDecoration(
                                    prefixIcon: Icon(Icons.flag, color: Colors.blue),
                                    labelText: "Destination Location",
                                    filled: true,
                                    fillColor: Colors.transparent,
                                    border: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(14),
                                      borderSide: BorderSide(color: Colors.blue, width: 1.2),
                                    ),
                                    enabledBorder: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(14),
                                      borderSide: BorderSide(color: Colors.blue, width: 1.2),
                                    ),
                                    focusedBorder: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(14),
                                      borderSide: BorderSide(color: Colors.green, width: 2),
                                    ),
                                    suffixIcon: (!_selectingPickup && _pickupConfirmed)
                                        ? Icon(Icons.edit, color: Colors.green)
                                        : null,
                                  ),
                                ),
                              ),
                            ),
                            SizedBox(height: 10),
                            if (_suggestions.isNotEmpty)
                              Container(
                                height: 100,
                                child: Scrollbar(
                                  thumbVisibility: true,
                                  child: ListView.builder(
                                    shrinkWrap: true,
                                    itemCount: _suggestions.length,
                                    itemBuilder: (context, index) {
                                      final s = _suggestions[index];
                                      return ListTile(
                                        dense: true,
                                        title: Text(s['description'], style: TextStyle(fontSize: 14)),
                                        onTap: () async {
                                          if (_selectingPickup) {
                                            _pickupController.text = s['description'];
                                            await _getLatLngFromAddress(s['description']);
                                          } else {
                                            _destinationController.text = s['description'];
                                            await _getLatLngFromAddress(s['description']);
                                          }
                                          setState(() => _suggestions.clear());
                                        },
                                      );
                                    },
                                  ),
                                ),
                              ),
                            SizedBox(height: 15),
                            Row(
                              children: [
                                Expanded(
                                  child: OutlinedButton.icon(
                                    onPressed: _goToCurrentLocation,
                                    icon: Icon(Icons.my_location, color: Colors.blue),
                                    label: Text("Current Location", style: TextStyle(color: Colors.blue)),
                                    style: OutlinedButton.styleFrom(
                                      side: BorderSide(color: Colors.blueAccent, width: 1.2),
                                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                                      padding: EdgeInsets.symmetric(vertical: 14),
                                    ),
                                  ),
                                ),
                                SizedBox(width: 12),
                                Expanded(
                                  child: !_pickupConfirmed
                                      ? ElevatedButton(
                                          onPressed: (_pickupLocation != null)
                                              ? () {
                                                  setState(() {
                                                    _pickupConfirmed = true;
                                                    _selectingPickup = false;
                                                  });
                                                }
                                              : null,
                                          style: ElevatedButton.styleFrom(
                                            backgroundColor: Colors.blue,
                                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                                            padding: EdgeInsets.symmetric(vertical: 14),
                                            elevation: 2,
                                          ),
                                          child: Text("Confirm Pickup", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                                        )
                                      : ElevatedButton(
                                          onPressed: (_pickupLocation != null && _destinationLocation != null)
                                              ? () {
                                                  if (widget.page == 1) {
                                                    Navigator.push(
                                                      context,
                                                      MaterialPageRoute(
                                                        builder: (context) => LottieSplashScreen(
                                                          nextPage: MapScreen(
                                                            pickup: _pickupLocation!,
                                                            destination: _destinationLocation!,
                                                            pick: _pickupController.text,
                                                            dest: _destinationController.text,
                                                          ),
                                                          assetPath: 'assets/animations/travel.json',
                                                        ),
                                                      ),
                                                    );
                                                  } else {
                                                    Navigator.push(
                                                      context,
                                                      MaterialPageRoute(
                                                        builder: (context) => MapScreenParcel(
                                                          pickup: _pickupLocation!,
                                                          destination: _destinationLocation!,
                                                          pick: _pickupController.text,
                                                          dest: _destinationController.text,
                                                        ),
                                                      ),
                                                    );
                                                  }
                                                }
                                              : null,
                                          style: ElevatedButton.styleFrom(
                                            backgroundColor: Colors.redAccent,
                                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                                            padding: EdgeInsets.symmetric(vertical: 14),
                                            elevation: 2,
                                          ),
                                          child: Text("Confirm Destination", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                                        ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: SizedBox.shrink(),
    );
  }
}
