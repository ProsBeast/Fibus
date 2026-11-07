import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:fibus/core/theme/app_colors.dart';

/// A premium, semi-transparent loading overlay widget for async operations.
///
/// Can be wrapped around any widget via [LoadingOverlay] or displayed
/// modally using [LoadingOverlay.show] and [LoadingOverlay.hide].
class LoadingOverlay extends StatelessWidget {
  /// Whether the overlay is currently visible.
  final bool isLoading;

  /// Optional message to display below the progress indicator.
  final String? message;

  /// The widget beneath the overlay.
  final Widget child;

  /// Background scrim color.
  final Color? barrierColor;

  /// Whether tapping the barrier dismisses the overlay (defaults to false).
  final bool dismissible;

  const LoadingOverlay({
    super.key,
    required this.isLoading,
    required this.child,
    this.message,
    this.barrierColor,
    this.dismissible = false,
  });

  /// Displays a modal loading overlay dialog.
  static void show(BuildContext context, {String? message}) {
    showDialog<void>(
      context: context,
      barrierDismissible: false,
      barrierColor: Colors.black.withAlpha(160),
      builder: (dialogContext) => PopScope(
        canPop: false,
        child: LoadingOverlayContent(message: message),
      ),
    );
  }

  /// Closes the modal loading overlay dialog if one is active.
  static void hide(BuildContext context) {
    if (Navigator.of(context, rootNavigator: true).canPop()) {
      Navigator.of(context, rootNavigator: true).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        child,
        if (isLoading)
          Positioned.fill(
            child: AnimatedOpacity(
              opacity: isLoading ? 1.0 : 0.0,
              duration: const Duration(milliseconds: 200),
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 4.0, sigmaY: 4.0),
                child: Container(
                  color: barrierColor ?? Colors.black.withAlpha(150),
                  alignment: Alignment.center,
                  child: LoadingOverlayContent(message: message),
                ),
              ),
            ),
          ),
      ],
    );
  }
}

/// The inner visual card for the loading overlay.
class LoadingOverlayContent extends StatelessWidget {
  final String? message;

  const LoadingOverlayContent({super.key, this.message});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Center(
      child: Container(
        constraints: const BoxConstraints(maxWidth: 280),
        padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 24),
        decoration: BoxDecoration(
          color: AppColors.surfaceElevated,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: AppColors.border, width: 1),
          boxShadow: const [
            BoxShadow(
              color: Colors.black54,
              blurRadius: 24,
              offset: Offset(0, 8),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const SizedBox(
              width: 44,
              height: 44,
              child: CircularProgressIndicator(
                strokeWidth: 3.5,
                valueColor: AlwaysStoppedAnimation<Color>(AppColors.primaryBlue),
                backgroundColor: AppColors.surfaceHighlight,
              ),
            ),
            if (message != null && message!.isNotEmpty) ...[
              const SizedBox(height: 18),
              Text(
                message!,
                textAlign: TextAlign.center,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: AppColors.textPrimary,
                  fontWeight: FontWeight.w500,
                  height: 1.3,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
