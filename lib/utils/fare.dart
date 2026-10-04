/// Fare rules shared with the gotan.in website (service/bookRider/waiting.jsx
/// and service/bookParcel/waiting.jsx).
class Fare {
  static const Map<String, int> ratePerKm = {'Bike': 10, 'Auto': 20, 'Car': 30};
  static const Map<String, int> maxPassengers = {'Bike': 1, 'Auto': 3, 'Car': 4};
  static const int parcelRatePerKm = 10;

  /// Trips shorter than this are almost certainly a mis-tap on the map.
  static const int minDistanceMeters = 200;

  static int ride(String vehicle, int meters) => (meters / 1000 * (ratePerKm[vehicle] ?? 10)).round();

  static int parcel(int meters) => (meters / 1000 * parcelRatePerKm).ceil();
}
