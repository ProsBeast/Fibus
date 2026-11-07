import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:fibus/core/theme/app_colors.dart';
import 'package:fibus/models/live_bus.dart';
import 'package:fibus/models/route_model.dart';
import 'package:fibus/models/stop_model.dart';

/// Mini map previewing the bus route geometry, boarding stop location,
/// and live bus GPS marker. Non-interactive display.
class RouteMapView extends StatelessWidget {
  const RouteMapView({
    super.key,
    required this.route,
    required this.stop,
    this.liveBus,
    this.height = 180.0,
  });

  final RouteModel? route;
  final StopModel? stop;
  final LiveBus? liveBus;
  final double height;

  LatLng get _initialCenter {
    if (liveBus != null && liveBus!.hasValidLocation) {
      return liveBus!.location;
    }
    if (stop != null) {
      return stop!.location;
    }
    if (route != null && route!.polylinePoints.isNotEmpty) {
      return route!.polylinePoints.first;
    }
    // Default fallback Hyderabad center
    return const LatLng(17.3850, 78.4867);
  }

  @override
  Widget build(BuildContext context) {
    final polyline = route?.polylinePoints ?? [];
    final hasBus = liveBus != null && liveBus!.hasValidLocation;
    final hasStop = stop != null;

    return Container(
      height: height,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.glassBorder),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.3),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: Stack(
          children: [
            FlutterMap(
              options: MapOptions(
                initialCenter: _initialCenter,
                initialZoom: 14.2,
                interactionOptions: const InteractionOptions(
                  flags: InteractiveFlag.none, // non-interactive
                ),
              ),
              children: [
                TileLayer(
                  urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                  userAgentPackageName: 'com.fibus.commuter',
                  tileBuilder: (context, tileWidget, tile) {
                    // Dark theme tint over standard OSM tiles
                    return ColorFiltered(
                      colorFilter: const ColorFilter.matrix([
                        0.25, 0, 0, 0, 15,
                        0, 0.28, 0, 0, 20,
                        0, 0, 0.35, 0, 30,
                        0, 0, 0, 1, 0,
                      ]),
                      child: tileWidget,
                    );
                  },
                ),
                if (polyline.isNotEmpty)
                  PolylineLayer(
                    polylines: [
                      Polyline(
                        points: polyline,
                        color: AppColors.primary,
                        strokeWidth: 4.5,
                      ),
                    ],
                  ),
                MarkerLayer(
                  markers: [
                    // Boarding Stop Marker
                    if (hasStop)
                      Marker(
                        point: stop!.location,
                        width: 38,
                        height: 38,
                        child: Container(
                          decoration: BoxDecoration(
                            color: AppColors.statusLive,
                            shape: BoxShape.circle,
                            border: Border.all(color: Colors.white, width: 2),
                            boxShadow: [
                              BoxShadow(
                                color: AppColors.statusLive.withValues(alpha: 0.6),
                                blurRadius: 8,
                                spreadRadius: 1,
                              ),
                            ],
                          ),
                          child: const Icon(
                            Icons.location_on_rounded,
                            color: Colors.white,
                            size: 20,
                          ),
                        ),
                      ),

                    // Live Bus GPS Position Marker
                    if (hasBus)
                      Marker(
                        point: liveBus!.location,
                        width: 44,
                        height: 44,
                        child: Container(
                          decoration: BoxDecoration(
                            color: AppColors.primary,
                            shape: BoxShape.circle,
                            border: Border.all(color: Colors.white, width: 2.5),
                            boxShadow: [
                              BoxShadow(
                                color: AppColors.primary.withValues(alpha: 0.7),
                                blurRadius: 10,
                                spreadRadius: 2,
                              ),
                            ],
                          ),
                          child: const Icon(
                            Icons.directions_bus_rounded,
                            color: Colors.white,
                            size: 22,
                          ),
                        ),
                      ),
                  ],
                ),
              ],
            ),

            // Gradient vignette overlay for dark theme integration
            Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.black.withValues(alpha: 0.4),
                    Colors.transparent,
                    Colors.black.withValues(alpha: 0.6),
                  ],
                ),
              ),
            ),

            // Top Label & Legend
            Positioned(
              top: 12,
              left: 14,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: AppColors.surface.withValues(alpha: 0.85),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: AppColors.glassBorder),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.map_rounded,
                      color: AppColors.primaryLight,
                      size: 14,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      route?.name ?? 'Route Map',
                      style: const TextStyle(
                        color: AppColors.textPrimary,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // Bottom Legend
            Positioned(
              bottom: 12,
              right: 14,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: AppColors.surface.withValues(alpha: 0.85),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 8,
                      height: 8,
                      decoration: const BoxDecoration(
                        color: AppColors.primary,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 4),
                    const Text(
                      'Bus',
                      style: TextStyle(color: AppColors.textSecondary, fontSize: 10),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      width: 8,
                      height: 8,
                      decoration: const BoxDecoration(
                        color: AppColors.statusLive,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 4),
                    const Text(
                      'Stop',
                      style: TextStyle(color: AppColors.textSecondary, fontSize: 10),
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
