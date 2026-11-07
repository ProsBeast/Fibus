import 'package:flutter/material.dart';
import 'package:fibus/core/theme/app_colors.dart';
import 'package:fibus/models/live_bus_model.dart';

/// Card showing current tracking telemetry and session state for a specific bus.
///
/// Features an animated pulsing border when actively tracking, amber when stale,
/// and subtle slate when inactive. Displays current operator ownership and session info.
class TrackingStatusCard extends StatefulWidget {
  /// Live telemetry snapshot of the bus, or null if idle/not loaded.
  final LiveBusModel? liveBus;

  /// Custom operator label or name to show when someone is tracking.
  final String? operatorName;

  /// Optional card title override (e.g. "CURRENT TELEMETRY STATUS").
  final String? title;

  /// Optional callback when user taps takeover or view action.
  final VoidCallback? onTakeoverTap;

  const TrackingStatusCard({
    super.key,
    required this.liveBus,
    this.operatorName,
    this.title,
    this.onTakeoverTap,
  });

  @override
  State<TrackingStatusCard> createState() => _TrackingStatusCardState();
}

class _TrackingStatusCardState extends State<TrackingStatusCard>
    with SingleTickerProviderStateMixin {
  late AnimationController _pulseController;
  late Animation<double> _glowAnimation;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1600),
    );

    _glowAnimation = Tween<double>(begin: 0.25, end: 0.85).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );

    _updateAnimation();
  }

  @override
  void didUpdateWidget(covariant TrackingStatusCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.liveBus?.isLive != widget.liveBus?.isLive) {
      _updateAnimation();
    }
  }

  void _updateAnimation() {
    final isLive = widget.liveBus?.isLive ?? false;
    if (isLive) {
      if (!_pulseController.isAnimating) {
        _pulseController.repeat(reverse: true);
      }
    } else {
      _pulseController.stop();
      _pulseController.reset();
    }
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  Color _getStatusColor() {
    final live = widget.liveBus;
    if (live == null || live.isOffline) {
      return AppColors.textMuted;
    }
    if (live.isLive) {
      return AppColors.statusLive;
    }
    if (live.isStale) {
      return AppColors.statusStale;
    }
    return AppColors.textMuted;
  }

  String _getStatusTitle() {
    final live = widget.liveBus;
    if (live == null || live.isOffline) {
      return 'NO ACTIVE BROADCAST';
    }
    if (live.isLive) {
      return 'BROADCASTING LIVE';
    }
    if (live.isStale) {
      return 'FEED STALE / INTERRUPTED';
    }
    return 'IDLE';
  }

  IconData _getStatusIcon() {
    final live = widget.liveBus;
    if (live == null || live.isOffline) {
      return Icons.sensors_off_rounded;
    }
    if (live.isLive) {
      return Icons.sensors_rounded;
    }
    if (live.isStale) {
      return Icons.warning_amber_rounded;
    }
    return Icons.radio_button_unchecked;
  }

  @override
  Widget build(BuildContext context) {
    final statusColor = _getStatusColor();
    final statusText = _getStatusTitle();
    final statusIcon = _getStatusIcon();
    final live = widget.liveBus;
    final isLive = live?.isLive ?? false;
    final isStale = live?.isStale ?? false;

    return AnimatedBuilder(
      animation: _pulseController,
      builder: (context, child) {
        final borderAlpha = isLive
            ? (_glowAnimation.value * 255).clamp(60, 255).toInt()
            : (isStale ? 180 : 50);

        return Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: statusColor.withAlpha(borderAlpha),
              width: isLive ? 1.8 : 1.2,
            ),
            boxShadow: [
              BoxShadow(
                color: statusColor.withAlpha(
                  isLive ? (_glowAnimation.value * 50).toInt() : 10,
                ),
                blurRadius: isLive ? 16 : 8,
                spreadRadius: isLive ? 1 : 0,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: child,
        );
      },
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          // Header Row
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: statusColor.withValues(alpha: 0.15),
                  shape: BoxShape.circle,
                ),
                child: Icon(statusIcon, color: statusColor, size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.title ?? 'TRACKING STATUS',
                      style: const TextStyle(
                        color: AppColors.textMuted,
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.8,
                      ),
                    ),
                    Text(
                      statusText,
                      style: TextStyle(
                        color: statusColor,
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.2,
                      ),
                    ),
                  ],
                ),
              ),
              if (isStale && widget.onTakeoverTap != null)
                TextButton.icon(
                  onPressed: widget.onTakeoverTap,
                  style: TextButton.styleFrom(
                    backgroundColor: AppColors.warning.withValues(alpha: 0.15),
                    foregroundColor: AppColors.warning,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 6,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                      side: BorderSide(
                        color: AppColors.warning.withValues(alpha: 0.4),
                      ),
                    ),
                  ),
                  icon: const Icon(Icons.swap_horiz_rounded, size: 16),
                  label: const Text(
                    'Takeover',
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
                  ),
                ),
            ],
          ),

          const SizedBox(height: 14),
          const Divider(height: 1, color: AppColors.border),
          const SizedBox(height: 12),

          // Details Grid
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              // Session Generation
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'SESSION GEN',
                    style: TextStyle(
                      color: AppColors.textMuted,
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    live != null && live.sessionGeneration > 0
                        ? '#${live.sessionGeneration}'
                        : 'None',
                    style: const TextStyle(
                      color: AppColors.textPrimary,
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),

              // Active Operator
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'OPERATOR',
                    style: TextStyle(
                      color: AppColors.textMuted,
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    widget.operatorName ??
                        (live != null && live.operatorUid.isNotEmpty
                            ? 'Operator (${live.operatorUid.substring(0, (live.operatorUid.length > 5 ? 5 : live.operatorUid.length))}...)'
                            : 'Unassigned'),
                    style: const TextStyle(
                      color: AppColors.textPrimary,
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),

              // Speed / Movement
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  const Text(
                    'SPEED',
                    style: TextStyle(
                      color: AppColors.textMuted,
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    live != null && isLive
                        ? '${(live.speed * 3.6).toStringAsFixed(0)} km/h'
                        : '0 km/h',
                    style: TextStyle(
                      color: isLive ? AppColors.textPrimary : AppColors.textMuted,
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }
}
