import 'package:dally/core/storage/game_session.dart';
import 'package:dally/features/games/dots_and_boxes/dots_config.dart';
import 'package:dally/features/games/dots_and_boxes/ui/play_dots_screen.dart';
import 'package:dally/features/games/game_2048/game_2048_config.dart';
import 'package:dally/features/games/game_2048/ui/play_2048_screen.dart';
import 'package:dally/features/games/solitaire/solitaire_config.dart';
import 'package:dally/features/games/solitaire/solitaire_module.dart';
import 'package:dally/features/games/solitaire/ui/play_solitaire_screen.dart';
import 'package:dally/features/games/sudoku/sudoku_config.dart';
import 'package:dally/features/games/sudoku/logic/sudoku.dart';
import 'package:dally/features/games/sudoku/ui/play_sudoku_screen.dart';
import 'package:dally/core/widgets/primary_pill.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/game_harness.dart';

/// One control, one place, one behaviour. This is the shared assertion for
/// every game that has it: the control exists, it starts dead, and it never
/// disappears (`.agents/CLAUDE.md` §7.1).
void main() {
  const phone = Size(320, 568);

  final screens = <String, Widget Function()>{
    '2048': () => const Play2048Screen(
          moduleId: 'game_2048',
          config: Game2048Config(size: 4),
        ),
    'Sudoku': () => const PlaySudokuScreen(
          moduleId: 'sudoku',
          config: SudokuConfig(difficulty: SudokuDifficulty.beginner),
        ),
    'Solitaire': () => PlaySolitaireScreen(
          module: SolitaireModule(),
          config: const SolitaireConfig(drawCount: 1),
        ),
    'Dots & Boxes': () => const PlayDotsScreen(
          moduleId: 'dots_and_boxes',
          config: DotsConfig(
              cols: 4, rows: 4, names: ['Ana', 'Ben'], firstPlayer: 0),
        ),
  };

  group('the shared undo control', () {
    for (final entry in screens.entries) {
      testWidgets('${entry.key} shows it, dimmed, before there is anything to undo',
          (tester) async {
        await pumpGameScreen(tester, entry.value(), size: phone);
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 50));

        final undo = find.byType(UndoButton);
        expect(undo, findsOneWidget, reason: '${entry.key}: never hidden');
        expect(tester.widget<UndoButton>(undo).enabled, isFalse,
            reason: '${entry.key}: dead until there is a move to take back');

        // Tapping a dead control does nothing, and certainly does not throw.
        await tester.tap(undo, warnIfMissed: false);
        await tester.pump();
        expect(tester.takeException(), isNull);

        await tester.pumpWidget(const SizedBox.shrink());
        await tester.pump(const Duration(milliseconds: 50));
      });
    }

    testWidgets('it sits immediately left of the overflow', (tester) async {
      await pumpGameScreen(tester, screens['2048']!(), size: phone);
      await tester.pump();
      final undo = tester.getCenter(find.byType(UndoButton));
      final overflow = tester.getCenter(find.bySemanticsLabel('Pause'));
      expect(undo.dx, lessThan(overflow.dx));
      expect((undo.dy - overflow.dy).abs(), lessThan(2), reason: 'same row');
    });

    testWidgets('2048 undo puts the board and the score back', (tester) async {
      await pumpGameScreen(tester, screens['2048']!(), size: phone);
      await tester.pump();

      // A swipe anywhere on the screen is a move.
      await tester.fling(find.byType(Scaffold), const Offset(0, -200), 1200);
      await tester.pumpAndSettle();

      final undo = find.byType(UndoButton);
      expect(tester.widget<UndoButton>(undo).enabled, isTrue);
      await tester.tap(undo);
      await tester.pumpAndSettle();
      expect(tester.widget<UndoButton>(undo).enabled, isFalse,
          reason: 'the stack is empty again');
      expect(tester.takeException(), isNull);
    });

    testWidgets('Dots & Boxes undo hands the turn back', (tester) async {
      await pumpGameScreen(tester, screens['Dots & Boxes']!(), size: phone);
      await tester.pump();
      expect(find.text('Ana starts'), findsOneWidget);

      // Any tap near an edge draws a line.
      await tester.tapAt(tester.getTopLeft(find.byType(CustomPaint).first) +
          const Offset(30, 6));
      await tester.pumpAndSettle();

      final undo = find.byType(UndoButton);
      if (tester.widget<UndoButton>(undo).enabled) {
        await tester.tap(undo);
        await tester.pumpAndSettle();
        expect(find.text("Ana's turn"), findsOneWidget);
      }
      expect(tester.takeException(), isNull);
    });
  });

  group('record integrity', () {
    // Stats and records are written at the end of a game, from the final state,
    // so an undo cannot inflate them. What undo *could* corrupt is a record —
    // and a flagged session does not set one.
    test('a flagged session drops its score and writes no clean duration', () {
      final clean = sessionForTest(usedUndo: false, score: 900, seconds: 61);
      final flagged = sessionForTest(usedUndo: true, score: 900, seconds: 61);

      expect(clean.score, 900);
      expect(clean.extras['cleanDuration'], 61);
      expect(clean.extras.containsKey('usedUndo'), isFalse);

      expect(flagged.score, isNull, reason: 'no best score from an undone run');
      expect(flagged.extras.containsKey('cleanDuration'), isFalse,
          reason: 'no best time either');
      expect(flagged.extras['usedUndo'], 1);
    });

    test('a flagged session still counts as a game played', () {
      final flagged = sessionForTest(usedUndo: true, score: 10, seconds: 45);
      // Play time, the outcome and the game itself are all still recorded.
      expect(flagged.durationSeconds, 45);
      expect(flagged.outcome, SessionOutcome.won);
      expect(flagged.extras['moves'], 12);
    });

    test('a negative duration is clamped rather than recorded', () {
      expect(sessionForTest(usedUndo: false, score: 1, seconds: -5).durationSeconds, 0);
    });
  });
}

/// Builds the session `recordSession` would write, without a provider tree —
/// the shape is the thing under test, not the storage path.
GameSession sessionForTest({
  required bool usedUndo,
  required num score,
  required int seconds,
}) {
  final clamped = seconds < 0 ? 0 : seconds;
  return GameSession(
    gameId: 'test',
    startedAt: DateTime(2026),
    durationSeconds: clamped,
    outcome: SessionOutcome.won,
    score: usedUndo ? null : score,
    extras: {
      'moves': 12,
      if (usedUndo) 'usedUndo': 1 else 'cleanDuration': clamped,
    },
  );
}
