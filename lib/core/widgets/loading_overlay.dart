import 'package:flutter/material.dart';
import 'package:fibus/core/theme/fibus_palette.dart';

/// Covers [child] with a plain scrim and a small spinner while [isLoading].
class LoadingOverlay extends StatelessWidget {
  const LoadingOverlay({
    super.key,
    required this.isLoading,
    required this.child,
    this.message,
  });

  final bool isLoading;
  final Widget child;
  final String? message;

  static void show(BuildContext context, {String? message}) {
    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (_) => PopScope(
        canPop: false,
        child: LoadingOverlayContent(message: message),
      ),
    );
  }

  static void hide(BuildContext context) {
    final nav = Navigator.of(context, rootNavigator: true);
    if (nav.canPop()) nav.pop();
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        child,
        if (isLoading)
          Positioned.fill(
            child: ColoredBox(
              color: context.fib.background.withValues(alpha: 0.72),
              child: LoadingOverlayContent(message: message),
            ),
          ),
      ],
    );
  }
}

class LoadingOverlayContent extends StatelessWidget {
  const LoadingOverlayContent({super.key, this.message});

  final String? message;

  @override
  Widget build(BuildContext context) {
    final c = context.fib;
    return Center(
      child: Container(
        constraints: const BoxConstraints(maxWidth: 260),
        padding: const EdgeInsets.all(FibusSpace.s24),
        decoration: BoxDecoration(
          color: c.surface,
          borderRadius: BorderRadius.circular(FibusSpace.radiusCard),
          border: Border.all(color: c.hairline),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(
              width: 24,
              height: 24,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
            if (message != null && message!.isNotEmpty) ...[
              const SizedBox(height: FibusSpace.s16),
              Text(
                message!,
                textAlign: TextAlign.center,
                style: context.type.bodyMedium?.copyWith(
                  color: c.textSecondary,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
