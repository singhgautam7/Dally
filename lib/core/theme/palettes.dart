import 'dart:ui';

import 'palette.dart';

/// Fixed Minesweeper digit colours for dark palettes (1–4 cool, 5–8 warm).
const List<Color> _inkNumbers = [
  Color(0xFF6EA8FE),
  Color(0xFF38BDF8),
  Color(0xFF4ADE80),
  Color(0xFFA3B3C7),
  Color(0xFFFBBF6E),
  Color(0xFFF59148),
  Color(0xFFF87171),
  Color(0xFFFB4E7E),
];

/// Fixed Minesweeper digit colours for light palettes.
const List<Color> _paperNumbers = [
  Color(0xFF2563EB),
  Color(0xFF0E7490),
  Color(0xFF16A34A),
  Color(0xFF5B6472),
  Color(0xFFB45309),
  Color(0xFFC2410C),
  Color(0xFFDC2626),
  Color(0xFFA21055),
];

/// The eight v1 palettes — six standard, two premium AMOLED. Values are copied
/// verbatim from `Dally Foundations.dc.html`.
class DallyPalettes {
  DallyPalettes._();

  static const Palette ink = Palette(
    id: 'ink',
    name: 'Ink',
    mode: 'dark',
    isDark: true,
    isAmoled: false,
    isPremium: false,
    bg: Color(0xFF0E0F12),
    surface: Color(0xFF16181D),
    surfaceAlt: Color(0xFF1E2127),
    border: Color(0xFF2A2E36),
    textPrimary: Color(0xFFECEDEF),
    textMuted: Color(0xFF9AA0AB),
    textFaint: Color(0xFF5A5F69),
    accent: Color(0xFF6EA8FE),
    success: Color(0xFF4ADE80),
    danger: Color(0xFFF87171),
    onAccent: Color(0xFF0E0F12),
    minesweeperNumbers: _inkNumbers,
    scalePeak: Color(0xFFB4D4FF),
  );

  static const Palette ember = Palette(
    id: 'ember',
    name: 'Ember',
    mode: 'dark · warm',
    isDark: true,
    isAmoled: false,
    isPremium: false,
    bg: Color(0xFF14100C),
    surface: Color(0xFF1E1811),
    surfaceAlt: Color(0xFF271F16),
    border: Color(0xFF3A2E20),
    textPrimary: Color(0xFFF3ECE2),
    textMuted: Color(0xFFB7A48E),
    textFaint: Color(0xFF7A6A52),
    accent: Color(0xFFF5A524),
    success: Color(0xFF86C34C),
    danger: Color(0xFFEF6A5B),
    onAccent: Color(0xFF14100C),
    minesweeperNumbers: _inkNumbers,
    scalePeak: Color(0xFFFBD9A0),
  );

  static const Palette tide = Palette(
    id: 'tide',
    name: 'Tide',
    mode: 'dark · cool',
    isDark: true,
    isAmoled: false,
    isPremium: false,
    bg: Color(0xFF0A0F14),
    surface: Color(0xFF10171F),
    surfaceAlt: Color(0xFF16202B),
    border: Color(0xFF223140),
    textPrimary: Color(0xFFE5EEF5),
    textMuted: Color(0xFF90A4B4),
    textFaint: Color(0xFF5B6E7E),
    accent: Color(0xFF38BDF8),
    success: Color(0xFF4ADE80),
    danger: Color(0xFFFB7185),
    onAccent: Color(0xFF0A0F14),
    minesweeperNumbers: _inkNumbers,
    scalePeak: Color(0xFFB8E6FF),
  );

  static const Palette paper = Palette(
    id: 'paper',
    name: 'Paper',
    mode: 'light',
    isDark: false,
    isAmoled: false,
    isPremium: false,
    bg: Color(0xFFF7F5F0),
    surface: Color(0xFFFFFFFF),
    surfaceAlt: Color(0xFFEFEBE3),
    border: Color(0xFFDED9CE),
    textPrimary: Color(0xFF1E1B16),
    textMuted: Color(0xFF6B655B),
    textFaint: Color(0xFFA9A398),
    accent: Color(0xFF2563EB),
    success: Color(0xFF16A34A),
    danger: Color(0xFFDC2626),
    onAccent: Color(0xFFFFFFFF),
    minesweeperNumbers: _paperNumbers,
    scalePeak: Color(0xFF16409E),
  );

  static const Palette meadow = Palette(
    id: 'meadow',
    name: 'Meadow',
    mode: 'light · green',
    isDark: false,
    isAmoled: false,
    isPremium: false,
    bg: Color(0xFFF2F6F0),
    surface: Color(0xFFFFFFFF),
    surfaceAlt: Color(0xFFE7EFE4),
    border: Color(0xFFD2DECC),
    textPrimary: Color(0xFF17211A),
    textMuted: Color(0xFF5E6B60),
    textFaint: Color(0xFF97A491),
    accent: Color(0xFF2E9E5B),
    success: Color(0xFF16A34A),
    danger: Color(0xFFDC2626),
    onAccent: Color(0xFFFFFFFF),
    minesweeperNumbers: _paperNumbers,
    scalePeak: Color(0xFF12613A),
  );

  static const Palette blush = Palette(
    id: 'blush',
    name: 'Blush',
    mode: 'light · rose',
    isDark: false,
    isAmoled: false,
    isPremium: false,
    bg: Color(0xFFFBF3F5),
    surface: Color(0xFFFFFFFF),
    surfaceAlt: Color(0xFFF5E7EC),
    border: Color(0xFFE7D2DA),
    textPrimary: Color(0xFF221A1E),
    textMuted: Color(0xFF766068),
    textFaint: Color(0xFFB49BA4),
    accent: Color(0xFFC13B7A),
    success: Color(0xFF16A34A),
    danger: Color(0xFFDC2626),
    onAccent: Color(0xFFFFFFFF),
    minesweeperNumbers: _paperNumbers,
    scalePeak: Color(0xFF7A264D),
  );

  static const Palette void_ = Palette(
    id: 'void',
    name: 'Void',
    mode: 'amoled · neutral',
    isDark: true,
    isAmoled: true,
    isPremium: true,
    bg: Color(0xFF000000),
    surface: Color(0xFF000000),
    surfaceAlt: Color(0xFF101014),
    border: Color(0xFF1E1E24),
    textPrimary: Color(0xFFF4F4F6),
    textMuted: Color(0xFF8A8A94),
    textFaint: Color(0xFF4A4A52),
    accent: Color(0xFF7AA2FF),
    success: Color(0xFF4ADE80),
    danger: Color(0xFFFF6B6B),
    onAccent: Color(0xFF000000),
    minesweeperNumbers: _inkNumbers,
    scalePeak: Color(0xFFB4D4FF),
  );

  static const Palette neon = Palette(
    id: 'neon',
    name: 'Neon',
    mode: 'amoled · accent',
    isDark: true,
    isAmoled: true,
    isPremium: true,
    bg: Color(0xFF000000),
    surface: Color(0xFF000000),
    surfaceAlt: Color(0xFF0C0A12),
    border: Color(0xFF241C2E),
    textPrimary: Color(0xFFF2ECFA),
    textMuted: Color(0xFFA08FB4),
    textFaint: Color(0xFF5A4A6E),
    accent: Color(0xFFC46BFF),
    success: Color(0xFF4ADE80),
    danger: Color(0xFFFF5FA2),
    onAccent: Color(0xFF000000),
    minesweeperNumbers: _inkNumbers,
    scalePeak: Color(0xFFE6C4FF),
  );

  /// Six standard palettes, in the order the theme picker lists them.
  static const List<Palette> standard = [ink, ember, tide, paper, meadow, blush];

  /// Two premium AMOLED palettes.
  static const List<Palette> premium = [void_, neon];

  /// All palettes.
  static const List<Palette> all = [
    ink,
    ember,
    tide,
    paper,
    meadow,
    blush,
    void_,
    neon,
  ];

  /// The default palette on first launch.
  static const Palette fallback = ink;

  /// Look up by stable id, falling back to [fallback] for unknown ids so a
  /// stale persisted choice can never crash the app.
  static Palette byId(String? id) {
    for (final p in all) {
      if (p.id == id) return p;
    }
    return fallback;
  }
}
