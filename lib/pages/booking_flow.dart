import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:provider/provider.dart';

import '../model/booking.dart';
import '../providers/UserProvider.dart';
import '../services/api.dart';
import '../services/session.dart';
import '../widgets/ui.dart';
import 'BookingTrackingScreen.dart';
import 'LocationPickerPage.dart';
import 'PhoneInputPage.dart';

/// Entry point for "Book a Rider" / "Deliver a Parcel".
Future<void> startBooking(BuildContext context, BookingKind kind) async {
  final user = context.read<UserProvider>();
  if (!user.isLoggedIn) {
    showAppSnack(context, 'Please log in to book');
    await Navigator.push(context, MaterialPageRoute(builder: (_) => const PhoneInputPage()));
    return;
  }

  // One live booking of each kind at a time; reopen it instead.
  final activeId = await Session.activeOrderId(ride: kind == BookingKind.ride);
  if (activeId != null) {
    try {
      final booking = await Api.getBooking(kind, user.phone, activeId);
      if (booking != null && booking.isActive) {
        if (!context.mounted) return;
        await Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => BookingTrackingScreen(kind: kind, orderId: activeId)),
        );
        return;
      }
      await Session.clearActiveOrderId(ride: kind == BookingKind.ride);
    } catch (_) {
      // If the status check fails, let the user book anyway.
    }
  }

  if (!context.mounted) return;
  if (!await ensureLocationPermission(context)) return;
  if (!context.mounted) return;
  await Navigator.push(context, MaterialPageRoute(builder: (_) => LocationPickerPage(kind: kind)));
}

/// Asks for location permission and services, explaining what to do when the
/// user has blocked them. Returns true when the location can be read.
Future<bool> ensureLocationPermission(BuildContext context) async {
  var permission = await Geolocator.checkPermission();
  if (permission == LocationPermission.denied) {
    permission = await Geolocator.requestPermission();
  }
  if (!context.mounted) return false;

  if (permission == LocationPermission.deniedForever) {
    final open = await confirmDialog(
      context,
      title: 'Location permission needed',
      message: 'Location is blocked for Gotan. Open settings and allow location to set your pickup point.',
      confirmLabel: 'Open settings',
    );
    if (open) await Geolocator.openAppSettings();
    return false;
  }
  if (permission == LocationPermission.denied) {
    showAppSnack(context, 'Location permission is needed to set your pickup point', error: true);
    return false;
  }

  if (!await Geolocator.isLocationServiceEnabled()) {
    if (!context.mounted) return false;
    final open = await confirmDialog(
      context,
      title: 'Turn on location',
      message: 'Your phone\'s location (GPS) is off. Turn it on so we can find your pickup point.',
      confirmLabel: 'Turn on',
    );
    if (open) await Geolocator.openLocationSettings();
    // The user can still search addresses manually.
  }
  return true;
}
