/// Colour matrices for OpenStreetMap tiles so the map sits quietly under
/// the interface in either theme.
abstract final class MapTiles {
  /// Light: slightly desaturated so the pin and panels lead.
  static const List<double> quiet = [
    0.75, 0.2, 0.05, 0, 6,
    0.1, 0.85, 0.05, 0, 6,
    0.1, 0.2, 0.7, 0, 6,
    0, 0, 0, 1, 0,
  ];

  /// Dark: inverted and desaturated to sit on the dark ramp.
  static const List<double> dark = [
    -0.28, -0.42, -0.08, 0, 232,
    -0.28, -0.42, -0.08, 0, 230,
    -0.26, -0.40, -0.08, 0, 224,
    0, 0, 0, 1, 0,
  ];
}
