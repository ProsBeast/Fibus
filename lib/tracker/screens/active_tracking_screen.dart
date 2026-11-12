import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:go_router/go_router.dart';
import 'package:latlong2/latlong.dart';
import 'package:provider/provider.dart';
import 'package:fibus/core/theme/fibus_palette.dart';
import 'package:fibus/core/theme/fibus_theme.dart';
import 'package:fibus/core/widgets/map_tiles.dart';
import 'package:fibus/models/bus_model.dart';
import 'package:fibus/models/route_model.dart';
import 'package:fibus/services/firestore_service.dart';
import 'package:fibus/tracker/providers/tracking_provider.dart';
import 'package:fibus/tracker/providers/trip_lifecycle_provider.dart';
import 'package:fibus/tracker/widgets/gps_health_indicator.dart';

/// During the trip: is the bus being shared, how good is the GPS, and how
/// to end the trip. Built to be read at a glance from a bus seat.
/// The foreground service keeps tracking if the operator leaves this screen.
class ActiveTrackingScreen extends StatefulWidget {
  const ActiveTrackingScreen({super.key, required this.busId});

  final String busId;

  @override
  State<ActiveTrackingScreen> createState() => _ActiveTrackingScreenState();
}

class _ActiveTrackingScreenState extends State<ActiveTrackingScreen> {
  final FirestoreService _firestoreService = FirestoreService();
  final MapController _mapController = MapController();

  BusModel? _bus;
  RouteModel? _route;
  bool _autoCenter = true;

  @override
  void initState() {
    super.initState();
    _loadMetadata();
  }

  Future<void> _loadMetadata() async {
    try {
      final bus = await _firestoreService.getBus(widget.busId);
      RouteModel? route;
      if (bus != null && bus.routeIds.isNotEmpty) {
        route = await _firestoreService.getRoute(bus.routeIds.first);
      }
      if (mounted) {
        setState(() {
          _bus = bus;
          _route = route;
        });
      }
    } catch (_) {
      // The screen works without the route line.
    }
  }

  Future<void> _confirmStopTracking() async {
    final c = context.fib;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        title: const Text('End this trip'),
        content: const Text(
            'Riders stop seeing the bus and fall back to the timetable'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogCtx).pop(false),
            child: const Text('Keep tracking'),
          ),
          TextButton(
            onPressed: () => Navigator.of(dialogCtx).pop(true),
            style: TextButton.styleFrom(foregroundColor: c.negative),
            child: const Text('End trip'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    await context.read<TripLifecycleProvider>().stopTrip(widget.busId);
    if (mounted) context.go('/buses');
  }

  @override
  Widget build(BuildContext context) {
    final c = context.fib;
    final t = context.type;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final tracking = context.watch<TrackingProvider>();
    final lifecycle = context.watch<TripLifecycleProvider>();

    final pos = tracking.currentPosition;
    final here = pos != null
        ? LatLng(pos.latitude, pos.longitude)
        : const LatLng(17.3850, 78.4867);

    if (_autoCenter && pos != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _mapController.move(here, _mapController.camera.zoom);
      });
    }

    // Honest status: "visible" only when the server confirmed a recent upload.
    final sharing = tracking.ridersCanSee;
    final ended = !lifecycle.isActive && !lifecycle.isProcessing;
    final String status;
    String? statusDetail;
    if (tracking.superseded) {
      status = 'Another phone took over this bus';
      statusDetail = 'Tracking stopped on this phone';
    } else if (ended) {
      status = lifecycle.autoEnded
          ? 'Trip ended automatically'
          : 'This trip has ended';
      statusDetail = lifecycle.autoEnded
          ? 'Trips end by themselves after 3 hours'
          : null;
    } else if (sharing) {
      status = 'Riders can see this bus';
    } else if (pos == null || tracking.secondsSinceLastFix >= 60) {
      status = 'Waiting for a GPS fix';
      statusDetail = 'Riders see the timetable until GPS returns';
    } else {
      status = 'No connection';
      statusDetail = 'Riders see the timetable until the phone is back online';
    }
    final finished = tracking.superseded || ended;

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        // Tracking continues in the background when going back to the list.
        if (!didPop) context.go('/buses');
      },
      child: Scaffold(
        appBar: AppBar(
          leading: IconButton(
            tooltip: 'Back to buses',
            icon: const Icon(Icons.arrow_back),
            onPressed: () => context.go('/buses'),
          ),
          title: Text(_bus?.displayName ?? 'Tracking'),
        ),
        body: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(
                  FibusSpace.page, FibusSpace.s8, FibusSpace.page, FibusSpace.s16),
              child: Semantics(
                liveRegion: true,
                child: Row(
                  children: [
                    Container(
                      width: 10,
                      height: 10,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: sharing ? c.positive : null,
                        border: sharing
                            ? null
                            : Border.all(color: c.textMuted, width: 1.5),
                      ),
                    ),
                    const SizedBox(width: FibusSpace.s12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(status, style: t.titleLarge),
                          if (statusDetail != null)
                            Text(statusDetail, style: t.bodySmall),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: FibusSpace.page),
              child: Row(
                children: [
                  Expanded(
                    child: _Figure(
                        label: 'Speed',
                        value: tracking.speedKmh.toStringAsFixed(0),
                        unit: 'km/h'),
                  ),
                  Expanded(
                    child: _Figure(
                        label: 'On trip', value: tracking.sessionDurationFormatted),
                  ),
                ],
              ),
            ),
            const SizedBox(height: FibusSpace.s16),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: FibusSpace.page),
              child: GpsHealthIndicator(
                accuracy: tracking.accuracy,
                fixCount: tracking.fixCount,
                lastFixTime: tracking.lastFixTime,
                isTracking: tracking.isTracking,
              ),
            ),
            const SizedBox(height: FibusSpace.s16),
            Expanded(
              child: Container(
                margin: const EdgeInsets.symmetric(horizontal: FibusSpace.page),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(FibusSpace.radiusCard),
                  border: Border.all(color: c.hairline),
                ),
                clipBehavior: Clip.antiAlias,
                child: Stack(
                  children: [
                    FlutterMap(
                      mapController: _mapController,
                      options: MapOptions(
                        initialCenter: here,
                        initialZoom: 15.5,
                        onPositionChanged: (_, hasGesture) {
                          if (hasGesture && _autoCenter) {
                            setState(() => _autoCenter = false);
                          }
                        },
                      ),
                      children: [
                        TileLayer(
                          urlTemplate:
                              'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                          userAgentPackageName: 'com.fibus.tracker',
                          tileBuilder: (context, tile, _) => ColorFiltered(
                            colorFilter: ColorFilter.matrix(
                                isDark ? MapTiles.dark : MapTiles.quiet),
                            child: tile,
                          ),
                        ),
                        if (_route != null && _route!.polylinePoints.isNotEmpty)
                          PolylineLayer(polylines: [
                            Polyline(
                              points: _route!.polylinePoints,
                              color: c.textPrimary.withValues(alpha: 0.7),
                              strokeWidth: 3,
                            ),
                          ]),
                        if (pos != null)
                          MarkerLayer(markers: [
                            Marker(
                              point: here,
                              width: 36,
                              height: 36,
                              child: Transform.rotate(
                                angle: pos.heading * math.pi / 180,
                                child: Container(
                                  decoration: BoxDecoration(
                                    color: c.accent,
                                    shape: BoxShape.circle,
                                    border: Border.all(color: c.surface, width: 3),
                                  ),
                                  child: Icon(Icons.navigation_outlined,
                                      size: 18, color: c.onAccent),
                                ),
                              ),
                            ),
                          ]),
                      ],
                    ),
                    if (!_autoCenter)
                      Positioned(
                        right: FibusSpace.s12,
                        bottom: FibusSpace.s12,
                        child: Material(
                          color: c.surface,
                          shape: RoundedRectangleBorder(
                            borderRadius:
                                BorderRadius.circular(FibusSpace.radiusControl),
                            side: BorderSide(color: c.hairline),
                          ),
                          child: IconButton(
                            tooltip: 'Follow the bus',
                            icon: const Icon(Icons.my_location),
                            onPressed: () {
                              setState(() => _autoCenter = true);
                              _mapController.move(here, 16);
                            },
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ],
        ),
        bottomNavigationBar: SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(
                FibusSpace.page, FibusSpace.s12, FibusSpace.page, FibusSpace.s12),
            child: finished
                ? FilledButton(
                    onPressed: () async {
                      // Clears local trip state after a takeover.
                      if (lifecycle.isActive) await lifecycle.stopTrip(widget.busId);
                      if (context.mounted) context.go('/buses');
                    },
                    child: const Text('Back to buses'),
                  )
                : OutlinedButton(
                    onPressed:
                        lifecycle.isProcessing ? null : _confirmStopTracking,
                    style: OutlinedButton.styleFrom(foregroundColor: c.negative),
                    child: Text(lifecycle.isProcessing ? 'Ending' : 'End trip'),
                  ),
          ),
        ),
      ),
    );
  }
}

class _Figure extends StatelessWidget {
  const _Figure({required this.label, required this.value, this.unit});
  final String label;
  final String value;
  final String? unit;

  @override
  Widget build(BuildContext context) {
    final c = context.fib;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: context.type.labelMedium),
        const SizedBox(height: FibusSpace.s4),
        Row(
          crossAxisAlignment: CrossAxisAlignment.baseline,
          textBaseline: TextBaseline.alphabetic,
          children: [
            Text(value,
                style: FibusType.figure(context, size: 32, weight: FontWeight.w500)),
            if (unit != null) ...[
              const SizedBox(width: FibusSpace.s4),
              Text(unit!,
                  style: FibusType.figure(context, size: 14, color: c.textSecondary)),
            ],
          ],
        ),
      ],
    );
  }
}
