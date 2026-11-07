import 'package:flutter/material.dart';
import 'package:fibus/core/theme/app_colors.dart';

/// Enumeration of possible bus tracking statuses.
enum TrackingStatus {
  /// Actively transmitting real-time GPS fixes within acceptable threshold.
  live,

  /// Location fix is older than the stale threshold but still active.
  stale,

  /// No live broadcast; arrival estimates derived from timetable schedule.
  scheduled,

  /// Bus service is currently inactive or completed for the day.
  offline;

  /// Helper parser from backend/RTDB status string.
  static TrackingStatus fromString(String? value) {
    if (value == null) return TrackingStatus.offline;
    switch (value.toLowerCase().trim()) {
      case 'live':
      case 'tracking':
      case 'active':
        return TrackingStatus.live;
      case 'stale':
        return TrackingStatus.stale;
      case 'schedule':
      case 'scheduled':
        return TrackingStatus.scheduled;
      case 'offline':
      case 'ended':
      case 'inactive':
      default:
        return TrackingStatus.offline;
    }
  }

  /// User-friendly status label.
  String get label {
    switch (this) {
      case TrackingStatus.live:
        return 'LIVE';
      case TrackingStatus.stale:
        return 'STALE';
      case TrackingStatus.scheduled:
        return 'SCHEDULE';
      case TrackingStatus.offline:
        return 'OFFLINE';
    }
  }

  /// Primary color associated with status.
  Color get color {
    switch (this) {
      case TrackingStatus.live:
        return AppColors.statusLive;
      case TrackingStatus.stale:
        return AppColors.statusStale;
      case TrackingStatus.scheduled:
        return AppColors.statusScheduled;
      case TrackingStatus.offline:
        return AppColors.statusOffline;
    }
  }

  /// Background container glow color.
  Color get glowColor {
    switch (this) {
      case TrackingStatus.live:
        return AppColors.statusLiveGlow;
      case TrackingStatus.stale:
        return AppColors.statusStaleGlow;
      case TrackingStatus.scheduled:
        return AppColors.statusScheduledGlow;
      case TrackingStatus.offline:
        return AppColors.statusOfflineGlow;
    }
  }
}

/// A pill-shaped status indicator badge with a pulsing beacon animation for live tracking.
class StatusBadge extends StatefulWidget {
  /// The current tracking status.
  final TrackingStatus status;

  /// Optional custom label text overriding the default enum label.
  final String? customLabel;

  /// Whether to render a compact version (dot only without text).
  final bool compact;

  /// Optional padding override.
  final EdgeInsetsGeometry? padding;

  const StatusBadge({
    super.key,
    required this.status,
    this.customLabel,
    this.compact = false,
    this.padding,
  });

  /// Convenience constructor from raw string.
  factory StatusBadge.fromString({
    Key? key,
    required String? statusString,
    String? customLabel,
    bool compact = false,
    EdgeInsetsGeometry? padding,
  }) {
    return StatusBadge(
      key: key,
      status: TrackingStatus.fromString(statusString),
      customLabel: customLabel,
      compact: compact,
      padding: padding,
    );
  }

  /// Convenience factory for Live status.
  factory StatusBadge.live({String? label, bool compact = false}) =>
      StatusBadge(
        status: TrackingStatus.live,
        customLabel: label,
        compact: compact,
      );

  /// Convenience factory for Stale status.
  factory StatusBadge.stale({String? label, bool compact = false}) =>
      StatusBadge(
        status: TrackingStatus.stale,
        customLabel: label,
        compact: compact,
      );

  /// Convenience factory for Scheduled status.
  factory StatusBadge.scheduled({String? label, bool compact = false}) =>
      StatusBadge(
        status: TrackingStatus.scheduled,
        customLabel: label,
        compact: compact,
      );

  /// Convenience factory for Offline status.
  factory StatusBadge.offline({String? label, bool compact = false}) =>
      StatusBadge(
        status: TrackingStatus.offline,
        customLabel: label,
        compact: compact,
      );

  @override
  State<StatusBadge> createState() => _StatusBadgeState();
}

class _StatusBadgeState extends State<StatusBadge>
    with SingleTickerProviderStateMixin {
  late AnimationController _pulseController;
  late Animation<double> _scaleAnimation;
  late Animation<double> _opacityAnimation;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    );

    _scaleAnimation = Tween<double>(begin: 1.0, end: 2.2).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeOut),
    );

    _opacityAnimation = Tween<double>(begin: 0.8, end: 0.0).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeOut),
    );

    if (widget.status == TrackingStatus.live) {
      _pulseController.repeat();
    }
  }

  @override
  void didUpdateWidget(covariant StatusBadge oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.status == TrackingStatus.live && !_pulseController.isAnimating) {
      _pulseController.repeat();
    } else if (widget.status != TrackingStatus.live && _pulseController.isAnimating) {
      _pulseController.stop();
      _pulseController.reset();
    }
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final statusColor = widget.status.color;
    final glowColor = widget.status.glowColor;
    final label = widget.customLabel ?? widget.status.label;

    if (widget.compact) {
      return _buildBeaconDot(statusColor);
    }

    return Container(
      padding: widget.padding ??
          const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: glowColor,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: statusColor.withAlpha(120), width: 1),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _buildBeaconDot(statusColor),
          const SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(
              color: statusColor,
              fontSize: 11,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.8,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBeaconDot(Color statusColor) {
    final isLive = widget.status == TrackingStatus.live;

    return SizedBox(
      width: 12,
      height: 12,
      child: Stack(
        alignment: Alignment.center,
        children: [
          if (isLive)
            AnimatedBuilder(
              animation: _pulseController,
              builder: (context, child) {
                return Transform.scale(
                  scale: _scaleAnimation.value,
                  child: Container(
                    width: 7,
                    height: 7,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: statusColor.withAlpha(
                        (_opacityAnimation.value * 255).clamp(0, 255).toInt(),
                      ),
                    ),
                  ),
                );
              },
            ),
          Container(
            width: 7,
            height: 7,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: statusColor,
              boxShadow: [
                BoxShadow(
                  color: statusColor.withAlpha(150),
                  blurRadius: 4,
                  spreadRadius: 1,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
