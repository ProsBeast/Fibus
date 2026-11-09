import 'package:flutter/material.dart';
import 'package:fibus/core/theme/fibus_palette.dart';

/// Figtree for the interface, JetBrains Mono for times and figures.
abstract final class FibusFonts {
  static const String ui = 'Figtree';
  static const String mono = 'JetBrainsMono';
}

/// Shared ThemeData for both Fibus apps, light and dark.
abstract final class FibusTheme {
  static ThemeData get light => _build(FibusPalette.light, Brightness.light);
  static ThemeData get dark => _build(FibusPalette.dark, Brightness.dark);

  static ThemeData _build(FibusPalette p, Brightness b) {
    final scheme = ColorScheme(
      brightness: b,
      primary: p.accent,
      onPrimary: p.onAccent,
      secondary: p.textPrimary,
      onSecondary: p.surface,
      surface: p.surface,
      onSurface: p.textPrimary,
      onSurfaceVariant: p.textSecondary,
      surfaceContainerHighest: p.raised,
      surfaceContainerHigh: p.raised,
      surfaceContainer: p.surface,
      surfaceContainerLow: p.surface,
      outline: p.hairline,
      outlineVariant: p.hairline,
      error: p.negative,
      onError: Colors.white,
    );

    TextStyle t(double size, double height, FontWeight w, Color c) => TextStyle(
          fontFamily: FibusFonts.ui,
          fontSize: size,
          height: height / size,
          fontWeight: w,
          color: c,
          letterSpacing: 0,
        );

    final text = TextTheme(
      headlineMedium: t(28, 34, FontWeight.w500, p.textPrimary),
      headlineSmall: t(24, 30, FontWeight.w500, p.textPrimary),
      titleLarge: t(20, 26, FontWeight.w500, p.textPrimary),
      titleMedium: t(17, 24, FontWeight.w500, p.textPrimary),
      titleSmall: t(15, 20, FontWeight.w500, p.textPrimary),
      bodyLarge: t(16, 24, FontWeight.w400, p.textPrimary),
      bodyMedium: t(15, 22, FontWeight.w400, p.textPrimary),
      bodySmall: t(13, 18, FontWeight.w400, p.textSecondary),
      labelLarge: t(15, 20, FontWeight.w500, p.textPrimary),
      labelMedium: t(13, 18, FontWeight.w500, p.textSecondary),
      labelSmall: t(12, 16, FontWeight.w400, p.textMuted),
    );

    final controlShape = RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(FibusSpace.radiusControl),
    );
    const buttonSize = Size(64, 48);
    const buttonPadding = EdgeInsets.symmetric(horizontal: 20);

    return ThemeData(
      useMaterial3: true,
      brightness: b,
      colorScheme: scheme,
      fontFamily: FibusFonts.ui,
      textTheme: text,
      scaffoldBackgroundColor: p.background,
      canvasColor: p.background,
      dividerColor: p.hairline,
      splashFactory: InkRipple.splashFactory,
      extensions: [p],
      appBarTheme: AppBarTheme(
        backgroundColor: p.background,
        foregroundColor: p.textPrimary,
        elevation: 0,
        scrolledUnderElevation: 0,
        surfaceTintColor: Colors.transparent,
        centerTitle: false,
        titleSpacing: FibusSpace.page,
        toolbarHeight: 56,
        titleTextStyle: text.titleMedium,
        iconTheme: IconThemeData(color: p.textPrimary, size: 22),
      ),
      iconTheme: IconThemeData(color: p.textSecondary, size: 18),
      dividerTheme: DividerThemeData(color: p.hairline, thickness: 1, space: 1),
      cardTheme: CardThemeData(
        color: p.surface,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(FibusSpace.radiusCard),
          side: BorderSide(color: p.hairline),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: p.accent,
          foregroundColor: p.onAccent,
          disabledBackgroundColor: p.raised,
          disabledForegroundColor: p.textMuted,
          minimumSize: buttonSize,
          padding: buttonPadding,
          shape: controlShape,
          textStyle: text.labelLarge,
          elevation: 0,
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: p.accent,
          foregroundColor: p.onAccent,
          disabledBackgroundColor: p.raised,
          disabledForegroundColor: p.textMuted,
          minimumSize: buttonSize,
          padding: buttonPadding,
          shape: controlShape,
          textStyle: text.labelLarge,
          elevation: 0,
          shadowColor: Colors.transparent,
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: p.textPrimary,
          backgroundColor: p.surface,
          minimumSize: buttonSize,
          padding: buttonPadding,
          shape: controlShape,
          side: BorderSide(color: p.hairline),
          textStyle: text.labelLarge,
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: p.textPrimary,
          minimumSize: const Size(48, 40),
          padding: const EdgeInsets.symmetric(horizontal: 12),
          shape: controlShape,
          textStyle: text.labelLarge,
        ),
      ),
      iconButtonTheme: IconButtonThemeData(
        style: IconButton.styleFrom(
          foregroundColor: p.textPrimary,
          minimumSize: const Size(48, 48),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: p.raised,
        hintStyle: text.bodyMedium?.copyWith(color: p.textMuted),
        prefixIconColor: p.textMuted,
        suffixIconColor: p.textMuted,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(FibusSpace.radiusControl),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(FibusSpace.radiusControl),
          borderSide: BorderSide(color: p.hairline),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(FibusSpace.radiusControl),
          borderSide: BorderSide(color: p.textSecondary),
        ),
      ),
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith((s) =>
            s.contains(WidgetState.selected) ? p.onAccent : p.textMuted),
        trackColor: WidgetStateProperty.resolveWith((s) =>
            s.contains(WidgetState.selected) ? p.accent : p.raised),
        trackOutlineColor: WidgetStateProperty.all(p.hairline),
      ),
      sliderTheme: SliderThemeData(
        activeTrackColor: p.textPrimary,
        inactiveTrackColor: p.raised,
        thumbColor: p.textPrimary,
        overlayColor: p.hairline,
        valueIndicatorColor: p.textPrimary,
        valueIndicatorTextStyle: text.labelMedium?.copyWith(color: p.surface),
      ),
      progressIndicatorTheme: ProgressIndicatorThemeData(
        color: p.textPrimary,
        linearTrackColor: p.raised,
        circularTrackColor: Colors.transparent,
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: p.textPrimary,
        contentTextStyle: text.bodyMedium?.copyWith(color: p.surface),
        actionTextColor: p.accent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(FibusSpace.radiusControl),
        ),
        elevation: 0,
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: p.surface,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(FibusSpace.radiusPanel),
          side: BorderSide(color: p.hairline),
        ),
        titleTextStyle: text.titleMedium,
        contentTextStyle: text.bodyMedium?.copyWith(color: p.textSecondary),
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: p.surface,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(
            top: Radius.circular(FibusSpace.radiusPanel),
          ),
        ),
      ),
      listTileTheme: ListTileThemeData(
        iconColor: p.textSecondary,
        textColor: p.textPrimary,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16),
        minVerticalPadding: 12,
      ),
    );
  }
}

/// Figure styles: timetable-like mono with tabular digits.
abstract final class FibusType {
  static TextStyle figure(BuildContext context,
      {double size = 15, FontWeight weight = FontWeight.w400, Color? color}) {
    return TextStyle(
      fontFamily: FibusFonts.mono,
      fontSize: size,
      height: 1.1,
      fontWeight: weight,
      color: color ?? context.fib.textPrimary,
      fontFeatures: const [FontFeature.tabularFigures()],
      letterSpacing: size >= 40 ? -0.02 * size : 0,
    );
  }
}
