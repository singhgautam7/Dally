import 'dart:ui';

import 'package:dally/core/game/player_identity.dart';
import 'package:dally/core/theme/accents.dart';
import 'package:dally/core/theme/palettes.dart';
import 'package:flutter_test/flutter_test.dart';

/// The contrast function ships in the app, not in a spreadsheet, and this walks
/// the whole matrix with it — so an eleventh accent cannot be added without
/// being measured (`Dally Theme System.dc.html` §21.5).
///
/// Thresholds: **4.5:1** for anything with text in it, **3:1** for a graphical
/// object that carries meaning on its own (the player tokens), and no threshold
/// for hairlines and tile fills, which are declared decorative and are held to
/// the rule that they never carry state alone.
void main() {
  const textThreshold = 4.5;
  const objectThreshold = 3.0;

  /// Every combination the three axes produce: ten accents in Light, ten in
  /// Dark, ten in Dark with AMOLED on.
  Iterable<(String, dynamic)> everyTriple() sync* {
    for (final mode in DallyMode.values) {
      for (final accent in kDallyAccents) {
        for (final amoled in const [false, true]) {
          if (mode == DallyMode.light && amoled) continue; // Dark only.
          yield (
            '${mode.name} · ${accent.name}${amoled ? ' · amoled' : ''}',
            DallyPalettes.palette(mode: mode, accentId: accent.id, amoled: amoled),
          );
        }
      }
    }
  }

  test('thirty combinations, and thirty is what the axes produce', () {
    expect(everyTriple().length, 30);
  });

  group('every mode × accent × amoled triple', () {
    for (final (label, p) in everyTriple()) {
      test('$label clears the thresholds', () {
        expect(contrastRatio(p.accent, p.bg), greaterThanOrEqualTo(textThreshold),
            reason: '$label: accent on background');
        expect(contrastRatio(p.onAccent, p.accent), greaterThanOrEqualTo(textThreshold),
            reason: '$label: label on a filled accent');
        expect(contrastRatio(p.success, p.bg), greaterThanOrEqualTo(textThreshold),
            reason: '$label: success');
        expect(contrastRatio(p.danger, p.bg), greaterThanOrEqualTo(textThreshold),
            reason: '$label: danger');
        expect(contrastRatio(p.textPrimary, p.bg), greaterThanOrEqualTo(textThreshold),
            reason: '$label: textPrimary');
        expect(contrastRatio(p.textMuted, p.bg), greaterThanOrEqualTo(textThreshold),
            reason: '$label: textMuted');
      });
    }
  });

  group('the eight presets, tint included', () {
    // A tint is a hue rotation at constant lightness, so every figure above
    // should hold for the tinted variant — but the build asserts that rather
    // than assuming it.
    for (final preset in DallyPalettes.presets) {
      test('${preset.name} holds its ratios under its neutral tint', () {
        final p = DallyPalettes.ofPreset(preset);
        expect(contrastRatio(p.accent, p.bg), greaterThanOrEqualTo(textThreshold));
        expect(contrastRatio(p.onAccent, p.accent), greaterThanOrEqualTo(textThreshold));
        expect(contrastRatio(p.textPrimary, p.bg), greaterThanOrEqualTo(textThreshold));
        expect(contrastRatio(p.textMuted, p.bg), greaterThanOrEqualTo(textThreshold));
        expect(contrastRatio(p.success, p.bg), greaterThanOrEqualTo(textThreshold));
        expect(contrastRatio(p.danger, p.bg), greaterThanOrEqualTo(textThreshold));
      });
    }
  });

  group('textFaint', () {
    // It failed the first measurement at 2.30 / 2.99 and both values moved.
    // Light stays the lower of the two: the warm ramp has less headroom before
    // faint stops reading as faint.
    test('clears 3:1 in Dark and 2.9 in Light, and never regresses', () {
      final light = DallyPalettes.palette(
          mode: DallyMode.light, accentId: 'azure', amoled: false);
      final dark =
          DallyPalettes.palette(mode: DallyMode.dark, accentId: 'azure', amoled: false);
      final amoled =
          DallyPalettes.palette(mode: DallyMode.dark, accentId: 'azure', amoled: true);
      expect(contrastRatio(light.textFaint, light.bg), greaterThanOrEqualTo(2.9));
      expect(contrastRatio(dark.textFaint, dark.bg), greaterThanOrEqualTo(3.0));
      expect(contrastRatio(amoled.textFaint, amoled.bg), greaterThanOrEqualTo(4.0));
    });

    test('high-contrast text promotes faint and muted together', () {
      for (final mode in DallyMode.values) {
        final plain =
            DallyPalettes.palette(mode: mode, accentId: 'azure', amoled: false);
        final hc = DallyPalettes.palette(
            mode: mode, accentId: 'azure', amoled: false, highContrastText: true);
        expect(contrastRatio(hc.textFaint, hc.bg),
            greaterThan(contrastRatio(plain.textFaint, plain.bg)),
            reason: '${mode.name}: faint');
        expect(contrastRatio(hc.textMuted, hc.bg),
            greaterThanOrEqualTo(textThreshold),
            reason: '${mode.name}: muted stays legible');
      }
    });
  });

  group('player identity', () {
    // The four fixed fills measure 3.08 / 2.03 / 3.34 / 2.49 on the Light
    // background — two of the four under 3:1. The mandatory hairline is what
    // carries the edge, and the fills themselves never move.
    test('the Light hairline lifts every seat over 3:1', () {
      final light =
          DallyPalettes.palette(mode: DallyMode.light, accentId: 'azure', amoled: false);
      for (final id in kPlayerIdentities) {
        expect(contrastRatio(identityOutline(id), light.bg),
            greaterThanOrEqualTo(objectThreshold),
            reason: '${id.name}: hairline on the light background');
      }
    });

    test('the fills are unchanged', () {
      expect(kPlayerIdentities.map((i) => i.color).toList(), const [
        Color(0xFFE05252),
        Color(0xFF3FA45B),
        Color(0xFF4A7FE0),
        Color(0xFFD9A21B),
      ]);
    });

    test('every seat clears 3:1 against the dark backgrounds on the fill alone',
        () {
      for (final amoled in const [false, true]) {
        final p = DallyPalettes.palette(
            mode: DallyMode.dark, accentId: 'azure', amoled: amoled);
        for (final id in kPlayerIdentities) {
          expect(contrastRatio(id.color, p.bg), greaterThanOrEqualTo(objectThreshold),
              reason: '${id.name} on ${amoled ? 'amoled' : 'dark'}');
        }
      }
    });
  });

  group('the 2048 ramp', () {
    // Steps read low against the background because they are *tile fills*. What
    // is measured is the numeral on the tile.
    test('every numeral clears 4.5:1 on its own tile', () {
      for (final (label, p) in everyTriple()) {
        for (final tile in p.scale) {
          expect(contrastRatio(p.scaleForeground(tile), tile),
              greaterThanOrEqualTo(textThreshold),
              reason: '$label: numeral on a ramp tile');
        }
      }
    });
  });

  group('the move-hint ordering', () {
    test('a legal-move marker is always weaker than the selected square', () {
      for (final (label, p) in everyTriple()) {
        expect(p.moveHint.a, lessThan(p.selectedTint.a), reason: label);
        expect(p.lastMoveTint.a, lessThan(p.moveHint.a), reason: label);
      }
    });
  });
}
