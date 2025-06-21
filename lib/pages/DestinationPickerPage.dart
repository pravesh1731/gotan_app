import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';
import 'package:gotan/MapScreen.dart';

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

  @override
  void initState() {
    super.initState();
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
        ]
            .where((part) => part != null && part!.isNotEmpty)
            .toSet()
            .join(', ');

        setState(() {
          _addressController1.text = detailedAddress;
        });
      }
    } catch (e) {
      //back print("Error getting address: $e");
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
        ]
            .where((part) => part != null && part!.isNotEmpty)
            .toSet()
            .join(', ');

        setState(() {
          _addressController.text = detailedAddress;
        });
      }
    } catch (e) {
      //back print("Error getting address: $e");
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
      //back print("Error finding location: $e");
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
    return Scaffold(
      body: Container(
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

            if (_isLoading)
              Center(child: CircularProgressIndicator()),

            Positioned(
              top: 0,
              left: 0,
              right: 0,
              child: Container(
                alignment: Alignment.bottomCenter,
                height: 80,
                padding: EdgeInsets.only(bottom: 16, right: 16, left: 16),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Colors.deepPurpleAccent, Colors.blue],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    GestureDetector(
                      onTap: () {
                        Navigator.pop(context);
                      },
                      child: Icon(Icons.arrow_back, color: Colors.white),
                    ),
                    Text(
                      "Set Destination",
                      style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
                    ),
                    Opacity(
                      opacity: 0.0,
                      child: Icon(
                        Icons.location_on,
                        color: Colors.white,
                        size: 20,
                      ),
                    ),
                  ],
                ),
              ),
            ),

            Positioned(
              top: 80,
              left: 0,
              right: 0,
              child: Container(
                // height: 60,
                padding: EdgeInsets.only(top: 16, left: 16, right: 16, bottom: 16),
                decoration: BoxDecoration(
                  color: Colors.white
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Circular background icon
                    Container(
                      padding: EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Color(0xFFE5E9FF), // light purple background
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        Icons.location_on,
                        color: Color(0xFF4B55E1), // marker color
                        size: 20,
                      ),
                    ),
                    SizedBox(width: 10),

                    // Text Column
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'PICKUP',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                              color: Colors.black,
                              letterSpacing: 0.5,
                            ),
                          ),
                          SizedBox(height: 2),
                          Text(
                            _addressController1.text,
                            overflow: TextOverflow.ellipsis,
                            maxLines: 1,
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w500,
                              color: Colors.black,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),

            Positioned(
              bottom: 0,
              left: 0,
              right: 0,
              child: Padding(
                padding: EdgeInsets.only(
                  bottom: MediaQuery.of(context).viewPadding.bottom + MediaQuery.of(context).viewInsets.bottom,
                ),
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
                              onSubmitted: (value) {
                                _getLatLngFromAddress(value);
                              },
                              decoration: InputDecoration(
                                prefixIcon: Icon(Icons.search),
                                hintText: "Type to search",
                                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                                filled: true,
                                fillColor: Colors.grey[100],
                              ),
                            ),
                          ),
                          IconButton(
                            icon: Icon(Icons.search),
                            onPressed: () {
                              _getLatLngFromAddress(_addressController.text);
                            },
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
                              label: Text("Current Location"),
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
                              child: Text("Confirm Destination", style: TextStyle(color: Colors.white)),
                            ),
                          ),
                        ],
                      )
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}