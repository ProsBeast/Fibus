import 'package:flutter/material.dart';
import 'package:fibus/core/theme/fibus_palette.dart';

/// Colour matrices for OpenStreetMap tiles so the map sits quietly under
/// the interface in either theme.
abstract final class MapTiles {
  /// Light: slightly desaturated so the pin and panels lead.
  static const List<double> quiet = [
    0.75,
    0.2,
    0.05,
    0,
    6,
    0.1,
    0.85,
    0.05,
    0,
    6,
    0.1,
    0.2,
    0.7,
    0,
    6,
    0,
    0,
    0,
    1,
    0,
  ];

  /// Dark: inverted and desaturated to sit on the dark ramp.
  static const List<double> dark = [
    -0.28,
    -0.42,
    -0.08,
    0,
    232,
    -0.28,
    -0.42,
    -0.08,
    0,
    230,
    -0.26,
    -0.40,
    -0.08,
    0,
    224,
    0,
    0,
    0,
    1,
    0,
  ];
}

/// The credit OpenStreetMap's tile policy requires on every map.
class OsmAttributionChip extends StatelessWidget {
  const OsmAttributionChip({super.key});

  @override
  Widget build(BuildContext context) {
    final c = context.fib;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: c.surface.withValues(alpha: 0.85),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        '© OpenStreetMap',
        style: TextStyle(fontSize: 10, height: 1.4, color: c.textSecondary),
      ),
    );
  }
}

/// [OsmAttributionChip] pinned to a corner, for use as the last child of a
/// `FlutterMap`.
class OsmAttribution extends StatelessWidget {
  const OsmAttribution({super.key, this.alignment = Alignment.bottomLeft});

  final Alignment alignment;

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: Align(
        alignment: alignment,
        child: const Padding(
          padding: EdgeInsets.all(6),
          child: OsmAttributionChip(),
        ),
      ),
    );
  }
}
