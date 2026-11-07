import 'package:flutter/material.dart';

/// Design tokens and color palette for Fibus.
///
/// Features a premium OLED-ready dark theme with deep electric blue
/// accents for commuters and high-visibility amber accents for operators/trackers.
abstract final class AppColors {
  // ---------------------------------------------------------------------------
  // Primary & Accent Colors (Commuter Theme)
  // ---------------------------------------------------------------------------
  /// Deep Electric Blue — Primary Commuter Brand Color
  static const Color primary = Color(0xFF2979FF);
  static const Color primaryBlue = primary;
  static const Color primaryLight = Color(0xFF82B1FF);
  static const Color primaryBlueLight = primaryLight;
  static const Color primaryDark = Color(0xFF1565C0);
  static const Color primaryBlueDark = primaryDark;
  static const Color primaryContainer = Color(0xFF1A3875);

  /// Vibrant Teal — Commuter Secondary / Accent Color
  static const Color accent = Color(0xFF00E5FF);
  static const Color accentTeal = accent;
  static const Color accentLight = Color(0xFF84FFFF);
  static const Color accentTealLight = accentLight;
  static const Color accentDark = Color(0xFF00B4D8);
  static const Color accentTealDark = accentDark;
  static const Color accentMuted = Color(0xFF009688);
  static const Color accentTealMuted = accentMuted;

  // ---------------------------------------------------------------------------
  // Tracker Brand Colors (Operator Theme)
  // ---------------------------------------------------------------------------
  /// Vibrant Amber/Orange — Primary Tracker Brand Color
  static const Color trackerAmber = Color(0xFFFF9100);
  static const Color trackerAmberDark = Color(0xFFFF6D00);
  static const Color trackerAmberLight = Color(0xFFFFD180);

  // ---------------------------------------------------------------------------
  // Surface & Neutral Colors (OLED Dark Palette)
  // ---------------------------------------------------------------------------
  /// Deepest background (#0B0F19 for subtle depth)
  static const Color background = Color(0xFF0B0F19);
  static const Color backgroundSecondary = Color(0xFF111827);

  /// Primary surface for cards, sheets, and dialogs (#1A2234)
  static const Color surface = Color(0xFF1A2234);

  /// Surface variant / secondary surface (#222C42)
  static const Color surfaceVariant = Color(0xFF222C42);

  /// Elevated card surface for floating elements (#2A3650)
  static const Color surfaceElevated = Color(0xFF2A3650);

  /// Secondary surface for input fields and pill containers
  static const Color surfaceHighlight = Color(0xFF232B3E);

  // ---------------------------------------------------------------------------
  // Glassmorphism Values
  // ---------------------------------------------------------------------------
  static const Color glassBackground = Color(0x991A2234);
  static const Color glassBorder = Color(0x26FFFFFF);
  static const Color glassBorderHover = Color(0x40FFFFFF);
  static const Color glassHighlight = Color(0x1AFFFFFF);

  // ---------------------------------------------------------------------------
  // Borders & Dividers
  // ---------------------------------------------------------------------------
  static const Color border = Color(0xFF2E3850);
  static const Color borderLight = Color(0xFF3F4D6B);
  static const Color outline = Color(0xFF334155);
  static const Color divider = Color(0xFF1E293B);

  // ---------------------------------------------------------------------------
  // Content / Typography Colors
  // ---------------------------------------------------------------------------
  static const Color textPrimary = Color(0xFFF8FAFC);
  static const Color textSecondary = Color(0xFF94A3B8);
  static const Color textTertiary = Color(0xFF64748B);
  static const Color textMuted = Color(0xFF64748B);
  static const Color textDisabled = Color(0xFF475569);

  // ---------------------------------------------------------------------------
  // Telemetry & Tracking Status Colors
  // ---------------------------------------------------------------------------
  /// Live: Active continuous GPS tracking (< 60s stale threshold)
  static const Color statusLive = Color(0xFF00E676);
  static const Color statusLiveGlow = Color(0x6600E676);

  /// Stale: GPS ping received between 60s and 5min ago
  static const Color statusStale = Color(0xFFFFB300);
  static const Color statusStaleGlow = Color(0x66FFB300);

  /// Offline: No live operator broadcast active
  static const Color statusOffline = Color(0xFFFF1744);
  static const Color statusOfflineGlow = Color(0x66FF1744);

  /// Scheduled: Bus ETA derived from static timetable schedule
  static const Color statusScheduled = Color(0xFF7C4DFF);
  static const Color statusScheduledGlow = Color(0x667C4DFF);

  // ---------------------------------------------------------------------------
  // Feedback & Semantic Alerts
  // ---------------------------------------------------------------------------
  static const Color success = Color(0xFF00E676);
  static const Color warning = Color(0xFFFFB300);
  static const Color error = Color(0xFFFF5252);
  static const Color info = Color(0xFF2979FF);

  // ---------------------------------------------------------------------------
  // Route / Map Overlay Colors
  // ---------------------------------------------------------------------------
  static const Color scooterPath = Color(0xFF00E5FF);
  static const Color busRoutePath = Color(0xFF2979FF);

  // ---------------------------------------------------------------------------
  // Decorative Gradients
  // ---------------------------------------------------------------------------
  /// Electric Blue Gradient for Commuter hero buttons and cards
  static const LinearGradient primaryGradient = LinearGradient(
    colors: [Color(0xFF2979FF), Color(0xFF00E5FF)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  /// Amber Tracker Gradient for operator broadcast buttons
  static const LinearGradient trackerGradient = LinearGradient(
    colors: [Color(0xFFFF9100), Color(0xFFFF6D00)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  /// Subtle dark card surface gradient
  static const LinearGradient cardGradient = LinearGradient(
    colors: [Color(0xFF1E283C), Color(0xFF141C2B)],
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
  );

  /// Pulsing glow gradient for live bus map markers
  static const RadialGradient livePulseGradient = RadialGradient(
    colors: [
      Color(0x8000E676),
      Color(0x3300E676),
      Color(0x0000E676),
    ],
    stops: [0.2, 0.6, 1.0],
  );
}
