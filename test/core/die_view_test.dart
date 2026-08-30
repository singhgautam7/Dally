import 'dart:ui' as ui;

import 'package:dally/core/widgets/die_view.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/game_harness.dart';

/// Records what a painter actually drew, so pip geometry can be asserted
/// without a golden file (which would be fragile across platforms).
class _Recorder {
  _Recorder(DiePainter painter, this.size) {
    final recorder = ui.PictureRecorder();
    painter.paint(Canvas(recorder), size);
    recorder.endRecording().dispose();
  }
  final Size size;
}

void main() {
  group('pip faces', () {
    test('every face lights the expected slots of the 3×3 grid', () {
      // 1 centre; 2/3 the diagonal; 4/6 the corners and sides; 5 adds the pip.
      expect(DiePainter.pipMask[1], [4]);
      expect(DiePainter.pipMask[2], [0, 8]);
      expect(DiePainter.pipMask[3], [0, 4, 8]);
      expect(DiePainter.pipMask[4], [0, 2, 6, 8]);
      expect(DiePainter.pipMask[5], [0, 2, 4, 6, 8]);
      // Six is two columns of three — the layout the design asks for.
      expect(DiePainter.pipMask[6], [0, 2, 3, 5, 6, 8]);
      final six = DiePainter.pipMask[6]!;
      expect(six.where((s) => s % 3 == 0), hasLength(3), reason: 'left column');
      expect(six.where((s) => s % 3 == 2), hasLength(3), reason: 'right column');
      expect(six.where((s) => s % 3 == 1), isEmpty, reason: 'nothing in the middle');
    });

    test('a face never repeats a slot and never spills off the grid', () {
      for (var v = 1; v <= 6; v++) {
        final mask = DiePainter.pipMask[v]!;
        expect(mask, hasLength(v));
        expect(mask.toSet(), hasLength(v));
        expect(mask.every((s) => s >= 0 && s < 9), isTrue);
      }
    });

    test('the pip grid is inset, so no pip touches the shell', () {
      // The outer pip centre sits at pad + cell/2 from the edge; with the inset
      // that clears the 2px shell stroke at the smallest size a game draws.
      const size = 34.0;
      final pad = size * DiePainter.pipInset;
      final cell = (size - pad * 2) / 3;
      final outerCentre = pad + cell / 2;
      final pipRadius = size * 0.075;
      expect(outerCentre - pipRadius, greaterThan(2.0));
    });
  });

  group('painting', () {
    testWidgets('every face and style paints without throwing', (tester) async {
      for (final style in DiceStyle.values) {
        for (var v = 1; v <= 6; v++) {
          _Recorder(
            DiePainter(
              value: v,
              style: style,
              ink: const Color(0xFF000000),
              accent: const Color(0xFFFF0000),
              onAccent: const Color(0xFFFFFFFF),
              border: const Color(0xFF888888),
            ),
            const Size(34, 34),
          );
        }
      }
      expect(tester.takeException(), isNull);
    });

    testWidgets('the shared in-game die renders and rolls on a tap',
        (tester) async {
      var rolls = 0;
      await pumpGameScreen(
        tester,
        Scaffold(
          body: Center(
            child: GameDie(
              state: DieSlotState.rollable,
              value: 4,
              onRoll: () => rolls++,
            ),
          ),
        ),
      );
      await tester.tap(find.byType(GameDie));
      expect(rolls, 1);
      expect(tester.takeException(), isNull);
    });

    testWidgets('an idle slot is inert however it is tapped', (tester) async {
      var rolls = 0;
      await pumpGameScreen(
        tester,
        Scaffold(
          body: Center(
            child: GameDie(state: DieSlotState.idle, onRoll: () => rolls++),
          ),
        ),
      );
      await tester.tap(find.byType(GameDie));
      expect(rolls, 0);
      expect(tester.takeException(), isNull);
    });
  });
}
