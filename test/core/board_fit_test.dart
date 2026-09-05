import 'dart:ui';

import 'package:dally/core/util/board_fit.dart';
import 'package:flutter_test/flutter_test.dart';

/// The fitter is the one place a board learns its pixel size, so its maths is
/// tested here once rather than in every grid game.
void main() {
  group('fitBoard', () {
    test('takes the smaller of the two scales', () {
      // Width allows 40px cells, height only 30 — height binds.
      final fit = fitBoard(
          available: const Size(400, 300), cols: 10, rows: 10, floor: 1, cap: 999);
      expect(fit.cell, 30);
      expect(fit.width, 300);
      expect(fit.height, 300);
    });

    test('a 10 × 6 and a 6 × 10 both fill the same box', () {
      const box = Size(360, 480);
      final wide = fitBoard(available: box, cols: 10, rows: 6, floor: 1, cap: 999);
      final tall = fitBoard(available: box, cols: 6, rows: 10, floor: 1, cap: 999);
      expect(wide.cell, 36, reason: 'width binds on the wide board');
      expect(tall.cell, 48, reason: 'height binds on the tall board');
      // Neither overflows the box it was measured against.
      expect(wide.overflows(box), isFalse);
      expect(tall.overflows(box), isFalse);
    });

    test('landscape needs no special case — the axes just swap', () {
      final portrait =
          fitBoard(available: const Size(360, 640), cols: 10, rows: 6, floor: 1, cap: 999);
      final landscape =
          fitBoard(available: const Size(640, 360), cols: 10, rows: 6, floor: 1, cap: 999);
      expect(portrait.cell, 36);
      expect(landscape.cell, 60, reason: 'the same board at a larger cell');
    });

    test('the cap stops a small grid becoming enormous', () {
      final fit = fitBoard(available: const Size(900, 900), cols: 3, rows: 3, cap: 64);
      expect(fit.cell, 64);
    });

    test('the floor stops a large grid becoming untappable, and it then scrolls',
        () {
      // 12 × 12 in 280px wants a 23px cell; the floor holds it at 26 and the
      // board is then wider than the box it was given.
      const box = Size(280, 280);
      final fit = fitBoard(available: box, cols: 12, rows: 12, floor: 26, cap: 64);
      expect(fit.cell, 26);
      expect(fit.width, 312);
      expect(fit.overflows(box), isTrue, reason: 'it scrolls rather than shrinking');
      // The same board on a bigger phone clears the floor and does not scroll.
      final roomy =
          fitBoard(available: const Size(360, 640), cols: 12, rows: 12, floor: 26, cap: 64);
      expect(roomy.cell, 30);
      expect(roomy.overflows(const Size(360, 640)), isFalse);
    });

    test('padding comes off both axes before the divide', () {
      final bare =
          fitBoard(available: const Size(300, 300), cols: 10, rows: 10, floor: 1, cap: 999);
      final padded = fitBoard(
          available: const Size(300, 300), cols: 10, rows: 10, floor: 1, cap: 999, padding: 20);
      expect(bare.cell, 30);
      expect(padded.cell, 26);
    });

    test('a zero-sized box degrades to the floor rather than to nothing', () {
      final fit = fitBoard(available: Size.zero, cols: 5, rows: 5, floor: 26, cap: 64);
      expect(fit.cell, 26);
    });

    test('centring puts the leftover space evenly on both sides', () {
      final fit = fitBoard(
          available: const Size(400, 300), cols: 10, rows: 10, floor: 1, cap: 999);
      expect(fit.originIn(const Size(400, 300)), const Offset(50, 0));
    });

    test('an oversized board is pinned to the origin, never negative', () {
      final fit = fitBoard(
          available: const Size(100, 100), cols: 12, rows: 12, floor: 26, cap: 64);
      expect(fit.originIn(const Size(100, 100)), Offset.zero);
    });
  });
}
