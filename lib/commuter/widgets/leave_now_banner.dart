import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:fibus/core/theme/app_colors.dart';

/// Full-width pulsing emergency departure banner displayed when now >= recommendedLeaveBy.
class LeaveNowBanner extends StatefulWidget {
  const LeaveNowBanner({
    super.key,
    required this.targetArrival,
    this.busName = 'Bus',
    this.onDismiss,
  });

  final DateTime? targetArrival;
  final String busName;
  final VoidCallback? onDismiss;

  @override
  State<LeaveNowBanner> createState() => _LeaveNowBannerState();
}

class _LeaveNowBannerState extends State<LeaveNowBanner>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulseController;
  late final Animation<double> _glowAnimation;
  bool _isDismissed = false;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..repeat(reverse: true);

    _glowAnimation = Tween<double>(begin: 0.85, end: 1.0).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_isDismissed) return const SizedBox.shrink();

    final arrivalTimeStr = widget.targetArrival != null
        ? DateFormat('hh:mm a').format(widget.targetArrival!)
        : 'soon';

    return AnimatedBuilder(
      animation: _glowAnimation,
      builder: (context, child) {
        return Container(
          width: double.infinity,
          margin: const EdgeInsets.only(bottom: 16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            gradient: LinearGradient(
              colors: [
                const Color(0xFFD50000).withValues(alpha: _glowAnimation.value),
                const Color(0xFFFF1744).withValues(alpha: _glowAnimation.value * 0.9),
                const Color(0xFFB71C1C).withValues(alpha: _glowAnimation.value),
              ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            boxShadow: [
              BoxShadow(
                color: AppColors.statusOffline.withValues(alpha: 0.5 * _glowAnimation.value),
                blurRadius: 18 * _glowAnimation.value,
                spreadRadius: 2,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Material(
            color: Colors.transparent,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.2),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.warning_rounded,
                      color: Colors.white,
                      size: 24,
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          '🚨 LEAVE NOW!',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 0.5,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'Start your scooter journey now to catch ${widget.busName} by $arrivalTimeStr.',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 13,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (widget.onDismiss != null)
                    IconButton(
                      icon: const Icon(Icons.close_rounded, color: Colors.white70, size: 20),
                      onPressed: () {
                        setState(() => _isDismissed = true);
                        widget.onDismiss?.call();
                      },
                    ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
