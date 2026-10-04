import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../model/booking.dart';
import '../providers/UserProvider.dart';
import '../services/api.dart';
import '../theme/app_theme.dart';
import '../widgets/ui.dart';
import 'BookingTrackingScreen.dart';
import 'PhoneInputPage.dart';

/// Rider and parcel history (website: riderHistory.jsx / parcelHistory.jsx).
class BookingHistoryScreen extends StatelessWidget {
  final BookingKind initialKind;
  const BookingHistoryScreen({super.key, this.initialKind = BookingKind.ride});

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      initialIndex: initialKind == BookingKind.ride ? 0 : 1,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('My bookings'),
          bottom: const TabBar(tabs: [Tab(text: 'Rides'), Tab(text: 'Parcels')]),
        ),
        body: const TabBarView(
          children: [_HistoryList(kind: BookingKind.ride), _HistoryList(kind: BookingKind.parcel)],
        ),
      ),
    );
  }
}

class _HistoryList extends StatefulWidget {
  final BookingKind kind;
  const _HistoryList({required this.kind});

  @override
  State<_HistoryList> createState() => _HistoryListState();
}

class _HistoryListState extends State<_HistoryList> with AutomaticKeepAliveClientMixin {
  late Future<List<Booking>> _future;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  Future<List<Booking>> _load() async {
    final user = context.read<UserProvider>();
    if (!user.isLoggedIn) return [];
    final list = await Api.bookingHistory(widget.kind, user.phone);
    // Drafts were never sent to riders (e.g. the app closed mid-booking).
    return list.where((b) => b.stage != BookingStage.draft).toList();
  }

  Future<void> _refresh() async {
    setState(() => _future = _load());
    await _future.catchError((_) => <Booking>[]);
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final ride = widget.kind == BookingKind.ride;
    if (!context.watch<UserProvider>().isLoggedIn) {
      return EmptyState(
        icon: Icons.lock_outline_rounded,
        title: 'Log in to see your bookings',
        actionLabel: 'Login',
        onAction: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const PhoneInputPage())),
      );
    }
    return FutureBuilder<List<Booking>>(
      future: _future,
      builder: (context, snap) {
        if (snap.connectionState != ConnectionState.done) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snap.hasError) {
          return EmptyState(
            icon: Icons.wifi_off_rounded,
            title: 'Could not load history',
            message: snap.error.toString(),
            actionLabel: 'Retry',
            onAction: _refresh,
          );
        }
        final items = snap.data ?? [];
        if (items.isEmpty) {
          return RefreshIndicator(
            onRefresh: _refresh,
            child: ListView(
              children: [
                EmptyState(
                  icon: ride ? Icons.pedal_bike_rounded : Icons.inventory_2_outlined,
                  title: ride ? 'No rides yet' : 'No parcels yet',
                  message: ride ? 'Your rides will show up here.' : 'Parcels you send will show up here.',
                ),
              ],
            ),
          );
        }
        return RefreshIndicator(
          onRefresh: _refresh,
          child: ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: items.length,
            separatorBuilder: (_, __) => const SizedBox(height: 12),
            itemBuilder: (context, i) => _HistoryCard(
              booking: items[i],
              onTap: () async {
                await Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => BookingTrackingScreen(kind: widget.kind, orderId: items[i].id)),
                );
                _refresh();
              },
            ),
          ),
        );
      },
    );
  }
}

class _HistoryCard extends StatelessWidget {
  final Booking booking;
  final VoidCallback onTap;
  const _HistoryCard({required this.booking, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final ride = booking.kind == BookingKind.ride;
    final when = booking.pickupDateTime;
    return AppCard(
      onTap: onTap,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: ride ? AppColors.yellowLight : AppColors.tealLight,
                  borderRadius: BorderRadius.circular(AppRadius.md),
                ),
                child: Center(
                  child: FaIcon(
                    ride ? FontAwesomeIcons.motorcycle : FontAwesomeIcons.boxOpen,
                    size: 16,
                    color: ride ? const Color(0xFFCA8A04) : AppColors.teal,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(booking.title, style: const TextStyle(fontWeight: FontWeight.w700)),
                    if (when != null)
                      Text(DateFormat('d MMM yyyy, h:mm a').format(when),
                          style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                  ],
                ),
              ),
              StatusChip(label: booking.stageLabel, tone: booking.tone, dense: true),
            ],
          ),
          const SizedBox(height: 12),
          RouteSummary(pickup: booking.pickup, drop: booking.drop, maxLines: 1),
          const SizedBox(height: 10),
          Row(
            children: [
              if (booking.distance.isNotEmpty)
                Text(booking.distance, style: const TextStyle(color: AppColors.textSecondary, fontSize: 13)),
              const Spacer(),
              Text(
                booking.price == null ? '' : rupees(booking.price),
                style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
