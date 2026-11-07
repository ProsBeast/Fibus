import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:go_router/go_router.dart';
import 'package:latlong2/latlong.dart';
import 'package:provider/provider.dart';
import 'package:fibus/core/theme/app_colors.dart';
import 'package:fibus/core/widgets/glass_card.dart';
import 'package:fibus/core/widgets/status_badge.dart';
import 'package:fibus/models/bus_model.dart';
import 'package:fibus/models/live_bus_model.dart';
import 'package:fibus/models/route_model.dart';
import 'package:fibus/models/stop_model.dart';
import 'package:fibus/services/firestore_service.dart';
import 'package:fibus/services/realtime_db_service.dart';
import 'package:fibus/tracker/providers/trip_lifecycle_provider.dart';
import 'package:fibus/tracker/widgets/tracking_status_card.dart';

/// Pre-trip inspection and route launch preview screen for bus operators.
///
/// Displays bus identity, route overview map, scheduled stops, active broadcast
/// status, takeover options if already active, and the prominent "START TRACKING" CTA.
class TripPreviewScreen extends StatefulWidget {
  final String busId;

  const TripPreviewScreen({super.key, required this.busId});

  @override
  State<TripPreviewScreen> createState() => _TripPreviewScreenState();
}

class _TripPreviewScreenState extends State<TripPreviewScreen> {
  final FirestoreService _firestoreService = FirestoreService();
  final RealtimeDbService _rtdbService = RealtimeDbService();
  final MapController _mapController = MapController();

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
      if (bus == null) {
        throw Exception('Bus ${widget.busId} not found in fleet database.');
      }

      RouteModel? route;
      List<StopModel> stops = [];
      if (bus.routeIds.isNotEmpty) {
        route = await _firestoreService.getRoute(bus.routeIds.first);
        if (route != null) {
          stops = await _firestoreService.getStopsByRoute(route.id);
        }
      }

      if (mounted) {
        setState(() {
          _bus = bus;
          _route = route;
          _stops = stops;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = 'Failed to load trip preview: $e';
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _handleStartTracking() async {
    final lifecycle = context.read<TripLifecycleProvider>();
    final success = await lifecycle.startTrip(widget.busId);

    if (success && mounted) {
      context.go('/tracking/${widget.busId}');
    } else if (mounted && lifecycle.error != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(lifecycle.error!),
          backgroundColor: AppColors.error,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        backgroundColor: AppColors.background,
        appBar: AppBar(
          backgroundColor: AppColors.surface,
          title: Text('Bus ${widget.busId}'),
        ),
        body: const Center(
          child: CircularProgressIndicator(
            valueColor: AlwaysStoppedAnimation<Color>(AppColors.trackerAmber),
          ),
        ),
      );
    }

    if (_errorMessage != null || _bus == null) {
      return Scaffold(
        backgroundColor: AppColors.background,
        appBar: AppBar(
          backgroundColor: AppColors.surface,
          title: const Text('Trip Preview'),
        ),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.error_outline, color: AppColors.error, size: 48),
                const SizedBox(height: 16),
                Text(
                  _errorMessage ?? 'Unable to find bus details.',
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: AppColors.textSecondary),
                ),
                const SizedBox(height: 20),
                ElevatedButton(
                  onPressed: _loadTripData,
                  child: const Text('Retry'),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return StreamBuilder<LiveBusModel?>(
      stream: _rtdbService.streamLiveBus(widget.busId),
      builder: (context, snapshot) {
        final liveBus = snapshot.data;
        final isLive = liveBus?.isLive ?? false;
        final isStale = liveBus?.isStale ?? false;

        return Scaffold(
          backgroundColor: AppColors.background,
          appBar: AppBar(
            backgroundColor: AppColors.surface,
            elevation: 0,
            title: Text(
              _bus!.displayName,
              style: const TextStyle(
                color: AppColors.textPrimary,
                fontSize: 18,
                fontWeight: FontWeight.w700,
              ),
            ),
            actions: [
              Padding(
                padding: const EdgeInsets.only(right: 16),
                child: StatusBadge(
                  status: isLive
                      ? TrackingStatus.live
                      : (isStale ? TrackingStatus.stale : TrackingStatus.offline),
                ),
              ),
            ],
          ),
          body: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // 1. Live status or Warning Banner
                if (isLive) ...[
                  Container(
                    margin: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: AppColors.statusLive.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color: AppColors.statusLive.withValues(alpha: 0.4),
                      ),
                    ),
                    child: Row(
                      children: [
                        const Icon(
                          Icons.radio_button_checked,
                          color: AppColors.statusLive,
                          size: 20,
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            'Active broadcast in progress by operator (${liveBus!.operatorUid.substring(0, (liveBus.operatorUid.length > 5 ? 5 : liveBus.operatorUid.length))}...).',
                            style: const TextStyle(
                              color: AppColors.textPrimary,
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ] else if (isStale) ...[
                  Container(
                    margin: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: AppColors.warning.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color: AppColors.warning.withValues(alpha: 0.5),
                      ),
                    ),
                    child: Row(
                      children: [
                        const Icon(
                          Icons.warning_amber_rounded,
                          color: AppColors.warning,
                          size: 20,
                        ),
                        const SizedBox(width: 10),
                        const Expanded(
                          child: Text(
                            'Previous broadcast has become stale. You can initiate a session takeover.',
                            style: TextStyle(
                              color: AppColors.textPrimary,
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],

                // 2. Route Map Overview
                Container(
                  margin: const EdgeInsets.all(16),
                  height: 220,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(color: AppColors.border),
                  ),
                  clipBehavior: Clip.antiAlias,
                  child: _buildMapOverview(),
                ),

                // 3. Tracking Status Card
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: TrackingStatusCard(
                    liveBus: liveBus,
                    onTakeoverTap: () {
                      context.push('/takeover/${widget.busId}');
                    },
                  ),
                ),
                const SizedBox(height: 16),

                // 4. Schedule & Stops List
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: GlassCard(
                    padding: const EdgeInsets.all(18),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text(
                              'SCHEDULED STOPS',
                              style: TextStyle(
                                color: AppColors.textMuted,
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                                letterSpacing: 0.8,
                              ),
                            ),
                            Text(
                              '${_stops.length} Stops',
                              style: const TextStyle(
                                color: AppColors.trackerAmber,
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 14),
                        if (_stops.isEmpty)
                          const Padding(
                            padding: EdgeInsets.symmetric(vertical: 8),
                            child: Text(
                              'No stop sequence registered for this route.',
                              style: TextStyle(color: AppColors.textSecondary, fontSize: 13),
                            ),
                          )
                        else
                          ..._stops.asMap().entries.map((entry) {
                            final idx = entry.key;
                            final stop = entry.value;
                            final isFirst = idx == 0;
                            final isLast = idx == _stops.length - 1;

                            return Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                // Step node
                                Column(
                                  children: [
                                    Container(
                                      width: 14,
                                      height: 14,
                                      decoration: BoxDecoration(
                                        shape: BoxShape.circle,
                                        color: isFirst
                                            ? AppColors.success
                                            : (isLast
                                                ? AppColors.trackerAmber
                                                : AppColors.surfaceHighlight),
                                        border: Border.all(
                                          color: isFirst
                                              ? AppColors.success
                                              : (isLast
                                                  ? AppColors.trackerAmber
                                                  : AppColors.border),
                                          width: 2,
                                        ),
                                      ),
                                    ),
                                    if (!isLast)
                                      Container(
                                        width: 2,
                                        height: 32,
                                        color: AppColors.border,
                                      ),
                                  ],
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Padding(
                                    padding: const EdgeInsets.only(bottom: 12),
                                    child: Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.spaceBetween,
                                      children: [
                                        Expanded(
                                          child: Text(
                                            stop.name,
                                            style: const TextStyle(
                                              color: AppColors.textPrimary,
                                              fontSize: 14,
                                              fontWeight: FontWeight.w600,
                                            ),
                                          ),
                                        ),
                                        Text(
                                          stop.scheduledArrivalLocalTime,
                                          style: const TextStyle(
                                            color: AppColors.textSecondary,
                                            fontSize: 13,
                                            fontWeight: FontWeight.w500,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ],
                            );
                          }),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 100), // Space for bottom action bar
              ],
            ),
          ),
          bottomSheet: Container(
            padding: const EdgeInsets.all(16),
            decoration: const BoxDecoration(
              color: AppColors.surface,
              border: Border(top: BorderSide(color: AppColors.border)),
            ),
            child: SafeArea(
              child: isStale
                  ? Row(
                      children: [
                        Expanded(
                          child: ElevatedButton.icon(
                            onPressed: () {
                              context.push('/takeover/${widget.busId}');
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.warning,
                              foregroundColor: Colors.black87,
                              padding: const EdgeInsets.symmetric(vertical: 16),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(16),
                              ),
                            ),
                            icon: const Icon(Icons.swap_horiz_rounded),
                            label: const Text(
                              'TAKEOVER TRACKING',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w800,
                                letterSpacing: 0.5,
                              ),
                            ),
                          ),
                        ),
                      ],
                    )
                  : Consumer<TripLifecycleProvider>(
                      builder: (context, lifecycle, child) {
                        return Container(
                          decoration: BoxDecoration(
                            gradient: AppColors.trackerGradient,
                            borderRadius: BorderRadius.circular(16),
                            boxShadow: [
                              BoxShadow(
                                color: AppColors.trackerAmber.withValues(alpha: 0.4),
                                blurRadius: 18,
                                offset: const Offset(0, 6),
                              ),
                            ],
                          ),
                          child: ElevatedButton(
                            onPressed: lifecycle.isProcessing
                                ? null
                                : _handleStartTracking,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.transparent,
                              shadowColor: Colors.transparent,
                              foregroundColor: Colors.black87,
                              padding: const EdgeInsets.symmetric(vertical: 16),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(16),
                              ),
                            ),
                            child: lifecycle.isProcessing
                                ? const SizedBox(
                                    height: 24,
                                    width: 24,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2.5,
                                      valueColor: AlwaysStoppedAnimation<Color>(
                                        Colors.black87,
                                      ),
                                    ),
                                  )
                                : Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: const [
                                      Icon(
                                        Icons.play_arrow_rounded,
                                        size: 26,
                                        color: Colors.black87,
                                      ),
                                      SizedBox(width: 8),
                                      Text(
                                        'START TRACKING',
                                        style: TextStyle(
                                          fontSize: 17,
                                          fontWeight: FontWeight.w800,
                                          letterSpacing: 0.8,
                                          color: Colors.black87,
                                        ),
                                      ),
                                    ],
                                  ),
                          ),
                        );
                      },
                    ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildMapOverview() {
    LatLng center = const LatLng(17.3850, 78.4867); // Hyderabad fallback
    final points = _route?.polylinePoints ?? [];
    if (points.isNotEmpty) {
      center = points[points.length ~/ 2];
    } else if (_stops.isNotEmpty) {
      center = _stops.first.location;
    }

    return FlutterMap(
      mapController: _mapController,
      options: MapOptions(
        initialCenter: center,
        initialZoom: 13.0,
      ),
      children: [
        TileLayer(
          urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
          userAgentPackageName: 'com.fibus.tracker',
        ),
        if (points.isNotEmpty)
          PolylineLayer(
            polylines: [
              Polyline(
                points: points,
                color: AppColors.trackerAmber,
                strokeWidth: 4.5,
              ),
            ],
          ),
        MarkerLayer(
          markers: _stops.map((stop) {
            return Marker(
              point: stop.location,
              width: 28,
              height: 28,
              child: Container(
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: AppColors.surface,
                  border: Border.all(color: AppColors.trackerAmber, width: 2),
                ),
                child: const Icon(
                  Icons.place_rounded,
                  size: 16,
                  color: AppColors.trackerAmber,
                ),
              ),
            );
          }).toList(),
        ),
      ],
    );
  }
}
