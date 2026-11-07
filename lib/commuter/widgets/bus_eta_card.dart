import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:fibus/core/theme/app_colors.dart';
import 'package:fibus/core/widgets/glass_card.dart';
import 'package:fibus/core/widgets/status_badge.dart';
import 'package:fibus/models/bus_model.dart';
import 'package:fibus/models/live_bus.dart';
import 'package:fibus/models/route_model.dart';
import 'package:fibus/models/stop_model.dart';
import 'package:fibus/services/bus_eta_estimator.dart';

/// Glassmorphism card displaying real-time or scheduled bus arrival telemetry,
/// countdown, health status badge, and stop details.
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
  });

  final BusModel? bus;
  final RouteModel? route;
  final StopModel? stop;
  final LiveBus? liveBus;
  final DateTime? busEta;

  /// Quality of the live ETA (live, warming up, stale, off route, ...).
  final LiveEtaStatus etaStatus;

  /// Live ETA minus timetable at the stop, in minutes (positive = late).
  final int delayMinutes;

  TrackingStatus get _trackingStatus {
    switch (etaStatus) {
      case LiveEtaStatus.live:
        return TrackingStatus.live;
      case LiveEtaStatus.stale:
        return TrackingStatus.stale;
      default:
        return TrackingStatus.scheduled;
    }
  }

  String _formatEtaCountdown() {
    if (busEta == null) return '--:--';
    final difference = busEta!.difference(DateTime.now());

    if (difference.isNegative) {
      return 'Arrived';
    }

    final totalMinutes = difference.inMinutes;
    final remainingSeconds = difference.inSeconds % 60;

    if (totalMinutes >= 60) {
      final hours = totalMinutes ~/ 60;
      final mins = totalMinutes % 60;
      return '${hours}h ${mins}m';
    }

    return '${totalMinutes.toString().padLeft(2, '0')}:${remainingSeconds.toString().padLeft(2, '0')}';
  }

  String _formatLastUpdated() {
    final age = liveBus?.ageSinceLastUpdate;
    switch (etaStatus) {
      case LiveEtaStatus.live:
        return age == null ? 'Live' : 'Live · ${age.inSeconds}s ago';
      case LiveEtaStatus.warmingUp:
        return 'Live warming up · timetable';
      case LiveEtaStatus.stale:
        return age == null
            ? 'GPS lost · timetable'
            : 'GPS lost ${age.inMinutes}m ago · timetable';
      case LiveEtaStatus.offRoute:
        return 'Bus off route · timetable';
      case LiveEtaStatus.passedStop:
        return 'Bus has passed your stop';
      case LiveEtaStatus.noTracker:
        return 'Not tracking yet · timetable';
    }
  }

  @override
  Widget build(BuildContext context) {
    final busTitle = bus?.displayName.isNotEmpty == true
        ? bus!.displayName
        : 'Assigned Bus';

    final routeTitle = route?.name.isNotEmpty == true
        ? route!.name
        : 'Campus Route';

    final stopTitle = stop?.name.isNotEmpty == true
        ? stop!.name
        : 'Boarding Stop';

    final etaTimeString = busEta != null
        ? DateFormat('hh:mm a').format(busEta!)
        : (stop?.scheduledArrivalLocalTime ?? '07:50 AM');

    return GlassCard(
      borderRadius: 22,
      padding: const EdgeInsets.all(22),
      gradient: LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [
          AppColors.surfaceVariant.withValues(alpha: 0.85),
          AppColors.surface.withValues(alpha: 0.70),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header: Bus Name, Route & Status Badge
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(
                          Icons.directions_bus_rounded,
                          color: AppColors.primaryLight,
                          size: 20,
                        ),
                        const SizedBox(width: 8),
                        Flexible(
                          child: Text(
                            busTitle,
                            style: const TextStyle(
                              color: AppColors.textPrimary,
                              fontSize: 18,
                              fontWeight: FontWeight.w700,
                              letterSpacing: -0.3,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      routeTitle,
                      style: const TextStyle(
                        color: AppColors.textSecondary,
                        fontSize: 13,
                        fontWeight: FontWeight.w400,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              StatusBadge(status: _trackingStatus),
            ],
          ),

          const SizedBox(height: 20),

          // Main Center Stage: ETA Countdown & Target Arrival
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            decoration: BoxDecoration(
              color: AppColors.background.withValues(alpha: 0.5),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: AppColors.glassBorder.withValues(alpha: 0.4),
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'ESTIMATED ARRIVAL',
                      style: TextStyle(
                        color: AppColors.textTertiary,
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.8,
                      ),
                    ),
                    const SizedBox(height: 4),
                    AnimatedSwitcher(
                      duration: const Duration(milliseconds: 300),
                      transitionBuilder: (child, animation) =>
                          FadeTransition(opacity: animation, child: child),
                      child: Text(
                        _formatEtaCountdown(),
                        key: ValueKey(_formatEtaCountdown()),
                        style: const TextStyle(
                          color: AppColors.textPrimary,
                          fontSize: 32,
                          fontWeight: FontWeight.w800,
                          letterSpacing: -0.5,
                          fontFeatures: [FontFeature.tabularFigures()],
                        ),
                      ),
                    ),
                  ],
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    const Text(
                      'ETA AT STOP',
                      style: TextStyle(
                        color: AppColors.textTertiary,
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.8,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      etaTimeString,
                      style: const TextStyle(
                        color: AppColors.accent,
                        fontSize: 20,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          const SizedBox(height: 16),

          // Subtitle / Location & Refresh indicator
          Row(
            children: [
              const Icon(
                Icons.location_on_outlined,
                color: AppColors.primaryLight,
                size: 16,
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  'Arriving at $stopTitle',
                  style: const TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              Text(
                _formatLastUpdated(),
                style: const TextStyle(
                  color: AppColors.textTertiary,
                  fontSize: 11,
                ),
              ),
            ],
          ),

          // Significant delay notification bar if delayed >= 5 min
          if (etaStatus == LiveEtaStatus.live && delayMinutes >= 5) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: AppColors.warning.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: AppColors.warning.withValues(alpha: 0.4),
                ),
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.warning_amber_rounded,
                    color: AppColors.warning,
                    size: 16,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Bus running $delayMinutes min late. Departure updated.',
                      style: const TextStyle(
                        color: AppColors.warning,
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}
