import 'dart:ui';

import 'package:flutter/painting.dart' show HSVColor;

import 'accents.dart';
import 'palette.dart';

/// Fixed Minesweeper digit colours for dark ramps (1–4 cool, 5–8 warm).
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

/// Fixed Minesweeper digit colours for the light ramp.
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

/// One of the eight shipped palettes, expressed as the triple it *is*.
///
/// That every palette is expressible this way is the test of whether the axes
/// were the right ones: if a preset had needed a fourth input, the model would
/// be wrong. Three of them carry a neutral tint, which is the thing a preset
/// gives you that building it yourself does not.
class ThemePreset {
  const ThemePreset({
    required this.id,
    required this.name,
    required this.mode,
    required this.accentId,
    required this.amoled,
    this.tint = NeutralTint.canonical,
    this.isPremium = false,
  });

  /// Stable key persisted in the old `paletteId` setting; the migration source.
  final String id;
  final String name;
  final DallyMode mode;
  final String accentId;
  final bool amoled;
  final NeutralTint tint;

  /// The PRO badge, kept on the two AMOLED entries. Decorative in v1 — every
  /// palette is unlocked. The toggle is the paid surface, not the preset.
  final bool isPremium;

  bool matches(DallyMode m, String accent, bool a) =>
      mode == m && accentId == accent && amoled == a;
}

/// The palette layer. `palette(mode, accent, amoled)` is the whole API; the
/// eight presets are named triples on top of it.
class DallyPalettes {
  DallyPalettes._();

  /// The eight shipped palettes, in picker order. Names and order are frozen.
  static const List<ThemePreset> presets = [
    ThemePreset(id: 'ink', name: 'Ink', mode: DallyMode.dark, accentId: 'azure', amoled: false),
    ThemePreset(
        id: 'ember',
        name: 'Ember',
        mode: DallyMode.dark,
        accentId: 'ember',
        amoled: false,
        tint: NeutralTint.warm),
    ThemePreset(id: 'tide', name: 'Tide', mode: DallyMode.dark, accentId: 'tide', amoled: false),
    ThemePreset(id: 'paper', name: 'Paper', mode: DallyMode.light, accentId: 'azure', amoled: false),
    ThemePreset(
        id: 'meadow',
        name: 'Meadow',
        mode: DallyMode.light,
        accentId: 'meadow',
        amoled: false,
        tint: NeutralTint.towardAccent),
    ThemePreset(
        id: 'blush',
        name: 'Blush',
        mode: DallyMode.light,
        accentId: 'blush',
        amoled: false,
        tint: NeutralTint.towardAccent),
    ThemePreset(
        id: 'void',
        name: 'Void',
        mode: DallyMode.dark,
        accentId: 'azure',
        amoled: true,
        isPremium: true),
    ThemePreset(
        id: 'neon',
        name: 'Neon',
        mode: DallyMode.dark,
        accentId: 'neon',
        amoled: true,
        isPremium: true),
  ];

  /// Six standard presets, in the order the theme screen lists them.
  static List<ThemePreset> get standard =>
      [for (final p in presets) if (!p.isPremium) p];

  /// The two AMOLED presets.
  static List<ThemePreset> get premium =>
      [for (final p in presets) if (p.isPremium) p];

  /// The default on first launch: Ink — Dark, Azure, AMOLED off.
  static const ThemePreset fallback = ThemePreset(
      id: 'ink', name: 'Ink', mode: DallyMode.dark, accentId: 'azure', amoled: false);

  static ThemePreset? presetById(String? id) {
    for (final p in presets) {
      if (p.id == id) return p;
    }
    return null;
  }

  /// The preset a triple names, or null when it matches none — in which case
  /// the screen calls it Custom. The preset name is **derived**, never stored,
  /// so renaming a preset later cannot orphan anyone's settings.
  static ThemePreset? presetFor(DallyMode mode, String accentId, bool amoled) {
    for (final p in presets) {
      if (p.matches(mode, accentId, amoled)) return p;
    }
    return null;
  }

  /// The palette for a triple.
  ///
  /// Pure, synchronous, no I/O: eight of the eleven tokens are a table lookup,
  /// two are computed from the accent, and one is a ratio comparison. Cheap
  /// enough to call on every build rather than caching, which is what keeps a
  /// mid-game switch instant.
  ///
  /// A triple that names a preset takes that preset's identity — its name, its
  /// PRO badge and its neutral tint — so the eight palettes and the three
  /// controls can never contradict each other.
  static Palette palette({
    required DallyMode mode,
    required String accentId,
    required bool amoled,
    bool highContrastText = false,
  }) {
    final preset = presetFor(mode, accentId, amoled);
    return build(
      mode: mode,
      accentId: accentId,
      amoled: amoled,
      tint: preset?.tint ?? NeutralTint.canonical,
      id: preset?.id ?? 'custom',
      name: preset?.name ?? 'Custom',
      isPremium: preset?.isPremium ?? false,
      highContrastText: highContrastText,
    );
  }

  /// The palette a named preset renders as.
  static Palette ofPreset(ThemePreset p, {bool highContrastText = false}) => build(
        mode: p.mode,
        accentId: p.accentId,
        amoled: p.amoled,
        tint: p.tint,
        id: p.id,
        name: p.name,
        isPremium: p.isPremium,
        highContrastText: highContrastText,
      );

  /// The derivation itself. Every token's rule is documented at its line.
  static Palette build({
    required DallyMode mode,
    required String accentId,
    required bool amoled,
    NeutralTint tint = NeutralTint.canonical,
    String id = 'custom',
    String name = 'Custom',
    bool isPremium = false,
    bool highContrastText = false,
  }) {
    // AMOLED is Dark-only by construction, so a stale `true` in Light can never
    // produce a black-on-white palette.
    final black = mode == DallyMode.dark && amoled;
    final ramp = rampFor(mode, black);
    final accentIdentity = accentById(accentId);
    final accent = accentIdentity.resolve(mode);

    // Neutral tint — a hue rotation at constant lightness. Presets only.
    final hue = switch (tint) {
      NeutralTint.canonical => null,
      NeutralTint.warm => 32.0,
      NeutralTint.towardAccent => HSVColor.fromColor(accent).hue,
    };
    final boost = tint == NeutralTint.towardAccent ? 1.6 : 1.0;
    Color n(Color c) => hue == null ? c : tintNeutral(c, hue, boost);

    final textFaint = highContrastText
        ? (mode == DallyMode.light ? kLightFaintHC : kDarkFaintHC)
        : ramp.textFaint;
    final textMuted = highContrastText
        ? (mode == DallyMode.light ? kLightMutedHC : kDarkMutedHC)
        : ramp.textMuted;

    return Palette(
      id: id,
      name: name,
      mode: mode,
      accentId: accentIdentity.id,
      isAmoled: black,
      isPremium: isPremium,
      // Straight lookup into one of the three ramps — accent-independent by
      // construction, which is what makes thirty combinations checkable as ten.
      bg: n(ramp.bg),
      surface: n(ramp.surface),
      surfaceAlt: n(ramp.surfaceAlt),
      border: n(ramp.border),
      textPrimary: n(ramp.textPrimary),
      textMuted: n(textMuted),
      textFaint: n(textFaint),
      accent: accent,
      // Fixed semantic hues, independent of the accent.
      success: mode == DallyMode.light ? kLightSuccess : kDarkSuccess,
      danger: mode == DallyMode.light ? kLightDanger : kDarkDanger,
      // Computed, never authored: whichever of ink and white scores higher
      // against the resolved accent. Ink here is the *ink* — the Light ramp's
      // near-black — not the mode's own text colour, which in Dark is already
      // near-white and would leave a filled button with two white candidates.
      onAccent: bestForegroundOn(accent, ink: kLightRamp.textPrimary),
      minesweeperNumbers: mode == DallyMode.light ? _paperNumbers : _inkNumbers,
      scaleMid: ramp.scaleMid,
      scalePeak: ramp.scalePeak,
    );
  }

  /// Every palette a *preset* names, for the picker and for tests that want to
  /// walk the shipped set.
  static List<Palette> get all => [for (final p in presets) ofPreset(p)];

  /// Legacy lookup by preset id, still used by tests and by anything holding a
  /// stale `paletteId`. Unknown ids fall back to Ink.
  static Palette byId(String? id) => ofPreset(presetById(id) ?? fallback);
}
