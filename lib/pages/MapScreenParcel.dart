import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:gotan/pages/ParcelSummaryScreen.dart';
import 'package:gotan/repo/directions_repository.dart';
import '../model/directions.dart';
import 'package:http/http.dart' as http;
import 'package:gotan/global/common.dart';
import 'package:shared_preferences/shared_preferences.dart';

class MapScreenParcel extends StatefulWidget {
  final LatLng pickup;
  final LatLng destination;
  final String pick;
  final String dest;

  const MapScreenParcel({
    Key? key,
    required this.pickup,
    required this.destination,
    required this.pick,
    required this.dest,
  }) : super(key: key);

  @override
  _MapScreenParcelState createState() => _MapScreenParcelState();
}

class _MapScreenParcelState extends State<MapScreenParcel> {
  static const _initialCameraPosition = CameraPosition(
    target: LatLng(28.6139, 77.2090),
    zoom: 11.5,
  );

  GoogleMapController? _googleMapController;
  Marker? _origin;
  Marker? _destination;
  Directions? _info;

  DateTime? selectedDateTime;
  String selectedRide = 'Bike';
  int passengerCount = 1;
  final TextEditingController weightController = TextEditingController();
  final TextEditingController instructionsController = TextEditingController();

  bool isLoading = false;

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
    _loadDirections();
  }

  @override
  void dispose() {
    _googleMapController?.dispose();
    weightController.dispose();
    instructionsController.dispose();
    super.dispose();
  }

  Future<void> _pickDateTime() async {
    final date = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime.now(),
      lastDate: DateTime(2100),
    );

    if (date == null) return;

    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.now(),
    );

    if (time == null) return;

    setState(() {
      selectedDateTime = DateTime(
        date.year,
        date.month,
        date.day,
        time.hour,
        time.minute,
      );
    });
  }

  Future<void> _bookRide() async {
    if (selectedDateTime == null) {
      _showSnackBar('Please select a date and time');
      return;
    }

    if (weightController.text.trim().isEmpty) {
      _showSnackBar('Please enter the weight');
      return;
    }

    if (instructionsController.text.trim().isEmpty) {
      _showSnackBar('Please enter the Instructions');
      return;
    }

    setState(() => isLoading = true);

    try {
      final prefs = await SharedPreferences.getInstance();
      final phoneNumber = prefs.getString('gotan_phone_number') ?? '0000000000';
      final sellerName = prefs.getString('gotan_name') ?? 'Customer';

      final formattedDateTime =
          "${selectedDateTime!.year.toString().padLeft(4, '0')}-"
          "${selectedDateTime!.month.toString().padLeft(2, '0')}-"
          "${selectedDateTime!.day.toString().padLeft(2, '0')}T"
          "${selectedDateTime!.hour.toString().padLeft(2, '0')}:"
          "${selectedDateTime!.minute.toString().padLeft(2, '0')}";

      final payload = {
        "phoneNumber": phoneNumber,
        "orderDetails": {
          "sellerName": sellerName,
          "sellerPhone": phoneNumber,
          "cityName": "Gotan",
          "pickupAddress": widget.pick,
          "deliveryAddress": widget.dest,
          "pickupTime": formattedDateTime,
          "weight": weightController.text,
          "message": instructionsController.text,
        }
      };

      final response = await http.post(
        Uri.parse(Common.baseUrl + 'api/user/addParcelOrder'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(payload),
      );

      if (response.statusCode == 200) {
        final jsonData = jsonDecode(response.body);
        final String orderId = jsonData['orderId'];
        await prefs.setString('gotan_orderId', orderId);
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => ParcelSummaryScreen(
              pickup: widget.pick,
              destination: widget.dest,
              rideType: selectedRide,
              passengers: passengerCount,
              dateTime: selectedDateTime!,
              distance: _info!.totalDistance,
              weight: weightController.text.trim(),
              instructions: instructionsController.text.trim(),
            ),
          ),
        );
      } else {
        _showSnackBar('Booking failed: ${response.body}');
      }
    } catch (e) {
      _showSnackBar('Error: $e');
    } finally {
      setState(() => isLoading = false);
    }
  }

  void _showSnackBar(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  Future<void> _loadDirections() async {
    setState(() {
      _origin = Marker(
        markerId: const MarkerId('origin'),
        infoWindow: const InfoWindow(title: 'Origin'),
        icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueBlue),
        position: widget.pickup,
      );

      _destination = Marker(
        markerId: const MarkerId('destination'),
        infoWindow: const InfoWindow(title: 'Destination'),
        icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueRed),
        position: widget.destination,
      );
    });

    final directions = await DirectionsRepository().getDirections(
      origin: widget.pickup,
      destination: widget.destination,
    );

    setState(() => _info = directions);

    if (_googleMapController != null && _info != null) {
      _googleMapController!.animateCamera(
        CameraUpdate.newLatLngBounds(_info!.bounds, 100.0),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    // SystemChrome.setSystemUIOverlayStyle(SystemUiOverlayStyle(
    //   statusBarColor: Colors.blue, // Match gradient start
    //   statusBarIconBrightness: Brightness.light,
    // ));
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle(
        statusBarColor: Colors.blue, // or any background
        statusBarIconBrightness: Brightness.light,
      ),
      child: Scaffold(
        resizeToAvoidBottomInset: true,
        appBar: PreferredSize(
          preferredSize: const Size.fromHeight(47),
          child: Container(
            alignment: Alignment.bottomCenter,
            padding: const EdgeInsets.only(bottom: 16, right: 16, left: 16),
            decoration: const BoxDecoration(
              color: Colors.blue
            ),
            child: SafeArea(
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  GestureDetector(
                    onTap: () => Navigator.pop(context),
                    child: const Icon(Icons.arrow_back, color: Colors.white),
                  ),
                  const Text(
                    "Parcel Delivery",
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const Opacity(
                    opacity: 0.0,
                    child: Icon(Icons.location_on, color: Colors.white, size: 20),
                  ),
                ],
              ),
            ),
          ),
        ),
        body: SafeArea(
          child: Column(
            children: [
              // MAP SECTION - fills remaining space
              Expanded(
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    GoogleMap(
                      myLocationButtonEnabled: false,
                      zoomControlsEnabled: false,
                      initialCameraPosition: _initialCameraPosition,
                      onMapCreated: (controller) => _googleMapController = controller,
                      markers: {
                        if (_origin != null) _origin!,
                        if (_destination != null) _destination!,
                      },
                      polylines: {
                        if (_info != null)
                          Polyline(
                            polylineId: const PolylineId('overview_polyline'),
                            color: Colors.red,
                            width: 5,
                            points: _info!.polylinePoints
                                .map((e) => LatLng(e.latitude, e.longitude))
                                .toList(),
                          ),
                      },
                      gestureRecognizers: <Factory<OneSequenceGestureRecognizer>>{
                        Factory<OneSequenceGestureRecognizer>(
                              () => EagerGestureRecognizer(),
                        ),
                      },
                    ),
                    Positioned(
                      bottom: 16,
                      right: 16,
                      child: FloatingActionButton(
                        backgroundColor: Colors.white,
                        foregroundColor: Colors.black,
                        onPressed: () => _googleMapController?.animateCamera(
                          _info != null
                              ? CameraUpdate.newLatLngBounds(_info!.bounds, 100.0)
                              : CameraUpdate.newCameraPosition(_initialCameraPosition),
                        ),
                        child: const Icon(Icons.center_focus_strong),
                      ),
                    ),
                    if (_info != null)
                      Positioned(
                        top: 20.0,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            vertical: 6.0,
                            horizontal: 12.0,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.yellowAccent,
                            borderRadius: BorderRadius.circular(20.0),
                            boxShadow: const [
                              BoxShadow(
                                color: Colors.black26,
                                offset: Offset(0, 2),
                                blurRadius: 6.0,
                              )
                            ],
                          ),
                          child: Text(
                            '${_info!.totalDistance}, ${_info!.totalDuration}',
                            style: const TextStyle(
                              fontSize: 18.0,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),

              // FORM SECTION - fixed size, scrolls if keyboard appears
              Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
                  boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 10)],
                ),
                child: Padding(
                  padding: EdgeInsets.only(
                    left: 16,
                    right: 16,
                    top: 16,
                    bottom: 16,
                  ),
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
                      GestureDetector(
                        onTap: _pickDateTime,
                        child: InputDecorator(
                          decoration: InputDecoration(
                            labelText: 'Pickup Date & Time',
                            suffixIcon: const Icon(Icons.calendar_today),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                          ),
                          child: Text(
                            selectedDateTime != null
                                ? '${selectedDateTime!.toLocal()}'.split('.')[0]
                                : 'Select Date & Time',
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: weightController,
                        keyboardType: TextInputType.number,
                        decoration: InputDecoration(
                          labelText: 'Parcel Weight (kg)',
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: instructionsController,
                        maxLines: 3,
                        decoration: InputDecoration(
                          labelText: 'Delivery Instructions',
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                      ),
                      const SizedBox(height: 20),
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton.icon(
                              onPressed: () => Navigator.pop(context),
                              icon: const Icon(Icons.arrow_back),
                              label: const Text("Go Back"),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: ElevatedButton(
                              onPressed: isLoading ? null : _bookRide,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.blue,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                              child: isLoading
                                  ? const SizedBox(
                                height: 20,
                                width: 20,
                                child: CircularProgressIndicator(
                                  color: Colors.white,
                                  strokeWidth: 2,
                                ),
                              )
                                  : const Text(
                                "Book Now",
                                style: TextStyle(color: Colors.white),
                              ),
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
