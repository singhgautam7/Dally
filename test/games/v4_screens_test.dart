import 'package:dally/core/game/game_registry.dart';
import 'package:dally/features/games/undercover/data/undercover_words.dart';
import 'package:dally/core/widgets/primary_pill.dart';
import 'package:dally/features/games/four_in_a_row/four_config.dart';
import 'package:dally/features/games/four_in_a_row/four_module.dart';
import 'package:dally/features/games/four_in_a_row/ui/play_four_screen.dart';
import 'package:dally/features/games/frog_hop/frog_hop_config.dart';
import 'package:dally/features/games/frog_hop/frog_hop_module.dart';
import 'package:dally/features/games/frog_hop/ui/play_frog_screen.dart';
import 'package:dally/features/games/arcade/ui/play_updraft_screen.dart';
import 'package:dally/features/games/undercover/logic/word_pair.dart';
import 'package:dally/features/games/undercover/ui/play_undercover_screen.dart';
import 'package:dally/features/games/undercover/undercover_config.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/game_harness.dart';

/// Every new board is laid out at 320×568 — the size where boards overflow —
/// and again at a tablet, because the v4 batch is the one that added a
/// resolution bug.
void main() {
  const phone = Size(320, 568);
  const tablet = Size(834, 1112);
  const landscape = Size(640, 360);

  Widget frog({FrogMode mode = FrogMode.race, int perSide = 3}) => PlayFrogScreen(
        module: FrogHopModule(),
        config: FrogHopConfig(perSide: perSide, mode: mode),
      );

  Widget four({int cols = 7, int rows = 6}) => PlayFourScreen(
        module: FourInARowModule(),
        config: FourConfig(
          cols: cols,
          rows: rows,
          names: const ['Mira', 'Tom'],
          firstPlayer: 0,
        ),
      );

  Widget undercover() => const PlayUndercoverScreen(
        moduleId: 'undercover',
        config: UndercoverConfig(
          names: ['Ravi', 'Ana', 'Priya', 'Noor', 'Sam'],
          undercover: 1,
          mrWhite: true,
          difficulty: WordDifficulty.normal,
          voting: UndercoverVoting.open,
        ),
      );

  group('Frog Hop', () {
    for (final (label, size) in const [
      ('a small phone', phone),
      ('a tablet', tablet),
      ('landscape', landscape),
    ]) {
      testWidgets('the lane lays out on $label', (tester) async {
        await pumpGameScreen(tester, frog(), size: size);
        await tester.pump();
        expect(tester.takeException(), isNull);
      });
    }

    testWidgets('every lane size lays out', (tester) async {
      for (final n in [3, 4, 5]) {
        await pumpGameScreen(tester, frog(perSide: n), size: phone);
        await tester.pump();
        expect(tester.takeException(), isNull, reason: '$n a side');
      }
    });

    testWidgets('the puzzle mode lays out and shows its move count',
        (tester) async {
      await pumpGameScreen(tester, frog(mode: FrogMode.puzzle), size: phone);
      await tester.pump();
      expect(tester.takeException(), isNull);
      expect(find.text('0'), findsWidgets);
    });

    testWidgets('undo starts disabled and there is no crash on tapping it',
        (tester) async {
      await pumpGameScreen(tester, frog(), size: phone);
      await tester.pump();
      // The control is present and dimmed rather than hidden.
      final undo = find.byType(UndoButton);
      expect(undo, findsOneWidget);
      expect(tester.widget<UndoButton>(undo).enabled, isFalse);
      await tester.tap(undo, warnIfMissed: false);
      await tester.pump();
      expect(tester.takeException(), isNull);
    });
  });

  group('Four-in-a-Row', () {
    for (final (label, size) in const [
      ('a small phone', phone),
      ('a tablet', tablet),
      ('landscape', landscape),
    ]) {
      testWidgets('the frame lays out on $label', (tester) async {
        await pumpGameScreen(tester, four(), size: size);
        await tester.pump();
        expect(tester.takeException(), isNull);
      });
    }

    testWidgets('every offered board size lays out', (tester) async {
      for (final (cols, rows) in FourConfig.sizes) {
        await pumpGameScreen(tester, four(cols: cols, rows: rows), size: phone);
        await tester.pump();
        expect(tester.takeException(), isNull, reason: '$cols×$rows');
      }
    });

    testWidgets('a tap on a column drops a disc and hands the turn over',
        (tester) async {
      await pumpGameScreen(tester, four(), size: phone);
      await tester.pump();
      expect(find.text("Mira's turn — tap a column"), findsOneWidget);

      // Tap the middle of the board — any column will do.
      await tester.tapAt(tester.getCenter(find.byType(CustomPaint).first));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(find.text("Mira's turn — tap a column"), findsNothing);
    });

    testWidgets('undo is available after a drop and dead before one',
        (tester) async {
      await pumpGameScreen(tester, four(), size: phone);
      await tester.pump();
      final undo = find.byType(UndoButton);
      expect(undo, findsOneWidget);
      expect(tester.widget<UndoButton>(undo).enabled, isFalse);

      await tester.tapAt(tester.getCenter(find.byType(CustomPaint).first));
      await tester.pumpAndSettle();
      expect(tester.widget<UndoButton>(undo).enabled, isTrue);

      await tester.tap(undo);
      await tester.pumpAndSettle();
      expect(find.text("Mira's turn"), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });

  group('Updraft', () {
    testWidgets('the arena opens at frame zero and lays out', (tester) async {
      await pumpGameScreen(tester, PlayUpdraftScreen(module: registryModule('updraft')),
          size: phone);
      await tester.pump();
      expect(tester.takeException(), isNull);
      expect(find.text('Tap to rise'), findsOneWidget);
      // Unmount so the ticker is disposed.
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump(const Duration(milliseconds: 50));
    });

    testWidgets('a tap starts the run', (tester) async {
      await pumpGameScreen(tester, PlayUpdraftScreen(module: registryModule('updraft')),
          size: phone);
      await tester.pump();
      await tester.tapAt(const Offset(160, 300));
      await tester.pump(const Duration(milliseconds: 100));
      expect(tester.takeException(), isNull);
      expect(find.text('Tap to rise'), findsNothing);
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump(const Duration(milliseconds: 50));
    });

    testWidgets('the arena lays out on a tablet too', (tester) async {
      await pumpGameScreen(tester, PlayUpdraftScreen(module: registryModule('updraft')),
          size: tablet);
      await tester.pump();
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump(const Duration(milliseconds: 50));
    });
  });

  group('Undercover', () {
    testWidgets('the deal opens on the peek guard, with nothing secret on screen',
        (tester) async {
      await pumpGameScreen(tester, undercover(), size: phone);
      await tester.pump();
      expect(find.text('Pass the phone to'), findsOneWidget);
      // No word is on screen before anyone has confirmed who they are.
      expect(find.textContaining('Your word'), findsNothing);
    });

    testWidgets('confirming a name covers the card, and a tap reveals it',
        (tester) async {
      await pumpGameScreen(tester, undercover(), size: phone);
      await tester.pump();

      await tester.tap(find.byType(PrimaryPill).first);
      await tester.pumpAndSettle();
      expect(find.text('Your word is under here'), findsOneWidget);

      await tester.tap(find.text('Tap the card to reveal'));
      await tester.pumpAndSettle();
      expect(find.text('YOUR WORD'), findsOneWidget);
      expect(find.text('Hide and pass on'), findsOneWidget);
    });

    testWidgets('the whole deal can be walked through to the describe round',
        (tester) async {
      await pumpGameScreen(tester, undercover(), size: phone);
      await tester.pump();

      for (var i = 0; i < 5; i++) {
        // "I'm <name>" → cover → reveal → hide → continue.
        await tester.tap(find.byType(PrimaryPill).first);
        await tester.pumpAndSettle();
        await tester.tap(find.text('Tap the card to reveal'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Hide and pass on'));
        await tester.pumpAndSettle();
        await tester.tap(find.byType(PrimaryPill).first);
        await tester.pumpAndSettle();
      }

      expect(find.text('Everyone has\nlooked.'), findsOneWidget);
      await tester.tap(find.text('Start round 1'));
      await tester.pumpAndSettle();
      expect(find.text('Now describing'), findsOneWidget);
      expect(find.text('SPEAKING ORDER'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('a whole round runs: describe, vote, reveal', (tester) async {
      await pumpGameScreen(tester, undercover(), size: phone);
      await tester.pump();

      // Deal all five cards.
      for (var i = 0; i < 5; i++) {
        await tester.tap(find.byType(PrimaryPill).first);
        await tester.pumpAndSettle();
        await tester.tap(find.text('Tap the card to reveal'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Hide and pass on'));
        await tester.pumpAndSettle();
        await tester.tap(find.byType(PrimaryPill).first);
        await tester.pumpAndSettle();
      }
      await tester.tap(find.text('Start round 1'));
      await tester.pumpAndSettle();

      // Describe: one tap per speaker, then the vote opens.
      for (var i = 0; i < 5; i++) {
        await tester.tap(find.byType(PrimaryPill).first);
        await tester.pumpAndSettle();
      }
      expect(find.text('Who is out?'), findsOneWidget);
      expect(find.text('One tap each. Tap again to take a vote back.'), findsOneWidget);
      expect(find.text('Votes cast'), findsOneWidget);
      expect(find.text('0 / 5'), findsOneWidget);

      // The button is dead until every living player has voted.
      expect(tester.widget<PrimaryPill>(find.byType(PrimaryPill).first).enabled,
          isFalse);

      // **Three votes on one name** — the case the sequential-voter model made
      // impossible, and the reason this test exists.
      for (var i = 0; i < 3; i++) {
        await tester.tap(find.text('Ana'));
        await tester.pumpAndSettle();
      }
      expect(find.text('3 / 5'), findsOneWidget);
      // The row carries the numeral, and one accent dot per vote beside it.
      expect(find.text('3'), findsOneWidget, reason: "Ana's count");
      expect(_dotsFor(tester, 'Ana'), 3);
      expect(_dotsFor(tester, 'Priya'), 0, reason: 'an unvoted row has no dots');

      // …and the rest land elsewhere.
      await tester.tap(find.text('Priya'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Noor'));
      await tester.pumpAndSettle();
      expect(find.text('5 / 5'), findsOneWidget);
      expect(_dotsFor(tester, 'Priya'), 1);
      expect(_dotsFor(tester, 'Noor'), 1);

      // Full ballot: the button names the leader and is live.
      final button = tester.widget<PrimaryPill>(find.byType(PrimaryPill).first);
      expect(button.enabled, isTrue);
      expect(button.label, 'Vote out Ana');

      await tester.tap(find.byType(PrimaryPill).first);
      await tester.pumpAndSettle();
      // …and the reveal names a role.
      expect(find.text('Voted out'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('a full ballot takes a vote back on the next tap', (tester) async {
      await pumpGameScreen(tester, undercover(), size: phone);
      await tester.pump();
      for (var i = 0; i < 5; i++) {
        await tester.tap(find.byType(PrimaryPill).first);
        await tester.pumpAndSettle();
        await tester.tap(find.text('Tap the card to reveal'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Hide and pass on'));
        await tester.pumpAndSettle();
        await tester.tap(find.byType(PrimaryPill).first);
        await tester.pumpAndSettle();
      }
      await tester.tap(find.text('Start round 1'));
      await tester.pumpAndSettle();
      for (var i = 0; i < 5; i++) {
        await tester.tap(find.byType(PrimaryPill).first);
        await tester.pumpAndSettle();
      }

      // Fill the ballot on one name…
      for (var i = 0; i < 5; i++) {
        await tester.tap(find.text('Ana'));
        await tester.pumpAndSettle();
      }
      expect(find.text('5 / 5'), findsOneWidget);
      // …a sixth tap cannot over-fill it…
      await tester.tap(find.text('Ana'));
      await tester.pumpAndSettle();
      expect(find.text('4 / 5'), findsOneWidget,
          reason: 'a tap on a full ballot takes one back');
      // …and the freed vote can be re-cast somewhere else.
      await tester.tap(find.text('Priya'));
      await tester.pumpAndSettle();
      expect(find.text('5 / 5'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('nothing on the describe screen can leak a word', (tester) async {
      await pumpGameScreen(tester, undercover(), size: phone);
      await tester.pump();
      for (var i = 0; i < 5; i++) {
        await tester.tap(find.byType(PrimaryPill).first);
        await tester.pumpAndSettle();
        await tester.tap(find.text('Tap the card to reveal'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Hide and pass on'));
        await tester.pumpAndSettle();
        await tester.tap(find.byType(PrimaryPill).first);
        await tester.pumpAndSettle();
      }
      await tester.tap(find.text('Start round 1'));
      await tester.pumpAndSettle();

      // The describe screen holds the speaking order and nothing else.
      final onScreen = tester
          .widgetList<Text>(find.byType(Text))
          .map((t) => t.data ?? '')
          .toList();
      for (final pair in kUndercoverPairs) {
        expect(onScreen, isNot(contains(pair.civilian)));
        expect(onScreen, isNot(contains(pair.undercover)));
      }
    });
  });
}

/// The registered module, so a screen test uses the same instance the app does.
dynamic registryModule(String id) => kGameModules.firstWhere((m) => m.id == id);

/// How many vote dots the row for [name] is showing: 8×8 circles inside that
/// candidate's row. The dots are the thing a table reads across the room, so
/// they are asserted as dots rather than inferred from the numeral.
int _dotsFor(WidgetTester tester, String name) {
  final row = find.ancestor(
    of: find.text(name),
    matching: find.byType(Container),
  );
  return tester
      .widgetList<Container>(find.descendant(of: row.last, matching: find.byType(Container)))
      .where((c) {
        final box = c.constraints?.biggest;
        final decoration = c.decoration;
        return box?.width == 8 &&
            box?.height == 8 &&
            decoration is BoxDecoration &&
            decoration.shape == BoxShape.circle;
      })
      .length;
}
