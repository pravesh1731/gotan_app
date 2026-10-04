import '../widgets/ui.dart' show Tone;

enum BookingKind { ride, parcel }

/// Where a booking is in its lifecycle, derived from gotanbackend fields:
/// `user` (Pending | accepted | rejected), `riderAccepted`, `acceptedUserOtp`
/// and `riderStatus` (En Route → In Transit → … → Delivered).
enum BookingStage { draft, cancelled, searching, assigned, inTransit, delivered }

class RiderInfo {
  final String name;
  final String phone;
  final String domain;
  final String vehicleType;
  final String photo;

  RiderInfo({required this.name, required this.phone, required this.domain, required this.vehicleType, required this.photo});

  factory RiderInfo.fromJson(Map<String, dynamic> json) => RiderInfo(
        name: (json['name'] ?? '').toString(),
        phone: (json['phoneNumber'] ?? '').toString(),
        domain: (json['riderDomain'] ?? '').toString(),
        vehicleType: (json['vehicleType'] ?? '').toString(),
        photo: (json['profile'] ?? '').toString(),
      );
}

class Booking {
  final BookingKind kind;
  final Map<String, dynamic> raw;
  final String id;
  final String pickup;
  final String drop;
  final String pickupTime;
  final String vehicleType;
  final String passengers;
  final String weight;
  final String message;
  final String expectedPrice;
  final String distance;
  final String userState;
  final String riderStatus;
  final String riderLocation;
  final bool riderAccepted;
  final bool otpVerified;
  final RiderInfo? rider;

  Booking({
    required this.kind,
    required this.raw,
    required this.id,
    required this.pickup,
    required this.drop,
    required this.pickupTime,
    required this.vehicleType,
    required this.passengers,
    required this.weight,
    required this.message,
    required this.expectedPrice,
    required this.distance,
    required this.userState,
    required this.riderStatus,
    required this.riderLocation,
    required this.riderAccepted,
    required this.otpVerified,
    required this.rider,
  });

  factory Booking.fromJson(BookingKind kind, Map<String, dynamic> json) {
    String str(dynamic v) => v == null ? '' : v.toString();
    final details = json['riderDetails'];
    RiderInfo? rider;
    if (details is List && details.isNotEmpty && details.first is Map) {
      rider = RiderInfo.fromJson((details.first as Map).cast<String, dynamic>());
    }
    return Booking(
      kind: kind,
      raw: json,
      id: str(json['_id']),
      pickup: str(json['pickupAddress']),
      drop: str(json['deliveryAddress']),
      pickupTime: str(json['pickupTime']),
      vehicleType: str(json['vehicleType']),
      passengers: str(json['numOfPassengers']),
      weight: str(json['weight']),
      message: str(json['message']),
      expectedPrice: str(json['expectedPrice']),
      distance: str(json['distance']),
      userState: str(json['user']).isEmpty ? 'Pending' : str(json['user']),
      riderStatus: str(json['riderStatus']).isEmpty ? 'En Route' : str(json['riderStatus']),
      riderLocation: str(json['riderCurrentLocation']),
      riderAccepted: json['riderAccepted'] == true,
      otpVerified: json['acceptedUserOtp'] == true,
      rider: rider,
    );
  }

  BookingStage get stage {
    if (userState.toLowerCase() == 'rejected') return BookingStage.cancelled;
    if (riderStatus.toLowerCase() == 'delivered') return BookingStage.delivered;
    if (riderAccepted && (otpVerified || riderStatus.toLowerCase() != 'en route')) {
      return BookingStage.inTransit;
    }
    if (riderAccepted) return BookingStage.assigned;
    if (userState.toLowerCase() == 'accepted') return BookingStage.searching;
    return BookingStage.draft;
  }

  /// Still worth showing on the home screen as an ongoing booking.
  bool get isActive =>
      stage == BookingStage.searching || stage == BookingStage.assigned || stage == BookingStage.inTransit;

  /// Users may only cancel before a rider has accepted (the rider app has no
  /// cancellation path once it has the order).
  bool get canCancel => stage == BookingStage.searching || stage == BookingStage.draft;

  num? get price {
    final p = num.tryParse(expectedPrice);
    return p;
  }

  DateTime? get pickupDateTime => DateTime.tryParse(pickupTime);

  String get title => kind == BookingKind.ride ? '${vehicleType.isEmpty ? 'Ride' : vehicleType} ride' : 'Parcel delivery';

  String get stageLabel {
    final ride = kind == BookingKind.ride;
    return switch (stage) {
      BookingStage.draft => 'Not confirmed',
      BookingStage.cancelled => 'Cancelled',
      BookingStage.searching => 'Finding a rider',
      BookingStage.assigned => ride ? 'Rider on the way' : 'Rider coming for pickup',
      BookingStage.inTransit => ride
          ? 'Ride started'
          : (riderStatus.toLowerCase() == 'en route' ? 'Parcel picked up' : riderStatus),
      BookingStage.delivered => ride ? 'Completed' : 'Delivered',
    };
  }

  Tone get tone => switch (stage) {
        BookingStage.draft => Tone.neutral,
        BookingStage.cancelled => Tone.error,
        BookingStage.searching => Tone.warning,
        BookingStage.assigned => Tone.info,
        BookingStage.inTransit => Tone.info,
        BookingStage.delivered => Tone.success,
      };
}
