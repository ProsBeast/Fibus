import 'dart:async';
import 'package:flutter/material.dart';
import 'package:fibus/core/theme/fibus_palette.dart';
import 'package:fibus/core/theme/fibus_theme.dart';

/// GPS quality in plain words with the three numbers behind it:
/// accuracy, time since the last fix and how many fixes were sent.
class GpsHealthIndicator extends StatefulWidget {
  const GpsHealthIndicator({
    super.key,
    required this.accuracy,
    required this.fixCount,
    required this.lastFixTime,
    required this.isTracking,
  });

  /// Horizontal accuracy in metres of the latest fix.
  final double accuracy;
  final int fixCount;
  final DateTime? lastFixTime;
  final bool isTracking;

  @override
  State<GpsHealthIndicator> createState() => _GpsHealthIndicatorState();
}

class _GpsHealthIndicatorState extends State<GpsHealthIndicator> {
  Timer? _ticker;

  @override
  void initState() {
    super.initState();
    // Refresh "last fix" age once a second.
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _ticker?.cancel();
    super.dispose();
  }

  String _quality(int? age) {
    if (!widget.isTracking || widget.lastFixTime == null) return 'No GPS yet';
    if (age != null && age >= 60) return 'GPS lost';
    if (widget.accuracy <= 20) return 'GPS good';
    if (widget.accuracy <= 50) return 'GPS fair';
    return 'GPS weak, move near a window';
  }

  @override
  Widget build(BuildContext context) {
    final c = context.fib;
    final age = widget.lastFixTime == null
        ? null
        : DateTime.now().difference(widget.lastFixTime!).inSeconds;
    final bad = age == null || age >= 60 || widget.accuracy > 50;

    return Container(
      padding: const EdgeInsets.all(FibusSpace.s16),
      decoration: BoxDecoration(
        color: c.surface,
        borderRadius: BorderRadius.circular(FibusSpace.radiusCard),
        border: Border.all(color: c.hairline),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(_quality(age),
              style: context.type.titleSmall
                  ?.copyWith(color: bad && widget.isTracking ? c.accentInk : null)),
          const SizedBox(height: FibusSpace.s12),
          Row(
            children: [
              Expanded(
                child: _Meta(
                    label: 'Accuracy',
                    value: widget.lastFixTime == null
                        ? '--'
                        : '±${widget.accuracy.toStringAsFixed(0)} m'),
              ),
              Expanded(
                child: _Meta(label: 'Last fix', value: age == null ? '--' : '$age s ago'),
              ),
              Expanded(child: _Meta(label: 'Sent', value: '${widget.fixCount}')),
            ],
          ),
        ],
      ),
    );
  }
}

class _Meta extends StatelessWidget {
  const _Meta({required this.label, required this.value});
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: context.type.labelSmall),
        const SizedBox(height: FibusSpace.s4),
        Text(value, style: FibusType.figure(context, size: 14)),
      ],
    );
  }
}
