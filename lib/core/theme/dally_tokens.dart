import 'package:flutter/material.dart';

import 'palette.dart';

/// The token bundle every widget reads via
/// `Theme.of(context).extension<DallyTokens>()!` (or the [tokens] extension on
/// [BuildContext]).
///
/// Scalar colour tokens are stored as fields so [lerp] can cross-fade them over
/// ~250ms when the palette changes. Discrete data (the palette identity, its
/// flags, and the derived sets — 2048 ramp, Minesweeper 1–8, chess fills) come
/// from [palette]; those snap to the target, which is imperceptible under the
/// colour fade.
@immutable
class DallyTokens extends ThemeExtension<DallyTokens> {
  const DallyTokens({
    required this.palette,
    required this.bg,
    required this.surface,
    required this.surfaceAlt,
    required this.border,
    required this.textPrimary,
    required this.textMuted,
    required this.textFaint,
    required this.accent,
    required this.success,
    required this.danger,
    required this.onAccent,
  });

  factory DallyTokens.of(Palette p) => DallyTokens(
        palette: p,
        bg: p.bg,
        surface: p.surface,
        surfaceAlt: p.surfaceAlt,
        border: p.border,
        textPrimary: p.textPrimary,
        textMuted: p.textMuted,
        textFaint: p.textFaint,
        accent: p.accent,
        success: p.success,
        danger: p.danger,
        onAccent: p.onAccent,
      );

  final Palette palette;

  final Color bg;
  final Color surface;
  final Color surfaceAlt;
  final Color border;
  final Color textPrimary;
  final Color textMuted;
  final Color textFaint;
  final Color accent;
  final Color success;
  final Color danger;
  final Color onAccent;

  // ── Derived sets (discrete; sourced from the target palette) ──────────────

  /// 2048 value ramp, backgrounds for 2 … 2048.
  List<Color> get scale => palette.scale;
  Color scaleForeground(Color tileBg) => palette.scaleForeground(tileBg);

  /// Fixed Minesweeper digit colours, index 0 == digit 1.
  List<Color> get minesweeperNumbers => palette.minesweeperNumbers;

  Color get pieceLight => Palette.pieceLight;
  Color get pieceLightOutline => Palette.pieceLightOutline;
  Color get pieceDark => palette.pieceDark;
  Color get pieceDarkOutline => palette.pieceDarkOutline;
  Color get moveHint => palette.moveHint;
  Color get selectedTint => palette.selectedTint;
  Color get lastMoveTint => palette.lastMoveTint;

  bool get isDark => palette.isDark;

  @override
  DallyTokens copyWith({Palette? palette}) =>
      palette == null ? this : DallyTokens.of(palette);

  @override
  DallyTokens lerp(covariant ThemeExtension<DallyTokens>? other, double t) {
    if (other is! DallyTokens) return this;
    return DallyTokens(
      // Discrete data snaps to the incoming palette past the midpoint.
      palette: t < 0.5 ? palette : other.palette,
      bg: Color.lerp(bg, other.bg, t)!,
      surface: Color.lerp(surface, other.surface, t)!,
      surfaceAlt: Color.lerp(surfaceAlt, other.surfaceAlt, t)!,
      border: Color.lerp(border, other.border, t)!,
      textPrimary: Color.lerp(textPrimary, other.textPrimary, t)!,
      textMuted: Color.lerp(textMuted, other.textMuted, t)!,
      textFaint: Color.lerp(textFaint, other.textFaint, t)!,
      accent: Color.lerp(accent, other.accent, t)!,
      success: Color.lerp(success, other.success, t)!,
      danger: Color.lerp(danger, other.danger, t)!,
      onAccent: Color.lerp(onAccent, other.onAccent, t)!,
    );
  }
}

/// Ergonomic access: `context.tokens.accent`.
extension DallyTokensX on BuildContext {
  DallyTokens get tokens => Theme.of(this).extension<DallyTokens>()!;
}
