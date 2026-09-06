import 'package:dally/core/theme/accents.dart';
import 'package:dally/core/theme/materials.dart';
import 'package:dally/core/theme/palettes.dart';
import 'package:flutter/painting.dart';
import 'package:flutter_test/flutter_test.dart';

/// The Toys material set is the fifth literal-colour exception
/// (`.agents/CLAUDE.md` §1, §11a.4). It is fenced by these:
/// accent-independent, visible on every ground, and never collapsed onto one
/// hue by a tinted preset.
void main() {
  double relativeLuminance(Color c) => c.computeLuminance();

  double contrast(Color a, Color b) {
    final la = relativeLuminance(a), lb = relativeLuminance(b);
    final hi = la > lb ? la : lb, lo = la > lb ? lb : la;
    return (hi + 0.05) / (lo + 0.05);
  }

  test('the set is full at eight and no more', () {
    expect(ToyMaterial.values.length, 8);
    for (final p in [kDarkMaterials, kLightMaterials]) {
      expect(p.entries.length, ToyMaterial.values.length);
    }
  });

  test('switching accent never moves a material', () {
    // This is what keeps the QA matrix at two resolved sets rather than thirty.
    final azure = DallyPalettes.build(mode: DallyMode.dark, accentId: 'azure', amoled: false);
    for (final accent in ['tide', 'ember', 'moss', 'violet']) {
      final other = DallyPalettes.build(mode: DallyMode.dark, accentId: accent, amoled: false);
      for (final m in ToyMaterial.values) {
        expect(other.materials.of(m), azure.materials.of(m), reason: '$accent / $m');
      }
    }
  });

  test('AMOLED reuses the Dark set unchanged', () {
    final dark = DallyPalettes.build(mode: DallyMode.dark, accentId: 'azure', amoled: false);
    final black = DallyPalettes.build(mode: DallyMode.dark, accentId: 'azure', amoled: true);
    for (final m in ToyMaterial.values) {
      expect(black.materials.of(m), dark.materials.of(m), reason: '$m');
    }
  });

  test('every material stays visible against every ground', () {
    // Materials are decorative fills and carry no text threshold, but Wall and
    // Smoke are the two that can approach the ground and neither may vanish.
    for (final p in DallyPalettes.all) {
      for (final m in ToyMaterial.values) {
        final c = p.materials.of(m);
        expect(contrast(c, p.bg), greaterThan(1.35),
            reason: '${p.name}: $m disappears into the background');
      }
    }
  });

  test('a tinted preset nudges the set without collapsing it', () {
    for (final p in DallyPalettes.all) {
      final hues = {
        for (final m in ToyMaterial.values)
          HSLColor.fromColor(p.materials.of(m)).hue.round(),
      };
      // Eight materials, and no preset may squash them into a single hue.
      expect(hues.length, greaterThan(5), reason: '${p.name} collapsed the set');
    }
  });

  test('the nudge is bounded — a material never becomes another one', () {
    for (final p in DallyPalettes.all) {
      final base = p.mode == DallyMode.light ? kLightMaterials : kDarkMaterials;
      for (final m in ToyMaterial.values) {
        final from = HSLColor.fromColor(base.of(m)).hue;
        final to = HSLColor.fromColor(p.materials.of(m)).hue;
        var delta = (to - from) % 360;
        if (delta > 180) delta -= 360;
        expect(delta.abs(), lessThanOrEqualTo(15), reason: '${p.name} / $m');
      }
    }
  });

  test('smoke is the only material you can see the ground through', () {
    for (final m in ToyMaterial.values) {
      expect(kDarkMaterials.alphaOf(m), m == ToyMaterial.smoke ? 0.7 : 1.0);
    }
  });
}
