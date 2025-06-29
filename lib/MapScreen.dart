import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:gotan/global/common.dart';
import 'package:gotan/pages/BookingSummaryScreen.dart';
import 'package:gotan/repo/directions_repository.dart';
import 'model/directions.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';

class MapScreen extends StatefulWidget {
  final LatLng pickup;
  final LatLng destination;
  final String pick;
  final String dest;

  const MapScreen({
    Key? key,
    required this.pickup,
    required this.destination,
    required this.pick,
    required this.dest,
  }) : super(key: key);

  @override
  _MapScreenState createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen> {
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
  bool isLoading = false;

  final Map<String, int> rideLimits = {
    'Bike': 1,
    'Auto': 3,
    'Car': 4,
  };

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
          time.minute
      );
    });
  }

  void _selectRide(String ride) {
    setState(() {
      selectedRide = ride;
      if (passengerCount > rideLimits[ride]!) {
        passengerCount = rideLimits[ride]!;
      }
    });
  }

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
    _googleMapController?.animateCamera(
      _info != null
          ? CameraUpdate.newLatLngBounds(_info!.bounds, 100.0)
          : CameraUpdate.newCameraPosition(_initialCameraPosition),
    );
  }

  Future<void> _bookRide() async {
    if (selectedDateTime == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select a date and time')),
      );
      return;
    }

    setState(() => isLoading = true);

    try {
      final prefs = await SharedPreferences.getInstance();
      final phoneNumber = prefs.getString('gotan_phone_number') ?? '0000000000';
      final sellerName = prefs.getString('gotan_name') ?? 'Customer';

      // Format the datetime to 2025-06-05T00:00 format
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
          "vehicleType": selectedRide,
          "numOfPassengers": passengerCount,
        }
      };

      final response = await http.post(
        Uri.parse(Common.baseUrl+'api/user/addriderorder'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(payload),
      );

      if (response.statusCode == 200) {
        final jsonData = jsonDecode(response.body);
        final String orderId = jsonData['orderId'];
        SharedPreferences prefs = await SharedPreferences.getInstance();
        await prefs.setString('gotan_orderId', orderId);
        //back print('===');
        //back print(orderId);
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => BookingSummaryScreen(
              pickup: widget.pick,
              destination: widget.dest,
              rideType: selectedRide,
              passengers: passengerCount,
              dateTime: selectedDateTime!,
              distance: _info!.totalDistance,
            ),
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Booking failed: ${response.body}')),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e')),
      );
    } finally {
      setState(() => isLoading = false);
    }
  }

  @override
  void dispose() {
    _googleMapController?.dispose();
    super.dispose();
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
                    "Book a Rider",
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
          child: Stack(
            children: [
              Column(
                children: [
                  Container(
                    height: MediaQuery.of(context).size.height * 0.5,
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
                            if (_destination != null) _destination!
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

                  // Bottom Container
                  Expanded(
                    child: Container(
                      padding: const EdgeInsets.all(16),
                      decoration: const BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
                        boxShadow: [BoxShadow(color: Colors.black26, blurRadius: 10)],
                      ),
                      child: Scrollbar(
                        thumbVisibility: true,
                        thickness: 4,
                        radius: Radius.circular(10),
                        child: SingleChildScrollView(
                          child: Column(
                            children: [
                              const SizedBox(height: 10),
                              InkWell(
                                onTap: _pickDateTime,
                                child: InputDecorator(
                                  decoration: InputDecoration(
                                    labelText: 'When do you want to ride?',
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
                              const SizedBox(height: 10),

                              // Ride Options
                              Row(
                                children: [
                                  _rideOption(
                                      icon: Icons.motorcycle,
                                      label: 'Bike',
                                      subtitle: 'Up to 1 passenger',
                                      selected: selectedRide == 'Bike'),
                                  _rideOption(
                                      icon: Icons.electric_rickshaw,
                                      label: 'Auto',
                                      subtitle: 'Up to 3 passengers',
                                      selected: selectedRide == 'Auto'),
                                  _rideOption(
                                      icon: Icons.directions_car,
                                      label: 'Car',
                                      subtitle: 'Up to 4 passengers',
                                      selected: selectedRide == 'Car'),
                                ],
                              ),
                              const SizedBox(height: 10),

                              // Passenger Count
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  const Text('Passengers',
                                      style: TextStyle(fontWeight: FontWeight.bold)),
                                  Row(
                                    children: [
                                      IconButton(
                                        onPressed: passengerCount > 1
                                            ? () => setState(() => passengerCount--)
                                            : null,
                                        icon: const Icon(Icons.remove_circle_outline),
                                      ),
                                      Text(passengerCount.toString()),
                                      IconButton(
                                        onPressed: passengerCount < rideLimits[selectedRide]!
                                            ? () => setState(() => passengerCount++)
                                            : null,
                                        icon: const Icon(Icons.add_circle_outline),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                              Container(
                                alignment: AlignmentDirectional.centerStart,
                                child: Text('Maximum ${rideLimits[selectedRide]} passengers for $selectedRide'),
                              ),

                              const SizedBox(height: 12),
                              Row(
                                children: [
                                  Expanded(
                                    child: OutlinedButton(
                                      onPressed: () => Navigator.pop(context),
                                      child: const Text("Go Back"),
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: ElevatedButton(
                                      onPressed: isLoading ? null : _bookRide,
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: Colors.blue,
                                        shape: RoundedRectangleBorder(
                                            borderRadius: BorderRadius.circular(12)),
                                      ),
                                      child: isLoading
                                          ? SizedBox(
                                        width: 18,
                                        height: 18,
                                        child: const CircularProgressIndicator(color: Colors.white, ),
                                      )
                                          : const Text("Book Now",
                                          style: TextStyle(color: Colors.white)),
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
                ],
              ),
              if (isLoading)
                const Center(
                  child: CircularProgressIndicator(),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _rideOption({
    required IconData icon,
    required String label,
    required String subtitle,
    required bool selected,
  }) {
    return Expanded(
      child: InkWell(
        onTap: () => _selectRide(label),
        child: Container(
          padding: const EdgeInsets.all(8),
          margin: const EdgeInsets.symmetric(horizontal: 4),
          decoration: BoxDecoration(
            color: selected ? Colors.blue.shade50 : Colors.white,
            border: Border.all(
              color: selected ? Colors.blue : Colors.grey.shade300,
            ),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(
            children: [
              Icon(icon, size: 32),
              const SizedBox(height: 4),
              Text(label, style: const TextStyle(fontWeight: FontWeight.bold)),
              Text(subtitle, style: const TextStyle(fontSize: 10)),
            ],
          ),
        ),
      ),
    );
  }
}