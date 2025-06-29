import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';
import 'package:gotan/MapScreen.dart';
import 'package:http/http.dart' as http;

import '../splash/LottieSplashScreen.dart';
import 'MapScreenParcel.dart';

class DestinationPickerPage extends StatefulWidget {
  final LatLng pickupLocation;
  final int page;

  const DestinationPickerPage({Key? key, required this.pickupLocation, required this.page}) : super(key: key);

  @override
  _DestinationPickerPageState createState() => _DestinationPickerPageState();
}

class _DestinationPickerPageState extends State<DestinationPickerPage> {
  GoogleMapController? _controller;
  LatLng _pickedLocation = LatLng(28.6139, 77.2090); // Default: Delhi
  TextEditingController _addressController = TextEditingController();
  TextEditingController _addressController1 = TextEditingController();
  bool _isLoading = false;

  List<dynamic> _suggestions = [];
  Timer? _debounce;
  final String _googleApiKey = 'AIzaSyB-HKYA7Ps8XvDkW4FBY6DR25Yk9yOnteQ'; // Replace with your actual key

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      SystemChrome.setSystemUIOverlayStyle(
        const SystemUiOverlayStyle(
          statusBarColor: Colors.blue, // or any color you want
          statusBarIconBrightness: Brightness.light, // use Brightness.light for white icons
        ),
      );
    });
    _getAddressFromLatLng(_pickedLocation);
    _getAddressFromLatLngPickUP(widget.pickupLocation);
  }

  void _updatePickedLocation(LatLng latLng) {
    setState(() {
      _pickedLocation = latLng;
    });
    _updateMapLocation(latLng);
    _getAddressFromLatLng(latLng);
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

  Future<void> _getAddressFromLatLngPickUP(LatLng position) async {
    setState(() => _isLoading = true);
    try {
      List<Placemark> placemarks = await placemarkFromCoordinates(position.latitude, position.longitude);
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

        setState(() {
          _addressController1.text = detailedAddress;
        });
      }
    } catch (e) {
      setState(() {
        _addressController1.text = "Unable to get address";
      });
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _getAddressFromLatLng(LatLng position) async {
    setState(() => _isLoading = true);
    try {
      List<Placemark> placemarks = await placemarkFromCoordinates(position.latitude, position.longitude);
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

        setState(() {
          _addressController.text = detailedAddress;
        });
      }
    } catch (e) {
      setState(() {
        _addressController.text = "Unable to get address";
      });
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
    _debounce?.cancel(); // Add this
    _addressController.dispose();
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
    // SystemChrome.setSystemUIOverlayStyle(
    //   const SystemUiOverlayStyle(
    //     statusBarColor: Colors.blue, // or any color you want
    //     statusBarIconBrightness: Brightness.light, // use Brightness.light for white icons
    //   ),
    // );
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle(
        statusBarColor: Colors.blue, // or any background
        statusBarIconBrightness: Brightness.light,
      ),
      child: Scaffold(
        resizeToAvoidBottomInset: true,
        body: SafeArea(
          child: Stack(
            children: [
              GoogleMap(
                initialCameraPosition: CameraPosition(target: _pickedLocation, zoom: 14),
                myLocationEnabled: true,
                onMapCreated: (controller) => _controller = controller,
                onTap: (LatLng location) => _updatePickedLocation(location),
                markers: {
                  Marker(
                    markerId: MarkerId('picked'),
                    position: _pickedLocation,
                    icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueRed),
                    infoWindow: InfoWindow(title: 'Selected Destination'),
                  ),
                  Marker(
                    markerId: MarkerId('pickup'),
                    position: widget.pickupLocation,
                    icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueBlue),
                    infoWindow: InfoWindow(title: 'Pickup Location'),
                  ),
                },
              ),

              if (_isLoading) Center(child: CircularProgressIndicator()),

              // Top AppBar
              Positioned(
                top: 0,
                left: 0,
                right: 0,
                child: Container(
                  height: 50,
                  alignment: Alignment.bottomCenter,
                  padding: EdgeInsets.only(bottom: 16, top: 16, left: 16, right: 16),
                  color: Colors.blue,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      GestureDetector(
                        onTap: () => Navigator.pop(context),
                        child: Icon(Icons.arrow_back, color: Colors.white),
                      ),
                      Text(
                        "Set Destination",
                        style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
                      ),
                      Opacity(opacity: 0.0, child: Icon(Icons.location_on, color: Colors.white)),
                    ],
                  ),
                ),
              ),

              // Pickup Address Panel
              Positioned(
                top: 50,
                left: 0,
                right: 0,
                child: Container(
                  padding: EdgeInsets.all(16),
                  color: Colors.white,
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        padding: EdgeInsets.all(8),
                        decoration: BoxDecoration(color: Color(0xFFE5E9FF), shape: BoxShape.circle),
                        child: Icon(Icons.location_on, color: Color(0xFF4B55E1), size: 20),
                      ),
                      SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('PICKUP', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500)),
                            SizedBox(height: 2),
                            Text(_addressController1.text, overflow: TextOverflow.ellipsis, maxLines: 1),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              // Bottom Panel
              Align(
                alignment: Alignment.bottomCenter,
                child: Container(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
                    boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 10)],
                  ),
                  padding: EdgeInsets.all(16),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        height: 4,
                        width: 40,
                        margin: EdgeInsets.only(bottom: 10),
                        decoration: BoxDecoration(
                          color: Colors.grey[300],
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                      if (_suggestions.isNotEmpty)
                        Container(
                          height: MediaQuery.of(context).size.height * 0.15,
                          child: Scrollbar(
                            thumbVisibility: true,
                            child: ListView.builder(
                              shrinkWrap: true,
                              itemCount: _suggestions.length,
                              itemBuilder: (context, index) {
                                final s = _suggestions[index];
                                return ListTile(
                                  dense: true,
                                  title: Text(s['description'], style: TextStyle(fontSize: 14, ),),
                                  onTap: () async {
                                    _addressController.text = s['description'];
                                    FocusScope.of(context).unfocus();
                                    await _getLatLngFromAddress(s['description']);
                                    setState(() => _suggestions.clear());
                                  },
                                );
                              },
                            ),
                          ),
                        ),

                      SizedBox(height: 8),
                      Align(
                        alignment: Alignment.centerLeft,
                        child: Text("Enter destination address", style: TextStyle(fontWeight: FontWeight.bold)),
                      ),
                      SizedBox(height: 8),
                      Row(
                        children: [
                          Expanded(
                            child: TextField(
                              controller: _addressController,
                              onSubmitted: _getLatLngFromAddress,
                              onChanged: (value) {
                                if (_debounce?.isActive ?? false) _debounce?.cancel();
                                _debounce = Timer(const Duration(milliseconds: 500), () {
                                  if (value.isNotEmpty) {
                                    _fetchSuggestions(value);
                                  } else {
                                    setState(() {
                                      _suggestions.clear();
                                    });
                                  }
                                });
                              },
                              decoration: InputDecoration(
                                hintText: "Type to search",
                                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                                filled: true,
                                fillColor: Colors.grey[100],
                                suffixIcon: _addressController.text.isNotEmpty
                                    ? IconButton(
                                  icon: Icon(Icons.clear),
                                  onPressed: () {
                                    _addressController.clear();
                                    setState(() {});
                                  },
                                )
                                    : null,
                              ),
                            ),
                          ),
                          IconButton(
                            icon: Icon(Icons.search),
                            onPressed: () => _getLatLngFromAddress(_addressController.text),
                          ),
                        ],
                      ),
                      SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton.icon(
                              onPressed: _goToCurrentLocation,
                              icon: Icon(Icons.my_location),
                              label: Text("Current Location", softWrap: true, overflow: TextOverflow.ellipsis,),
                            ),
                          ),
                          SizedBox(width: 12),
                          Expanded(
                            child: ElevatedButton(
                              onPressed: () {
                                if (widget.page == 1) {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (context) => LottieSplashScreen(
                                        nextPage: MapScreen(
                                          pickup: widget.pickupLocation,
                                          destination: _pickedLocation,
                                          pick: _addressController1.text,
                                          dest: _addressController.text,
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
                                        pickup: widget.pickupLocation,
                                        destination: _pickedLocation,
                                        pick: _addressController1.text,
                                        dest: _addressController.text,
                                      ),
                                    ),
                                  );
                                }
                              },
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.blue,
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                              ),
                              child: Text("Confirm Destination", style: TextStyle(color: Colors.white), softWrap: true, overflow: TextOverflow.ellipsis,),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
