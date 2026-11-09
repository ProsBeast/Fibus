import 'package:flutter/material.dart';
import 'package:fibus/core/theme/fibus_palette.dart';

/// The product name with a flat mark: a marigold tile holding a bus glyph.
class FibusWordmark extends StatelessWidget {
  const FibusWordmark({super.key, this.suffix});

  /// Optional second word, e.g. "Tracker".
  final String? suffix;

  @override
  Widget build(BuildContext context) {
    final c = context.fib;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 28,
          height: 28,
          decoration: BoxDecoration(
            color: c.accent,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(Icons.directions_bus_outlined, size: 18, color: c.onAccent),
        ),
        const SizedBox(width: FibusSpace.s8),
        Text('Fibus',
            style: context.type.titleMedium?.copyWith(fontWeight: FontWeight.w600)),
        if (suffix != null) ...[
          const SizedBox(width: FibusSpace.s4),
          Text(suffix!,
              style: context.type.titleMedium?.copyWith(color: c.textSecondary)),
        ],
      ],
    );
  }
}
