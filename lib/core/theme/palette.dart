import 'dart:ui';

/// A Dally theme *is* a palette. There is no separate light/dark switch — the
/// palette carries its own mode. Every game reads these tokens and nothing
/// else, so swapping a palette costs zero layout.
///
/// The eleven semantic tokens mirror `Dally Foundations.dc.html` exactly:
/// [bg], [surface], [surfaceAlt], [border], [textPrimary], [textMuted],
/// [textFaint], [accent], [success], [danger] — plus [onAccent] (the ink laid
/// on top of an accent fill, e.g. inside a primary pill).
///
/// Derived sets ([scale] for the 2048 ramp, [minesweeperNumbers] for the fixed
/// 1–8 digit colours, and the chess piece fills) are computed from the tokens
/// so a new palette only needs the eleven values plus its accent character.
class Palette {
  const Palette({
    required this.id,
    required this.name,
    required this.mode,
    required this.isDark,
    required this.isAmoled,
    required this.isPremium,
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
    required this.minesweeperNumbers,
    required this.scalePeak,
  });

  /// Stable key persisted to storage; never localise or reorder.
  final String id;
  final String name;

  /// Human label for the palette's character, e.g. `dark · warm`.
  final String mode;

  final bool isDark;
  final bool isAmoled;

  /// Marked "Pro" in the UI. In v1 the badge is decorative — every palette is
  /// unlocked and free (see the entitlements layer).
  final bool isPremium;

  // ── The eleven tokens ────────────────────────────────────────────────────
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

  // ── Derived-set inputs ───────────────────────────────────────────────────

  /// The fixed 8-step Minesweeper digit colours (1–4 cool, 5–8 warm). The
  /// design ships one set for dark palettes and one for light; a palette points
  /// at whichever suits its mode.
  final List<Color> minesweeperNumbers;

  /// The lightest/darkest tint the 2048 ramp reaches at its top stop. Dark
  /// palettes lift toward light; light palettes deepen. Kept explicit so the
  /// two hand-tuned canonical ramps (Ink, Paper) stay legible.
  final Color scalePeak;

  // ── Chess piece fills (never follow the theme; light is always lighter) ───

  /// Light-side piece fill — fixed across every palette.
  static const Color pieceLight = Color(0xFFEEEAE1);

  /// Light-side piece hairline — fixed across every palette.
  static const Color pieceLightOutline = Color(0xFF33312C);

  /// Dark-side piece fill takes the palette accent…
  Color get pieceDark => accent;

  /// …outlined with a lighter tint of itself.
  Color get pieceDarkOutline => Color.lerp(accent, const Color(0xFFFFFFFF), 0.45)!;

  /// Legal-move markers: a muted translucent accent tint, weaker than both the
  /// pieces and the selected-square tint.
  Color get moveHint => accent.withValues(alpha: 0.28);

  /// Selected-square tint.
  Color get selectedTint => accent.withValues(alpha: 0.22);

  /// Last-move highlight.
  Color get lastMoveTint => accent.withValues(alpha: 0.14);

  // ── Chess board squares ───────────────────────────────────────────────────
  // Near-neutral by design (from `Dally Chess Pieces.dc.html`) so the fixed
  // cream light pieces never disappear: light themes drop to a warm taupe, dark
  // themes to a cool charcoal, AMOLED to a near-black checker.

  Color get chessLightSquare => isAmoled
      ? const Color(0xFF14161B)
      : isDark
          ? const Color(0xFF212530)
          : const Color(0xFFE9E4DA);

  Color get chessDarkSquare => isAmoled
      ? const Color(0xFF000000)
      : isDark
          ? const Color(0xFF171A20)
          : const Color(0xFFD5CEC0);

  /// Neutral fill laid *under* the line for the "Outline" piece style, so the
  /// contour carries the shape while the body still contrasts with the square.
  Color get pieceHollowLight =>
      isDark ? const Color(0xFF2C313B) : const Color(0xFFC6BFAF);
  Color get pieceHollowDark => Color.alphaBlend(
        accent.withValues(alpha: isDark ? 0.18 : 0.22),
        isDark ? surface : const Color(0xFFE9E4DA),
      );

  // ── 2048 value ramp ──────────────────────────────────────────────────────

  /// Eleven tile backgrounds for values 2 … 2048, ramping
  /// `surfaceAlt → accent → scalePeak`.
  List<Color> get scale {
    final out = <Color>[];
    for (var i = 0; i <= 10; i++) {
      if (i <= 8) {
        out.add(Color.lerp(surfaceAlt, accent, i / 8)!);
      } else {
        out.add(Color.lerp(accent, scalePeak, (i - 8) / 2)!);
      }
    }
    return out;
  }

  /// Foreground (numeral) colour for a given 2048 tile background — flips with
  /// the tile's luminance so it stays legible in every palette.
  Color scaleForeground(Color tileBg) {
    return tileBg.computeLuminance() > 0.5 ? _nearBlack : _nearWhite;
  }

  Color get _nearBlack => isDark ? bg : const Color(0xFF141414);
  Color get _nearWhite => const Color(0xFFFFFFFF);

  Palette copyWith({String? id}) => Palette(
        id: id ?? this.id,
        name: name,
        mode: mode,
        isDark: isDark,
        isAmoled: isAmoled,
        isPremium: isPremium,
        bg: bg,
        surface: surface,
        surfaceAlt: surfaceAlt,
        border: border,
        textPrimary: textPrimary,
        textMuted: textMuted,
        textFaint: textFaint,
        accent: accent,
        success: success,
        danger: danger,
        onAccent: onAccent,
        minesweeperNumbers: minesweeperNumbers,
        scalePeak: scalePeak,
      );
}
