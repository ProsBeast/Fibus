import 'package:flutter/material.dart';

/// Fibus colour roles, resolved per brightness through the theme.
///
/// Direction: punctual, plain-spoken, a little warm — a roadside stop at
/// 7:30 a.m. Surfaces are a near-neutral stone ramp so the content carries
/// the colour. One marigold accent marks the primary action, the selection
/// and the bus on the route strip. Positive and negative only carry meaning
/// (live GPS, errors). Read it with `context.fib`.
@immutable
class FibusPalette extends ThemeExtension<FibusPalette> {
  const FibusPalette({
    required this.background,
    required this.surface,
    required this.raised,
    required this.hairline,
    required this.textPrimary,
    required this.textSecondary,
    required this.textMuted,
    required this.accent,
    required this.onAccent,
    required this.accentInk,
    required this.accentSoft,
    required this.positive,
    required this.negative,
    required this.negativeSoft,
  });

  /// Page background.
  final Color background;

  /// Cards and sheets.
  final Color surface;

  /// Inputs, selected rows, pressed states.
  final Color raised;

  /// Borders and dividers: primary text at about 8 %.
  final Color hairline;

  final Color textPrimary;
  final Color textSecondary;

  /// Meta and captions only.
  final Color textMuted;

  /// Marigold: primary buttons, selection, the bus marker.
  final Color accent;

  /// Text and icons on [accent].
  final Color onAccent;

  /// The accent when used as text or ink on [surface] (meets 4.5:1).
  final Color accentInk;

  /// A faint accent wash for a selected row.
  final Color accentSoft;

  /// Live GPS, a good change.
  final Color positive;

  /// Errors and destructive actions.
  final Color negative;
  final Color negativeSoft;

  static const light = FibusPalette(
    background: Color(0xFFF7F6F4),
    surface: Color(0xFFFFFFFF),
    raised: Color(0xFFF0EFEC),
    hairline: Color(0x141C1B19),
    textPrimary: Color(0xFF1C1B19),
    textSecondary: Color(0xFF57534E),
    textMuted: Color(0xFF6F6A64),
    accent: Color(0xFFE9A23B),
    onAccent: Color(0xFF1C1B19),
    accentInk: Color(0xFF8F5300),
    accentSoft: Color(0x1FE9A23B),
    positive: Color(0xFF15803D),
    negative: Color(0xFFC7302B),
    negativeSoft: Color(0x14C7302B),
  );

  static const dark = FibusPalette(
    background: Color(0xFF141413),
    surface: Color(0xFF1B1A19),
    raised: Color(0xFF252422),
    hairline: Color(0x14EDEBE8),
    textPrimary: Color(0xFFEDEBE8),
    textSecondary: Color(0xFFA8A29E),
    textMuted: Color(0xFF8C8782),
    accent: Color(0xFFEFAE4E),
    onAccent: Color(0xFF1C1B19),
    accentInk: Color(0xFFF2B861),
    accentSoft: Color(0x24EFAE4E),
    positive: Color(0xFF4CC38A),
    negative: Color(0xFFE5484D),
    negativeSoft: Color(0x1FE5484D),
  );

  @override
  FibusPalette copyWith() => this;

  @override
  FibusPalette lerp(FibusPalette? other, double t) {
    if (other == null) return this;
    Color l(Color a, Color b) => Color.lerp(a, b, t)!;
    return FibusPalette(
      background: l(background, other.background),
      surface: l(surface, other.surface),
      raised: l(raised, other.raised),
      hairline: l(hairline, other.hairline),
      textPrimary: l(textPrimary, other.textPrimary),
      textSecondary: l(textSecondary, other.textSecondary),
      textMuted: l(textMuted, other.textMuted),
      accent: l(accent, other.accent),
      onAccent: l(onAccent, other.onAccent),
      accentInk: l(accentInk, other.accentInk),
      accentSoft: l(accentSoft, other.accentSoft),
      positive: l(positive, other.positive),
      negative: l(negative, other.negative),
      negativeSoft: l(negativeSoft, other.negativeSoft),
    );
  }
}

/// Spacing, radius and motion tokens. Spacing sits on a 4 px grid.
abstract final class FibusSpace {
  static const double s4 = 4;
  static const double s8 = 8;
  static const double s12 = 12;
  static const double s16 = 16;
  static const double s20 = 20;
  static const double s24 = 24;
  static const double s32 = 32;
  static const double s40 = 40;
  static const double s48 = 48;

  /// Page edge padding.
  static const double page = 20;

  static const double radiusControl = 10;
  static const double radiusCard = 16;
  static const double radiusPanel = 20;

  static const Curve ease = Cubic(0.22, 1, 0.36, 1);
  static const Duration fast = Duration(milliseconds: 160);
  static const Duration enter = Duration(milliseconds: 320);
}

extension FibusContext on BuildContext {
  /// The Fibus palette for the current brightness.
  FibusPalette get fib =>
      Theme.of(this).extension<FibusPalette>() ?? FibusPalette.light;

  TextTheme get type => Theme.of(this).textTheme;
}
