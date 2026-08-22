import 'dart:ui';

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

    test('2048 ramp has 11 stops from surfaceAlt toward the peak', () {
      for (final p in DallyPalettes.all) {
        final scale = p.scale;
        expect(scale, hasLength(11), reason: '${p.name} ramp');
        expect(scale.first, p.surfaceAlt, reason: '${p.name} first stop is surfaceAlt');
      }
    });

    test('scale foreground flips with tile luminance', () {
      final ink = DallyPalettes.ink;
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
