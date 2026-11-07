import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:fibus/core/theme/app_colors.dart';
import 'package:fibus/core/widgets/glass_card.dart';
import 'package:fibus/services/route_service.dart';

/// Departure recommendation card highlighting when to leave home, dynamic
/// color shift (Green -> Amber -> Red), scooter travel time, and safety margin.
class DepartureCountdown extends StatelessWidget {
  const DepartureCountdown({
    super.key,
    required this.recommendation,
  });

  final DepartureRecommendation? recommendation;

  Color _getUrgencyColor(int secondsRemaining) {
    if (secondsRemaining <= 0) {
      return AppColors.statusOffline; // Red (Leave Now!)
    } else if (secondsRemaining <= 180) {
      return AppColors.statusOffline; // Red (< 3 min)
    } else if (secondsRemaining <= 600) {
      return AppColors.statusStale; // Amber (3-10 min)
    } else {
      return AppColors.statusLive; // Green (> 10 min)
    }
  }

  String _formatRemainingTime(int secondsRemaining) {
    if (secondsRemaining <= 0) {
      final pastSec = secondsRemaining.abs();
      final mins = pastSec ~/ 60;
      final secs = pastSec % 60;
      return 'Overdue by ${mins}m ${secs}s';
    }

    final mins = secondsRemaining ~/ 60;
    final secs = secondsRemaining % 60;

    if (mins >= 60) {
      final hours = mins ~/ 60;
      final remMins = mins % 60;
      return '${hours}h ${remMins}m';
    }

    return '${mins.toString().padLeft(2, '0')}m ${secs.toString().padLeft(2, '0')}s';
  }

  @override
  Widget build(BuildContext context) {
    if (recommendation == null) {
      return const GlassCard(
        borderRadius: 22,
        padding: EdgeInsets.all(24),
        child: Center(
          child: Text(
            'Calculating departure recommendation...',
            style: TextStyle(color: AppColors.textSecondary),
          ),
        ),
      );
    }

    final leaveTime = recommendation!.recommendedLeaveBy;
    final secondsRemaining = recommendation!.secondsUntilLeave;
    final urgencyColor = _getUrgencyColor(secondsRemaining);
    final isLeaveNow = recommendation!.isLeaveNow;

    final leaveTimeStr = DateFormat('hh:mm a').format(leaveTime);
    final targetArrivalStr =
        DateFormat('hh:mm a').format(recommendation!.targetStopArrival);

    final scooterMinutes = (recommendation!.scooterDurationSeconds / 60).ceil();
    final safetyMarginMinutes =
        (recommendation!.safetyMarginSeconds / 60).ceil();

    return GlassCard(
      borderRadius: 22,
      padding: const EdgeInsets.all(22),
      borderColor: urgencyColor.withValues(alpha: 0.35),
      gradient: LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [
          urgencyColor.withValues(alpha: 0.12),
          AppColors.surface.withValues(alpha: 0.8),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header Tag & Status
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: urgencyColor.withValues(alpha: 0.2),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      Icons.moped_rounded,
                      color: urgencyColor,
                      size: 16,
                    ),
                  ),
                  const SizedBox(width: 8),
                  const Text(
                    'RECOMMENDED DEPARTURE',
                    style: TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.8,
                    ),
                  ),
                ],
              ),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: urgencyColor.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: urgencyColor.withValues(alpha: 0.5),
                  ),
                ),
                child: Text(
                  isLeaveNow ? 'LEAVE NOW' : 'ON SCHEDULE',
                  style: TextStyle(
                    color: urgencyColor,
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.5,
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 18),

          // Core Departure Milestone: "Leave by HH:mm"
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              const Text(
                'Leave by ',
                style: TextStyle(
                  color: AppColors.textSecondary,
                  fontSize: 20,
                  fontWeight: FontWeight.w500,
                ),
              ),
              Text(
                leaveTimeStr,
                style: TextStyle(
                  color: urgencyColor,
                  fontSize: 32,
                  fontWeight: FontWeight.w900,
                  letterSpacing: -0.5,
                ),
              ),
            ],
          ),

          const SizedBox(height: 8),

          // Live Countdown Timer
          Row(
            children: [
              Icon(
                Icons.timer_outlined,
                color: urgencyColor,
                size: 18,
              ),
              const SizedBox(width: 6),
              Text(
                isLeaveNow
                    ? 'Time to leave home immediately!'
                    : '${_formatRemainingTime(secondsRemaining)} to departure',
                style: TextStyle(
                  color: urgencyColor,
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  fontFeatures: const [FontFeature.tabularFigures()],
                ),
              ),
            ],
          ),

          const SizedBox(height: 18),
          const Divider(color: AppColors.divider),
          const SizedBox(height: 14),

          // Journey Breakdown Rows
          Row(
            children: [
              const Icon(
                Icons.two_wheeler_rounded,
                size: 15,
                color: AppColors.accent,
              ),
              const SizedBox(width: 8),
              const Text(
                'Scooter Travel Time:',
                style: TextStyle(
                  color: AppColors.textSecondary,
                  fontSize: 13,
                ),
              ),
              const Spacer(),
              Text(
                '~$scooterMinutes min',
                style: const TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),

          const SizedBox(height: 8),

          Row(
            children: [
              const Icon(
                Icons.shield_outlined,
                size: 15,
                color: AppColors.primaryLight,
              ),
              const SizedBox(width: 8),
              const Text(
                'Safety Margin & Buffer:',
                style: TextStyle(
                  color: AppColors.textSecondary,
                  fontSize: 13,
                ),
              ),
              const Spacer(),
              Text(
                '+$safetyMarginMinutes min (+5m at stop)',
                style: const TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),

          const SizedBox(height: 8),

          Row(
            children: [
              const Icon(
                Icons.flag_outlined,
                size: 15,
                color: AppColors.statusLive,
              ),
              const SizedBox(width: 8),
              const Text(
                'Target Stop Arrival:',
                style: TextStyle(
                  color: AppColors.textSecondary,
                  fontSize: 13,
                ),
              ),
              const Spacer(),
              Text(
                targetArrivalStr,
                style: const TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
