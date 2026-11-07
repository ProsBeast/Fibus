import 'package:flutter/material.dart';
import 'package:fibus/core/theme/app_colors.dart';

/// A versatile, dark-themed error display widget.
///
/// Can be displayed full-screen or embedded as a compact card inside a list/panel.
class ErrorDisplay extends StatelessWidget {
  /// Primary error message.
  final String message;

  /// Optional heading title (defaults to "Something went wrong").
  final String? title;

  /// Optional icon (defaults to `Icons.error_outline_rounded`).
  final IconData? icon;

  /// Callback when user taps the retry button. If null, no retry button is shown.
  final VoidCallback? onRetry;

  /// Label for the primary retry button (defaults to "Try Again").
  final String retryLabel;

  /// Optional secondary action callback (e.g. "Go Back" or "Contact Support").
  final VoidCallback? onSecondaryAction;

  /// Label for secondary action button.
  final String? secondaryActionLabel;

  /// Whether to render in compact card style instead of centered full-page.
  final bool compact;

  const ErrorDisplay({
    super.key,
    required this.message,
    this.title,
    this.icon,
    this.onRetry,
    this.retryLabel = 'Try Again',
    this.onSecondaryAction,
    this.secondaryActionLabel,
    this.compact = false,
  });

  @override
  Widget build(BuildContext context) {
    if (compact) {
      return _buildCompactCard(context);
    }
    return _buildFullScreen(context);
  }

  Widget _buildCompactCard(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.error.withAlpha(80), width: 1),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: AppColors.error.withAlpha(35),
              shape: BoxShape.circle,
            ),
            child: Icon(
              icon ?? Icons.error_outline_rounded,
              color: AppColors.error,
              size: 22,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                if (title != null && title!.isNotEmpty)
                  Text(
                    title!,
                    style: const TextStyle(
                      color: AppColors.textPrimary,
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                const SizedBox(height: 2),
                Text(
                  message,
                  style: const TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 13,
                    height: 1.3,
                  ),
                ),
                if (onRetry != null) ...[
                  const SizedBox(height: 8),
                  TextButton.icon(
                    onPressed: onRetry,
                    style: TextButton.styleFrom(
                      padding: EdgeInsets.zero,
                      minimumSize: Size.zero,
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      foregroundColor: AppColors.primaryBlueLight,
                    ),
                    icon: const Icon(Icons.refresh_rounded, size: 16),
                    label: Text(
                      retryLabel,
                      style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFullScreen(BuildContext context) {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            // Icon container with soft glow
            Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                color: AppColors.error.withAlpha(25),
                shape: BoxShape.circle,
                border: Border.all(color: AppColors.error.withAlpha(80), width: 1.5),
              ),
              child: Icon(
                icon ?? Icons.error_outline_rounded,
                size: 38,
                color: AppColors.error,
              ),
            ),
            const SizedBox(height: 20),

            // Title
            Text(
              title ?? 'Something Went Wrong',
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: AppColors.textPrimary,
                fontSize: 18,
                fontWeight: FontWeight.w700,
                letterSpacing: -0.2,
              ),
            ),
            const SizedBox(height: 8),

            // Message
            Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: AppColors.textSecondary,
                fontSize: 14,
                height: 1.4,
              ),
            ),
            const SizedBox(height: 24),

            // Action Buttons
            if (onRetry != null)
              ElevatedButton.icon(
                onPressed: onRetry,
                icon: const Icon(Icons.refresh_rounded, size: 18),
                label: Text(retryLabel),
                style: ElevatedButton.styleFrom(
                  minimumSize: const Size(160, 48),
                ),
              ),

            if (onSecondaryAction != null && secondaryActionLabel != null) ...[
              const SizedBox(height: 10),
              TextButton(
                onPressed: onSecondaryAction,
                child: Text(secondaryActionLabel!),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
