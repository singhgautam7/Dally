import 'dart:ui';

import 'accents.dart';

/// A resolved palette: the eleven semantic tokens plus the derived sets every
/// game reads. It is **not** authored any more — it is what
/// `DallyPalettes.palette(mode, accent, amoled)` returns, a pure function of
/// three inputs (`Dally Theme System.dc.html`, phase 21).
///
/// The token names, their count and every call site are unchanged from the
/// literal-palette era: this is a change behind one interface, which is why no
/// game screen was touched by it.
///
/// The eleven tokens mirror `Dally Foundations.dc.html`: [bg], [surface],
/// [surfaceAlt], [border], [textPrimary], [textMuted], [textFaint], [accent],
/// [success], [danger], [onAccent].
///
/// Derived sets ([scale] for the 2048 ramp, [minesweeperNumbers], the chess
/// fills) hang off the same inputs, so a new accent needs no new values.
class Palette {
  const Palette({
    required this.id,
    required this.name,
    required this.mode,
    required this.accentId,
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
    required this.scaleMid,
    required this.scalePeak,
  });

  /// The preset id this palette resolves to, or `'custom'` when the triple
  /// matches no preset. Derived, never the source of truth.
  final String id;

  /// The preset name, or `'Custom'`.
  final String name;

  final DallyMode mode;

  /// The accent identity behind [accent] — the thing that is persisted.
  final String accentId;

  final bool isAmoled;

  /// Marked "Pro" in the UI. Decorative in v1: every palette is unlocked, and
  /// the gate is the AMOLED toggle rather than the preset.
  final bool isPremium;

  bool get isDark => mode == DallyMode.dark;

  /// Human label for the palette's character, e.g. `dark · amoled`.
  String get modeLabel => isAmoled ? 'dark · amoled' : mode.label.toLowerCase();

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

  /// The fixed 8-step Minesweeper digit colours (1–4 cool, 5–8 warm), one set
  /// per mode.
  final List<Color> minesweeperNumbers;

  /// The 2048 ramp's mid and top stops — **accent-independent**, one authored
  /// pair per neutral ramp. Tiles are surfaces, so what is measured is the
  /// numeral on the tile rather than the tile on the background.
  final Color scaleMid;
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

  /// The chess legal-move marker: the resolved accent at 34% over bg in Dark,
  /// 26% in Light. A fraction of the same colour rather than its own value, so
  /// it can never grow stronger than the selected-square tint.
  Color get moveHint => accent.withValues(alpha: isDark ? 0.34 : 0.26);

  /// Selected-square tint. Deliberately stronger than [moveHint] — selection is
  /// state, a legal-move dot is a hint.
  Color get selectedTint => accent.withValues(alpha: isDark ? 0.46 : 0.38);

  /// Last-move highlight, the weakest of the three.
  Color get lastMoveTint => accent.withValues(alpha: 0.14);

  // ── Chess board squares ───────────────────────────────────────────────────
  // Near-neutral by design (from `Dally Chess Pieces.dc.html`) so the fixed
  // cream light pieces never disappear.

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

  /// Neutral fill laid *under* the line for the "Outline" piece style.
  Color get pieceHollowLight =>
      isDark ? const Color(0xFF2C313B) : const Color(0xFFC6BFAF);
  Color get pieceHollowDark => Color.alphaBlend(
        accent.withValues(alpha: isDark ? 0.18 : 0.22),
        isDark ? surface : const Color(0xFFE9E4DA),
      );

  // ── 2048 value ramp ──────────────────────────────────────────────────────

  /// Eleven tile backgrounds for values 2 … 2048, ramping
  /// `surfaceAlt → scaleMid → scalePeak`. Accent-independent: eleven tinted
  /// steps plus an accent is twelve colours fighting.
  List<Color> get scale {
    final out = <Color>[];
    for (var i = 0; i <= 10; i++) {
      if (i <= 8) {
        out.add(Color.lerp(surfaceAlt, scaleMid, i / 8)!);
      } else {
        out.add(Color.lerp(scaleMid, scalePeak, (i - 8) / 2)!);
      }
    }
    return out;
  }

  /// Foreground (numeral) colour for a given 2048 tile background.
  ///
  /// The two candidates are the extremes rather than the palette's own text
  /// colours: a tile is a **fill**, and what is measured is the numeral on it,
  /// which has to clear 4.5:1 on every one of the eleven steps in all three
  /// ramps. A mid-ramp tile sits at a luminance where only the extremes get
  /// there — nudging either candidate toward the page costs the middle of the
  /// ramp its legibility, which is exactly the regression the matrix test
  /// catches.
  Color scaleForeground(Color tileBg) =>
      bestForegroundOn(tileBg, ink: const Color(0xFF000000));
}
