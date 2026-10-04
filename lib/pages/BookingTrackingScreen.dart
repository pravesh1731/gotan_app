import 'dart:async';

import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../model/booking.dart';
import '../providers/UserProvider.dart';
import '../services/api.dart';
import '../services/notification_service.dart';
import '../services/session.dart';
import '../theme/app_theme.dart';
import '../utils/invoice.dart';
import '../utils/launch.dart';
import '../widgets/ui.dart';

/// Live status of a ride or parcel (website: riderDetails.jsx). Polls
/// gotanbackend every 5 s and refreshes immediately on push notifications.
class BookingTrackingScreen extends StatefulWidget {
  final BookingKind kind;
  final String orderId;

  const BookingTrackingScreen({super.key, required this.kind, required this.orderId});

  @override
  State<BookingTrackingScreen> createState() => _BookingTrackingScreenState();
}

class _BookingTrackingScreenState extends State<BookingTrackingScreen> {
  Booking? _booking;
  bool _loading = true;
  bool _refreshFailed = false;
  bool _cancelling = false;
  Timer? _timer;
  StreamSubscription? _pushSub;

  bool get _isRide => widget.kind == BookingKind.ride;

  @override
  void initState() {
    super.initState();
    _fetch();
    _timer = Timer.periodic(const Duration(seconds: 5), (_) => _fetch());
    _pushSub = NotificationService().messages.listen((_) => _fetch());
    // Make sure the ride OTP shown below is the one the backend checks.
    final user = context.read<UserProvider>();
    if (user.otp.isEmpty) user.refresh().catchError((_) => null);
  }

  @override
  void dispose() {
    _timer?.cancel();
    _pushSub?.cancel();
    super.dispose();
  }

  Future<void> _fetch() async {
    final phone = context.read<UserProvider>().phone;
    try {
      final booking = await Api.getBooking(widget.kind, phone, widget.orderId);
      if (!mounted) return;
      setState(() {
        _booking = booking;
        _loading = false;
        _refreshFailed = false;
      });
      if (booking != null && !booking.isActive && booking.stage != BookingStage.draft) {
        // Finished or cancelled: stop polling and free the "active" slot.
        _timer?.cancel();
        Session.clearActiveOrderId(ride: _isRide);
      }
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _refreshFailed = true;
      });
    }
  }

  Future<void> _cancel() async {
    final ok = await confirmDialog(
      context,
      title: _isRide ? 'Cancel this ride?' : 'Cancel this parcel?',
      message: 'Riders will no longer be able to accept it.',
      confirmLabel: 'Yes, cancel',
      cancelLabel: 'Keep it',
      destructive: true,
    );
    if (!ok || !mounted) return;
    setState(() => _cancelling = true);
    try {
      await Api.cancelBooking(widget.kind, context.read<UserProvider>().phone, widget.orderId);
      await Session.clearActiveOrderId(ride: _isRide);
      await _fetch();
      if (mounted) showAppSnack(context, _isRide ? 'Ride cancelled' : 'Parcel cancelled');
    } catch (e) {
      if (mounted) showAppSnack(context, e.toString(), error: true);
    } finally {
      if (mounted) setState(() => _cancelling = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final booking = _booking;
    return Scaffold(
      appBar: AppBar(
        title: Text(_isRide ? 'Ride status' : 'Parcel status'),
        actions: [
          IconButton(tooltip: 'Refresh', onPressed: _fetch, icon: const Icon(Icons.refresh_rounded)),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : booking == null
              ? EmptyState(
                  icon: Icons.search_off_rounded,
                  title: 'Booking not found',
                  message: _refreshFailed ? 'Check your internet connection and try again.' : 'It may have been removed.',
                  actionLabel: 'Retry',
                  onAction: () {
                    setState(() => _loading = true);
                    _fetch();
                  },
                )
              : RefreshIndicator(
                  onRefresh: _fetch,
                  child: ListView(
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
                    children: [
                      if (_refreshFailed)
                        const Padding(
                          padding: EdgeInsets.only(bottom: 10),
                          child: StatusChip(label: 'Offline · retrying…', tone: Tone.warning),
                        ),
                      _StatusHeader(booking: booking),
                      if (booking.stage == BookingStage.searching || booking.stage == BookingStage.assigned) ...[
                        const SizedBox(height: 12),
                        _OtpCard(otp: context.watch<UserProvider>().otp, isRide: _isRide),
                      ],
                      if (booking.rider != null) ...[
                        const SizedBox(height: 12),
                        _RiderCard(booking: booking),
                      ],
                      const SizedBox(height: 12),
                      _TripCard(booking: booking),
                      const SizedBox(height: 20),
                      if (booking.canCancel)
                        AppButton(
                          label: _isRide ? 'Cancel ride' : 'Cancel parcel',
                          variant: ButtonVariant.secondary,
                          loading: _cancelling,
                          onPressed: _cancel,
                        ),
                      if (booking.stage == BookingStage.delivered) ...[
                        AppButton(
                          label: 'View invoice',
                          icon: Icons.receipt_long_outlined,
                          onPressed: () {
                            final user = context.read<UserProvider>();
                            showBookingInvoice(booking, customerName: user.name, customerPhone: user.phone).catchError(
                              (e) {
                                if (context.mounted) showAppSnack(context, 'Could not create invoice', error: true);
                              },
                            );
                          },
                        ),
                      ],
                      const SizedBox(height: 10),
                      AppButton(
                        label: booking.isActive ? 'Check later' : 'Back to home',
                        variant: ButtonVariant.ghost,
                        onPressed: () => Navigator.of(context).popUntil((r) => r.isFirst),
                      ),
                    ],
                  ),
                ),
    );
  }
}

class _StatusHeader extends StatelessWidget {
  final Booking booking;
  const _StatusHeader({required this.booking});

  @override
  Widget build(BuildContext context) {
    final ride = booking.kind == BookingKind.ride;
    final stage = booking.stage;
    final steps = [
      ('Booked', BookingStage.searching),
      ('Rider assigned', BookingStage.assigned),
      (ride ? 'Ride started' : 'Picked up', BookingStage.inTransit),
      (ride ? 'Completed' : 'Delivered', BookingStage.delivered),
    ];
    final order = [BookingStage.searching, BookingStage.assigned, BookingStage.inTransit, BookingStage.delivered];
    final current = order.indexOf(stage);

    final subtitle = switch (stage) {
      BookingStage.searching => 'We have notified riders in Gotan. This usually takes a few minutes.',
      BookingStage.assigned => ride
          ? 'Your rider is coming to the pickup point. Share your OTP to start the ride.'
          : 'Your rider is coming to collect the parcel. Share your OTP at pickup.',
      BookingStage.inTransit => ride ? 'Enjoy your ride!' : 'Your parcel is on its way.',
      BookingStage.delivered => ride ? 'You have reached your destination.' : 'Your parcel has been delivered.',
      BookingStage.cancelled => 'This booking was cancelled.',
      BookingStage.draft => 'This booking was not confirmed.',
    };

    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 46,
                height: 46,
                decoration: BoxDecoration(color: StatusChip.colors(booking.tone).$1, shape: BoxShape.circle),
                child: Center(
                  child: stage == BookingStage.searching
                      ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2.4))
                      : FaIcon(
                          stage == BookingStage.delivered
                              ? FontAwesomeIcons.circleCheck
                              : stage == BookingStage.cancelled
                                  ? FontAwesomeIcons.circleXmark
                                  : (ride ? FontAwesomeIcons.motorcycle : FontAwesomeIcons.boxOpen),
                          color: StatusChip.colors(booking.tone).$2,
                          size: 20,
                        ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(booking.stageLabel, style: const TextStyle(fontSize: 19, fontWeight: FontWeight.w800)),
                    Text(booking.title, style: const TextStyle(color: AppColors.textSecondary, fontSize: 13)),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(subtitle, style: const TextStyle(color: AppColors.textSecondary, height: 1.4)),
          if (current >= 0) ...[
            const SizedBox(height: 16),
            Row(
              children: [
                for (var i = 0; i < steps.length; i++) ...[
                  Expanded(
                    child: Column(
                      children: [
                        Container(
                          height: 5,
                          decoration: BoxDecoration(
                            color: i <= current ? AppColors.teal : AppColors.border,
                            borderRadius: BorderRadius.circular(99),
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          steps[i].$1,
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 10.5,
                            fontWeight: i == current ? FontWeight.w700 : FontWeight.w500,
                            color: i <= current ? AppColors.textPrimary : AppColors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (i < steps.length - 1) const SizedBox(width: 6),
                ],
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class _OtpCard extends StatelessWidget {
  final String otp;
  final bool isRide;
  const _OtpCard({required this.otp, required this.isRide});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.navy,
        borderRadius: BorderRadius.circular(AppRadius.lg),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('YOUR OTP', style: TextStyle(color: AppColors.yellow, fontSize: 11, fontWeight: FontWeight.w800, letterSpacing: 1)),
                const SizedBox(height: 4),
                Text(
                  isRide ? 'Tell this to your rider to start the ride' : 'Tell this to the rider at pickup',
                  style: const TextStyle(color: AppColors.textDisabled, fontSize: 12),
                ),
              ],
            ),
          ),
          Text(
            otp.isEmpty ? '----' : otp.split('').join(' '),
            style: const TextStyle(
              color: Colors.white,
              fontSize: 26,
              fontWeight: FontWeight.w800,
              fontFamily: AppTheme.displayFamily,
              letterSpacing: 2,
            ),
          ),
        ],
      ),
    );
  }
}

class _RiderCard extends StatelessWidget {
  final Booking booking;
  const _RiderCard({required this.booking});

  @override
  Widget build(BuildContext context) {
    final rider = booking.rider!;
    return AppCard(
      child: Column(
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 26,
                backgroundColor: AppColors.tealLight,
                child: ClipOval(
                  child: rider.photo.isNotEmpty
                      ? NetImage(rider.photo, width: 52, height: 52, fallbackIcon: Icons.person)
                      : Text(
                          rider.name.isEmpty ? '?' : rider.name[0].toUpperCase(),
                          style: const TextStyle(color: AppColors.teal, fontWeight: FontWeight.w800, fontSize: 20),
                        ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(rider.name.isEmpty ? 'Your rider' : rider.name,
                        style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
                    Text(
                      [
                        if (rider.vehicleType.isNotEmpty) rider.vehicleType,
                        if (rider.phone.isNotEmpty) '+91 ${rider.phone}',
                      ].join(' · '),
                      style: const TextStyle(color: AppColors.textSecondary, fontSize: 13),
                    ),
                  ],
                ),
              ),
              IconButton.filled(
                style: IconButton.styleFrom(backgroundColor: AppColors.teal),
                onPressed: () => callNumber(context, rider.phone),
                icon: const Icon(Icons.call_rounded, color: Colors.white),
              ),
            ],
          ),
          if (booking.riderLocation.isNotEmpty) ...[
            const SizedBox(height: 12),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(color: AppColors.background, borderRadius: BorderRadius.circular(AppRadius.md)),
              child: Row(
                children: [
                  const Icon(Icons.near_me_outlined, size: 18, color: AppColors.teal),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text('Rider is near ${booking.riderLocation}',
                        style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500)),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _TripCard extends StatelessWidget {
  final Booking booking;
  const _TripCard({required this.booking});

  @override
  Widget build(BuildContext context) {
    final ride = booking.kind == BookingKind.ride;
    final when = booking.pickupDateTime;
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Trip details', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
          const SizedBox(height: 14),
          RouteSummary(pickup: booking.pickup, drop: booking.drop),
          const SizedBox(height: 12),
          const Divider(),
          const SizedBox(height: 6),
          if (when != null) InfoRow(label: 'Pickup time', value: DateFormat('d MMM, h:mm a').format(when)),
          if (booking.distance.isNotEmpty) InfoRow(label: 'Distance', value: booking.distance),
          if (ride && booking.vehicleType.isNotEmpty) InfoRow(label: 'Vehicle', value: booking.vehicleType),
          if (ride && booking.passengers.isNotEmpty) InfoRow(label: 'Passengers', value: booking.passengers),
          if (!ride && booking.weight.isNotEmpty) InfoRow(label: 'Weight', value: booking.weight),
          if (!ride && booking.message.isNotEmpty) InfoRow(label: 'Package', value: booking.message),
          const Divider(),
          InfoRow(
            label: 'Fare (pay rider)',
            value: booking.price == null ? booking.expectedPrice : rupees(booking.price),
            bold: true,
          ),
        ],
      ),
    );
  }
}
