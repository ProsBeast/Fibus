import 'package:flutter/material.dart';
import 'package:fibus/core/theme/fibus_palette.dart';

/// Where a bus's position or ETA comes from.
enum TrackingStatus {
  /// Fresh GPS fixes within the 60 s threshold.
  live,

  /// Tracking started but no fresh fix for 60 s.
  stale,

  /// No live feed; times come from the published timetable.
  scheduled,

  /// Not tracking, or the trip ended.
  offline;

  static TrackingStatus fromString(String? value) {
    switch (value?.toLowerCase().trim()) {
      case 'live':
      case 'tracking':
      case 'active':
        return TrackingStatus.live;
      case 'stale':
        return TrackingStatus.stale;
      case 'schedule':
      case 'scheduled':
        return TrackingStatus.scheduled;
      default:
        return TrackingStatus.offline;
    }
  }

  String get label {
    switch (this) {
      case TrackingStatus.live:
        return 'Live';
      case TrackingStatus.stale:
        return 'GPS lost';
      case TrackingStatus.scheduled:
        return 'Timetable';
      case TrackingStatus.offline:
        return 'Not tracking';
    }
  }
}

/// A status dot with a sentence-case label. Only "Live" gets colour; the
/// other states are hollow or muted so colour is never the only signal.
/// Static: nothing pulses.
class StatusBadge extends StatelessWidget {
  const StatusBadge({
    super.key,
    required this.status,
    this.customLabel,
    this.compact = false,
  });

  final TrackingStatus status;
  final String? customLabel;

  /// Dot only.
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final c = context.fib;
    final isLive = status == TrackingStatus.live;
    final color = isLive ? c.positive : c.textMuted;
    final filled = isLive || status == TrackingStatus.scheduled;

    final dot = Container(
      width: 8,
      height: 8,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: filled ? color : null,
        border: filled ? null : Border.all(color: color, width: 1.5),
      ),
    );
    if (compact) return dot;

    return Semantics(
      label: customLabel ?? status.label,
      child: ExcludeSemantics(
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            dot,
            const SizedBox(width: FibusSpace.s8),
            Text(
              customLabel ?? status.label,
              style: context.type.labelMedium
                  ?.copyWith(color: isLive ? c.positive : c.textSecondary),
            ),
          ],
        ),
      ),
    );
  }
}
