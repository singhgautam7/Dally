import 'package:dally/features/games/solitaire/logic/cards.dart';
import 'package:dally/features/games/solitaire/logic/solitaire.dart';
import 'package:dally/features/games/solitaire/logic/solitaire_layout.dart';
import 'package:dally/features/games/solitaire/solitaire_config.dart';
import 'package:dally/features/games/solitaire/solitaire_module.dart';
import 'package:dally/features/games/solitaire/ui/play_solitaire_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/game_harness.dart';

void main() {
  Widget screen(int draw) => PlaySolitaireScreen(
        module: SolitaireModule(),
        config: SolitaireConfig(drawCount: draw),
      );

  for (final size in const [Size(320, 568), Size(360, 640), Size(430, 932)]) {
    testWidgets('the table lays out at ${size.width}×${size.height}',
        (tester) async {
      await pumpGameScreen(tester, screen(1), size: size);
      expect(tester.takeException(), isNull);
      expect(find.textContaining('Drag a card'), findsOneWidget);
    });
  }

  testWidgets('tapping the stock turns cards without throwing', (tester) async {
    await pumpGameScreen(tester, screen(3));
    // The stock sits at the top-left of the board area.
    final board = find.byType(CustomPaint).last;
    final topLeft = tester.getTopLeft(board);
    for (var i = 0; i < 5; i++) {
      await tester.tapAt(topLeft + const Offset(20, 20));
      await tester.pumpAndSettle();
    }
    expect(tester.takeException(), isNull);
  });

  testWidgets('tapping a card does not move it — drag is the only way',
      (tester) async {
    await pumpGameScreen(tester, screen(1));
    final state = tester.state(find.byType(PlaySolitaireScreen));
    final game = (state as dynamic).gameForTest as Solitaire;
    final before = game.tableau.map((c) => c.length).toList();
    final moves = game.moves;

    final board = find.byType(CustomPaint).last;
    final origin = tester.getTopLeft(board);
    final layout = SolitaireLayout(game, tester.getSize(board));
    // The exposed card of the last column is the one most likely to have a
    // legal home — tapping it must still do nothing at all.
    final card = layout.tableauRect(6, game.tableau[6].length - 1);
    await tester.tapAt(origin + card.center);
    await tester.pumpAndSettle();

    expect(game.tableau.map((c) => c.length).toList(), before);
    expect(game.moves, moves, reason: 'a tap is not a move');
  });

  testWidgets('a drag onto an illegal pile leaves the table untouched',
      (tester) async {
    await pumpGameScreen(tester, screen(1));
    final state = tester.state(find.byType(PlaySolitaireScreen));
    final game = (state as dynamic).gameForTest as Solitaire;
    final before = game.tableau.map((c) => c.length).toList();

    final board = find.byType(CustomPaint).last;
    final origin = tester.getTopLeft(board);
    final layout = SolitaireLayout(game, tester.getSize(board));
    final from = layout.tableauRect(6, game.tableau[6].length - 1).center;
    // Onto the stock, which never accepts a drop.
    final to = layout.stockRect.center;
    await tester.dragFrom(origin + from, to - from);
    await tester.pumpAndSettle();

    expect(game.tableau.map((c) => c.length).toList(), before);
  });

  testWidgets('a legal drag moves the run', (tester) async {
    await pumpGameScreen(tester, screen(1));
    final state = tester.state(find.byType(PlaySolitaireScreen));
    final game = (state as dynamic).gameForTest as Solitaire;

    // Rig a guaranteed-legal move: a red six onto a black seven.
    game.tableau[0]
      ..clear()
      ..add(const PlayingCard(7, Suit.spades));
    game.faceUpFrom[0] = 0;
    game.tableau[1]
      ..clear()
      ..add(const PlayingCard(6, Suit.hearts));
    game.faceUpFrom[1] = 0;
    await tester.pump();

    final board = find.byType(CustomPaint).last;
    final origin = tester.getTopLeft(board);
    final layout = SolitaireLayout(game, tester.getSize(board));
    final from = layout.tableauRect(1, 0).center;
    final to = layout.tableauRect(0, 0).center;
    await tester.dragFrom(origin + from, to - from);
    await tester.pumpAndSettle();

    expect(game.tableau[0], hasLength(2));
    expect(game.tableau[0].last, const PlayingCard(6, Suit.hearts));
    expect(game.tableau[1], isEmpty);
  });

  testWidgets('a cancelled drag puts the run back rather than losing it',
      (tester) async {
    await pumpGameScreen(tester, screen(1));
    final state = tester.state(find.byType(PlaySolitaireScreen));
    final game = (state as dynamic).gameForTest as Solitaire;
    final before = game.tableau.map((c) => c.length).toList();

    final board = find.byType(CustomPaint).last;
    final origin = tester.getTopLeft(board);
    final layout = SolitaireLayout(game, tester.getSize(board));
    final from = layout.tableauRect(6, game.tableau[6].length - 1).center;

    final gesture = await tester.startGesture(origin + from);
    await gesture.moveBy(const Offset(0, -80));
    await tester.pump();
    await gesture.cancel();
    await tester.pumpAndSettle();

    expect(game.tableau.map((c) => c.length).toList(), before);
    // Nothing is left held: the next drag starts clean.
    expect(tester.takeException(), isNull);
  });
}
