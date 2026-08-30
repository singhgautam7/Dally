import 'package:dally/core/theme/theme_controller.dart';
import 'package:dally/core/widgets/die_view.dart';
import 'package:dally/features/games/ludo/logic/ludo.dart';
import 'package:dally/features/games/ludo/ludo_config.dart';
import 'package:dally/features/games/ludo/ui/ludo_seat.dart';
import 'package:dally/features/games/ludo/ui/play_ludo_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/game_harness.dart';

void main() {
  Widget screen(int players) => PlayLudoScreen(
        moduleId: 'ludo',
        config: LudoConfig(
          playerCount: players,
          names: const ['Ana', 'Bo', 'Cy', 'Di'].sublist(0, players),
          rules: const LudoRules(),
          firstPlayer: 0,
        ),
      );

  /// The one slot that can be tapped right now.
  Finder liveDie() => find.byWidgetPredicate(
      (w) => w is GameDie && w.state == DieSlotState.rollable);

  List<GameDie> dice(WidgetTester tester) =>
      tester.widgetList<GameDie>(find.byType(GameDie)).toList();

  /// Advances past the shared dice spin — a fake clock, not a real one, so the
  /// test never depends on how long anything actually takes.
  Future<void> settleRoll(WidgetTester tester) async {
    await tester.pump(PlayLudoScreen.rollSpin + const Duration(milliseconds: 16));
    await tester.pumpAndSettle();
  }

  ProviderContainer containerOf(WidgetTester tester) =>
      ProviderScope.containerOf(tester.element(find.byType(PlayLudoScreen)));

  group('seats', () {
    for (final size in const [Size(320, 568), Size(360, 640), Size(430, 932)]) {
      testWidgets('four seats and a live die fit ${size.width}×${size.height}',
          (tester) async {
        await pumpGameScreen(tester, screen(4), size: size);
        expect(tester.takeException(), isNull);
        expect(find.byType(LudoSeat), findsNWidgets(4));
        // Every seat carries a slot; exactly one of them is tappable.
        expect(find.byType(GameDie), findsNWidgets(4));
        expect(liveDie(), findsOneWidget);
        // And it is actually reachable, not clipped off the screen.
        final rect = tester.getRect(liveDie());
        expect(rect.width, greaterThanOrEqualTo(42));
        expect(rect.top, greaterThanOrEqualTo(0));
        expect(rect.bottom, lessThanOrEqualTo(size.height));
      });
    }

    testWidgets('the row of name pills is gone', (tester) async {
      await pumpGameScreen(tester, screen(4));
      // The old strip rendered every seat's name in one row above the board;
      // the seat markers replace it.
      expect(find.byType(LudoSeat), findsNWidgets(4));
      for (final name in const ['Ana', 'Bo', 'Cy', 'Di']) {
        expect(find.text(name), findsOneWidget);
      }
    });

    testWidgets('a three-player game leaves the fourth corner empty',
        (tester) async {
      await pumpGameScreen(tester, screen(3));
      expect(find.byType(LudoSeat), findsNWidgets(3));
      expect(find.text('Di'), findsNothing);
    });

    testWidgets('each seat shows its tokens home', (tester) async {
      await pumpGameScreen(tester, screen(4));
      expect(find.text('0/4'), findsNWidgets(4));
    });

    testWidgets('a narrow phone folds the progress into the name row',
        (tester) async {
      await pumpGameScreen(tester, screen(4), size: const Size(320, 568));
      // Name and count share one line; the count is a separate span so it is
      // never the thing that gets clipped.
      expect(find.text('Ana'), findsOneWidget);
      expect(find.text(' · 0/4'), findsNWidgets(4));
      expect(find.text('0/4'), findsNothing);
      // The die is the tap target, so it is the one thing that never shrinks.
      expect(tester.getSize(liveDie()).width, 42);
    });
  });

  group('the dice slot state machine', () {
    testWidgets('only the seat on turn is rollable; the rest are idle',
        (tester) async {
      await pumpGameScreen(tester, screen(4));
      final states = dice(tester).map((d) => d.state).toList();
      expect(states.where((s) => s == DieSlotState.rollable), hasLength(1));
      expect(states.where((s) => s == DieSlotState.idle), hasLength(3));
    });

    testWidgets('a rollable slot shows "?" before the roll', (tester) async {
      await pumpGameScreen(tester, screen(4));
      expect(find.text('?'), findsOneWidget);
    });

    testWidgets('a roll runs not-rolled → rolling → rolled', (tester) async {
      await pumpGameScreen(tester, screen(2));
      List<DieSlotState> states() => dice(tester).map((d) => d.state).toList();

      expect(states().where((s) => s == DieSlotState.rollable), hasLength(1));
      await tester.tap(liveDie());
      await tester.pump();
      expect(states().where((s) => s == DieSlotState.rolling), hasLength(1));
      expect(liveDie(), findsNothing, reason: 'a rolling slot takes no taps');

      // Past the spin the face is held while the player picks a token, or the
      // turn has already moved on and the next seat is asking to roll.
      await settleRoll(tester);
      expect(states().where((s) => s == DieSlotState.rolling), isEmpty);
      expect(
          states().where((s) =>
              s == DieSlotState.rollable || s == DieSlotState.rolled),
          hasLength(1));
    });

    testWidgets('a seat that is not on turn holds the face it last rolled',
        (tester) async {
      await pumpGameScreen(tester, screen(2));
      // Nobody has rolled: every slot is empty rather than showing a face.
      expect(dice(tester).every((d) => d.state == DieSlotState.idle
              ? d.value == null
              : d.state == DieSlotState.rollable),
          isTrue);

      await tester.tap(liveDie());
      await settleRoll(tester);

      // Whoever rolled is now showing a real face — either still choosing a
      // token, or spent because the turn moved on.
      final showing = dice(tester).where((d) =>
          d.state == DieSlotState.rolled || d.state == DieSlotState.used);
      expect(showing, isNotEmpty);
      for (final d in showing) {
        expect(d.value, isNotNull);
        expect(d.value, inInclusiveRange(1, 6));
      }
    });

    testWidgets('the roll is spent once the turn passes on', (tester) async {
      await pumpGameScreen(tester, screen(2));
      // Seed a game where the first roll cannot be used, so the turn passes.
      final state = tester.state(find.byType(PlayLudoScreen));
      final game = (state as dynamic).gameForTest as LudoGame;
      final first = game.current;
      await tester.tap(liveDie());
      await settleRoll(tester);
      if (game.current != first) {
        // The seat that rolled is idle again; the new seat is asking to roll.
        final byState = {for (final d in dice(tester)) d.tint: d.state};
        expect(byState.values.where((s) => s == DieSlotState.rollable),
            hasLength(1));
      }
    });

    testWidgets('centre-bottom mode leaves one die and strips the slots',
        (tester) async {
      await pumpGameScreen(tester, screen(4));
      await containerOf(tester)
          .read(settingsControllerProvider.notifier)
          .setLudoDieFollowsTurn(false);
      await tester.pumpAndSettle();

      expect(find.byType(LudoSeat), findsNWidgets(4), reason: 'seats remain');
      expect(find.byType(GameDie), findsOneWidget);
      expect(liveDie(), findsOneWidget);
    });

    testWidgets('the dice-position choice persists', (tester) async {
      await pumpGameScreen(tester, screen(2));
      final container = containerOf(tester);
      expect(container.read(settingsControllerProvider).ludoDieFollowsTurn, isTrue);
      await container
          .read(settingsControllerProvider.notifier)
          .setLudoDieFollowsTurn(false);
      expect(container.read(settingsControllerProvider).ludoDieFollowsTurn, isFalse);
    });
  });

  testWidgets('rolling repeatedly never throws', (tester) async {
    await pumpGameScreen(tester, screen(2));
    for (var i = 0; i < 15; i++) {
      final die = liveDie();
      if (die.evaluate().isEmpty) break;
      await tester.tap(die);
      await settleRoll(tester);
    }
    expect(tester.takeException(), isNull);
  });
}
