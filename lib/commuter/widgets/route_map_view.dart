import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:fibus/core/theme/fibus_palette.dart';
import 'package:fibus/core/widgets/map_tiles.dart';
import 'package:fibus/models/live_bus.dart';
import 'package:fibus/models/route_model.dart';
import 'package:fibus/models/stop_model.dart';

/// Non-interactive map of the route, the boarding stop and the bus.
/// The route is drawn in primary ink; only the bus carries the accent.
class RouteMapView extends StatelessWidget {
  const RouteMapView({
    super.key,
    required this.route,
    required this.stop,
    this.liveBus,
    this.height = 200,
  });

  final RouteModel? route;
  final StopModel? stop;
  final LiveBus? liveBus;
  final double height;

  LatLng get _initialCenter {
    if (liveBus != null && liveBus!.hasValidLocation) return liveBus!.location;
    if (stop != null) return stop!.location;
    if (route != null && route!.polylinePoints.isNotEmpty) {
      return route!.polylinePoints.first;
    }
    return const LatLng(17.3850, 78.4867);
  }

  @override
  Widget build(BuildContext context) {
    final c = context.fib;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final polyline = route?.polylinePoints ?? const <LatLng>[];
    final hasBus =
        liveBus != null && liveBus!.hasValidLocation && !liveBus!.isOffline;
    final busLive = liveBus?.isLive ?? false;

    return Semantics(
      label: 'Map of ${route?.name ?? 'the route'}',
      child: Container(
        height: height,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(FibusSpace.radiusCard),
          border: Border.all(color: c.hairline),
        ),
        clipBehavior: Clip.antiAlias,
        child: FlutterMap(
          options: MapOptions(
            initialCenter: _initialCenter,
            initialZoom: 13.5,
            interactionOptions: const InteractionOptions(
              flags: InteractiveFlag.none,
            ),
          ),
          children: [
            TileLayer(
              urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
              userAgentPackageName: 'com.fibus.commuter',
              tileBuilder: (context, tile, _) => ColorFiltered(
                colorFilter: ColorFilter.matrix(
                  isDark ? MapTiles.dark : MapTiles.quiet,
                ),
                child: tile,
              ),
            ),
            if (polyline.isNotEmpty)
              PolylineLayer(
                polylines: [
                  Polyline(
                    points: polyline,
                    color: c.textPrimary.withValues(alpha: 0.8),
                    strokeWidth: 3,
                  ),
                ],
              ),
            const OsmAttribution(),
            MarkerLayer(
              markers: [
                if (stop != null)
                  Marker(
                    point: stop!.location,
                    width: 20,
                    height: 20,
                    child: Container(
                      decoration: BoxDecoration(
                        color: c.surface,
                        shape: BoxShape.circle,
                        border: Border.all(color: c.textPrimary, width: 3),
                      ),
                    ),
                  ),
                if (hasBus)
                  Marker(
                    point: liveBus!.location,
                    width: 32,
                    height: 28,
                    child: Container(
                      decoration: BoxDecoration(
                        color: busLive ? c.accent : c.surface,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: c.accent,
                          width: busLive ? 0 : 2,
                        ),
                      ),
                      child: Icon(
                        Icons.directions_bus_outlined,
                        size: 18,
                        color: busLive ? c.onAccent : c.accentInk,
                      ),
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
