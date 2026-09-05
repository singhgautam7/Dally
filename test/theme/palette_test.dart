import 'dart:ui';

import 'package:dally/core/theme/accents.dart';
import 'package:dally/core/theme/palette.dart';
import 'package:dally/core/theme/palettes.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('DallyPalettes', () {
    test('ships six standard and two premium palettes', () {
      expect(DallyPalettes.standard, hasLength(6));
      expect(DallyPalettes.premium, hasLength(2));
      expect(DallyPalettes.all, hasLength(8));
    });

    test('ids are unique and stable', () {
      final ids = DallyPalettes.all.map((p) => p.id).toSet();
      expect(ids, hasLength(8));
      expect(ids, containsAll(['ink', 'ember', 'tide', 'paper', 'meadow', 'blush', 'void', 'neon']));
    });

    test('byId falls back to Ink for unknown ids', () {
      expect(DallyPalettes.byId('nope').id, 'ink');
      expect(DallyPalettes.byId(null).id, 'ink');
      expect(DallyPalettes.byId('neon').id, 'neon');
    });

    test('every preset is expressible as a mode × accent × amoled triple', () {
      for (final preset in DallyPalettes.presets) {
        final derived = DallyPalettes.palette(
          mode: preset.mode,
          accentId: preset.accentId,
          amoled: preset.amoled,
        );
        // The triple names the preset back — which is what lets the screen
        // derive the name instead of storing it.
        expect(derived.id, preset.id, reason: preset.name);
        expect(derived.name, preset.name);
      }
    });

    test('a triple that matches no preset is Custom', () {
      final p = DallyPalettes.palette(mode: DallyMode.dark, accentId: 'citron', amoled: true);
      expect(p.id, 'custom');
      expect(p.name, 'Custom');
    });

    test('AMOLED is ignored in Light, so a stale flag cannot invert a palette', () {
      final light = DallyPalettes.palette(mode: DallyMode.light, accentId: 'azure', amoled: true);
      expect(light.isAmoled, isFalse);
      expect(light.bg, kLightRamp.bg);
    });

    test('the 2048 ramp is accent-independent', () {
      final a = DallyPalettes.palette(mode: DallyMode.dark, accentId: 'azure', amoled: false);
      final b = DallyPalettes.palette(mode: DallyMode.dark, accentId: 'coral', amoled: false);
      expect(a.scale, b.scale);
      expect(a.success, b.success);
      expect(a.danger, b.danger);
    });

    test('Ink and Paper keep the exact ramps they shipped with', () {
      // The 2048 values are on the "does not change" list for phase 21.
      expect(DallyPalettes.byId('ink').scale[8], const Color(0xFF6EA8FE));
      expect(DallyPalettes.byId('paper').scale[8], const Color(0xFF2563EB));
    });

    test('2048 ramp has 11 stops from surfaceAlt toward the peak', () {
      for (final p in DallyPalettes.all) {
        final scale = p.scale;
        expect(scale, hasLength(11), reason: '${p.name} ramp');
        expect(scale.first, p.surfaceAlt, reason: '${p.name} first stop is surfaceAlt');
      }
    });

    test('scale foreground flips with tile luminance', () {
      final ink = DallyPalettes.byId('ink');
      // A bright top tile takes dark ink; a dark low tile takes light ink.
      final darkText = ink.scaleForeground(const Color(0xFFFFFFFF));
      final lightText = ink.scaleForeground(const Color(0xFF101010));
      expect(darkText.computeLuminance() < lightText.computeLuminance(), isTrue);
    });

    test('minesweeper number sets have all eight digits', () {
      for (final p in DallyPalettes.all) {
        expect(p.minesweeperNumbers, hasLength(8), reason: p.name);
      }
    });

    test('chess light piece is always lighter than the dark (accent) piece', () {
      for (final p in DallyPalettes.all) {
        expect(
          Palette.pieceLight.computeLuminance() > p.pieceDark.computeLuminance(),
          isTrue,
          reason: '${p.name}: light piece must read lighter than the dark side',
        );
      }
    });
  });
}
