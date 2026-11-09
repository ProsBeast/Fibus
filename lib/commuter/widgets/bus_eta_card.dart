import 'package:flutter/material.dart';
import 'package:fibus/commuter/widgets/departure_countdown.dart';
import 'package:fibus/commuter/widgets/route_strip.dart';
import 'package:fibus/core/theme/fibus_palette.dart';
import 'package:fibus/core/theme/fibus_theme.dart';
import 'package:fibus/core/widgets/fib_card.dart';
import 'package:fibus/core/widgets/status_badge.dart';
import 'package:fibus/models/bus_model.dart';
import 'package:fibus/models/live_bus.dart';
import 'package:fibus/models/route_model.dart';
import 'package:fibus/models/stop_model.dart';
import 'package:fibus/services/bus_eta_estimator.dart';

/// Where the bus is and when it reaches your stop, with the route strip
/// and an honest line about where the time comes from (FR-19, FR-27).
class BusEtaCard extends StatelessWidget {
  const BusEtaCard({
    super.key,
    required this.bus,
    required this.route,
    required this.stop,
    this.liveBus,
    this.busEta,
    this.etaStatus = LiveEtaStatus.noTracker,
    this.delayMinutes = 0,
    this.stopNames = const [],
    this.stopFractions = const [],
    this.busFraction,
  });

  final BusModel? bus;
  final RouteModel? route;
  final StopModel? stop;
  final LiveBus? liveBus;
  final DateTime? busEta;
  final LiveEtaStatus etaStatus;

  /// Live ETA minus timetable at the stop, in minutes (positive = late).
  final int delayMinutes;
  final List<String> stopNames;
  final List<double> stopFractions;
  final double? busFraction;

  TrackingStatus get _trackingStatus {
    switch (etaStatus) {
      case LiveEtaStatus.live:
        return TrackingStatus.live;
      case LiveEtaStatus.stale:
        return TrackingStatus.stale;
      case LiveEtaStatus.noTracker:
        return TrackingStatus.offline;
      default:
        return TrackingStatus.scheduled;
    }
  }

  String _source() {
    final age = liveBus?.ageSinceLastUpdate;
    switch (etaStatus) {
      case LiveEtaStatus.live:
        return age == null ? 'From live GPS' : 'From live GPS, ${age.inSeconds} s ago';
      case LiveEtaStatus.warmingUp:
        return 'Tracking just started. Using the timetable for now';
      case LiveEtaStatus.stale:
        return age == null
            ? 'GPS lost. Using the timetable'
            : 'GPS lost ${age.inMinutes} min ago. Using the timetable';
      case LiveEtaStatus.offRoute:
        return 'The bus is off its usual road. Using the timetable';
      case LiveEtaStatus.passedStop:
        return 'The bus has passed your stop';
      case LiveEtaStatus.noTracker:
        return 'Tracking has not started. Using the timetable';
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = context.fib;
    final t = context.type;
    final stopName = stop?.name.isNotEmpty == true ? stop!.name : 'your stop';
    final eta = busEta == null ? null : splitTime(busEta!);
    final until = busEta?.difference(DateTime.now());
    final boardingIndex =
        stop == null ? -1 : stopNames.indexWhere((n) => n == stop!.name);

    String? drift;
    if (etaStatus == LiveEtaStatus.live) {
      if (delayMinutes >= 5) drift = 'Running $delayMinutes min late vs timetable';
      if (delayMinutes <= -3) drift = 'Running ${-delayMinutes} min early vs timetable';
    }

    return FibCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  bus?.displayName.isNotEmpty == true ? bus!.displayName : 'Your bus',
                  style: t.titleSmall,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: FibusSpace.s12),
              StatusBadge(status: _trackingStatus),
            ],
          ),
          const SizedBox(height: FibusSpace.s16),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Reaches $stopName', style: t.labelMedium),
                    const SizedBox(height: FibusSpace.s4),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.baseline,
                      textBaseline: TextBaseline.alphabetic,
                      children: [
                        Text(eta?.clock ?? '--:--',
                            style: FibusType.figure(context,
                                size: 28, weight: FontWeight.w500)),
                        if (eta != null) ...[
                          const SizedBox(width: FibusSpace.s4),
                          Text(eta.meridiem,
                              style: FibusType.figure(context,
                                  size: 14, color: c.textSecondary)),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
              if (until != null)
                Text(
                  until.isNegative ? 'Due now' : 'in ${formatDuration(until)}',
                  style: t.bodySmall,
                ),
            ],
          ),
          if (boardingIndex >= 0 && stopFractions.length == stopNames.length) ...[
            const SizedBox(height: FibusSpace.s16),
            RouteStrip(
              stopNames: stopNames,
              stopFractions: stopFractions,
              boardingIndex: boardingIndex,
              busFraction: busFraction,
              busIsLive: etaStatus == LiveEtaStatus.live,
            ),
          ],
          const SizedBox(height: FibusSpace.s12),
          if (drift != null)
            Padding(
              padding: const EdgeInsets.only(bottom: FibusSpace.s4),
              child: Text(drift, style: t.bodySmall?.copyWith(color: c.accentInk)),
            ),
          Text(_source(), style: t.labelSmall),
        ],
      ),
    );
  }
}
