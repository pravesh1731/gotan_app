import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geolocator/geolocator.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:geocoding/geocoding.dart';

import '../splash/LottieSplashScreen.dart';
import 'DestinationPickerPage.dart';

class LocationPickerPage extends StatefulWidget {
  final int page;
  const LocationPickerPage({Key? key, required this.page}) : super(key: key);

  @override
  _LocationPickerPageState createState() => _LocationPickerPageState();
}

class _LocationPickerPageState extends State<LocationPickerPage> {
  GoogleMapController? _controller;
  LatLng _pickedLocation = LatLng(28.6139, 77.2090); // Default: Delhi
  TextEditingController _addressController = TextEditingController();
  bool _isLoading = false;
  bool _isFirstTapOnAddress = true;


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
    _checkPermissions();
    _getAddressFromLatLng(_pickedLocation);
  }

  Future<void> _checkPermissions() async {
    await Permission.location.request();
    await Geolocator.requestPermission();
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

  Future<void> _getAddressFromLatLng(LatLng position) async {
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
    _addressController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    SystemChrome.setSystemUIOverlayStyle(SystemUiOverlayStyle(
      statusBarColor: Colors.blue, // Match gradient start
      statusBarIconBrightness: Brightness.light,
    ));

    return Scaffold(
      resizeToAvoidBottomInset: true,
      body: SafeArea(
        child: Column(
          children: [
            // Google Map - fills available space
            Expanded(
              child: Stack(
                children: [
                  GoogleMap(
                    initialCameraPosition: CameraPosition(
                      target: _pickedLocation,
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
                      Marker(
                        markerId: MarkerId('picked'),
                        position: _pickedLocation,
                        icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueBlue),
                        infoWindow: InfoWindow(title: 'Selected Location'),
                      ),
                    },
                  ),

                  // Loading spinner
                  if (_isLoading)
                    Center(child: CircularProgressIndicator()),

                  // Gradient AppBar
                  Positioned(
                    top: 0,
                    left: 0,
                    right: 0,
                    child: Container(
                      alignment: Alignment.bottomCenter,
                      // height: 80,
                      padding: EdgeInsets.only(bottom: 16, right: 16, left: 16, top: 16),
                      decoration: BoxDecoration(
                        color: Colors.blue
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          GestureDetector(
                            onTap: () => Navigator.pop(context),
                            child: Icon(Icons.arrow_back, color: Colors.white),
                          ),
                          Text(
                            "Set Pickup Location",
                            style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
                          ),
                          Opacity(
                            opacity: 0.0,
                            child: Icon(Icons.location_on, color: Colors.white),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // Bottom panel — naturally sits above keyboard
            Container(
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
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Text("Enter pickup address", style: TextStyle(fontWeight: FontWeight.bold)),
                  ),
                  SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _addressController,
                          onSubmitted: (value) {
                            _getLatLngFromAddress(value);
                          },
                          onChanged: (value) {
                            setState(() {}); // Show/hide clear button dynamically
                          },
                          decoration: InputDecoration(
                            hintText: "Type to search",
                            filled: true,
                            fillColor: Colors.grey[100],
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            suffixIcon: _addressController.text.isNotEmpty
                                ? IconButton(
                              icon: Icon(Icons.clear, size: 18,),
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
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => LottieSplashScreen(
                                  nextPage: DestinationPickerPage(
                                    pickupLocation: _pickedLocation,
                                    page: widget.page,
                                  ),
                                  assetPath: 'assets/animations/travel.json',
                                ),
                              ),
                            );
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.blue,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                          child: Text("Confirm Location", style: TextStyle(color: Colors.white), softWrap: true, overflow: TextOverflow.ellipsis,),
                        ),
                      ),
                    ],
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
