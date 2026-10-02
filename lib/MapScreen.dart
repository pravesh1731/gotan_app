import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:gotan/global/common.dart';
import 'package:gotan/pages/BookingSummaryScreen.dart';
import 'splash/LottieSplashScreenToHome.dart';
import 'package:gotan/repo/directions_repository.dart';
import 'model/directions.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:lottie/lottie.dart' as lottie;
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
  bool _isConfirming = false;

  Future<void> _confirmBooking(BuildContext context, String orderId) async {
    setState(() {
      _isConfirming = true;
    });
    try {
      final prefs = await SharedPreferences.getInstance();
      final phoneNumber = prefs.getString('gotan_phone_number') ?? '1234567890';
      final distanceValue = double.parse(_info!.totalDistance.replaceAll(RegExp(r'[^0-9.]'), ''));
      final priceMultiplier = selectedRide == "Bike" ? 1 : selectedRide == "Auto" ? 2 : 3;
      final expectedPrice = (distanceValue * 10 * priceMultiplier).toStringAsFixed(2);
      final payload = {
        "phoneNumber": phoneNumber,
        "orderId": orderId,
        "expectedPrice": (double.parse(expectedPrice)).round(),
        "distance": _info!.totalDistance,
      };
      final uri = Uri.parse(Common.baseUrl + 'api/user/acceptBookRiderOrder')
          .replace(queryParameters: {'cityName': 'Gotan'});
      final response = await http.post(
        uri,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(payload),
      );
      setState(() {
        _isConfirming = false;
      });
      if (response.statusCode == 200) {
        final jsonData = jsonDecode(response.body);
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => LottieSplashScreenToHome(orderId: orderId, phoneNumber: phoneNumber, isRide: true),
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Booking confirmation failed: \\${response.body}')),
        );
      }
    } catch (e) {
      setState(() {
        _isConfirming = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: \\${e}')),
      );
    }
  }
  double _calculateFare(String rideType) {
    if (_info == null) return 0.0;
    final distanceValue = double.tryParse(_info!.totalDistance.replaceAll(RegExp(r'[^0-9.]'), '')) ?? 0.0;
    final priceMultiplier = rideType == "Bike" ? 1 : rideType == "Auto" ? 2 : 3;
    return distanceValue * 10 * priceMultiplier;
  }
  static const _initialCameraPosition = CameraPosition(
    target: LatLng(28.6139, 77.2090),
    zoom: 11.5,
  );

  GoogleMapController? _googleMapController;
  Marker? _origin;
  Marker? _destination;
  Directions? _info;

  DateTime get selectedDateTime => DateTime.now();
  String selectedRide = 'Bike';
  int passengerCount = 1;
  bool isLoading = false;

  final Map<String, int> rideLimits = {
    'Bike': 1,
    'Auto': 3,
    'Car': 4,
  };

  // _pickDateTime removed: booking always uses current date/time

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
        // Directly confirm booking after booking is successful
        await _confirmBooking(context, orderId);
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
    return Scaffold(
      backgroundColor: Colors.white,
      resizeToAvoidBottomInset: true,
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(47),
        child: Container(
          alignment: Alignment.bottomCenter,
          padding: const EdgeInsets.only(bottom: 16, right: 16, left: 16),
          decoration: const BoxDecoration(
            color: Colors.white
          ),
          child: SafeArea(
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                GestureDetector(
                  onTap: () => Navigator.pop(context),
                  child: const Icon(Icons.arrow_back, color: Colors.black),
                ),
                const Text(
                  "Book a Rider",
                  style: TextStyle(
                    color: Colors.black,
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
            // Show pickup and drop location card at the top
            Container(
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
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Pickup & Drop Card
                      Card(
                        elevation: 4,
                        color: Colors.white,
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12)),
                        child: Padding(
                          padding: const EdgeInsets.all(8.0),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  const Icon(Icons.location_on, color: Colors.green),
                                  const SizedBox(width: 8),
                                  const Text("Pickup",
                                      style: TextStyle(
                                          fontWeight: FontWeight.bold, fontSize: 16)),
                                ],
                              ),
                              const SizedBox(height: 4),
                              Text(
                                widget.pick,
                                style: const TextStyle(fontSize: 14),
                              ),
                              const SizedBox(height: 16),
                              Row(
                                children: [
                                  const Icon(Icons.location_on, color: Colors.orange),
                                  const SizedBox(width: 8),
                                  const Text("Drop",
                                      style: TextStyle(
                                          fontWeight: FontWeight.bold, fontSize: 16)),
                                ],
                              ),
                              const SizedBox(height: 4),
                              Text(
                                widget.dest,
                                style: const TextStyle(fontSize: 14),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),
                      // Distance, City, and Booking Summary Image Card
                      Card(
                        elevation: 4,
                        color: Colors.white,
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12)),
                        child: Padding(
                          padding: const EdgeInsets.all(16.0),
                          child: Column(
                            children: [
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Row(
                                    children: [
                                      const Icon(Icons.route, color: Colors.blue),
                                      const SizedBox(width: 4),
                                      Text('Distance: ${_info?.totalDistance ?? '--'}', style: const TextStyle(fontSize: 14)),
                                    ],
                                  ),
                                  Row(
                                    children: [
                                      const Icon(Icons.location_city, color: Colors.deepPurple),
                                      const SizedBox(width: 4),
                                      const Text('City: Gotan', style: TextStyle(fontSize: 14)),
                                    ],
                                  ),
                                ],
                              ),
                              const SizedBox(height: 16),
                              Center(
                                child: SizedBox(
                                  height: 100,
                                  child: Builder(
                                    builder: (context) {
                                      try {
                                        // Try to use Lottie if available
                                        return (Theme.of(context).platform == TargetPlatform.android || Theme.of(context).platform == TargetPlatform.iOS)
                                            ? (lottie.Lottie.asset(
                                                "assets/animations/booking.json",
                                                fit: BoxFit.contain,
                                              ))
                                            : Icon(Icons.image, size: 60, color: Colors.blueGrey);
                                      } catch (_) {
                                        return Icon(Icons.image, size: 60, color: Colors.blueGrey);
                                      }
                                    },
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),
                      // Ride Options, Passenger Count, and Max Passengers in one rounded Card
                      Card(
                        elevation: 4,
                        color: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.all(16.0),
                          child: Column(
                            children: [
                              Row(
                                children: [
                                  _rideOption(
                                    icon: Icons.motorcycle,
                                    label: 'Bike',
                                    subtitle: 'Up to 1 passenger',
                                    selected: selectedRide == 'Bike',
                                    fare: _calculateFare('Bike'),
                                  ),
                                  _rideOption(
                                    icon: Icons.electric_rickshaw,
                                    label: 'Auto',
                                    subtitle: 'Up to 3 passengers',
                                    selected: selectedRide == 'Auto',
                                    fare: _calculateFare('Auto'),
                                  ),
                                  _rideOption(
                                    icon: Icons.directions_car,
                                    label: 'Car',
                                    subtitle: 'Up to 4 passengers',
                                    selected: selectedRide == 'Car',
                                    fare: _calculateFare('Car'),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 10),
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
                            ],
                          ),
                        ),
                      ),

                      const SizedBox(height: 8),
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
                                  : const Text("Confirm Booking",
                                  style: TextStyle(color: Colors.white)),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                    ],
                  ),
                ),
              ),
            ),
            // Loader in the center removed; only show loader in Book Now button
          ],
        ),
      ),
      bottomNavigationBar: Container(
        color: Colors.white,
        height: 0,
        child: const SizedBox(),
      ),
    );
  }

  Widget _rideOption({
    required IconData icon,
    required String label,
    required String subtitle,
    required bool selected,
    required double fare,
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
              const SizedBox(height: 4),
              Text(
                fare > 0 ? '₹${fare.toStringAsFixed(2)}' : '--',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: Colors.green[700],
                  fontSize: 14,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}