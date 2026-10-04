import 'package:flutter_polyline_points/flutter_polyline_points.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

class Directions {
  final LatLngBounds bounds;
  final List<PointLatLng> polylinePoints;
  final String totalDistance;
  final String totalDuration;

  /// Raw leg values from the Directions API. Fares must use these, not the
  /// display text: "850 m" parsed as a number would be priced as 850 km.
  final int distanceMeters;
  final int durationSeconds;

  const Directions({
    required this.bounds,
    required this.polylinePoints,
    required this.totalDistance,
    required this.totalDuration,
    required this.distanceMeters,
    required this.durationSeconds,
  });

  double get distanceKm => distanceMeters / 1000;

  factory Directions.fromMap(Map<String, dynamic> map) {
    final routes = map['routes'] as List? ?? const [];
    if (routes.isEmpty) {
      throw Exception('No route found between these places');
    }

    final data = Map<String, dynamic>.from(routes[0]);

    final northeast = data['bounds']['northeast'];
    final southwest = data['bounds']['southwest'];
    final bounds = LatLngBounds(
      northeast: LatLng((northeast['lat'] as num).toDouble(), (northeast['lng'] as num).toDouble()),
      southwest: LatLng((southwest['lat'] as num).toDouble(), (southwest['lng'] as num).toDouble()),
    );

    String distance = '';
    String duration = '';
    int meters = 0;
    int seconds = 0;
    if ((data['legs'] as List).isNotEmpty) {
      final leg = data['legs'][0];
      distance = leg['distance']['text'];
      duration = leg['duration']['text'];
      meters = (leg['distance']['value'] as num).toInt();
      seconds = (leg['duration']['value'] as num).toInt();
    }

    return Directions(
      bounds: bounds,
      polylinePoints: PolylinePoints().decodePolyline(data['overview_polyline']['points']),
      totalDistance: distance,
      totalDuration: duration,
      distanceMeters: meters,
      durationSeconds: seconds,
    );
  }
}
