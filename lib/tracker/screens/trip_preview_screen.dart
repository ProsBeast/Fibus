import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:go_router/go_router.dart';
import 'package:latlong2/latlong.dart';
import 'package:provider/provider.dart';
import 'package:fibus/core/theme/fibus_palette.dart';
import 'package:fibus/core/theme/fibus_theme.dart';
import 'package:fibus/core/widgets/error_display.dart';
import 'package:fibus/core/widgets/fib_card.dart';
import 'package:fibus/core/widgets/map_tiles.dart';
import 'package:fibus/core/widgets/status_badge.dart';
import 'package:fibus/models/bus_model.dart';
import 'package:fibus/models/live_bus_model.dart';
import 'package:fibus/models/route_model.dart';
import 'package:fibus/models/stop_model.dart';
import 'package:fibus/services/auth_service.dart';
import 'package:fibus/services/firestore_service.dart';
import 'package:fibus/services/realtime_db_service.dart';
import 'package:fibus/services/service_calendar.dart';
import 'package:fibus/tracker/providers/trip_lifecycle_provider.dart';

/// Before the trip: the route, its timetable and one action — start
/// tracking, or take over when someone else's feed has gone quiet.
class TripPreviewScreen extends StatefulWidget {
  const TripPreviewScreen({super.key, required this.busId});

  final String busId;

  @override
  State<TripPreviewScreen> createState() => _TripPreviewScreenState();
}

class _TripPreviewScreenState extends State<TripPreviewScreen> {
  final FirestoreService _firestoreService = FirestoreService();
  final RealtimeDbService _rtdbService = RealtimeDbService();
  late final Stream<LiveBusModel?> _liveStream = _rtdbService.streamLiveBus(
    widget.busId,
  );

  bool _isLoading = true;
  String? _errorMessage;
  BusModel? _bus;
  RouteModel? _route;
  List<StopModel> _stops = [];

  @override
  void initState() {
    super.initState();
    _loadTripData();
  }

  Future<void> _loadTripData() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });
    try {
      final bus = await _firestoreService.getBus(widget.busId);
      if (bus == null) throw Exception('missing bus');
      RouteModel? route;
      var stops = <StopModel>[];
      if (bus.routeIds.isNotEmpty) {
        route = await _firestoreService.getRoute(bus.routeIds.first);
        if (route != null)
          stops = await _firestoreService.getStopsByRoute(route.id);
      }
      if (mounted) {
        setState(() {
          _bus = bus;
          _route = route;
          _stops = stops;
          _isLoading = false;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _errorMessage = 'Could not load this bus. Check your connection';
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _handleStartTracking() async {
    final lifecycle = context.read<TripLifecycleProvider>();
    final messenger = ScaffoldMessenger.of(context);
    final success = await lifecycle.startTrip(widget.busId);
    if (!mounted) return;
    if (success) {
      context.go('/tracking/${widget.busId}');
    } else if (lifecycle.error != null) {
      messenger.showSnackBar(SnackBar(content: Text(lifecycle.error!)));
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        appBar: AppBar(),
        body: const Center(child: CircularProgressIndicator(strokeWidth: 2)),
      );
    }
    if (_errorMessage != null || _bus == null) {
      return Scaffold(
        appBar: AppBar(),
        body: ErrorDisplay(
          message: _errorMessage ?? 'This bus could not be found',
          onRetry: _loadTripData,
        ),
      );
    }

    final c = context.fib;
    final t = context.type;

    return StreamBuilder<LiveBusModel?>(
      stream: _liveStream,
      builder: (context, snapshot) {
        final live = snapshot.data;
        final isLive = live?.isLive ?? false;
        final isStale = live?.isStale ?? false;
        final myUid = context.read<AuthService>().currentUser?.uid;
        // The feed is this operator's own, for example after the app was
        // closed mid-trip. They may resume without waiting for a takeover.
        final isMine =
            live != null && myUid != null && live.operatorUid == myUid;
        final lifecycleNow = context.watch<TripLifecycleProvider>();
        final trackingHere =
            lifecycleNow.isActive && lifecycleNow.currentBusId == widget.busId;

        return Scaffold(
          appBar: AppBar(title: Text(_bus!.displayName)),
          body: ListView(
            padding: const EdgeInsets.fromLTRB(
              FibusSpace.page,
              FibusSpace.s8,
              FibusSpace.page,
              FibusSpace.s24,
            ),
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      _route?.name ?? 'No route set',
                      style: t.bodyMedium?.copyWith(color: c.textSecondary),
                    ),
                  ),
                  StatusBadge(
                    status: isLive
                        ? TrackingStatus.live
                        : (isStale
                              ? TrackingStatus.stale
                              : TrackingStatus.offline),
                  ),
                ],
              ),
              if ((isLive || isStale) && !trackingHere) ...[
                const SizedBox(height: FibusSpace.s16),
                FibCard(
                  color: isLive && !isMine ? c.raised : c.accentSoft,
                  borderColor: Colors.transparent,
                  padding: const EdgeInsets.all(FibusSpace.s16),
                  child: Text(
                    isMine
                        ? 'Your last trip on this bus was not ended. Resume '
                              'to keep sharing it'
                        : isLive
                        ? 'This bus is being tracked from another phone'
                        : 'The last tracker stopped sending over a minute '
                              'ago. You can take over',
                    style: t.bodySmall?.copyWith(color: c.textPrimary),
                  ),
                ),
              ],
              const SizedBox(height: FibusSpace.s16),
              Container(
                height: 200,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(FibusSpace.radiusCard),
                  border: Border.all(color: c.hairline),
                ),
                clipBehavior: Clip.antiAlias,
                child: _buildMap(c),
              ),
              const SizedBox(height: FibusSpace.s24),
              SectionLabel(
                'Timetable',
                trailing: Text('${_stops.length} stops', style: t.labelSmall),
              ),
              const SizedBox(height: FibusSpace.s8),
              FibCard(
                padding: const EdgeInsets.symmetric(vertical: FibusSpace.s8),
                child: _stops.isEmpty
                    ? Padding(
                        padding: const EdgeInsets.all(FibusSpace.s16),
                        child: Text(
                          'No stops are set up for this route',
                          style: t.bodySmall,
                        ),
                      )
                    : Column(
                        children: [
                          for (var i = 0; i < _stops.length; i++)
                            _StopRow(
                              stop: _stops[i],
                              first: i == 0,
                              last: i == _stops.length - 1,
                            ),
                        ],
                      ),
              ),
            ],
          ),
          bottomNavigationBar: SafeArea(
            child: Container(
              padding: const EdgeInsets.fromLTRB(
                FibusSpace.page,
                FibusSpace.s12,
                FibusSpace.page,
                FibusSpace.s12,
              ),
              decoration: BoxDecoration(
                color: c.background,
                border: Border(top: BorderSide(color: c.hairline)),
              ),
              child: trackingHere
                  ? FilledButton(
                      onPressed: () => context.go('/tracking/${widget.busId}'),
                      child: const Text('Open tracking'),
                    )
                  : isStale && !isMine
                  ? FilledButton(
                      onPressed: () =>
                          context.push('/takeover/${widget.busId}'),
                      child: const Text('Take over tracking'),
                    )
                  : FilledButton(
                      onPressed:
                          lifecycleNow.isProcessing || (isLive && !isMine)
                          ? null
                          : _handleStartTracking,
                      child: Text(
                        lifecycleNow.isProcessing
                            ? 'Starting'
                            : isMine && (isLive || isStale)
                            ? 'Resume tracking'
                            : isLive
                            ? 'Already tracking'
                            : 'Start tracking',
                      ),
                    ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildMap(FibusPalette c) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final points = _route?.polylinePoints ?? const <LatLng>[];
    final center = points.isNotEmpty
        ? points[points.length ~/ 2]
        : (_stops.isNotEmpty
              ? _stops.first.location
              : const LatLng(17.3850, 78.4867));
    return FlutterMap(
      options: MapOptions(initialCenter: center, initialZoom: 11.5),
      children: [
        TileLayer(
          urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
          userAgentPackageName: 'com.fibus.tracker',
          tileBuilder: (context, tile, _) => ColorFiltered(
            colorFilter: ColorFilter.matrix(
              isDark ? MapTiles.dark : MapTiles.quiet,
            ),
            child: tile,
          ),
        ),
        if (points.isNotEmpty)
          PolylineLayer(
            polylines: [
              Polyline(
                points: points,
                color: c.textPrimary.withValues(alpha: 0.8),
                strokeWidth: 3,
              ),
            ],
          ),
        const OsmAttribution(),
        MarkerLayer(
          markers: [
            for (final s in _stops)
              Marker(
                point: s.location,
                width: 12,
                height: 12,
                child: Container(
                  decoration: BoxDecoration(
                    color: c.surface,
                    shape: BoxShape.circle,
                    border: Border.all(color: c.textPrimary, width: 2),
                  ),
                ),
              ),
          ],
        ),
      ],
    );
  }
}

class _StopRow extends StatelessWidget {
  const _StopRow({required this.stop, required this.first, required this.last});
  final StopModel stop;
  final bool first;
  final bool last;

  @override
  Widget build(BuildContext context) {
    final c = context.fib;
    return ConstrainedBox(
      constraints: const BoxConstraints(minHeight: 44),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: FibusSpace.s16),
        child: IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              ConstrainedBox(
                constraints: const BoxConstraints(minWidth: 68),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    formatTimetable(stop.scheduledArrivalLocalTime),
                    style: FibusType.figure(
                      context,
                      size: 13,
                      color: c.textSecondary,
                    ),
                  ),
                ),
              ),
              SizedBox(
                width: 24,
                child: CustomPaint(
                  painter: _LinePainter(
                    first: first,
                    last: last,
                    line: c.textMuted.withValues(alpha: 0.4),
                    ink: c.textPrimary,
                    fill: c.surface,
                  ),
                ),
              ),
              const SizedBox(width: FibusSpace.s12),
              Expanded(
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      vertical: FibusSpace.s12,
                    ),
                    child: Text(stop.name, style: context.type.bodyMedium),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _LinePainter extends CustomPainter {
  _LinePainter({
    required this.first,
    required this.last,
    required this.line,
    required this.ink,
    required this.fill,
  });

  final bool first, last;
  final Color line, ink, fill;

  @override
  void paint(Canvas canvas, Size size) {
    final cx = size.width / 2;
    final cy = size.height / 2;
    canvas.drawLine(
      Offset(cx, first ? cy : 0),
      Offset(cx, last ? cy : size.height),
      Paint()
        ..color = line
        ..strokeWidth = 2,
    );
    final end = first || last;
    canvas.drawCircle(
      Offset(cx, cy),
      end ? 5 : 4,
      Paint()..color = end ? ink : fill,
    );
    if (!end) {
      canvas.drawCircle(
        Offset(cx, cy),
        4,
        Paint()
          ..color = ink.withValues(alpha: 0.55)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.5,
      );
    }
  }

  @override
  bool shouldRepaint(_LinePainter old) => old.ink != ink || old.line != line;
}
