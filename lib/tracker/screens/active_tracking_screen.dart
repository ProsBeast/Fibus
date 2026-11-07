import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:go_router/go_router.dart';
import 'package:latlong2/latlong.dart';
import 'package:provider/provider.dart';
import 'package:fibus/core/theme/app_colors.dart';
import 'package:fibus/core/widgets/glass_card.dart';
import 'package:fibus/models/bus_model.dart';
import 'package:fibus/models/route_model.dart';
import 'package:fibus/services/firestore_service.dart';
import 'package:fibus/tracker/providers/tracking_provider.dart';
import 'package:fibus/tracker/providers/trip_lifecycle_provider.dart';
import 'package:fibus/tracker/widgets/gps_health_indicator.dart';

/// Active live tracking screen displaying real-time telemetry broadcast.
///
/// Shows live speedometer, GPS health metrics, elapsed trip duration,
/// interactive route map with heading-oriented bus marker, and prominent STOP CTA.
/// Note: Screen wake-lock and background persistence are enforced by FlutterForegroundTask.
class ActiveTrackingScreen extends StatefulWidget {
  final String busId;

  const ActiveTrackingScreen({super.key, required this.busId});

  @override
  State<ActiveTrackingScreen> createState() => _ActiveTrackingScreenState();
}

class _ActiveTrackingScreenState extends State<ActiveTrackingScreen> {
  final FirestoreService _firestoreService = FirestoreService();
  final MapController _mapController = MapController();

  BusModel? _bus;
  RouteModel? _route;
  bool _isLoadingMetadata = true;
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
          _isLoadingMetadata = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoadingMetadata = false;
        });
      }
    }
  }

  Future<void> _confirmStopTracking() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        backgroundColor: AppColors.surfaceElevated,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: const [
            Icon(Icons.stop_circle_rounded, color: AppColors.error, size: 28),
            SizedBox(width: 10),
            Text(
              'End Tracking Trip?',
              style: TextStyle(
                color: AppColors.textPrimary,
                fontSize: 18,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
        content: const Text(
          'Ending the trip will conclude real-time broadcast for this bus and mark the session ended in the central RTDB.',
          style: TextStyle(color: AppColors.textSecondary, fontSize: 14, height: 1.4),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogCtx).pop(false),
            child: const Text('Cancel', style: TextStyle(color: AppColors.textMuted)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(dialogCtx).pop(true),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.error,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            child: const Text('Stop Tracking', style: TextStyle(fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      final lifecycle = context.read<TripLifecycleProvider>();
      await lifecycle.stopTrip(widget.busId);
      if (mounted) {
        context.go('/buses');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final tracking = context.watch<TrackingProvider>();
    final lifecycle = context.watch<TripLifecycleProvider>();

    final currentPos = tracking.currentPosition;
    final currentLatLng = currentPos != null
        ? LatLng(currentPos.latitude, currentPos.longitude)
        : const LatLng(17.3850, 78.4867);

    // Auto-center map if enabled and valid location received
    if (_autoCenter && currentPos != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _mapController.move(currentLatLng, _mapController.camera.zoom);
      });
    }

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) async {
        if (didPop) return;
        // Background tracking continues even if user returns to bus list
        context.go('/buses');
      },
      child: Scaffold(
        backgroundColor: AppColors.background,
        appBar: AppBar(
          backgroundColor: AppColors.surface,
          elevation: 0,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back_rounded, color: AppColors.textPrimary),
            onPressed: () => context.go('/buses'),
          ),
          title: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                _bus?.displayName ?? 'Bus ${widget.busId}',
                style: const TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                ),
              ),
              Row(
                children: [
                  Container(
                    width: 7,
                    height: 7,
                    decoration: const BoxDecoration(
                      shape: BoxShape.circle,
                      color: AppColors.statusLive,
                    ),
                  ),
                  const SizedBox(width: 5),
                  Text(
                    'Gen #${lifecycle.sessionGeneration}',
                    style: const TextStyle(
                      color: AppColors.statusLive,
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ],
          ),
          actions: [
            IconButton(
              icon: Icon(
                _autoCenter ? Icons.my_location_rounded : Icons.location_searching_rounded,
                color: _autoCenter ? AppColors.trackerAmber : AppColors.textMuted,
              ),
              tooltip: 'Toggle Auto Center',
              onPressed: () {
                setState(() {
                  _autoCenter = !_autoCenter;
                });
                if (_autoCenter && currentPos != null) {
                  _mapController.move(currentLatLng, 16.0);
                }
              },
            ),
          ],
        ),
        body: Column(
          children: [
            // 1. GPS Health Bar at Top
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 10),
              child: GpsHealthIndicator(
                accuracy: tracking.accuracy,
                fixCount: tracking.fixCount,
                lastFixTime: tracking.lastFixTime,
                isTracking: tracking.isTracking,
              ),
            ),

            // 2. Interactive Map with Live Marker
            Expanded(
              flex: 4,
              child: Stack(
                children: [
                  FlutterMap(
                    mapController: _mapController,
                    options: MapOptions(
                      initialCenter: currentLatLng,
                      initialZoom: 15.5,
                      onPositionChanged: (pos, hasGesture) {
                        if (hasGesture && _autoCenter) {
                          setState(() {
                            _autoCenter = false;
                          });
                        }
                      },
                    ),
                    children: [
                      TileLayer(
                        urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                        userAgentPackageName: 'com.fibus.tracker',
                      ),
                      if (_route != null && _route!.polylinePoints.isNotEmpty)
                        PolylineLayer(
                          polylines: [
                            Polyline(
                              points: _route!.polylinePoints,
                              color: AppColors.trackerAmber.withValues(alpha: 0.8),
                              strokeWidth: 4.0,
                            ),
                          ],
                        ),
                      if (currentPos != null)
                        MarkerLayer(
                          markers: [
                            Marker(
                              point: currentLatLng,
                              width: 50,
                              height: 50,
                              child: Transform.rotate(
                                angle: (currentPos.heading * (3.141592653589793 / 180.0)),
                                child: Container(
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    color: AppColors.surface,
                                    border: Border.all(
                                      color: AppColors.statusLive,
                                      width: 2.5,
                                    ),
                                    boxShadow: [
                                      BoxShadow(
                                        color: AppColors.statusLive.withValues(alpha: 0.4),
                                        blurRadius: 10,
                                        spreadRadius: 2,
                                      ),
                                    ],
                                  ),
                                  child: const Center(
                                    child: Icon(
                                      Icons.navigation_rounded,
                                      color: AppColors.statusLive,
                                      size: 26,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                    ],
                  ),

                  // Floating Re-Center Button if user panned away
                  if (!_autoCenter)
                    Positioned(
                      bottom: 16,
                      right: 16,
                      child: FloatingActionButton.small(
                        backgroundColor: AppColors.surfaceElevated,
                        foregroundColor: AppColors.trackerAmber,
                        onPressed: () {
                          setState(() {
                            _autoCenter = true;
                          });
                          _mapController.move(currentLatLng, 16.0);
                        },
                        child: const Icon(Icons.my_location),
                      ),
                    ),
                ],
              ),
            ),

            // 3. Telemetry Dashboard (Speed, Duration)
            Expanded(
              flex: 3,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: const BoxDecoration(
                  color: AppColors.surface,
                  border: Border(
                    top: BorderSide(color: AppColors.border, width: 1.2),
                  ),
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    // Metrics Row
                    Row(
                      children: [
                        // Speedometer card
                        Expanded(
                          child: GlassCard(
                            padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 12),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                const Text(
                                  'SPEED',
                                  style: TextStyle(
                                    color: AppColors.textMuted,
                                    fontSize: 10,
                                    fontWeight: FontWeight.w700,
                                    letterSpacing: 0.8,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  crossAxisAlignment: CrossAxisAlignment.baseline,
                                  textBaseline: TextBaseline.alphabetic,
                                  children: [
                                    Text(
                                      tracking.speedKmh.toStringAsFixed(0),
                                      style: const TextStyle(
                                        color: AppColors.textPrimary,
                                        fontSize: 34,
                                        fontWeight: FontWeight.w900,
                                        fontFeatures: [FontFeature.tabularFigures()],
                                      ),
                                    ),
                                    const SizedBox(width: 4),
                                    const Text(
                                      'km/h',
                                      style: TextStyle(
                                        color: AppColors.trackerAmber,
                                        fontSize: 13,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),

                        // Elapsed Duration card
                        Expanded(
                          child: GlassCard(
                            padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 12),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                const Text(
                                  'SESSION DURATION',
                                  style: TextStyle(
                                    color: AppColors.textMuted,
                                    fontSize: 10,
                                    fontWeight: FontWeight.w700,
                                    letterSpacing: 0.8,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  tracking.sessionDurationFormatted,
                                  style: const TextStyle(
                                    color: AppColors.textPrimary,
                                    fontSize: 26,
                                    fontWeight: FontWeight.w800,
                                    fontFeatures: [FontFeature.tabularFigures()],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),

                    // BIG STOP TRACKING BUTTON
                    Container(
                      width: double.infinity,
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [Color(0xFFFF5252), Color(0xFFD32F2F)],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: [
                          BoxShadow(
                            color: AppColors.error.withValues(alpha: 0.4),
                            blurRadius: 16,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: ElevatedButton.icon(
                        onPressed: lifecycle.isProcessing ? null : _confirmStopTracking,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.transparent,
                          shadowColor: Colors.transparent,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                        ),
                        icon: const Icon(Icons.stop_circle_rounded, size: 28),
                        label: const Text(
                          'STOP TRACKING',
                          style: TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 1.0,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
