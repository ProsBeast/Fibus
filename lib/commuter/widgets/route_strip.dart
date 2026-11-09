import 'package:flutter/material.dart';
import 'package:fibus/core/theme/fibus_palette.dart';
import 'package:fibus/core/theme/fibus_theme.dart';

/// Fibus's signature: the route drawn like a route board, stops spaced by
/// real distance, with the bus on it. The accent marks only the bus. A
/// filled marker means live GPS; an outlined one is the last known position.
class RouteStrip extends StatelessWidget {
  const RouteStrip({
    super.key,
    required this.stopNames,
    required this.stopFractions,
    required this.boardingIndex,
    this.busFraction,
    this.busIsLive = false,
  });

  final List<String> stopNames;

  /// 0..1 positions of each stop along the route, in order.
  final List<double> stopFractions;
  final int boardingIndex;

  /// 0..1 position of the bus, or null when there is no tracker data.
  final double? busFraction;
  final bool busIsLive;

  static const double _height = 76;
  static const double _lineY = 36;
  static const double _inset = 8;

  @override
  Widget build(BuildContext context) {
    if (stopFractions.length < 2) return const SizedBox(height: _height);
    final c = context.fib;

    return Semantics(
      label: _describe(),
      child: ExcludeSemantics(
        child: SizedBox(
          height: _height,
          child: LayoutBuilder(builder: (context, box) {
            final w = box.maxWidth - _inset * 2;
            double x(double f) => _inset + f * w;

            final labels = <_Label>[
              _Label(0, TextAlign.left),
              if (boardingIndex > 0 && boardingIndex < stopNames.length - 1)
                _Label(boardingIndex, TextAlign.center),
              _Label(stopNames.length - 1, TextAlign.right),
            ];
            // Drop an end label that would collide with the boarding label.
            final boardX = x(stopFractions[boardingIndex]);
            labels.removeWhere((l) =>
                l.index != boardingIndex &&
                (x(stopFractions[l.index]) - boardX).abs() < 84 &&
                labels.any((o) => o.index == boardingIndex));

            return Stack(
              clipBehavior: Clip.none,
              children: [
                Positioned.fill(
                  child: CustomPaint(
                    painter: _StripPainter(
                      fractions: stopFractions,
                      boardingIndex: boardingIndex,
                      busFraction: busFraction,
                      inset: _inset,
                      lineY: _lineY,
                      line: c.textMuted.withValues(alpha: 0.35),
                      travelled: c.textPrimary,
                      tickAhead: c.textMuted,
                      fill: c.surface,
                    ),
                  ),
                ),
                if (busFraction != null)
                  Positioned(
                    left: x(busFraction!) - 12,
                    top: _lineY - 30,
                    child: _BusMarker(live: busIsLive),
                  ),
                for (final l in labels)
                  _positionedLabel(context, l, x(stopFractions[l.index]),
                      box.maxWidth),
              ],
            );
          }),
        ),
      ),
    );
  }

  Widget _positionedLabel(
      BuildContext context, _Label l, double cx, double maxWidth) {
    final c = context.fib;
    final isBoarding = l.index == boardingIndex;
    final text = Text(
      isBoarding ? 'You · ${stopNames[l.index]}' : stopNames[l.index],
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      textAlign: l.align,
      style: context.type.labelSmall?.copyWith(
        color: isBoarding ? c.textPrimary : c.textMuted,
        fontWeight: isBoarding ? FontWeight.w500 : FontWeight.w400,
      ),
    );
    const width = 132.0;
    double left;
    switch (l.align) {
      case TextAlign.left:
        left = 0;
      case TextAlign.right:
        left = maxWidth - width;
      default:
        left = (cx - width / 2).clamp(0, maxWidth - width);
    }
    return Positioned(left: left, top: _lineY + 14, width: width, child: text);
  }

  String _describe() {
    final stop = stopNames[boardingIndex];
    final f = busFraction;
    if (f == null) return 'Route to $stop. No live bus position';
    final ahead = stopFractions.indexWhere((s) => s > f);
    if (f >= stopFractions[boardingIndex]) return 'The bus has reached $stop';
    final next = ahead < 0 ? stopNames.last : stopNames[ahead];
    return 'The bus is before $next, heading to $stop';
  }
}

class _Label {
  _Label(this.index, this.align);
  final int index;
  final TextAlign align;
}

class _BusMarker extends StatelessWidget {
  const _BusMarker({required this.live});
  final bool live;

  @override
  Widget build(BuildContext context) {
    final c = context.fib;
    return Container(
      width: 24,
      height: 20,
      decoration: BoxDecoration(
        color: live ? c.accent : c.surface,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: c.accent, width: live ? 0 : 1.5),
      ),
      child: Icon(Icons.directions_bus_outlined,
          size: 14, color: live ? c.onAccent : c.accentInk),
    );
  }
}

class _StripPainter extends CustomPainter {
  _StripPainter({
    required this.fractions,
    required this.boardingIndex,
    required this.busFraction,
    required this.inset,
    required this.lineY,
    required this.line,
    required this.travelled,
    required this.tickAhead,
    required this.fill,
  });

  final List<double> fractions;
  final int boardingIndex;
  final double? busFraction;
  final double inset;
  final double lineY;
  final Color line;
  final Color travelled;
  final Color tickAhead;
  final Color fill;

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width - inset * 2;
    double x(double f) => inset + f * w;
    final y = lineY;

    final base = Paint()
      ..color = line
      ..strokeWidth = 2
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(Offset(x(0), y), Offset(x(1), y), base);

    final bus = busFraction;
    if (bus != null && bus > 0) {
      canvas.drawLine(
        Offset(x(0), y),
        Offset(x(bus), y),
        Paint()
          ..color = travelled
          ..strokeWidth = 2
          ..strokeCap = StrokeCap.round,
      );
    }

    for (var i = 0; i < fractions.length; i++) {
      final cx = x(fractions[i]);
      final passed = bus != null && fractions[i] <= bus;
      if (i == boardingIndex) {
        canvas.drawCircle(Offset(cx, y), 7, Paint()..color = fill);
        canvas.drawCircle(
          Offset(cx, y),
          7,
          Paint()
            ..color = travelled
            ..style = PaintingStyle.stroke
            ..strokeWidth = 2,
        );
        canvas.drawCircle(Offset(cx, y), 3, Paint()..color = travelled);
      } else {
        canvas.drawCircle(Offset(cx, y), 4, Paint()..color = fill);
        canvas.drawCircle(
          Offset(cx, y),
          4,
          Paint()
            ..color = passed ? travelled : tickAhead
            ..style = passed ? PaintingStyle.fill : PaintingStyle.stroke
            ..strokeWidth = 1.5,
        );
      }
    }
  }

  @override
  bool shouldRepaint(_StripPainter old) =>
      old.busFraction != busFraction ||
      old.boardingIndex != boardingIndex ||
      old.fractions != fractions ||
      old.line != line ||
      old.travelled != travelled;
}

/// Big timetable-style clock figure, e.g. `07:42`, with an optional suffix.
class ClockFigure extends StatelessWidget {
  const ClockFigure(this.time, {super.key, this.size = 56, this.color});

  final String time;
  final double size;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    return Text(
      time,
      style: FibusType.figure(context,
          size: size, weight: FontWeight.w500, color: color),
    );
  }
}
