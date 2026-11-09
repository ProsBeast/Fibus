import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:fibus/commuter/widgets/route_strip.dart';
import 'package:fibus/core/theme/fibus_palette.dart';
import 'package:fibus/core/theme/fibus_theme.dart';
import 'package:fibus/core/widgets/fib_card.dart';
import 'package:fibus/services/route_service.dart';

/// Formats a time as `7:41` plus a lowercase `am`, timetable style.
({String clock, String meridiem}) splitTime(DateTime t) => (
      clock: DateFormat('h:mm').format(t),
      meridiem: DateFormat('a').format(t).toLowerCase(),
    );

/// `18 min`, `1 h 05 min`.
String formatDuration(Duration d) {
  final m = d.inMinutes.abs();
  if (m >= 60) return '${m ~/ 60} h ${(m % 60).toString().padLeft(2, '0')} min';
  return '$m min';
}

/// The answer Fibus exists to give: when to leave home. The one bright
/// moment of the dashboard — a large timetable figure and how it was made.
class DepartureCountdown extends StatelessWidget {
  const DepartureCountdown({
    super.key,
    required this.recommendation,
    this.stopName,
  });

  final DepartureRecommendation? recommendation;
  final String? stopName;

  @override
  Widget build(BuildContext context) {
    final c = context.fib;
    final t = context.type;
    final rec = recommendation;

    if (rec == null) {
      return FibCard(
        child: Text('Working out when you should leave', style: t.bodySmall),
      );
    }

    final leaveNow = rec.isLeaveNow;
    final leave = splitTime(rec.recommendedLeaveBy);
    final eta = splitTime(rec.busEta);
    final untilLeave = rec.recommendedLeaveBy.difference(DateTime.now());
    final rideMin = (rec.scooterDurationSeconds / 60).ceil();
    final bufferMin =
        ((rec.safetyMarginSeconds + 300) / 60).ceil(); // margin + 5 min at stop

    final String countdown;
    if (!leaveNow) {
      countdown = 'In ${formatDuration(untilLeave)}';
    } else if (untilLeave.inMinutes.abs() < 1) {
      countdown = 'Head out now';
    } else {
      countdown = 'You are ${formatDuration(untilLeave)} behind. Head out now';
    }

    return Semantics(
      liveRegion: leaveNow,
      label: leaveNow
          ? 'Leave now. $countdown'
          : 'Leave by ${leave.clock} ${leave.meridiem}. $countdown',
      child: ExcludeSemantics(
        child: FibCard(
          borderColor: leaveNow ? c.accent : null,
          padding: const EdgeInsets.fromLTRB(
              FibusSpace.s20, FibusSpace.s20, FibusSpace.s20, FibusSpace.s16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(leaveNow ? 'Leave now' : 'Leave by',
                  style: t.labelMedium?.copyWith(
                      color: leaveNow ? c.accentInk : c.textSecondary)),
              const SizedBox(height: FibusSpace.s4),
              Row(
                crossAxisAlignment: CrossAxisAlignment.baseline,
                textBaseline: TextBaseline.alphabetic,
                children: [
                  ClockFigure(leave.clock, size: 56),
                  const SizedBox(width: FibusSpace.s8),
                  Text(leave.meridiem,
                      style: FibusType.figure(context,
                          size: 20, color: c.textSecondary)),
                ],
              ),
              const SizedBox(height: FibusSpace.s8),
              Text(countdown,
                  style: t.bodyMedium?.copyWith(
                      color: leaveNow ? c.textPrimary : c.textSecondary)),
              const SizedBox(height: FibusSpace.s16),
              const Divider(),
              const SizedBox(height: FibusSpace.s12),
              Row(
                children: [
                  Expanded(
                    child: _Fact(
                      label: 'Bus at stop',
                      value: '${eta.clock} ${eta.meridiem}',
                    ),
                  ),
                  Expanded(child: _Fact(label: 'Scooter ride', value: '$rideMin min')),
                  Expanded(child: _Fact(label: 'Buffer', value: '$bufferMin min')),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Fact extends StatelessWidget {
  const _Fact({required this.label, required this.value});
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: context.type.labelSmall),
        const SizedBox(height: FibusSpace.s4),
        Text(value, style: FibusType.figure(context, size: 15)),
      ],
    );
  }
}
