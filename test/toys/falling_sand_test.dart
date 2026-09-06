import 'dart:typed_data';

import 'package:dally/core/util/dally_random.dart';
import 'package:dally/features/toys/falling_sand/logic/sand_grid.dart';
import 'package:dally/features/toys/falling_sand/ui/sand_painter.dart';
import 'package:flutter_test/flutter_test.dart';

/// The CA step is a pure function of (grid, rng), so every case here is exact.
/// Nothing touches a widget tree or a clock.
void main() {
  SandGrid grid({int cols = 9, int rows = 9, int seed = 1}) =>
      SandGrid(cols: cols, rows: rows, rng: DallyRandom.seeded(seed));

  /// A picture of the grid, one character a cell — easier to read than indices.
  List<String> render(SandGrid g) => [
        for (var r = 0; r < g.rows; r++)
          [
            for (var c = 0; c < g.cols; c++)
              switch (g.at(c, r)) {
                Substance.empty => '.',
                Substance.sand => 's',
                Substance.water => 'w',
                Substance.wall => '#',
                Substance.fire => 'f',
                Substance.oil => 'o',
                Substance.plant => 'p',
                Substance.smoke => '~',
              }
          ].join(),
      ];

  void put(SandGrid g, int c, int r, Substance s) => g.paint(c, r, s, 0);

  group('sand', () {
    test('falls straight down until something stops it', () {
      final g = grid();
      put(g, 4, 0, Substance.sand);
      for (var i = 0; i < 20; i++) {
        g.step();
      }
      expect(g.at(4, g.rows - 1), Substance.sand);
      expect(g.at(4, 0), Substance.empty);
    });

    test('piles rather than stacking in a tower', () {
      final g = grid(cols: 9, rows: 9, seed: 4);
      for (var i = 0; i < 12; i++) {
        put(g, 4, 0, Substance.sand);
        for (var k = 0; k < 12; k++) {
          g.step();
        }
      }
      // A column of twelve grains would be nine tall; a pile spreads instead.
      var tallest = 0;
      for (var c = 0; c < g.cols; c++) {
        var h = 0;
        for (var r = 0; r < g.rows; r++) {
          if (g.at(c, r) == Substance.sand) h++;
        }
        if (h > tallest) tallest = h;
      }
      expect(tallest, lessThan(9));
      var occupied = 0;
      for (var c = 0; c < g.cols; c++) {
        if (g.at(c, g.rows - 1) == Substance.sand) occupied++;
      }
      expect(occupied, greaterThan(1), reason: 'the pile has a base wider than one');
    });

    test('sinks through water, which is what makes water read as liquid', () {
      // A one-cell-wide column, so the water has nowhere to spread and the
      // only thing being tested is which of the two ends up on the bottom.
      final g = grid(cols: 1, rows: 6);
      for (var r = 3; r < 6; r++) {
        put(g, 0, r, Substance.water);
      }
      put(g, 0, 0, Substance.sand);
      for (var i = 0; i < 30; i++) {
        g.step();
      }
      expect(g.at(0, 5), Substance.sand, reason: 'sand ends up under the water');
    });
  });

  group('water', () {
    test('finds its level instead of standing in a column', () {
      final g = grid(cols: 9, rows: 6, seed: 3);
      for (var r = 0; r < 5; r++) {
        put(g, 4, r, Substance.water);
      }
      for (var i = 0; i < 40; i++) {
        g.step();
      }
      var widest = 0;
      for (var c = 0; c < g.cols; c++) {
        if (g.at(c, g.rows - 1) == Substance.water) widest++;
      }
      expect(widest, greaterThan(1), reason: 'water spread along the floor');
      expect(g.at(4, 0), Substance.empty);
    });

    test('a wall holds it', () {
      final g = grid(cols: 5, rows: 5);
      for (var r = 0; r < 5; r++) {
        put(g, 0, r, Substance.wall);
        put(g, 4, r, Substance.wall);
      }
      for (var c = 1; c < 4; c++) {
        put(g, c, 4, Substance.wall);
        put(g, c, 2, Substance.water);
      }
      for (var i = 0; i < 20; i++) {
        g.step();
      }
      var held = 0;
      for (var r = 0; r < 5; r++) {
        for (var c = 0; c < 5; c++) {
          if (g.at(c, r) == Substance.water) held++;
        }
      }
      expect(held, 3, reason: 'nothing leaked through the walls');
    });
  });

  group('oil floats, fire burns', () {
    test('oil ends up above water', () {
      final g = grid(cols: 3, rows: 8, seed: 6);
      for (var r = 4; r < 8; r++) {
        put(g, 1, r, Substance.oil);
      }
      put(g, 1, 0, Substance.water);
      for (var i = 0; i < 60; i++) {
        g.step();
      }
      var lowestOil = 0, lowestWater = 0;
      for (var r = 0; r < g.rows; r++) {
        for (var c = 0; c < g.cols; c++) {
          if (g.at(c, r) == Substance.oil) lowestOil = r;
          if (g.at(c, r) == Substance.water) lowestWater = r;
        }
      }
      expect(lowestWater, greaterThanOrEqualTo(lowestOil),
          reason: 'water sinks below the oil');
    });

    test('fire spreads along oil and leaves smoke', () {
      final g = grid(cols: 12, rows: 4, seed: 2);
      for (var c = 0; c < 12; c++) {
        put(g, c, 3, Substance.wall);
        put(g, c, 2, Substance.oil);
      }
      put(g, 0, 2, Substance.fire);
      for (var i = 0; i < 12; i++) {
        g.step();
      }
      var burning = 0;
      for (var c = 0; c < 12; c++) {
        if (g.at(c, 2) == Substance.fire) burning++;
      }
      expect(burning, greaterThan(1), reason: 'the fire ran along the oil');

      for (var i = 0; i < SandGrid.fireLife + 4; i++) {
        g.step();
      }
      var smoke = 0;
      for (var r = 0; r < g.rows; r++) {
        for (var c = 0; c < g.cols; c++) {
          if (g.at(c, r) == Substance.smoke) smoke++;
        }
      }
      expect(smoke, greaterThan(0), reason: 'burnt fuel leaves smoke');
    });

    test('water puts fire out', () {
      final g = grid(cols: 3, rows: 3);
      put(g, 1, 1, Substance.fire);
      put(g, 1, 0, Substance.water);
      g.step();
      expect(g.at(1, 1), isNot(Substance.fire));
    });

    test('a wall does nothing at all', () {
      final g = grid(cols: 3, rows: 3);
      put(g, 1, 0, Substance.wall);
      for (var i = 0; i < 10; i++) {
        g.step();
      }
      expect(g.at(1, 0), Substance.wall);
    });
  });

  test('smoke rises and eventually thins to nothing', () {
    final g = grid(cols: 5, rows: 6, seed: 5);
    put(g, 2, 5, Substance.smoke);
    for (var i = 0; i < 5; i++) {
      g.step();
    }
    var highest = g.rows;
    for (var r = 0; r < g.rows; r++) {
      for (var c = 0; c < g.cols; c++) {
        if (g.at(c, r) == Substance.smoke && r < highest) highest = r;
      }
    }
    expect(highest, lessThan(5), reason: 'smoke went up');

    for (var i = 0; i < SandGrid.smokeLife + 5; i++) {
      g.step();
    }
    for (var i = 0; i < g.cells.length; i++) {
      expect(g.cells[i], Substance.empty.index);
    }
  });

  test('plant creeps along damp cells', () {
    final g = grid(cols: 7, rows: 3, seed: 8);
    for (var c = 0; c < 7; c++) {
      put(g, c, 2, Substance.wall);
      put(g, c, 1, Substance.water);
    }
    put(g, 0, 1, Substance.plant);
    for (var i = 0; i < 400; i++) {
      g.step();
    }
    var plants = 0;
    for (var c = 0; c < 7; c++) {
      if (g.at(c, 1) == Substance.plant) plants++;
    }
    expect(plants, greaterThan(1), reason: 'the plant grew into the water');
  });

  group('determinism', () {
    test('the same grid and seed give the same next grid, exactly', () {
      List<String> run(int seed) {
        final g = grid(cols: 11, rows: 11, seed: seed);
        for (var c = 2; c < 9; c++) {
          g.paint(c, 1, Substance.sand, 1);
          g.paint(c, 4, Substance.water, 1);
        }
        g.paint(5, 8, Substance.wall, 2);
        g.paint(3, 6, Substance.fire, 1);
        for (var i = 0; i < 25; i++) {
          g.step();
        }
        return render(g);
      }

      expect(run(12), run(12));
    });

    test('a different seed takes a different path', () {
      List<String> run(int seed) {
        final g = grid(cols: 11, rows: 11, seed: seed);
        g.paint(5, 0, Substance.sand, 2);
        for (var i = 0; i < 30; i++) {
          g.step();
        }
        return render(g);
      }

      expect(run(1), isNot(run(999)));
    });

    test('nothing is created or destroyed by a plain fall', () {
      final g = grid(cols: 9, rows: 9, seed: 7);
      g.paint(4, 1, Substance.sand, 2);
      final before = g.cells.where((c) => c == Substance.sand.index).length;
      for (var i = 0; i < 40; i++) {
        g.step();
      }
      final after = g.cells.where((c) => c == Substance.sand.index).length;
      expect(after, before);
    });
  });

  group('the canvas', () {
    test('a brush paints a disc, and the eraser is the same path', () {
      final g = grid(cols: 11, rows: 11);
      g.paint(5, 5, Substance.wall, 3);
      expect(g.at(5, 5), Substance.wall);
      expect(g.at(5, 2), Substance.wall);
      expect(g.at(2, 2), Substance.empty, reason: 'a disc, not a square');
      g.paint(5, 5, Substance.empty, 3);
      expect(g.fillRatio, 0);
    });

    test('a painted edge never runs off the grid', () {
      final g = grid(cols: 5, rows: 5);
      g.paint(0, 0, Substance.sand, 4);
      g.paint(4, 4, Substance.sand, 4);
      expect(g.cells.length, 25);
    });

    test('clear empties it, and a snapshot brings it back', () {
      final g = grid(cols: 7, rows: 7);
      g.paint(3, 3, Substance.sand, 2);
      final cells = g.snapshot();
      final ages = g.ageSnapshot();
      expect(g.fillRatio, greaterThan(0));
      g.clear();
      expect(g.fillRatio, 0);
      g.restore(cells, ages);
      expect(g.fillRatio, greaterThan(0));
      expect(g.at(3, 3), Substance.sand);
    });

    test('a snapshot is a copy, not a view of the live buffer', () {
      final g = grid(cols: 5, rows: 5);
      g.paint(2, 2, Substance.sand, 1);
      final Uint8List snap = g.snapshot();
      g.clear();
      expect(snap.where((c) => c != 0).length, greaterThan(0));
    });
  });

  group('the brush', () {
    int filled(SandGrid g) => g.cells.where((c) => c != 0).length;

    /// The screen's rule: a fixed physical radius, converted to cells at the
    /// current grain, never below a single cell.
    int radiusFor(double cellDp, {double brushDp = 9}) =>
        (brushDp / cellDp).round().clamp(0, 8);

    test('a dab is small — a few cells, not a splodge', () {
      // The old floor was a five-cell blob at *any* grain, which on the chunky
      // grain is a 24dp splodge and far too coarse to place anything.
      for (final grain in SandGrain.values) {
        final g = grid(cols: 41, rows: 41);
        g.paint(20, 20, Substance.sand, radiusFor(grain.cellDp));
        expect(filled(g), lessThanOrEqualTo(13), reason: grain.label);
        expect(filled(g), greaterThan(0), reason: grain.label);
      }
    });

    test('it is the same physical size at either grain', () {
      // Grain is the only thing that decides precision, which is why the brush
      // needs no control of its own.
      for (final grain in SandGrain.values) {
        final r = radiusFor(grain.cellDp);
        final acrossDp = (2 * r + 1) * grain.cellDp;
        expect(acrossDp, inInclusiveRange(16, 28), reason: grain.label);
      }
    });

    test('the finest grain still paints a single cell when asked', () {
      final g = grid(cols: 21, rows: 21);
      g.paint(10, 10, Substance.sand, 0);
      expect(filled(g), 1);
      expect(g.at(10, 10), Substance.sand);
    });

    test('a stroke joins its samples rather than leaving a row of dots', () {
      // A finger reports a handful of positions; the gaps between them used to
      // stay empty at the smallest sizes.
      final g = grid(cols: 31, rows: 31);
      g.paintLine(2, 15, 28, 15, Substance.wall, 0);
      for (var c = 2; c <= 28; c++) {
        expect(g.at(c, 15), Substance.wall, reason: 'gap at column $c');
      }
      expect(filled(g), 27);
    });

    test('a diagonal stroke is continuous too', () {
      final g = grid(cols: 31, rows: 31);
      g.paintLine(3, 3, 27, 20, Substance.wall, 0);
      var seen = 0;
      for (var r = 0; r < g.rows; r++) {
        for (var c = 0; c < g.cols; c++) {
          if (g.at(c, r) == Substance.wall) seen++;
        }
      }
      expect(seen, greaterThanOrEqualTo(24));
      expect(g.at(3, 3), Substance.wall);
      expect(g.at(27, 20), Substance.wall);
    });

    test('a stroke that leaves the grid paints only what is inside it', () {
      final g = grid(cols: 11, rows: 11);
      g.paintLine(-40, 5, 40, 5, Substance.wall, 0);
      expect(filled(g), 11);
    });

    test('a zero-length stroke is one dab, not a hang', () {
      final g = grid(cols: 11, rows: 11);
      g.paintLine(5, 5, 5, 5, Substance.sand, 2);
      expect(filled(g), 13);
    });
  });
}
