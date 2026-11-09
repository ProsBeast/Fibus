import 'package:flutter/material.dart';
import 'package:fibus/core/theme/fibus_palette.dart';

/// A plain raised surface: card colour, a hairline, 16 px corners.
/// Depth comes from the surface step, never from blur, glow or gradient.
class FibCard extends StatelessWidget {
  const FibCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(FibusSpace.s20),
    this.onTap,
    this.color,
    this.borderColor,
    this.radius = FibusSpace.radiusCard,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final VoidCallback? onTap;
  final Color? color;
  final Color? borderColor;
  final double radius;

  @override
  Widget build(BuildContext context) {
    final c = context.fib;
    final shape = RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(radius),
      side: BorderSide(color: borderColor ?? c.hairline),
    );
    return Material(
      color: color ?? c.surface,
      shape: shape,
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        highlightColor: c.raised,
        splashColor: c.hairline,
        child: Padding(padding: padding, child: child),
      ),
    );
  }
}

/// A quiet sentence-case label above a group, 24 above and 8 below by
/// convention of the caller.
class SectionLabel extends StatelessWidget {
  const SectionLabel(this.text, {super.key, this.trailing});

  final String text;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final label = Text(text, style: context.type.labelMedium);
    if (trailing == null) return label;
    return Row(children: [Expanded(child: label), trailing!]);
  }
}

/// A label/value row used in detail lists: label left, figure right.
class DetailRow extends StatelessWidget {
  const DetailRow({
    super.key,
    required this.label,
    required this.value,
    this.icon,
    this.valueColor,
    this.mono = false,
  });

  final String label;
  final String value;
  final IconData? icon;
  final Color? valueColor;
  final bool mono;

  @override
  Widget build(BuildContext context) {
    final c = context.fib;
    final valueStyle = mono
        ? TextStyle(
            fontFamily: 'JetBrainsMono',
            fontSize: 14,
            color: valueColor ?? c.textPrimary,
            fontFeatures: const [FontFeature.tabularFigures()],
          )
        : context.type.bodyMedium?.copyWith(color: valueColor ?? c.textPrimary);
    return SizedBox(
      height: 44,
      child: Row(
        children: [
          if (icon != null) ...[
            SizedBox(width: 20, child: Icon(icon, size: 18, color: c.textMuted)),
            const SizedBox(width: FibusSpace.s12),
          ],
          Expanded(
            child: Text(label,
                style: context.type.bodyMedium?.copyWith(color: c.textSecondary)),
          ),
          const SizedBox(width: FibusSpace.s12),
          Flexible(
            child: Text(value,
                style: valueStyle,
                textAlign: TextAlign.end,
                maxLines: 1,
                overflow: TextOverflow.ellipsis),
          ),
        ],
      ),
    );
  }
}
