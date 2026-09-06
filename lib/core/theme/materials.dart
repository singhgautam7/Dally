import 'package:flutter/painting.dart' show HSLColor;
import 'dart:ui';

/// The Toys material palette — the one bounded exception to mono-plus-accent
/// (`.agents/CLAUDE.md` §1 exception 5, §11a.4).
///
/// Sand is not water and water is not fire, so a powder sandbox cannot be
/// monochrome. These behave like data colours: they **identify a substance and
/// never decorate**. Nothing outside a toy canvas may use one — the material
/// selector's swatch is the only place a material colour leaves the canvas.
///
/// The set is **accent-independent** and resolved from the neutral ramp alone,
/// which keeps the QA matrix at two resolved sets rather than thirty. AMOLED
/// reuses the Dark set unchanged: the materials are already dark enough that a
/// true-black ground needs no separate values, and an unlit pixel is the point.
enum ToyMaterial {
  sand,
  water,
  wall,
  fire,

  /// The lighter tip value fire is drawn with — the single sanctioned two-tone,
  /// applied per cell by the sim, flat. No gradient, no blur, no glow.
  fireTip,
  oil,
  plant,

  /// The only material drawn at partial alpha, because it is the only one you
  /// should see the ground through.
  smoke,
}

/// A resolved material set. Eight is the cap and it is full — a new material
/// replaces one rather than extending the row.
class MaterialPalette {
  const MaterialPalette(this._byMaterial);

  final Map<ToyMaterial, Color> _byMaterial;

  Color of(ToyMaterial m) => _byMaterial[m] ?? const Color(0xFF808080);

  /// Smoke is the one partial-alpha material.
  double alphaOf(ToyMaterial m) => m == ToyMaterial.smoke ? 0.7 : 1.0;

  /// Every material, for tests and for the selector row.
  Iterable<MapEntry<ToyMaterial, Color>> get entries => _byMaterial.entries;

  /// Pulls the whole set a few degrees toward [hueDegrees], so a warm-tinted
  /// preset moves the canvas with its neutrals.
  ///
  /// This is a **relative** nudge, deliberately not the absolute hue the
  /// neutrals take (`tintNeutral`): setting the hue would collapse water, fire
  /// and plant onto the same colour, which is the opposite of what a material
  /// is for. At [amount] 0.08 the largest possible shift is about 14°.
  MaterialPalette nudgedToward(double? hueDegrees, {double amount = 0.08}) {
    if (hueDegrees == null) return this;
    return MaterialPalette({
      for (final e in _byMaterial.entries) e.key: _nudge(e.value, hueDegrees, amount),
    });
  }

  @override
  bool operator ==(Object other) =>
      other is MaterialPalette &&
      ToyMaterial.values.every((m) => other.of(m) == of(m));

  @override
  int get hashCode => Object.hashAll([for (final m in ToyMaterial.values) of(m)]);
}

Color _nudge(Color c, double hueDegrees, double amount) {
  final hsl = HSLColor.fromColor(c);
  var delta = (hueDegrees - hsl.hue) % 360;
  if (delta > 180) delta -= 360;
  return hsl.withHue((hsl.hue + delta * amount) % 360).toColor();
}

/// Dark ramps. Low saturation on purpose: a full canvas should read as a
/// cross-section of earth, not as a palette.
const kDarkMaterials = MaterialPalette({
  ToyMaterial.sand: Color(0xFFC9A227),
  ToyMaterial.water: Color(0xFF3E7CA8),
  ToyMaterial.wall: Color(0xFF6B7280),
  ToyMaterial.fire: Color(0xFFD1493F),
  ToyMaterial.fireTip: Color(0xFFE8A33D),
  ToyMaterial.oil: Color(0xFF57506E),
  ToyMaterial.plant: Color(0xFF4E9A5A),
  ToyMaterial.smoke: Color(0xFF9AA3AE),
});

/// The Light ramp darkens every material so it reads on paper.
const kLightMaterials = MaterialPalette({
  ToyMaterial.sand: Color(0xFFA8801A),
  ToyMaterial.water: Color(0xFF2F6489),
  ToyMaterial.wall: Color(0xFF4B5563),
  ToyMaterial.fire: Color(0xFFB03A31),
  ToyMaterial.fireTip: Color(0xFFC77F22),
  ToyMaterial.oil: Color(0xFF3A3550),
  ToyMaterial.plant: Color(0xFF3B7A45),
  ToyMaterial.smoke: Color(0xFF6B7480),
});
