import 'dart:async';
import 'package:flutter/material.dart';
import 'package:fibus/core/theme/app_colors.dart';

/// A compact, high-visibility GPS health telemetry bar for bus operators.
///
/// Displays real-time signal strength bars, horizontal accuracy in meters with
/// color-coded health tiers, fix frequency counter, and dynamic fix age counter.
class GpsHealthIndicator extends StatefulWidget {
  /// Horizontal accuracy in meters (lower is better).
  final double accuracy;

  /// Total count of valid GPS fixes received in this tracking session.
  final int fixCount;

  /// Timestamp of the latest GPS fix, or null if no fix yet received.
  final DateTime? lastFixTime;

  /// Whether active GPS sampling is in progress.
  final bool isTracking;

  const GpsHealthIndicator({
    super.key,
    required this.accuracy,
    required this.fixCount,
    this.lastFixTime,
    this.isTracking = true,
  });

  @override
  State<GpsHealthIndicator> createState() => _GpsHealthIndicatorState();
}

class _GpsHealthIndicatorState extends State<GpsHealthIndicator> {
  Timer? _tickerTimer;

  @override
  void initState() {
    super.initState();
    // 1-second refresh for the fix age timer
    _tickerTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted && widget.lastFixTime != null) {
        setState(() {});
      }
    });
  }

  @override
  void dispose() {
    _tickerTimer?.cancel();
    super.dispose();
  }

  Color _getAccuracyColor(double acc) {
    if (!widget.isTracking || widget.lastFixTime == null) {
      return AppColors.textMuted;
    }
    if (acc <= 10.0) return AppColors.success;
    if (acc <= 30.0) return AppColors.warning;
    return AppColors.error;
  }

  int _getSignalBars(double acc) {
    if (!widget.isTracking || widget.lastFixTime == null) return 0;
    if (acc <= 8.0) return 4;
    if (acc <= 20.0) return 3;
    if (acc <= 50.0) return 2;
    return 1;
  }

  String _formatFixAge() {
    if (!widget.isTracking || widget.lastFixTime == null) {
      return 'Waiting for GPS';
    }
    final seconds = DateTime.now().difference(widget.lastFixTime!).inSeconds;
    if (seconds < 2) return 'Just now';
    if (seconds < 60) return '${seconds}s ago';
    final minutes = seconds ~/ 60;
    return '${minutes}m ago';
  }

  @override
  Widget build(BuildContext context) {
    final accColor = _getAccuracyColor(widget.accuracy);
    final signalBars = _getSignalBars(widget.accuracy);
    final fixAgeText = _formatFixAge();

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: widget.isTracking
              ? accColor.withValues(alpha: 0.35)
              : AppColors.border,
          width: 1.2,
        ),
        boxShadow: [
          BoxShadow(
            color: widget.isTracking
                ? accColor.withValues(alpha: 0.12)
                : Colors.black26,
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          // 1. Signal strength icon with tiered bars
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildSignalBarsWidget(signalBars, accColor),
              const SizedBox(width: 8),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'GPS SIGNAL',
                    style: TextStyle(
                      color: AppColors.textMuted,
                      fontSize: 9,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.8,
                    ),
                  ),
                  Text(
                    widget.isTracking && widget.lastFixTime != null
                        ? '±${widget.accuracy.toStringAsFixed(1)} m'
                        : 'NO FIX',
                    style: TextStyle(
                      color: accColor,
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ],
          ),

          // Divider
          Container(
            height: 24,
            width: 1,
            color: AppColors.border,
          ),

          // 2. Last fix age
          Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'LAST FIX',
                style: TextStyle(
                  color: AppColors.textMuted,
                  fontSize: 9,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.8,
                ),
              ),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 6,
                    height: 6,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: accColor,
                    ),
                  ),
                  const SizedBox(width: 5),
                  Text(
                    fixAgeText,
                    style: TextStyle(
                      color: AppColors.textPrimary,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ],
          ),

          // Divider
          Container(
            height: 24,
            width: 1,
            color: AppColors.border,
          ),

          // 3. Total Fix Count
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'FIX COUNT',
                style: TextStyle(
                  color: AppColors.textMuted,
                  fontSize: 9,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.8,
                ),
              ),
              Text(
                '${widget.fixCount}',
                style: const TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  fontFeatures: [FontFeature.tabularFigures()],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSignalBarsWidget(int activeBars, Color activeColor) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: List.generate(4, (index) {
        final barHeight = 6.0 + (index * 4.0);
        final isActive = index < activeBars;
        return Container(
          width: 3.5,
          height: barHeight,
          margin: const EdgeInsets.symmetric(horizontal: 1.2),
          decoration: BoxDecoration(
            color: isActive ? activeColor : AppColors.surfaceHighlight,
            borderRadius: BorderRadius.circular(2),
          ),
        );
      }),
    );
  }
}
