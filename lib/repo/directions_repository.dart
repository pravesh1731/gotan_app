import 'package:dio/dio.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

import '../global/common.dart';
import '../model/directions.dart';

class DirectionsRepository {
  static const String _baseUrl = 'https://maps.googleapis.com/maps/api/directions/json?';

  final Dio _dio;

  DirectionsRepository({Dio? dio})
      : _dio = dio ??
            Dio(BaseOptions(
              connectTimeout: const Duration(seconds: 15),
              receiveTimeout: const Duration(seconds: 15),
            ));

  /// Returns null when Google has no route; throws on network failure.
  Future<Directions?> getDirections({
    required LatLng origin,
    required LatLng destination,
  }) async {
    final response = await _dio.get(
      _baseUrl,
      queryParameters: {
        'origin': '${origin.latitude},${origin.longitude}',
        'destination': '${destination.latitude},${destination.longitude}',
        'key': Common.mapsApiKey,
      },
    );

    if (response.statusCode == 200 && response.data is Map) {
      final data = Map<String, dynamic>.from(response.data);
      if (data['status'] != 'OK') return null;
      return Directions.fromMap(data);
    }
    return null;
  }
}
