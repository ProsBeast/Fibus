import 'package:flutter/material.dart';
import 'package:fibus/core/theme/fibus_palette.dart';

/// An error message with an optional retry, full-page or as a compact card.
class ErrorDisplay extends StatelessWidget {
  const ErrorDisplay({
    super.key,
    required this.message,
    this.title,
    this.icon,
    this.onRetry,
    this.retryLabel = 'Try again',
    this.onSecondaryAction,
    this.secondaryActionLabel,
    this.compact = false,
  });

  final String message;
  final String? title;
  final IconData? icon;
  final VoidCallback? onRetry;
  final String retryLabel;
  final VoidCallback? onSecondaryAction;
  final String? secondaryActionLabel;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final c = context.fib;
    final t = context.type;

    if (compact) {
      return Container(
        padding: const EdgeInsets.all(FibusSpace.s16),
        decoration: BoxDecoration(
          color: c.negativeSoft,
          borderRadius: BorderRadius.circular(FibusSpace.radiusCard),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon ?? Icons.error_outline, size: 18, color: c.negative),
            const SizedBox(width: FibusSpace.s12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (title != null) Text(title!, style: t.titleSmall),
                  Text(message, style: t.bodySmall),
                  if (onRetry != null)
                    Padding(
                      padding: const EdgeInsets.only(top: FibusSpace.s8),
                      child: TextButton(
                        onPressed: onRetry,
                        style: TextButton.styleFrom(
                          padding: EdgeInsets.zero,
                          minimumSize: const Size(0, 32),
                        ),
                        child: Text(retryLabel),
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      );
    }

    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(FibusSpace.s32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon ?? Icons.error_outline, size: 28, color: c.textMuted),
            const SizedBox(height: FibusSpace.s16),
            Text(title ?? 'Something went wrong',
                style: t.titleMedium, textAlign: TextAlign.center),
            const SizedBox(height: FibusSpace.s8),
            Text(message,
                style: t.bodyMedium?.copyWith(color: c.textSecondary),
                textAlign: TextAlign.center),
            if (onRetry != null) ...[
              const SizedBox(height: FibusSpace.s24),
              OutlinedButton(onPressed: onRetry, child: Text(retryLabel)),
            ],
            if (onSecondaryAction != null && secondaryActionLabel != null) ...[
              const SizedBox(height: FibusSpace.s8),
              TextButton(
                  onPressed: onSecondaryAction,
                  child: Text(secondaryActionLabel!)),
            ],
          ],
        ),
      ),
    );
  }
}
