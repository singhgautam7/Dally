import 'dart:math' as math;
import 'dart:ui';

import 'package:flutter/painting.dart' show HSLColor;

/// The three independent inputs a palette is built from
/// (`Dally Theme System.dc.html`, phase 21).
///
/// A palette used to be a literal token set looked up by id. It is now
/// `palette(mode, accentId, amoled)` — a pure function of these three axes, so
/// ten accents in two modes with one toggle produce thirty palettes from one
/// derivation, and the eight shipped presets survive as named triples on top.

/// Axis 1 — chooses the neutral ramp. Nothing else on the screen depends on it.
enum DallyMode { light, dark }

DallyMode modeFromId(String? id) => id == 'light' ? DallyMode.light : DallyMode.dark;

extension DallyModeX on DallyMode {
  String get id => name;
  String get label => this == DallyMode.light ? 'Light' : 'Dark';
  bool get isDark => this == DallyMode.dark;
}

/// Axis 2 — an accent is an *identity*, not a hex.
///
/// It resolves to a darker, more saturated value in Light and a lighter one in
/// Dark, because a single hex cannot carry 4.5:1 against both a near-white and
/// a near-black background: one that cleared both would sit in the middle of
/// the lightness range, where every hue turns muddy and all ten converge on the
/// same greyed pastel.
class DallyAccent {
  const DallyAccent({
    required this.id,
    required this.name,
    required this.light,
    required this.dark,
  });

  /// Stable key persisted to storage; never localise or reorder.
  final String id;
  final String name;

  /// Resolved value in Light mode.
  final Color light;

  /// Resolved value in Dark mode. AMOLED reuses it unchanged — a blacker
  /// background only raises its contrast.
  final Color dark;

  Color resolve(DallyMode mode) => mode == DallyMode.light ? light : dark;
}

/// The ten accent identities, in picker order — two rows of five.
///
/// Neon is listed last on purpose: `#4DFF8F` is a Dark-mode idea, and in Light
/// it resolves to a deep bottle green. It is still offered in Light, because
/// hiding an accent by mode is a worse surprise than a quiet one.
const List<DallyAccent> kDallyAccents = [
  DallyAccent(id: 'azure', name: 'Azure', light: Color(0xFF1D66D6), dark: Color(0xFF6EA8FE)),
  DallyAccent(id: 'ember', name: 'Ember', light: Color(0xFFA85B00), dark: Color(0xFFF5A524)),
  DallyAccent(id: 'tide', name: 'Tide', light: Color(0xFF00706B), dark: Color(0xFF3ECFC4)),
  DallyAccent(id: 'meadow', name: 'Meadow', light: Color(0xFF2F7233), dark: Color(0xFF68C46E)),
  DallyAccent(id: 'blush', name: 'Blush', light: Color(0xFFB93A6E), dark: Color(0xFFF284AF)),
  DallyAccent(id: 'iris', name: 'Iris', light: Color(0xFF6B45CE), dark: Color(0xFFB197FA)),
  DallyAccent(id: 'coral', name: 'Coral', light: Color(0xFFBE3E2E), dark: Color(0xFFFF8A72)),
  DallyAccent(id: 'citron', name: 'Citron', light: Color(0xFF6B7000), dark: Color(0xFFC8D63C)),
  DallyAccent(id: 'slate', name: 'Slate', light: Color(0xFF4A5A73), dark: Color(0xFF9FB4D0)),
  DallyAccent(id: 'neon', name: 'Neon', light: Color(0xFF0F7A2E), dark: Color(0xFF4DFF8F)),
];

/// The default accent — Ink's, and the first-launch default.
const String kDefaultAccentId = 'azure';

DallyAccent accentById(String? id) {
  for (final a in kDallyAccents) {
    if (a.id == id) return a;
  }
  return kDallyAccents.first;
}

/// Axis 3 is a plain `bool amoled`, Dark only. It drops the background to true
/// black and the surfaces almost to it; text lifts slightly to hold the extra
/// range, and the accent is untouched. In Light it is disabled with the reason
/// stated, never hidden.

/// The neutral ramp: seven accent-independent tokens, one set per mode state.
///
/// These are the shipped Paper, Ink and Void neutrals, promoted from three
/// palettes into the three ramps every palette now uses — so a user on Ink
/// today sees no pixel move. The one edit is [textFaint], which measured 2.30
/// in Light and 2.99 in Dark and is now 2.99 / 3.84.
class NeutralRamp {
  const NeutralRamp({
    required this.bg,
    required this.surface,
    required this.surfaceAlt,
    required this.border,
    required this.textPrimary,
    required this.textMuted,
    required this.textFaint,
    required this.scaleMid,
    required this.scalePeak,
  });

  final Color bg;
  final Color surface;
  final Color surfaceAlt;
  final Color border;
  final Color textPrimary;
  final Color textMuted;
  final Color textFaint;

  /// The 2048 ramp's mid and top stops. **Accent-independent by design**:
  /// eleven tinted steps plus an accent is twelve colours fighting. Three
  /// authored sets, one per ramp; the measured requirement is the numeral on
  /// the tile, not the tile on the background.
  final Color scaleMid;
  final Color scalePeak;
}

/// Light — warm neutral.
const NeutralRamp kLightRamp = NeutralRamp(
  bg: Color(0xFFF7F5F0),
  surface: Color(0xFFFFFFFF),
  surfaceAlt: Color(0xFFF1EFE9),
  border: Color(0xFFDED9CE),
  textPrimary: Color(0xFF1E1B16),
  textMuted: Color(0xFF6B655B),
  textFaint: Color(0xFF948E82),
  scaleMid: Color(0xFF2563EB),
  scalePeak: Color(0xFF16409E),
);

/// Dark — cool neutral.
const NeutralRamp kDarkRamp = NeutralRamp(
  bg: Color(0xFF0E0F12),
  surface: Color(0xFF16181D),
  surfaceAlt: Color(0xFF1C1F26),
  border: Color(0xFF2A2E36),
  textPrimary: Color(0xFFECEDEF),
  textMuted: Color(0xFF9AA0AB),
  textFaint: Color(0xFF6A7079),
  scaleMid: Color(0xFF6EA8FE),
  scalePeak: Color(0xFFB4D4FF),
);

/// Dark + AMOLED — true black.
const NeutralRamp kAmoledRamp = NeutralRamp(
  bg: Color(0xFF000000),
  surface: Color(0xFF0A0B0D),
  surfaceAlt: Color(0xFF101216),
  border: Color(0xFF23262D),
  textPrimary: Color(0xFFF2F3F5),
  textMuted: Color(0xFF9AA0AB),
  textFaint: Color(0xFF6A7079),
  scaleMid: Color(0xFF7AA2FF),
  scalePeak: Color(0xFFB4D4FF),
);

NeutralRamp rampFor(DallyMode mode, bool amoled) {
  if (mode == DallyMode.light) return kLightRamp;
  return amoled ? kAmoledRamp : kDarkRamp;
}

/// A neutral tint — a hue rotation applied at **constant lightness**, so every
/// contrast figure in the audit holds for the tinted variant.
///
/// Presets only. Custom mode does not expose it: two axes are a choice, three
/// are a colour picker, and a colour picker is how a minimal app stops looking
/// like one. The tints stay the thing a preset gives you that building it
/// yourself does not.
enum NeutralTint {
  /// The ramp's own values — warm in Light, cool in Dark.
  canonical,

  /// Warm neutrals over the cool Dark ramp (Ember).
  warm,

  /// Neutrals pulled a step toward the accent hue (Meadow, Blush).
  towardAccent,
}

/// Fixed semantic hues, two values each — deliberately independent of the
/// accent, because a Coral accent must not make every error message ambiguous.
const Color kLightSuccess = Color(0xFF2A7A46);
const Color kLightDanger = Color(0xFFC0392B);
const Color kDarkSuccess = Color(0xFF4FBE7B);
const Color kDarkDanger = Color(0xFFE5534B);

/// Settings › Accessibility › High-contrast text promotes the two quiet text
/// weights a step: faint to 3.41 / 4.56 and muted with it.
const Color kLightFaintHC = Color(0xFF8A8478);
const Color kDarkFaintHC = Color(0xFF767C86);
const Color kLightMutedHC = Color(0xFF57524A);
const Color kDarkMutedHC = Color(0xFFB4BAC4);

// ── Colour maths ───────────────────────────────────────────────────────────

/// WCAG relative luminance of an opaque colour.
double relativeLuminance(Color c) {
  double channel(double v) =>
      v <= 0.03928 ? v / 12.92 : math.pow((v + 0.055) / 1.055, 2.4).toDouble();
  return 0.2126 * channel(c.r) + 0.7152 * channel(c.g) + 0.0722 * channel(c.b);
}

/// WCAG contrast ratio between two opaque colours, 1.0 … 21.0.
///
/// Shipped **in the app**, not in a spreadsheet, so the contrast matrix test
/// can walk every mode × accent × amoled triple and fail the build if an
/// eleventh accent is added without measuring it.
double contrastRatio(Color a, Color b) {
  final la = relativeLuminance(a), lb = relativeLuminance(b);
  final hi = math.max(la, lb), lo = math.min(la, lb);
  return (hi + 0.05) / (lo + 0.05);
}

/// Ink and white are the only two candidates for a label on a filled accent;
/// the provider picks whichever scores higher. In practice Light accents take
/// white and Dark accents take ink, so a primary button inverts with the mode.
Color bestForegroundOn(Color fill, {required Color ink}) =>
    contrastRatio(fill, ink) >= contrastRatio(fill, const Color(0xFFFFFFFF))
        ? ink
        : const Color(0xFFFFFFFF);

/// Rotates [c] to [hueDegrees] at constant HSL lightness, scaling its
/// saturation by [saturationScale]. Neutrals carry very little saturation, so
/// the luminance shift is small — but the contrast matrix test asserts that
/// rather than assuming it.
Color tintNeutral(Color c, double hueDegrees, double saturationScale) {
  final hsl = HSLColor.fromColor(c);
  if (hsl.saturation < 0.002 && saturationScale <= 1) return c;
  final saturation = (hsl.saturation * saturationScale).clamp(0.0, 1.0);
  return hsl.withHue(hueDegrees % 360).withSaturation(saturation).toColor();
}
